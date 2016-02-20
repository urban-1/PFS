#!/bin/bash

#
# 
#
function usage {
    echo
    echo "Create Usage:"
    echo
    echo "  $0 -p /path/to/new/env -v python-version [-r pip-requirements-file]"
    echo
    echo "  Options: "
    echo "  -p       Path to the new virtual environment"
    echo "  -v       Python version (optional) - if missing, autodiscover"
    echo "  -r       Python requirements file (optional)"
    echo 
    echo
    echo "Delete Usage:"
    echo
    echo "  $0 -p /path/to/new/env -c [-a]"
    echo
    echo "  Options:"
    echo "  -c       Clean Python virtual environment ('bin', 'lib' folders)"
    echo "  -a       Remove all except 'local' developement environment (optional)"
    echo
    echo "Build package:"
    echo
    echo "  $0 -p /path/to/new/env -b [/install/path/on/system]"
    echo
    echo "  Options:"
    echo "  -b       Build flag and installation path. If no path given '/usr/local' is the default"
    echo "  -v       Python version (optional) - if missing, autodiscover"
    echo 
    echo "Global options:"
    echo
    echo "  -h       This help message"
    echo "  -p       Path to the virtual environment"
    echo
    exit 1
}

venv=""
freeze=""
clean=0
all=0
buildPackage=0

while getopts ":hr:v:p:cab:" opt; do
  case $opt in
    h)
        usage
        ;;
    r)
        freeze=$OPTARG
        ;;
    v)
        version=$OPTARG
        ;;
    p)
        venv="$OPTARG"
        ;;
    c)
        clean=1
        ;;
    a)
        all=1
        ;;
    b)
        buildPackage=1
        INSTALL_PREFIX=$OPTARG
        ;;
    :)
        if [ "$OPTARG" == "b" ]; then
            buildPackage=1
            INSTALL_PREFIX="/usr/local"
            continue
        fi
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

# 
# SETUP  ---------------------------------------
# 
DN=/dev/null
mkdir -p $venv 2> $DN
ROOT="`readlink -f "$venv"`"
PREFIX="$ROOT/local"

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
# We use it a lot
PREOPT="--prefix=$PREFIX"

# Python version settings
PYTHON=`which python`
if [ "$version" != "" ]; then

    PYVER=`echo "$version" | cut -d'.' -f1`
    PYVER="$PYVER.`echo "$version" | cut -d'.' -f2`"

    echo "* Checking user-provided $PREFIX/bin/python$PYVER"
    if [ -f "$PREFIX/bin/python$PYVER" ]; then
        PYTHON="$PREFIX/bin/python$PYVER"
    fi
else
    # Try to figure it out
    echo "* Python version autodiscover..."
    if [ -e "$PREFIX/bin/python" ]; then
        PYTHON="$PREFIX/bin/python"
    fi
    
    PYVER=`$PYTHON -V 2>&1 | cut -d' ' -f2`
    PYVER=`echo "$PYVER" | cut -d'.' -f1,2`
    
    # In any case
    pypath=`dirname "$PYTHON"`
    echo "  - Found python $PYVER in $pypath"
fi

#
# BUILD PACKAGE
#
if [ $buildPackage -eq 1 ]; then
    echo "* Creating package from the local environment"
    echo "  - Environment Location: $PREFIX"
    echo "  - Installation Path: $INSTALL_PREFIX"
    
    # Check, checkinstall
    if [ "`which checkinstall`" == "" ]; then
        echo "!! checkinstall is required... "
        echo "!! You can manually cp -r $PREFIX /usr/local but is not suggested."
        exit 1
    fi
    
    checkinstall -D -y --install=no \
                 --fstrans=yes \
                 --pkgname="python-pfs" \
                 --maintainer="`whoami`" \
                 --provides=python \
                 --requires="?" \
                 --pkgversion=$PYVER
            cp -r "$PREFIX/*" "$INSTALL_PREFIX/*" 
    
    # Clean up
    rm ./description-pak
    rm -r ./doc-pak/
    exit 0
    

#
# CLEAN UP
#
elif [ $clean -eq 1 ]; then
    if [ "`readlink -f $ROOT`" == "/usr/local" ]; then
        echo "Get serious.."
        exit 1
    fi
    echo "  - Removing Virtual environment basics"
    rm -rf "$ROOT/lib" 2> $DN
    rm -rf "$ROOT/bin" 2> $DN
    
    if [ $all -eq 1 ]; then
        echo "  - Removing all sources"
        rm -rf "$ROOT/src" 2> $DN
    fi
    exit 0
fi

#
# BUILD DEV AND PYTHON ENVIRONMENTs
#
echo "** BUILDING IN $ROOT **"
echo "* Setting Up..."
    
# Allow user to provide tools like autoconf...
export PATH=~/bin:$PATH
export LD_LIBRARY_PATH="$LIBDIR:$LIB64DIR"
export C_INCLUDE_PATH="$INCDIR/ncurses:$INCDIR/readline:$INCDIR/libxslt/:$INCDIR/libxml2:$PREFIX/lib/libffi-3.2.1/include:$C_INCLUDE_PATH"

function freezeInstall() {
    if [ "$freeze" == "" ]; then
        echo " * Skipping requirements"
        return
    fi
    if [ ! -f "$freeze" ]; then
        echo " * Requirements File NOT FOUND?!"
        return
    fi
    
    export C_INCLUDE_PATH; export PATH export; install -r $freeze --global-option=build_ext  --global-option=-L$PREFIX/lib64 --global-option=-L$PREFIX/lib
}

