#!/bin/bash

# Install needed updates
sudo apt install build-essential g++ gcc pkg-config tar
# Install needed tools
sudo apt install autoconf autoconf-archive automake cmake curl gawk git gperf libtool ragel texi2html help2man po4a xmlto libtool-bin autogen autopoint yasm bison flex subversion
# Install dependencies (only add if you don't build them yourself)
sudo apt install w3m libxext-dev libgdbm-dev libsqlite3-dev libreadline6-dev libncurses5-dev libudev-dev \
  libdbus-1-dev libaudit-dev libcrack2-dev libdb-dev libselinux1-dev libxcrypt-dev libmount-dev texinfo #libx11-dev libgavl-dev libjbig-dev
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

# For 12.04
# libx265 requires cmake version >= 2.8.8
# 12.04 only have 2.8.7
ubuntu_version=`lsb_release -rs`
need_ppa=`echo $ubuntu_version'<=12.04' | bc -l`
if [ $need_ppa -eq 1 ]; then
    sudo add-apt-repository ppa:roblib/ppa
    sudo apt-get update
    sudo apt-get install cmake
fi

./build.sh "$@"
