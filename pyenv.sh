#!/bin/bash

venv=""
freeze=""
clean=0
all=0
while getopts "hr:v:p:ca" opt; do
  case $opt in
    h)
        echo "Create Usage: $0 -p /path/to/new/env -r pip-requirements-file -v python-version"
        echo "   OR"
        echo "Delete Usage: $0 -p /path/to/new/env -c [-a]"
        echo "   -a removes sources and local installs" 
        exit 1
      ;;
    r)
        freeze=$OPTARG
      ;;
    v)
        version=$OPTARG
      ;;
    p)
        venv=$OPTARG
      ;;
    c)
        clean=1
      ;;
    a)
        all=1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
    *)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done


if [ "$venv" == "" ]; then
    echo "-p <path> is required"
    exit 1
fi

# SETUP 
ROOT="`readlink -f "$venv"`"
PREFIX="$ROOT/local"
DN=/dev/null

if [ $clean -eq 1 ]; then
    echo "  - Removing Virtual environment basics"
    rm -rf "$ROOT/lib" 2> $DN
    rm -rf "$ROOT/bin" 2> $DN
    
    if [ $all -eq 1 ]; then
        echo "  - Removing all sources"
        rm -rf "$ROOT/src" 2> $DN
        rm -rf "$ROOT/local" 2> $DN
    fi
    exit 0
fi
        
echo "* Setting Up..."

# Set the basics
mkdir -p "$ROOT/src"
mkdir -p "$ROOT/local"
mkdir -p "$ROOT/bin"
mkdir -p "$ROOT/lib"

SRCDIR="$ROOT/src"

LIBDIR="$PREFIX/lib"
LIB64DIR="$PREFIX/lib64"
INCDIR="$PREFIX/include"
BINDIR="$ROOT/bin"

PYVER=`echo "$version" | cut -d'.' -f1`
PYVER="$PYVER.`echo "$version" | cut -d'.' -f2`"

# We use it a lot
PREOPT="--prefix=$PREFIX"


PYTHON=`which python`
echo "* Checking $PREFIX/bin/python$PYVER"
if [ -f "$PREFIX/bin/python$PYVER" ]; then
    PYTHON="$PREFIX/bin/python$PYVER"
fi

# Allow user to provide tools like autoconf...
export PATH=~/bin:$PATH
export LD_LIBRARY_PATH="$LIBDIR:$LIB64DIR"
export C_INCLUDE_PATH="$INCDIR/ncurses:$INCDIR/readline:$INCDIR/libxslt/:$INCDIR/libxml2:$PREFIX/lib/libffi-3.2.1/include:$C_INCLUDE_PATH"

#
# Activate the environment
#
function activate() {
    echo "* Changing to new environment ($BINDIR/activate)"
    source $BINDIR/activate
    if [ $? -ne 0 ]; then
        echo "Failed to source new environment!!!!"
        exit 4
    fi
}

function freezeInstall() {
    if [ "$freeze" == "" ]; then
        echo " * Skipping requirements"
        return
    fi
    if [ ! -f "$freeze" ]; then
        echo " * Requirements File NOT FOUND?!"
        return
    fi
    
    pip install -r $freeze
}

function downloadSrc {
    what=$1
    base=$2
    echo "  - Checking $SRCDIR/$base"
    if [ ! -e "$SRCDIR/$base" ]; then
        echo "  - Getting it..."
        wget --no-check-certificate $what -O "$SRCDIR/$base"
    fi
}

#
# UNZIP/TAR if required
# 
function unzipSrc {
    what=$1
    folder=$2
    echo " * UNZIP: $what"
    if [ ! -d "$SRCDIR/$folder" ]; then
        (cd "$SRCDIR" && unzip "$what")
    fi
}

function untarSrc {
    what=$1
    folder=$2
    echo " * UNTAR: $what"
    if [ ! -d "$SRCDIR/$folder" ]; then
        (cd "$SRCDIR" && tar -xvf "$what")
    fi
}

