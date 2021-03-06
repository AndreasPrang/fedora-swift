#!/bin/sh
BUILDROOT=~/tmp/swiftbuild

BRANCH="--branch swift-3.0-branch"
declare -a SWIFTREPOS=(\
        "https://github.com/apple/swift.git swift" \
        "https://github.com/apple/swift-llvm.git llvm" \
        "https://github.com/apple/swift-clang.git clang" \
        "https://github.com/apple/swift-lldb.git lldb" \
        "https://github.com/apple/swift-cmark.git cmark" \
        "https://github.com/apple/swift-llbuild.git llbuild" \
        "https://github.com/apple/swift-package-manager.git swiftpm" \
        "https://github.com/apple/swift-corelibs-xctest.git swift-corelibs-xctest"  \
        "https://github.com/apple/swift-corelibs-foundation.git swift-corelibs-foundation"\
	"https://github.com/apple/swift-corelibs-libdispatch.git swift-corelibs-libdispatch"\
        )
BUILDTHREADS=2
NOW=`date +%Y-%m-%d--%H:%M:%S`

THISDIR="`dirname \"$0\"`"              # relative
THISDIR="`( pushd \"$THISDIR\" >/dev/null && pwd )`"  # absolutized and normalized
if [ -z "$THISDIR" ] ; then
  # error; for some reason, the path is not accessible
  # to the script (e.g. permissions re-evaled after suid)
  exit 1  # fail
fi

