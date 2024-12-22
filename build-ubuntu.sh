#!/bin/bash

# Install needed tools
sudo apt install build-essential g++ gcc pkg-config unzip subversion
# Install extra tools
sudo apt install autoconf autoconf-archive automake indent ocaml-interp cmake curl gawk git gperf libtool ragel texi2html help2man po4a xmlto libtool-bin autogen autopoint yasm bison flex mercurial
# Install dependencies (only add if you don't build them yourself)
sudo apt install w3m libxext-dev libgdbm-dev libsqlite3-dev libreadline6-dev libncurses5-dev libudev-dev \
  libdbus-1-dev libaudit-dev libcrack2-dev libdb-dev libselinux1-dev libmount-dev texinfo #libx11-dev libgavl-dev libjbig-dev
sudo apt install \
  libbz2-dev \
  libcairo2-dev \
  libsdl1.2-dev \
  libva-dev \
  libvdpau-dev \
  libxcb1-dev \
  libxcb-shm0-dev \
  libxcb-xfixes0-dev
#  libass-dev \
#  libcaca-dev \
#  libfreetype6-dev \
#  frei0r-plugins-dev \
#  libglib2.0-dev \
#  libopencore-amrnb-dev \
#  libopencore-amrwb-dev \
#  libspeex-dev \
#  libssl-dev \
#  libtheora-dev \
#  libvo-amrwbenc-dev \
#  libvorbis-dev \
#  libwebp-dev \
#  libxvidcore-dev \
#  zlib1g-dev

ubuntu_version=`lsb_release -rs`

# For 12.04
# libx265 requires cmake version >= 2.8.8
# 12.04 only have 2.8.7
need_ppa=`echo $ubuntu_version'<=12.04' | bc -l`
if [ $need_ppa -eq 1 ]; then
    sudo add-apt-repository ppa:roblib/ppa
    sudo apt-get update
    sudo apt-get install cmake
fi

# For 16.04
version=`echo $ubuntu_version'<=16.04' | bc -l`
if [ $version -eq 1 ]; then
#    sudo apt install libxcrypt-dev; else
#    sudo apt install libxcrypt-source
    sudo apt install libnss3-dev libssl-dev libreadline-dev libffi-dev -y
    wget https://www.python.org/ftp/python/3.7.4/Python-3.7.4.tgz
    tar xzf Python-3.7.4.tgz
    cd Python-3.7.4
    ./configure
    make -j 4
    sudo make install
    sudo apt remove libnss3-dev libssl-dev libreadline-dev libffi-dev -y
fi

# For 18.04
version=`echo $ubuntu_version'==18.04' | bc -l`
if [ $version -eq 1 ]; then
#    sudo apt install libxcrypt-dev; else
#    sudo apt install libxcrypt-source
    sudo apt install python3.8 -y
    sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.6 1
    sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.8 2
fi

# For 20.04
version=`echo $ubuntu_version'<=20.04' | bc -l`
if [ $version -eq 1 ]; then
    sudo apt install doxygen -y
fi

./build.sh "$@"
