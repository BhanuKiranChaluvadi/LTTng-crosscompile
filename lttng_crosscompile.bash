#!/bin/bash

# install this stuff before
# apt-get install  lib32z1 lib32ncurses5 lib32bz2-1.0 bison flex build-essential
# change your flags here

export PATH=/opt/ursdk-cxx/bin:$PATH
export ac_cv_func_malloc_0_nonnull=yes ac_cv_func_realloc_0_nonnull=yes
export HOST=i686-pc-linux-gnu
export SYSROOT=/opt/ursdk-cxx/i686-pc-linux-gnu/sysroot

G_CC=i686-pc-linux-gnu-gcc
G_PREFIX=usr/local


G_CFG_FILE="$PWD/${0%\.*}.conf" # tracking download/compile steps

G_TARBALL_DIR=$PWD/tarballs
G_SOURCES_DIR=$PWD/sources
G_BUILD_DIR=$PWD/builds

# steps for tracking progress in $G_CFG_FILE
step_start=0
step_download=1
step_compile=2

echo
echo "This script will compile and install lttng and some deps"
echo "Building for HOST=$HOST"
echo
echo "Builds are located in $G_BUILD_DIR"
echo "Sources are located in $G_SOURCES_DIR"
echo "Tarballs are located in $G_TARBALL_DIR"
echo "sysroot is located at $SYSROOT"
echo "prefix is set to $G_PREFIX"
echo
echo "press Enter to continue or CRTL-C to abort"
read

[ -e "$G_CFG_FILE" ] && . "$G_CFG_FILE" &> /dev/null

function get_src_dir()
{
    local filename="$1"
    tar -tf "$G_TARBALL_DIR/$filename"| sed -e 's@/.*@@' | uniq
}

function build()
{
    local filename="$1"
    local what="$2"
    local dir_name="$3"
    local state="$4"
    local do_bootstrap=$5

    if [ $state -eq $step_download ] ; then

        if $do_bootstrap ; then
            pushd $G_SOURCES_DIR/$dir_name
            ./bootstrap
            popd
        fi

        mkdir -p "$G_BUILD_DIR/$dir_name"       
        pushd "$G_BUILD_DIR/$dir_name"      
        if [ -n "$patch" ] ; then
            pushd "$G_SOURCES_DIR/$dir_name"        
            wget $patch -O- | patch -p1
            popd
        fi
        "$G_SOURCES_DIR/$dir_name"/configure --host=$HOST --prefix=$SYSROOT/${G_PREFIX} $EXTRA_CONF
        make -j3
        make install && echo "$what=$step_compile" >> $G_CFG_FILE
        popd
    fi
    if [ $state -eq $step_compile ] ; then
        echo ">> $what is already compiled"
    fi
}

function download()
{
    local url="$1"
    local what="$2"
    local filename="$3"
    local state="$4"

    if [ $state -lt $step_download ] ; then
        wget "$url" -O "$G_TARBALL_DIR/$filename"
        echo "$what=$step_download" >> $G_CFG_FILE
        tar -C $G_SOURCES_DIR -xf "$G_TARBALL_DIR/$filename"
        . "$G_CFG_FILE" &> /dev/null
    fi
}

function download_git()
{
    local url="$1"
    local what="$2"
    local filename="$3"
    local state="$4"

    if [ $state -lt $step_download ] ; then

        pushd $G_SOURCES_DIR
        git clone $url
        popd
        echo "$what=$step_download" >> $G_CFG_FILE
        . "$G_CFG_FILE" &> /dev/null
    fi
}

function init()
{
    local what="$1"
    eval state=\$$what

    if [ ! -n "$state" ] ; then
        echo "$what=$step_start" >> $G_CFG_FILE
        . "$G_CFG_FILE" &> /dev/null
    fi

    eval state=\$$what
}