if [ $# -lt 1 ]
then
  echo "Usage : $0 [reset|clean|setup|update|build]"
  exit
fi

case "$1" in

  "reset" )  echo "reset build enviroment"
    rm -rf $BUILDROOT
    mkdir -p $BUILDROOT
    mkdir -p $BUILDROOT/package
    mkdir -p $BUILDROOT/symroot
    mkdir -p $BUILDROOT/build
    
    echo "reset done"
  ;;




  "setup" )  echo "Setup build enviroment"
    sudo yum install -y \
    git \
    cmake \
    cmake3 \
    ninja-build \
    clang \
    gcc-c++ \
    re2c \
    uuid-devel \
    libuuid-devel \
    icu \
    libicu \
    libicu-devel \
    libbsd-devel \
    libedit-devel \
    libxml2-devel \
    sqlite-devel \
    swig \
    python-libs \
    ncurses-devel \
    python-devel \
    pkg-config

    #install updated binutils
    wget https://dl.fedoraproject.org/pub/fedora/linux/updates/24/x86_64/b/binutils-2.26.1-1.fc24.x86_64.rpm
    yum -y install binutils-2.26.1-1.fc24.x86_64.rpm

    #substitute cmake for cmake3
    sudo mv /usr/bin/cmake /usr/bin/cmake2
    sudo ln -s /usr/bin/cmake3 /usr/bin/cmake

    #substitute ld for ld.gold
    sudo rm /etc/alternatives/ld
    sudo ln -s /usr/bin/ld.gold /etc/alternatives/ld

    #fix the missing libc6 references
    #pushd /usr/include
    #	sudo ln -s . x86_64-linux-gnu
    #popd

    # Make sure the build root directory is present.

    mkdir -p $BUILDROOT
    mkdir -p $BUILDROOT/package
    mkdir -p $BUILDROOT/symroot
    mkdir -p $BUILDROOT/build

    pushd $BUILDROOT
    for repo in "${SWIFTREPOS[@]}"; do
      repodir=$BUILDROOT/`echo $repo | cut -d " " -f 2`
      if [ ! -d "$repodir" ] ; then
        git clone $BRANCH $repo
      fi
    done


    if [ ! -d ~/tmp/swiftbuild/ninja ] ; then
      git clone https://github.com/martine/ninja.git
    fi

    if [ ! -f /usr/bin/ninja ] ; then
         if [ -f /usr/bin/ninja-build ] ; then
            sudo ln -s /usr/bin/ninja-build /usr/bin/ninja
         fi
    fi

    popd

  ;;

  "update" )  echo  "updating repositories"

  mkdir -p $BUILDROOT
  mkdir -p $BUILDROOT/package
  mkdir -p $BUILDROOT/symroot
  mkdir -p $BUILDROOT/build


    for repo in "${SWIFTREPOS[@]}"; do
      repodir=$BUILDROOT/`echo $repo | cut -d " " -f 2`
      if [  -d "$repodir" ] ; then
        pushd $repodir
        git pull
        popd
      fi
    done

    if [ -d ~/tmp/swiftbuild/ninja ] ; then
      pushd ~/tmp/swiftbuild/ninja
      git pull
      popd
    fi

  mkdir -p $BUILDROOT/build/buildbot_linux/lldb-linux-x86_64/lib
  mkdir -p $BUILDROOT/build/buildbot_linux/lldb-linux-x86_64/lib64/python2.7

  if [ ! -d $BUILDROOT/build/buildbot_linux/lldb-linux-x86_64/lib/python2.7 ] ; then
    if [ -d $BUILDROOT/build/buildbot_linux/lldb-linux-x86_64/lib64/python2.7 ] ; then
      ln -s $BUILDROOT/build/buildbot_linux/lldb-linux-x86_64/lib64/python2.7 $BUILDROOT/build/buildbot_linux/lldb-linux-x86_64/lib/python2.7
    fi
  fi


  ;;

  "clean" )  echo  "clean build"
  mkdir -p $BUILDROOT
  mkdir -p $BUILDROOT/package
  mkdir -p $BUILDROOT/symroot
  mkdir -p $BUILDROOT/build
  rm -rf $BUILDROOT/build/*
  rm -rf $BUILDROOT/package/*
  rm -rf $BUILDROOT/symroot/*
  ;;

  "build" )  echo  "build"
  mkdir -p $BUILDROOT
  mkdir -p $BUILDROOT/package
  mkdir -p $BUILDROOT/symroot

  if [ -f  "$BUILDROOT/package/swift-linux-x86_64-fedora-$NOW.tgz" ] ; then
    rm "$BUILDROOT/package/swift-linux-x86_64-fedora-$NOW.tgz"
  fi

  mkdir -p $BUILDROOT/build/buildbot_linux/lldb-linux-x86_64/lib
  mkdir -p $BUILDROOT/build/buildbot_linux/lldb-linux-x86_64/lib64/python2.7

  if [ ! -d $BUILDROOT/build/buildbot_linux/lldb-linux-x86_64/lib/python2.7 ] ; then
    if [ -d $BUILDROOT/build/buildbot_linux/lldb-linux-x86_64/lib64/python2.7 ] ; then
      ln -s $BUILDROOT/build/buildbot_linux/lldb-linux-x86_64/lib64/python2.7 $BUILDROOT/build/buildbot_linux/lldb-linux-x86_64/lib/python2.7
    fi
  fi

  pushd $BUILDROOT/swift
    utils/build-script --preset-file=$THISDIR/linuxpreset.ini \
      --preset=buildbot_linux_build_fedora23 \
      install_destdir="$BUILDROOT/package" \
      install_symroot="$BUILDROOT/symroot" \
      installable_package="$BUILDROOT/package/swift-linux-x86_64-fedora-$NOW.tgz" \
      build_threads=$BUILDTHREADS
  popd
  ;;

"patch" )  echo  "patch"
  mkdir -p $BUILDROOT
  mkdir -p $BUILDROOT/package
  mkdir -p $BUILDROOT/symroot

  if [ -f  "$BUILDROOT/package/swift-linux-x86_64-fedora-$NOW.tgz" ] ; then
    rm "$BUILDROOT/package/swift-linux-x86_64-fedora-$NOW.tgz"
  fi

  mkdir -p $BUILDROOT/build/buildbot_linux/lldb-linux-x86_64/lib
  mkdir -p $BUILDROOT/build/buildbot_linux/lldb-linux-x86_64/lib64/python2.7

  if [ ! -d $BUILDROOT/build/buildbot_linux/lldb-linux-x86_64/lib/python2.7 ] ; then 
    if [ -d $BUILDROOT/build/buildbot_linux/lldb-linux-x86_64/lib64/python2.7 ] ; then
      ln -s $BUILDROOT/build/buildbot_linux/lldb-linux-x86_64/lib64/python2.7 $BUILDROOT/build/buildbot_linux/lldb-linux-x86_64/lib/python2.7
    fi
  fi
  echo "patched ";
  ;;

  *) echo "Unrecognised command: $1"
  ;;
esac
