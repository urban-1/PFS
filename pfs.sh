#!/bin/bash

#
# PFS: Python From Scratch
# 
# Compile python from scratch, install in a local development environment and 
# create a python virtual environment on top, that has no system dependencies.
#

. "`dirname $0`/lib.sh"

function usage {
    echo
    echo "Create environment:"
    echo
    echo "  $0 -p /path/to/new/env -v python-version [-r pip-requirements-file]"
    echo
    echo "  Options: "
    echo "  -p       Path to the new virtual environment"
    echo "  -v       Python version (optional) - if missing, autodiscover"
    echo "  -r       Python requirements file (optional)"
    echo "  -j       Number of cores/threads to use when compiling (default=2)"
    echo "  -s       Source/build directory (optional - default is <path>/src)"
    echo 
    echo
    echo "Delete environment:"
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
    echo "  -R       Build .rpm (RHEL)"
    echo "  -D       Build .deb (Debian)"
    echo "  -S       Build .tgz (SlackWare)"
    echo 
    echo "Global options:"
    echo
    echo "  -d       Bebug mode == show output"
    echo "  -h       This help message"
    echo "  -p       Path to the virtual environment"
    echo
    exit 1
}

# option vars
venv=""
freeze=""
clean=0
all=0
buildPackage=0
buildType=""
verbose=0
cores=2
srcdir=""

while getopts ":hr:v:p:cab:DRSdj:s:" opt; do
  case $opt in
    h) usage ;;
    r) freeze="$OPTARG" ;;
    v) version="$OPTARG" ;;
    p) venv="$OPTARG" ;;
    s) srcdir="$OPTARG";;
    c) clean=1 ;;
    a) all=1 ;;
    d) verbose=1 ;;
    b)
        buildPackage=1
        INSTALL_PREFIX="$OPTARG"
        ;;
    R) buildType=R;;
    S) buildType=S;;
    D) buildType=D;;
    j)
        if [[ $OPTARG =~ ^-?[0-9]+$ ]]; then
            cores=$OPTARG
        else
            echo "!!! IGNORING number of cores/threads - not an integer ($OPTARG)"
        fi
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
if [ $? -ne 0 ]; then
    echo "*** NO PERMISSIONS ON '$venv'... ABORT ***"
    exit 1
fi

ROOT="`readlink -f "$venv"`"
PREFIX="$ROOT/local"

# Logging and verbosity
LOGDIR="$ROOT/log"
mkdir -p "$LOGDIR"
RND=$RANDOM
LOGFILE="$LOGDIR/build-$RND.log"
touch "$LOGFILE"

# Set verbosity
exec 3>&1
exec 4>&2


if [ $verbose -eq 0 ]; then
    exec 1>> "$LOGFILE"
    exec 2>> "$LOGFILE"
fi

# Create folders
mkdir -p "$ROOT/local"
mkdir -p "$ROOT/bin"
mkdir -p "$ROOT/lib"

SRCDIR="$ROOT/src"
if [ "$srcdir" != "" ]; then
    SRCDIR=$srcdir
fi
mkdir -p "$SRCDIR"


LIBDIR="$PREFIX/lib"
LIB64DIR="$PREFIX/lib64"
INCDIR="$PREFIX/include"
BINDIR="$ROOT/bin"
# We use it a lot
PREOPT="--prefix=$PREFIX"


prt " * Logfile Path: $LOGFILE"

#
# Python version settings
#
PYTHON=`which python`
if [ "$version" != "" ]; then

    PYVER=`echo "$version" | cut -d'.' -f1`
    PYVER="$PYVER.`echo "$version" | cut -d'.' -f2`"

    prt " * Checking user-provided $PREFIX/bin/python$PYVER"
    if [ -f "$PREFIX/bin/python$PYVER" ]; then
        PYTHON="$PREFIX/bin/python$PYVER"
    fi
else
    # Try to figure it out
    prt " * Python version autodiscover..."
    
    if [ -e "$PREFIX/bin/python" ]; then
        PYTHON="$PREFIX/bin/python"
    
    else
        tmp=`ls "$PREFIX/bin/python"{2..100}.{0..100} 2> $DN | sort | tail -n1`
        if [ "$tmp" != "" ]; then
            PYTHON="$tmp"
        fi
    fi
    
    PYVER=`$PYTHON -V 2>&1 | cut -d' ' -f2`
    PYVER=`echo "$PYVER" | cut -d'.' -f1,2`
    
    # In any case
    pypath=`dirname "$PYTHON"`
    prt "  - Found python $PYVER in $pypath"
fi