#
# Basic python only installation
#
function installPython {
    base="Python-$version.tgz"
    folder="Python-$version"
    file="https://www.python.org/ftp/python/$version/Python-$version.tgz"
    
    downloadSrc "$file" "$base"
    untarSrc "$base" "$folder"
    
    p=`pwd`
    
    if [ -f "$SRCDIR/$folder/python" ]; then
        echo " - python is build... skipping"
        return
    fi
    
    cd "$SRCDIR/$folder"
    
    make clean
    ./configure --enable-shared $PREOPT
    
    # Take care of cross compile
    sed -i "s|/usr/local/lib|$PREFIX/lib|" ./setup.py
    sed -i "s|/usr/local/include|$PREFIX/include|" ./setup.py
    
    make && make install
    # if successfull set the new python
    if [ -e "$PREFIX/bin/python" ]; then
        echo "  - Setting new python to \"$PREFIX/bin/python\""
        PYTHON=$PREFIX/bin/python
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
    
    echo " * Installing lib $base"
    
    if [ -e "$INCDIR/$checkFile" ]; then 
        echo "  - Skipping, seems installed"
        return
    fi
    
    p=`pwd`
    downloadSrc "$url" "$base"
    untarSrc "$base" "$folder" 2> $DN
    if [ $? -ne 0 ]; then
        unzipSrc "$base" "$folder"
    fi
    
    # Get in the folder
    cd "$SRCDIR/$folder"
    
    
    # In any case
    export LD_LIBRARY_PATH="$LIBDIR:$LIB64DIR"
    
    makeArgs=""
    
    if [ $type == "autogen" ]; then
        echo "  - Running: './autogen.sh $opts'"
        ./autogen.sh $opts
    elif [ $type == "confmake" ]; then
        echo "  - Running: './configure $opts'"
        ./configure $opts
    elif [ $type == "confmake2" ]; then
        # bzlib
        makeArgs="PREFIX=$PREFIX"
        sed -i "s|CC=gcc|CC=gcc -fPIC|" ./Makefile
    fi
    
    echo "  - Running: 'make && make install $makeArgs'"
    make && make install $makeArgs
    
    cd "$p"
}


if [ "$version" != "" ]; then

    # DEPENDENCIES
    installLib "http://ftp.gnu.org/pub/gnu/ncurses/ncurses-6.0.tar.gz" \
               "ncurses-6.0.tar.gz" \
               "ncurses-6.0" \
               "ncurses/curses.h" \
               "confmake" \
               "--with-shared --without-normal"
               
    installLib "ftp://ftp.cwru.edu/pub/bash/readline-6.3.tar.gz" \
               "readline-6.3.tar.gz" \
               "readline-6.3" \
               "readline/readline.h" \
               "confmake"
    
    installLib "http://prdownloads.sourceforge.net/libpng/zlib-1.2.8.tar.gz?download" \
               "zlib-1.2.8.tar.gz" \
               "zlib-1.2.8" \
               "zlib.h" \
               "confmake"
               
    installLib "http://www.bzip.org/1.0.6/bzip2-1.0.6.tar.gz" \
               "bzip2-1.0.6.tar.gz" \
               "bzip2-1.0.6" \
               "bzlib.h" \
               "confmake2"
    
    installLib "https://www.sqlite.org/2016/sqlite-autoconf-3110000.tar.gz" \
               "sqlite-autoconf-3110000.tar.gz" \
               "sqlite-autoconf-3110000" \
               "sqlite3.h" \
               "confmake"
               
               
    # INSTALL PYTHON
    installPython
    
    # POST-LIBS and TOOLS
    #  - SNMP/SMI
    installLib "https://www.ibr.cs.tu-bs.de/projects/libsmi/download/libsmi-0.5.0.tar.gz" \
               "libsmi-0.5.0.tar.gz" \
               "libsmi-0.5.0" \
               "smi.h" \
               "confmake"
               
    installLib "ftp://sourceware.org/pub/libffi/libffi-3.2.1.tar.gz" \
               "libffi-3.2.1.tar.gz" \
               "libffi-3.2.1" \
               "../lib/libffi-3.2.1/include/ffi.h" \
               "confmake"
    #  - LXML
    installLib "https://codeload.github.com/GNOME/libxml2/zip/master" \
               "libxml2.zip" \
               "libxml2-master" \
               "libxml2/libxml/xmlversion.h" \
               "autogen" \
               "--with-python=$PREFIX/bin/python$PYVER"
    
    installLib "https://codeload.github.com/GNOME/libxslt/zip/master" \
               "libxslt.zip" \
               "libxslt-master" \
               "libxslt/xslt.h" \
               "autogen" \
               " --with-libxml-prefix=$PREFIX"
