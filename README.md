 
# PFS: Python From Scratch #

Compile python from scratch, install in a local development environment and 
create a python virtual environment on top, that has no system dependencies.

_Why?:_ Because I couldn't find a complete tutorial or anything similar and I 
do need a way to easily build the exact same environment on multiple hosts 
(different distros).

This is different from [pyevn](https://github.com/yyuu/pyenv/) in the following
ways:

-   Installs locally all required libraries, including build tools when these are
    missing (if pyenv was doing that, this script wouldn't be needed)
-   Not intended to be a python environment manager, instead is only the builder
    while `virtualenv` is used to change between environments
-   It can build a package using `checkinstall`
-   Its a lot more immature and untested


_NOTE_: Tested on:
- CentOS 6.6
- Debian 7.1
- Ubuntu 14.04.3

Drop me a message if you have successfully run this on different distros/platforms.


## Requirements ##

Build tools: g++, make. All other tools will be installed is missing

## Usage ##

**DO NEVER RUN THIS AS ROOT**

### Creating a new environment ###

    /path/to/pfs.sh -p </path/to/new/env> -v <X.Y.Z> [-r <pip-requirements-file>]
    
If a requirements file is given, after the environment is created
(and sourced) it runs:

    export C_INCLUDE_PATH; export PATH export; \
    pip install -r  <pip-requirements-file> --global-option=build_ext \
                --global-option=-L$PREFIX/lib64 --global-option=-L$PREFIX/lib
    
Use this environment as any python venv:

    source /path/to/new/env/bin/activate
    
### Remove an environment ###

Well, the obvious:

    rm -rf /path/to/env
    
However, the following will remove the python virtual environment keeping the
sources and local build environment intact:

    /path/to/pfs.sh -p </path/to/new/env> -c
    
Appending `-a` will remove `lib`, `bin` and `src` folders and thus the python
virtual environment and sources are gone. The venv can be rebuild at any time
using the "create" command. Libraries are not going to be re-build since the
`local` folder (development/build environment) has been preserved.

#### Cleaning-up ####

Once you are happy with your build you can remove the sources to reduce disk
space (from ~650M to ~250M):

    rm -rf /path/to/new/env/src


## Installing modules that require C/C++ libs ##

We have a custom development/build environment and therefore, in order to 
build new libraries, we need to export the correct include and lib paths. 
The `virtualenv.py` `activate` scripts has been modified to do this, so 
all we need to do is:

    export C_INCLUDE_PATH && pip install <module>
    
Installing pure python modules should not be a problem. Depending on how 
the build environment was created, we might have to export more variables
(see later: `TMPDIR`, `LD_LIBRARY_PATH`, etc)

## Troubleshooting ##

Few issues I had:

1.  `libtool` not installed or corrupted, solution: Install in home directory 
    and add to the `$PATH`
2.  Python linking against system's `libpython.X.X.so`, solution: As suggested 
    on `stackoverflow`[todo], modify the setup.py (see `sed -i` in the script).
3.  `pip --global-option` being ignored or includes not found, solution: Setup 
    your `LD_LIBRARY_PATH` and `C_INCLUDE_PATH` and export them. If the venv is
    active you can also use `$VIRTUAL_ENV`, example:
     
     ```
     export PATH; export TMPDIR=~/tmp; export C_INCLUDE_PATH && pip install cffi --global-option=build_ext  --global-option=-L$VIRTUAL_ENV/lib64
     ```
4.  `/tmp` missing exec permissions (security on some systems), solution: export
    another `TMPDIR` as in the example above
    

## Internals/Hacking ##

This project is under development so things are not complete - not all python
dependencies are satisfied... 

The high level process is:

1.  Install python dependencies. At the moment we are installing: `ncurses`,
    `readline`, `zlib`, `bzip2` and `sqlite3`
    
2.  Install python:
    
    ... the usual process. The only difference is that setup.py is modified to 
    not look into `/usr/loca/lib` and `include`, instead these are replaced with
    the local prefix before `make && make install`:
    
    ```
    sed -i "s|/usr/local/lib|$PREFIX/lib|" ./setup.py
    sed -i "s|/usr/local/include|$PREFIX/include|" ./setup.py
    ```
    
3.  Install few extra libs on top. They are mainly for SNMP and xml
    parsing: `libsmi`, `libffi`, `libxml2` and `libxslt`
    
### Installing more libraries

A function is provided to take care of the heavy lifting: `installLib` use it
the following way:

    installLib "http://ftp.gnu.org/pub/gnu/ncurses/ncurses-6.0.tar.gz" \ # <-- Download URL
               "ncurses-6.0.tar.gz" \             # <-- File name to save it in `src` folder
               "ncurses-6.0" \                    # <-- Folder name after extraction (tar.gz and zip supported)
               "ncurses/curses.h" \               # <-- A single `include` file that is use to check if already installed
               "confmake" \                       # <-- Build type (confmake, autogen - see source)
               "--with-shared --without-normal"   # <-- Additional args to `./configure` (--prefix and --enable-shared are added)
               
Have fun!

## **DISCLAIMER** ##

THIS SOFTWARE IS PROVIDED "AS IS" AND ANY EXPRESSED OR IMPLIED WARRANTIES, 
INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND 
FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE REGENTS 
OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, 
EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT 
OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING 
IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY 
OF SUCH DAMAGE.