#
# BUILD PACKAGE
#
if [ $buildPackage -eq 1 ]; then
    prt " * Creating package from the local environment"
    prt "  - Environment Location: $PREFIX"
    prt "  - Installation Path: $INSTALL_PREFIX"
    
    # Check, checkinstall
    if [ "`which checkinstall`" == "" ]; then
        echo "!! checkinstall is required... "
        echo "!! You can manually cp -r $PREFIX /usr/local but is not suggested."
        exit 1
    fi
    
    if [ "$buildType" == "" ]; then
        buildType="D"
    fi
    
    prt " * Build Type $buildType"
    
    echo "Custom python build

Build with PFS for $($PYTHON -V)
" > ./description-pak
    
    prt " * Building package: this will take time, go refill your coffee..."
    
    echo "#!/bin/bash

mkdir -p \"$INSTALL_PREFIX\" 2> /dev/null
cd \"$PREFIX\" && tar -cf - --exclude=\"lib/python$PYVER/**/tests/*\" \\
                           --exclude=\"lib/python$PYVER/test/*\" \\
                           --exclude=\"lib/python$PYVER/**/test/*\" \\
                           --exclude=\"lib/python$PYVER/**/idle_test/*\" \\
                           --exclude=\"*.pyo\" \\
                           --exclude=\"docs/*\" \\
                           --exclude=\"share/man/*\" \\
                           --exclude=\"share/info/*\" \\
                           --exclude=\"ssl/man/*\" \\
                           --exclude=\"share/doc/*\" \\
                           --exclude=\"share/gtk-doc/*\" \\
                           --exclude=\"share/pibs/*\" \\
                           --exclude=\"share/mibs/*\" \\
                           --exclude=\"*.a\" \\
                           --exclude=\"*.la\" \\
                           . | (cd "$INSTALL_PREFIX" && tar -xvf - )

exit 0
" > install.sh
    chmod +x ./install.sh
    
    checkinstall -$buildType -y \
                 --install=no \
                 --fstrans=yes \
                 --delspec=yes \
                 --deldoc=yes \
                 --deldesc=yes \
                 --pkgname="python-pfs" \
                 --maintainer="`whoami`" \
                 --provides=python \
                 --requires="libc6" \
                 --pkgversion=$PYVER \
                 --pkggroup="development" \
                 ./install.sh
    # Clean up
    rm ./install.sh
    rm ./description-pak 2> $DN
    exit 0

#
# CLEAN UP
#
elif [ $clean -eq 1 ]; then
    if [ "`readlink -f $ROOT`" == "/usr/local" ]; then
        echo "Get serious.."
        exit 1
    fi
    prt "  - Removing Virtual environment basics"
    rm -rf "$ROOT/lib" 2> $DN
    rm -rf "$ROOT/bin" 2> $DN
    
    if [ $all -eq 1 ]; then
        prt "  - Removing all sources"
        rm -rf "$ROOT/src" 2> $DN
    fi
    exit 0
fi

#
# BUILD DEV AND PYTHON ENVIRONMENTs
#
prt " ** BUILDING IN $ROOT with $cores cores **"
prt " * Setting Up..."
    
# Allow user to provide tools like autoconf...
# export PATH=~/bin:$PATH
export LD_LIBRARY_PATH="$LIBDIR:$LIB64DIR"
export C_INCLUDE_PATH="$INCDIR:$INCDIR/ncurses:$INCDIR/readline:$PREFIX/lib/libffi-$V_FFI/include:$C_INCLUDE_PATH"

# Load versions
V="`dirname $0`/versions.sh"
prt " * Loading versions from $V"
. "$V"