fi


if [ ! -e "$ROOT/bin/python" ]; then
    echo "* Getting virtualenv..."
    rm ./virtualenv.py* 2> $DN; wget --no-check-certificate -q https://raw.github.com/pypa/virtualenv/master/virtualenv.py


    echo "* Creating base structure"
    echo "  - Using $PYTHON"
    $PYTHON -m ensurepip
    $PYTHON ./virtualenv.py -p "$PYTHON" --no-setuptools "$ROOT"
    mv ./virtualenv.py "$ROOT/bin/"
    rm ./virtualenv.pyc 2> $DN
    rm .__python__ 2> $DN

    # Add dynamic lib support: WARNING: NOT TESTED
    # :\$VIRTUAL_ENV/local/lib64 breaks OpenSSL with local cffi?!
    # 
    # Assuming ORACLE_HOME withing VENV
    # 
    echo -e "\n\n# Urban was here
    
export OLD_ORACLE_HOME=\"\$ORACLE_HOME\"
export OLD_LD_LIBRARY_PATH=\"\$LD_LIBRARY_PATH\"
export OLD_C_INCLUDE_PATH=\"\$C_INCLUDE_PATH\"

export ORACLE_HOME=\"\$VIRTUAL_ENV/addons/instantclient_12_1\"
LD_LIBRARY_PATH=\"\$VIRTUAL_ENV/local/lib:\$VIRTUAL_ENV/local/lib64:\$ORACLE_HOME:\$LD_LIBRARY_PATH\"
export C_INCLUDE_PATH=\"\$VIRTUAL_ENV/local/include:\$VIRTUAL_ENV/local/include/libxml2:\$VIRTUAL_ENV/local/lib/libffi-3.2.1/include:\$C_INCLUDE_PATH\"
export LD_LIBRARY_PATH\n" >> "$ROOT/bin/activate"
    
    sed -i "s|deactivate () {|deactivate () {\n\
    if [ ! \"\${1-}\" = \"nondestructive\" ] ; then\n\
        export ORACLE_HOME=\"\$OLD_ORACLE_HOME\"\n\
        export LD_LIBRARY_PATH=\"\$OLD_LD_LIBRARY_PATH\"\n\
        export C_INCLUDE_PATH=\"\$OLD_C_INCLUDE_PATH\"
    fi|" "$ROOT/bin/activate"


    activate

    echo "* Getting pip!"
    (cd "$ROOT/bin/" && rm ./get-pip.py* 2> $DN;  wget --no-check-certificate https://bootstrap.pypa.io/get-pip.py && $PYTHON ./get-pip.py)


    if [ $? -ne 0 ]; then
        echo "Failed to install pip"
        exit 4
    fi

    freezeInstall
else
    echo "Skipping Virtual environment cause it is there. If you want to clean it run:"
    echo "  $0 -c -p $ROOT"
fi
echo "All done, run the follwoing to activeate:"
echo "  source $PREFIX/bin/activate  "
echo -e "\n\n\n... DO NOT FORGET:\n"

echo -e "pip install cffi --global-option=build_ext --global-option=-I/data/env/devel2.7.10/local/lib/libffi-3.2.1/include --global-option=build_ext  --global-option=-L/data/env/devel2.7.10/lib64\n"

echo -e "pip install snimpy --global-option=build_ext --global-option=-I$PREFIX/lib/libffi-3.2.1/include --global-option=-I$PREFIX/include  --global-option=build_ext  --global-option=-L$PREFIX/lib64\n"

echo -e "OR lxml: export C_INCLUDE_PATH=$PREFIX/include/libxml2:$PREFIX/include && pip install lxml"
echo -e "OR lxml: export C_INCLUDE_PATH && pip install lxml"

echo -e "USE EXPORT C_INCLUDE_PATH and LD_LIBRARY_PATH before pip install"

echo "source $BINDIR/activate  "

exit 0
