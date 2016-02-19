 
# PFS: Python From Scratch #

Compile python from scratch and create a virtual environment in user-space that
has no dependencies to the system

**NOTE: Tested on CentOS 6 only**

## Requirements ##

Build tools: g++, make, autotools

## Usage ##

### Creating a new environment ###

    /path/to/pyenv.sh -p </path/to/new/env> -v <X.Y.Z> [-r <pip-requirements-file>]
    
If a requirements file is given, after the environment is created it runs:

    pip install -r <pip-requirements-file>
    
Use this environment as any python venv:

    source /path/to/new/env/bin/activate
    
### Remove an environment ###

Well the obvious:

    rm -rf /path/to/env
    
However, the following will remove the virtual environment keeping the sources
and local python installation intact:

    /path/to/pyenv.sh -p </path/to/new/env> -c
    
Appending `-a` will remove `lib`, `bin`, `src` and `local` folders and thus 
virtual environment, python and sources are gone


## Installing modules that require libs ##

Since we are using custom libraries, when installing python modules that require
these libraries we have to export paths. The `activate` has been modified to do
this so all we need is:

    export C_INCLUDE_PATH && pip install <module>
    
Installing pure python modules should not be a problem


## Internals ##

This project is under development and requires a lot of testing so things are
not complete. 

The high level process is:

1.  Install python dependencies
    
    At the moment we are installing: `ncurses`, `readline`, `zlib`, `bzip2` and `sqlite2`
    
2.  Install python
    
    ... the usual process. The only difference is that setup.py is modified to 
    not look into `/usr/loca/lib` and `include`, instead these are replaced with
    the local prefix
    
3.  Install few extra libs

    The libs installed on top are: `libsmi`, `libffi`, `libxml2` and `libxslt`
    

    
    