function get_em()
{
    local url="$1"
    local what="$2"
    local filename=$(basename $url) 

    init "$what"
    download "$url" "$what" $filename $state
    eval state=\$$what
    local dir_name=$(get_src_dir $filename)
    build $filename "$what" $dir_name $state false
}

function get_em_git()
{
    local url="$1"
    local what="$2"
    local do_bootstrap="$3"
    local filename=$(basename $url) 
    filename=${filename/.git}

    init "$what"
    download_git "$url" "$what" $filename $state
    eval state=\$$what

    build $filename "$what" $filename $state $do_bootstrap
}

echo "create directories"
mkdir -p "$G_TARBALL_DIR" "$G_SOURCES_DIR" "$G_BUILD_DIR" &>/dev/null


########################
# define the packages we want to compile
########################

# this are the dependencies that are missing for our sysroot
# we will compile them and install the to the $SYSROOT
# 
# --- BEGIN --- dependencies
what=libuuid
url=http://downloads.sourceforge.net/project/libuuid/libuuid-1.0.3.tar.gz
get_em $url "$what"

what=libxml2
url=http://xmlsoft.org/sources/libxml2-2.9.10.tar.gz
EXTRA_CONF=--without-python
get_em $url "$what"
unset EXTRA_CONF

what=popt
url=ftp://anduin.linuxfromscratch.org/BLFS/svn/p/popt-1.16.tar.gz
get_em $url "$what"

what=libiconv
url=http://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.14.tar.gz
patch=http://data.gpo.zugaina.org/gentoo/dev-libs/libiconv/files/libiconv-1.14-no-gets.patch
get_em $url "$what"
unset patch

what=zlib
url=https://zlib.net/fossils/zlib-1.2.8.tar.gz
init "$what"
filename=$(basename $url)   
download "$url" "$what" $filename $state
if [ $state -eq $step_compile ] ; then
    echo ">> $what is already compiled"
else
    dir_name=$(get_src_dir $filename)
    pushd $G_SOURCES_DIR/$dir_name
    CC=$G_CC \
    LDSHARED="$G_CC -shared -Wl,-soname,libz.so.1" \
    ./configure --shared --prefix=$SYSROOT/${G_PREFIX}
    make
    make install prefix=$SYSROOT/${G_PREFIX} && echo "$what=$step_compile" >> $G_CFG_FILE
    popd
fi

# --- END --- dependencies


#######################
# compile lttng related packages and install into $SYSROOT
what=userspace_rcu
url=https://lttng.org/files/urcu/userspace-rcu-0.11.1.tar.bz2
export CFLAGS="-m32 -g -O2"
get_em $url "$what"
unset CFLAGS

what=lttng_ust
url=http://lttng.org/files/lttng-ust/lttng-ust-latest-2.11.tar.bz2
export CPPFLAGS="-I$SYSROOT/${G_PREFIX}/include"
export LDFLAGS="-L$SYSROOT/${G_PREFIX}/lib -Wl,-rpath-link=$SYSROOT/${G_PREFIX}/lib:$SYSROOT/lib/i386-linux-gnu"
EXTRA_CONF="--disable-numa --disable-man-pages"
get_em $url "$what"
unset CPPFLAGS
unset LDFLAGS
 
what=lttng_tools
url=https://github.com/lttng/lttng-tools/releases/download/v2.11.0/lttng-tools-2.11.0.tar.bz2
export CPPFLAGS="-I$SYSROOT/${G_PREFIX}/include"
export LDFLAGS="-L$SYSROOT/${G_PREFIX}/lib -Wl,-rpath-link=$SYSROOT/${G_PREFIX}/lib:$SYSROOT/lib/i386-linux-gnu"
export PKG_CONFIG_PATH=$SYSROOT/${G_PREFIX}/lib/pkgconfig
EXTRA_CONF="--disable-man-pages"
get_em $url "$what"
unset CPPFLAGS
unset LDFLAGS
unset PKG_CONFIG_PATH


echo
echo "INFO: the build progress for all packages is tracked in $G_CFG_FILE"