function downloadSrc {
    what=$1
    base=$2
    echo "  - Checking $SRCDIR/$base"
    if [ ! -e "$SRCDIR/$base" ]; then
        echo "  - Getting it..."
        wget -q --no-check-certificate $what -O "$SRCDIR/$base"
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
    if [ -e "$PREFIX/bin/python$PYVER" ]; then
        echo "  - Setting new python to \"$PREFIX/bin/python$PYVER\""
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
    installLib "https://github.com/GNOME/libxml2/archive/master.tar.gz" \
               "libxml2.tar.gz" \
               "libxml2-master" \
               "libxml2/libxml/xmlversion.h" \
               "autogen" \
               "--with-python=$PREFIX/bin/python$PYVER"
    
    installLib "https://github.com/GNOME/libxslt/archive/master.tar.gz" \
               "libxslt.tar.gz" \
               "libxslt-master" \
               "libxslt/xslt.h" \
               "autogen" \
               " --with-libxml-prefix=$PREFIX"
fi


if [ ! -e "$ROOT/bin/python" ]; then
    echo "* Installing virtualenv..."
    if [ ! -e $SRCDIR/virtualenv-14.0.6.tar.gz ]; then
        echo "  - Getting virtualenv..."
        wget --no-check-certificate "https://pypi.python.org/packages/source/v/virtualenv/virtualenv-14.0.6.tar.gz" -O "$SRCDIR/virtualenv-14.0.6.tar.gz"
    fi
    if [ ! -e $SRCDIR/virtualenv-14.0.6 ]; then
        echo "  - Extracting virtualenv..."
        (cd $SRCDIR && tar -xvf virtualenv-14.0.6.tar.gz)
    fi


    echo "* Creating base structure"
    echo "  - Using $PYTHON"
    
    (cd $SRCDIR/virtualenv-14.0.6 && $PYTHON ./virtualenv.py --no-site-packages --no-setuptools "$ROOT")
    rc=$?
    mv ./virtualenv.py "$ROOT/bin/"
    rm ./virtualenv.pyc 2> $DN
    rm -r ./__pycache__ 2> $DN
    
    if [ $rc -ne 0 ]; then
        echo "Failed to build virtualenv..."
        exit 1
    fi
    # 
    # Handle export variables in `activate`
    # 
    echo -e "\n\n# Urban was here
    
OLD_ORACLE_HOME=\"\$ORACLE_HOME\"
OLD_LD_LIBRARY_PATH=\"\$LD_LIBRARY_PATH\"
OLD_C_INCLUDE_PATH=\"\$C_INCLUDE_PATH\"

export ORACLE_HOME=\"\$VIRTUAL_ENV/addons/instantclient_12_1\"
LD_LIBRARY_PATH=\"\$VIRTUAL_ENV/local/lib:\$VIRTUAL_ENV/local/lib64:\$ORACLE_HOME:\$LD_LIBRARY_PATH\"
export C_INCLUDE_PATH=\"\$VIRTUAL_ENV/local/include:\$VIRTUAL_ENV/local/include/libxml2:\$VIRTUAL_ENV/local/lib/libffi-3.2.1/include:\$C_INCLUDE_PATH\"
export LD_LIBRARY_PATH\n" >> "$ROOT/bin/activate"
    
    #
    # Clean up in deactivate...
    #
    sed -i "s|deactivate () {|deactivate () {\n\
    if [ ! \"\${1-}\" = \"nondestructive\" ] ; then\n\
        export ORACLE_HOME=\"\$OLD_ORACLE_HOME\"\n\
        export LD_LIBRARY_PATH=\"\$OLD_LD_LIBRARY_PATH\"\n\
        export C_INCLUDE_PATH=\"\$OLD_C_INCLUDE_PATH\"\n\
    fi|" "$ROOT/bin/activate"


    echo "* Changing to new environment ($BINDIR/activate)"
    source "$BINDIR/activate"
    
    echo "* Getting pip"
    
    # Use source python...
    cd "$ROOT/bin/" && rm ./get-pip.py* 2> $DN;  wget --no-check-certificate https://bootstrap.pypa.io/get-pip.py && python ./get-pip.py
    if [ $? -ne 0 ]; then
        echo "Failed to install pip"
        exit 4
    fi

    freezeInstall
else
    echo "* Skipping Virtual environment cause it is there. If you want to clean it run:"
    echo "  $0 -c -p $ROOT"
fi

echo "All done, run the follwoing to activeate:"
echo "source $BINDIR/activate  "

# --global-options:
# pip install snimpy --global-option=build_ext --global-option=-I$PREFIX/lib/libffi-3.2.1/include --global-option=-I$PREFIX/include  --global-option=build_ext  --global-option=-L$PREFIX/lib64
# 
# Using the env C_INCLUDE_PATH which should have all correct paths:
# export C_INCLUDE_PATH && pip install cffi --global-option=build_ext  --global-option=-L$VIRTUAL_ENV/lib64
# export C_INCLUDE_PATH && pip install lxml
# 
# Exporting extra variables
#  - TMPDIR: if /tmp mode is -x... (pycrypto needs it)
#  - PATH: Override system scripts (I needed it for autotools - wrong SheBang)
#  
# export PATH; export TMPDIR=~/tmp ; export C_INCLUDE_PATH && pip install pycrypto
# export PATH; export TMPDIR=~/tmp; export C_INCLUDE_PATH && pip install cffi --global-option=build_ext  --global-option=-L$VIRTUAL_ENV/lib64


exit 0