#
# If a version was given, we have to go through the installation process. Any
# already installed libs will be skipped
#
if [ "$version" != "" ]; then
    
    # Build... the build tools
    export PATH="$PREFIX/bin:$PATH"
    export LDFLAGS="-L$PREFIX/lib"
    
    if [ "`which m4`" == "" ]; then
        installLib "http://ftp.gnu.org/gnu/m4/m4-$V_M4.tar.gz" \
               "m4-$V_M4.tar.gz" \
               "m4-$V_M4" \
               "../bin/m4" \
               "confmake"
    fi
    
    if [ "`which shtool`" == "" ]; then
        installLib "ftp://ftp.gnu.org/gnu/shtool/shtool-$V_SHTOOL.tar.gz" \
               "shtool-$V_SHTOOL.tar.gz" \
               "shtool-$V_SHTOOL" \
               "../bin/shtool" \
               "confmake"
    fi
    
    if [ "`which autoconf`" == "" ]; then
        installLib "http://ftp.gnu.org/gnu/autoconf/autoconf-$V_AUTOCONF.tar.gz" \
               "autoconf-$V_AUTOCONF.tar.gz" \
               "autoconf-$V_AUTOCONF" \
               "../bin/autoconf" \
               "confmake"
    fi
    
    if [ "`which automake`" == "" ]; then
        installLib "http://ftp.gnu.org/gnu/automake/automake-$V_AUTOMAKE.tar.gz" \
               "automake-$V_AUTOMAKE.tar.gz" \
               "automake-$V_AUTOMAKE" \
               "../bin/automake" \
               "confmake"
    fi
    
    if [ "`which libtool`" == "" ]; then
        installLib "http://ftpmirror.gnu.org/libtool/libtool-$V_LIBTOOL.tar.gz" \
               "libtool-$V_LIBTOOL.tar.gz" \
               "libtool-$V_LIBTOOL" \
               "../bin/libtool" \
               "confmake"
    fi

    # DEPENDENCIES
    
    installLib "http://tukaani.org/xz/xz-$V_XZ.tar.gz" \
               "xz-$V_XZ.tar.gz" \
               "xz-$V_XZ" \
               "lzma.h" \
               "confmake"
               
    installLib "http://ftp.gnu.org/pub/gnu/ncurses/ncurses-$V_NCURSES.tar.gz" \
               "ncurses-$V_NCURSES.tar.gz" \
               "ncurses-$V_NCURSES" \
               "ncurses/curses.h" \
               "confmake" \
               "--with-shared" # --without-normal
    
    installLib "https://ftp.gnu.org/gnu/readline/readline-$V_READLINE.tar.gz" \
               "readline-$V_READLINE.tar.gz" \
               "readline-$V_READLINE" \
               "readline/readline.h" \
               "confmake_readline"
    
    installLib "http://prdownloads.sourceforge.net/libpng/zlib-$V_ZLIB.tar.gz?download" \
               "zlib-$V_ZLIB.tar.gz" \
               "zlib-$V_ZLIB" \
               "zlib.h" \
               "confmake"
               
    installLib "http://www.bzip.org/$V_BZ2/bzip2-$V_BZ2.tar.gz" \
               "bzip2-$V_BZ2.tar.gz" \
               "bzip2-$V_BZ2" \
               "bzlib.h" \
               "confmake_bzlib"
    
    installLib "https://www.sqlite.org/2016/sqlite-autoconf-$V_SQLITE.tar.gz" \
               "sqlite-autoconf-$V_SQLITE.tar.gz" \
               "sqlite-autoconf-$V_SQLITE" \
               "sqlite3.h" \
               "confmake"
               
    installLib "ftp://ftp.gnu.org/gnu/gdbm/gdbm-$V_GDBM.tar.gz" \
               "gdbm-$V_GDBM.tar.gz" \
               "gdbm-$V_GDBM" \
               "gdbm.h" \
               "confmake"
               
#     Not found by python...
#     installLib "http://download.oracle.com/berkeley-db/db-$V_DBM.tar.gz" \
#                "db-$V_DBM.tar.gz" \
#                "db-$V_DBM" \
#                "db.h" \
#                "confmake_db" \
#                "--enable-compat185 --enable-dbm --enable-cxx"
               
    installLib "https://github.com/openssl/openssl/archive/OpenSSL_$V_SSL.tar.gz" \
               "OpenSSL_$V_SSL.tar.gz" \
               "openssl-OpenSSL_$V_SSL" \
               "openssl/ssl.h" \
               "confmake_ssl" \
               "shared zlib threads"

    # Required for libxml2
    export ACLOCAL_PATH=/usr/local/share/aclocal:/usr/share/aclocal    
       
    # INSTALL PYTHON
    installPython
    
    # POST-LIBS and TOOLS
    #  - SNMP/SMI
    installLib "https://www.ibr.cs.tu-bs.de/projects/libsmi/download/libsmi-$V_SMI.tar.gz" \
               "libsmi-$V_SMI.tar.gz" \
               "libsmi-$V_SMI" \
               "smi.h" \
               "confmake"
               
    installLib "ftp://sourceware.org/pub/libffi/libffi-$V_FFI.tar.gz" \
               "libffi-$V_FFI.tar.gz" \
               "libffi-$V_FFI" \
               "../lib/libffi-$V_FFI/include/ffi.h" \
               "confmake"
    #  - LXML
    installLib "https://github.com/GNOME/libxml2/archive/v$V_XML2.tar.gz" \
               "libxml2-$V_XML2.tar.gz" \
               "libxml2-$V_XML2" \
               "libxml2/libxml/xmlversion.h" \
               "autogen" \
               "--with-python=$PREFIX/bin/python$PYVER --disable-static --with-history"

    
    # Early export breaks ncurses build?
    export C_INCLUDE_PATH="$C_INCLUDE_PATH:$INCDIR/libxslt/:$INCDIR/libxml2"
    
    [ $? -eq 0 ] && installLib "https://github.com/GNOME/libxslt/archive/v$V_XSLT.tar.gz" \
               "libxslt-$V_XSLT.tar.gz" \
               "libxslt-$V_XSLT" \
               "libxslt/xslt.h" \
               "autogen" \
               " --with-libxml-prefix=$PREFIX"               
    
    installLib "http://pyyaml.org/download/libyaml/yaml-$V_YAML.tar.gz" \
            "yaml-$V_YAML.tar.gz" \
            "yaml-$V_YAML" \
            "yaml.h" \
            "confmake"
