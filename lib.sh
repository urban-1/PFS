#
# Functions
# 


#
# Echo on both screen and log
#
function prt {
    echo "$1" | tee -a "$LOGFILE" 1>&3
}

function freezeInstall() {
    if [ "$freeze" == "" ]; then
        prt " * Skipping requirements"
        return
    fi
    if [ ! -f "$freeze" ]; then
        prt " * Requirements File NOT FOUND?!"
        return
    fi
    
    pip install -r "$freeze"
}

function downloadSrc {
    what=$1
    base=$2
    prt "  - Checking $SRCDIR/$base"
    if [ ! -e "$SRCDIR/$base" ]; then
        prt "  - Getting it..."
        wget -q --no-check-certificate $what -O "$SRCDIR/$base"
    fi
}

 
function unzipSrc {
    what=$1
    folder=$2
    prt "  - unzip: $what"
    if [ ! -d "$SRCDIR/$folder" ]; then
        (cd "$SRCDIR" && unzip "$what")
    fi
}

function untarSrc {
    what=$1
    folder=$2
    prt "  - untar: $what"
    if [ ! -d "$SRCDIR/$folder" ]; then
        (cd "$SRCDIR" && tar -xvf "$what")
    fi
}

#
# Basic python installation
#
function installPython {
    prt " * Installing python $PYVER"
    
    base="Python-$version.tgz"
    folder="Python-$version"
    file="https://www.python.org/ftp/python/$version/Python-$version.tgz"
    
    downloadSrc "$file" "$base"
    untarSrc "$base" "$folder"
    
    p=`pwd`
    
    prt "  - Checking $PREFIX/bin/python$PYVER"
    if [ -e "$PREFIX/bin/python$PYVER" ]; then
        prt " - Python is build... skipping"
        return
    fi
    
    cd "$SRCDIR/$folder"
    
    make clean 2> $DN
    ./configure --enable-shared $PREOPT --enable-ipv6 --with-threads
    
    # Take care of cross compile
    sed -i "s|/usr/local/lib|$PREFIX/lib|" ./setup.py
    sed -i "s|/usr/local/include|$PREFIX/include|" ./setup.py
    
    make -j $cores && make install
    
    # if successfull set the new python
    if [ -e "$PREFIX/bin/python$PYVER" ]; then
        prt "  - Setting new python to \"$PREFIX/bin/python$PYVER\""
        PYTHON="$PREFIX/bin/python$PYVER"
    fi
    
    cd $p
}

#
# Install a library
#
function installLib {
    url="$1"; shift
    base="$1"; shift
    folder="$1"; shift
    checkFile="$1"; shift
    type="$1"; shift
    opts="$@ $PREOPT  --enable-shared"
    
    prt " * Installing lib $base"
    
    if [ -e "$INCDIR/$checkFile" ]; then 
        prt "  - Skipping, seems installed"
        return
    fi
    
    p=`pwd`
    downloadSrc "$url" "$base"
    untarSrc "$base" "$folder" 2> $DN
    if [ $? -ne 0 ]; then
        unzipSrc "$base" "$folder"
    fi
    if [ $? -ne 0 ]; then
        prt " !! FAILED TO EXTRACT"
        return
    fi
    
    # Get in the folder
    cd "$SRCDIR/$folder"
    prt "  - cd $SRCDIR/$folder"
    
    makeArgs=""
    confRC=0
    makeRC=0
    
    if [ $type == "autogen" ]; then
        prt "  - Running: './autogen.sh $opts'"
        ./autogen.sh $opts
        confRC=$?
    elif [ $type == "confmake" ]; then
        prt "  - Running: './configure $opts'"
        ./configure $opts
        confRC=$?
    elif [ $type == "confmake_readline" ]; then
        # readline needs to be linked against ncurses...
        # LD_LIBRARY_PATH is ignored
        makeArgs="SHLIB_LIBS=-lncurses"
        ./configure $opts
        confRC=$?
    elif [ $type == "confmake_db" ]; then
        # DB has multiple build directories...
        cd build_unix
        ../dist/configure $PREOPT $@
        confRC=$?
    elif [ $type == "confmake_ssl" ]; then
        # OpenSSL does not understand --enable-shared
        ./config $PREOPT $@
        confRC=$?
    elif [ $type == "confmake_bzlib" ]; then
        # bzlib... weird way to set prefix...
        makeArgs="PREFIX=$PREFIX"
        sed -i "s|CC=gcc|CC=gcc -fPIC|" ./Makefile
    fi
    
    if [ $confRC -ne 0 ]; then
        prt " !!! ERROR CONFIGURING ($confRC) !!!"
        cd "$p"
        return $confRC
    fi
    
    prt "  - Running: 'make $makeArgs && make $makeArgs install'"
    make $makeArgs -j $cores && make $makeArgs install 
    makeRC=$?
    
    cd "$p"
    
    if [ $makeRC -ne 0 ]; then
        prt " !!! ERROR MAKING !!!"
        cd "$p"
        return $makeRC
    fi
    
    return 0
}