fi


if [ ! -e "$ROOT/bin/python" ] && [ "$ROOT" != "/usr" ]; then
    prt " * Installing virtualenv..."
    if [ ! -e $SRCDIR/virtualenv-$V_VENV.tar.gz ]; then
        prt "  - Getting virtualenv..."
        wget -q --no-check-certificate "https://pypi.python.org/packages/source/v/virtualenv/virtualenv-$V_VENV.tar.gz" -O "$SRCDIR/virtualenv-$V_VENV.tar.gz"
    fi
    if [ ! -e $SRCDIR/virtualenv-$V_VENV ]; then
        prt "  - Extracting virtualenv..."
        (cd $SRCDIR && tar -xvf virtualenv-$V_VENV.tar.gz)
    fi


    prt " * Creating base structure"
    prt "  - Using $PYTHON"
    
    (cd $SRCDIR/virtualenv-$V_VENV && $PYTHON ./virtualenv.py --no-site-packages --no-setuptools "$ROOT")
    rc=$?
    rm ./*.pyc 2> $DN
    rm -r ./__pycache__ 2> $DN
    
    if [ $rc -ne 0 ]; then
        prt "Failed to build virtualenv..."
        exit 1
    fi
    # 
    # Handle export variables in `activate`
    # 
    echo -e "\n\n# Urban was here
    
OLD_ORACLE_HOME=\"\$ORACLE_HOME\"
OLD_LD_LIBRARY_PATH=\"\$LD_LIBRARY_PATH\"
OLD_C_INCLUDE_PATH=\"\$C_INCLUDE_PATH\"
OLD_LDFLAGS=\"\$LDFLAGS\"

export ORACLE_HOME=\"\$VIRTUAL_ENV/addons/instantclient_12_1\"
export LDFLAGS=\"-L\$VIRTUAL_ENV/local/lib -L\$VIRTUAL_ENV/local/lib64\"
export LD_LIBRARY_PATH=\"\$VIRTUAL_ENV/local/lib:\$VIRTUAL_ENV/local/lib64:\$ORACLE_HOME:\$LD_LIBRARY_PATH\"
export C_INCLUDE_PATH=\"\$VIRTUAL_ENV/local/include:\$VIRTUAL_ENV/local/include/libxml2:\$VIRTUAL_ENV/local/lib/libffi-$V_FFI/include:\$C_INCLUDE_PATH\"
" >> "$ROOT/bin/activate"
    
    #
    # Clean up in deactivate...
    #
    sed -i "s|deactivate () {|deactivate () {\n\
    if [ ! \"\${1-}\" = \"nondestructive\" ] ; then\n\
        export ORACLE_HOME=\"\$OLD_ORACLE_HOME\"\n\
        export LDFLAGS=\"\$OLD_LDFLAGS\"\n\
        export LD_LIBRARY_PATH=\"\$OLD_LD_LIBRARY_PATH\"\n\
        export C_INCLUDE_PATH=\"\$OLD_C_INCLUDE_PATH\"\n\
    fi|" "$ROOT/bin/activate"


    prt " * Changing to new environment ($BINDIR/activate)"
    . "$BINDIR/activate"
    
    prt " * Getting pip"
    
    # Use source python...
    cd "$ROOT/bin/" && rm ./get-pip.py* 2> $DN;  wget -q --no-check-certificate https://bootstrap.pypa.io/get-pip.py && python ./get-pip.py
    if [ $? -ne 0 ]; then
        prt "Failed to install pip"
        exit 4
    fi

    freezeInstall
else
    prt " * Skipping Virtual environment cause it is there. If you want to clean it run:"
    prt "  $0 -c -p $ROOT"
fi

prt "All done, run the following to activeate:"
prt "source $BINDIR/activate  "

# --global-options:
# pip install snimpy --global-option=build_ext --global-option=-I$PREFIX/lib/libffi-$V_FFI/include --global-option=-I$PREFIX/include  --global-option=build_ext  --global-option=-L$PREFIX/lib64
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
