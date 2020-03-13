#!/bin/sh

# ffmpeg static build 3.1s

set -e
set -u
echo
date +%H:%M:%S

jflag=
jval=$(nproc)
rebuild=0
download_only=0
uname -mpi | grep -qE 'x86|i386|i686' && is_x86=1 || is_x86=0

while getopts 'j:Bd' OPTION
do
  case $OPTION in
  j)
      jflag=1
      jval="$OPTARG"
      ;;
  B)
      rebuild=1
      ;;
  d)
      download_only=1
      ;;
  ?)
      printf "Usage: %s: [-j concurrency_level] (hint: your cores + 20%%) [-B] [-d]\n" $(basename $0) >&2
      exit 2
      ;;
  esac
done
shift $(($OPTIND - 1))

if [ "$jflag" ]
then
  if [ "$jval" ]
  then
    printf "Option -j specified (%d)\n" $jval
  fi
fi

[ "$rebuild" -eq 1 ] && echo && /bin/echo -e "\e[93m Reconfiguring existing packages...\e[39m" && echo
[ $is_x86 -ne 1 ] && echo && /bin/echo -e "\e[93m Not using yasm or nasm on non-x86 platform...\e[39m" && echo

cd `dirname $0`
ENV_ROOT=`pwd`
. ./env.source

# check operating system
OS=`uname`
platform="unknown"

case $OS in
  'Darwin')
    platform='darwin'
    ;;
  'Linux')
    platform='linux'
    ;;
esac

#if you want a rebuild
#rm -rf "$BUILD_DIR" "$TARGET_DIR"
mkdir -p "$BUILD_DIR" "$TARGET_DIR" "$DOWNLOAD_DIR" "$BIN_DIR"

#download and extract package
download(){
  filename="$1"
  if [ ! -z "$2" ];then
    filename="$2"
  fi
  ../download.pl "$DOWNLOAD_DIR" "$1" "$filename" "$3" "$4"
  #disable uncompress
  REPLACE="$rebuild" CACHE_DIR="$DOWNLOAD_DIR" ../fetchurl "http://cache/$filename"
}

echo
/bin/echo -e "\e[93m#### FFmpeg static build ####\e[39m"
echo

#this is our working directory
cd $BUILD_DIR

#[ $is_x86 -eq 1 ] && download \
#  "yasm-1.3.0.tar.gz" \
#  "" \
#  "fc9e586751ff789b34b1f21d572d96af" \
#  "http://www.tortall.net/projects/yasm/releases/"

rm -rf asciidoc-git
git clone https://github.com/asciidoc/asciidoc asciidoc-git

[ $is_x86 -eq 1 ] && download \
  "nasm-2.14.tar.gz" \
  "" \
  "bc1cdaa06fc522eefa35c4ba881348f5" \
  "http://www.nasm.us/pub/nasm/releasebuilds/2.14/"

#download \
#  "master.tar.gz" \
#  "linux-pam-master.tar.gz" \
#  "nil" \
#  "https://github.com/linux-pam/linux-pam/archive/"

#download \
#  "libcap-master.tar.gz" \
#  "" \
#  "nil" \
#  "https://git.kernel.org/pub/scm/libs/libcap/libcap.git/snapshot/"

download \
  "alsa-lib-1.2.1.2.tar.bz2" \
  "" \
  "82ddd3698469beec147e4f4a67134ea0" \
  "https://www.alsa-project.org/files/pub/lib/"

#download \
#  "giflib-5.2.1.tar.gz" \
#  "" \
#  "6f03aee4ebe54ac2cc1ab3e4b0a049e5" \
#  "https://sourceforge.net/projects/giflib/files/"
rm -rf giflib-ffontaine35
git clone https://git.code.sf.net/u/ffontaine35/giflib giflib-ffontaine35

download \
  "xz-5.2.4.tar.gz" \
  "" \
  "5ace3264bdd00c65eeec2891346f65e6" \
  "https://tukaani.org/xz/"

download \
  "v1.2.5.tar.gz" \
  "zlib-1.2.5.tar.gz" \
  "9d8bc8be4fb6d9b369884c4a64398ed7" \
  "https://github.com/madler/zlib/archive/"

download \
  "master.tar.gz" \
  "libjpeg-turbo-master.tar.gz" \
  "nil" \
  "https://github.com/libjpeg-turbo/libjpeg-turbo/archive/"

download \
  "master.tar.gz" \
  "libpng-master.tar.gz" \
  "nil" \
  "https://github.com/glennrp/libpng/archive/"

download \
  "v1.2.11.tar.gz" \
  "zlib-1.2.11.tar.gz" \
  "0095d2d2d1f3442ce1318336637b695f" \
  "https://github.com/madler/zlib/archive/"

download \
  "libid3tag-0.15.1b.tar.gz" \
  "" \
  "e5808ad997ba32c498803822078748c3" \
  "https://sourceforge.net/projects/mad/files/"

download \
  "dev.tar.gz" \
  "zstd-dev.tar.gz" \
  "nil" \
  "https://github.com/facebook/zstd/archive/"

download \
  "v1.1.0.tar.gz" \
  "libwebp-1.1.0.tar.gz" \
  "35831dd0f8d42119691eb36f2b9d23b7" \
  "https://github.com/webmproject/libwebp/archive/"

download \
  "tiff-4.1.0.tar.gz" \
  "" \
  "nil" \
  "http://download.osgeo.org/libtiff/"

#download \
#  "util-macros-1.19.2.tar.gz" \
#  "" \
#  "5059b328fac086b733ffac6607164c41" \
#  "https://www.x.org/archive//individual/util/"

#download \
#  "xorgproto-2019.1.tar.bz2" \
#  "" \
#  "802ccb9e977ba3cf94ba798ddb2898a4" \
#  "https://xorg.freedesktop.org/archive/individual/proto/"

download \
  "tk8.6.10-src.tar.gz" \
  "" \
  "602a47ad9ecac7bf655ada729d140a94" \
  "https://netix.dl.sourceforge.net/project/tcl/Tcl/8.6.10/"

download \
  "tcl8.6.10-src.tar.gz" \
  "" \
  "97c55573f8520bcab74e21bfd8d0aadc" \
  "https://netcologne.dl.sourceforge.net/project/tcl/Tcl/8.6.10/"

download \
  "master.tar.gz" \
  "libexpat-master.tar.gz" \
  "nil" \
  "https://github.com/libexpat/libexpat/archive/"

#download \
#  "Python-2.7.17.tar.xz" \
#  "" \
#  "b3b6d2c92f42a60667814358ab9f0cfd" \
#  "https://www.python.org/ftp/python/2.7.17/"

#download \
#  "Python-3.8.1.tar.xz" \
#  "" \
#  "b3fb85fd479c0bf950c626ef80cacb57" \
#  "https://www.python.org/ftp/python/3.8.1/"

download \
  "libxml2-2.9.10.tar.gz" \
  "" \
  "10942a1dc23137a8aa07f0639cbfece5" \
  "http://xmlsoft.org/sources/"

download \
  "freetype-2.10.1.tar.xz" \
  "" \
  "bd42e75127f8431923679480efb5ba8f" \
  "https://downloads.sourceforge.net/freetype/"

download \
  "fontconfig-2.13.92.tar.xz" \
  "" \
  "d5431bf5456522380d4c2c9c904a6d96" \
  "https://www.freedesktop.org/software/fontconfig/release/"

# libass dependency
download \
  "2.6.4.tar.gz" \
  "harfbuzz-2.6.4.tar.gz" \
  "188407981048daf6d92d554cfeeed48e" \
  "https://github.com/harfbuzz/harfbuzz/archive/"

download \
  "v2.3.1.tar.gz" \
  "openjpeg-2.3.1.tar.gz" \
  "3b9941dc7a52f0376694adb15a72903f" \
  "https://github.com/uclouvain/openjpeg/archive/"

download \
  "imlib2-1.6.1.tar.bz2" \
  "" \
  "7b3fbcb974b48822b32b326c6a47764b" \
  "https://netix.dl.sourceforge.net/project/enlightenment/imlib2-src/1.6.1/"

download \
  "v0.99.beta19.tar.gz" \
  "libcaca-0.99.beta19.tar.gz" \
  "2e1ed59dc3cb2f69d3d98fd0e6a205b4" \
  "https://github.com/cacalabs/libcaca/archive/"
#git clone https://github.com/cacalabs/libcaca.git "$BUILD_DIR"/libcaca-clone

download \
  "vo-amrwbenc-0.1.3.tar.gz" \
  "" \
  "f63bb92bde0b1583cb3cb344c12922e0" \
  "http://downloads.sourceforge.net/opencore-amr/vo-amrwbenc/"
#git clone https://github.com/mstorsjo/vo-amrwbenc.git "$BUILD_DIR"/vo-amrwbenc-clone

download \
  "opencore-amr-0.1.3.tar.gz" \
  "" \
  "09d2c5dfb43a9f6e9fec8b1ae678e725" \
  "http://downloads.sourceforge.net/opencore-amr/opencore-amr/"
#git clone https://github.com/BelledonneCommunications/opencore-amr.git "$BUILD_DIR"/opencore-amr-clone

download \
  "OpenSSL_1_0_2o.tar.gz" \
  "" \
  "5b5c050f83feaa0c784070637fac3af4" \
  "https://github.com/openssl/openssl/archive/"

download \
  "master.tar.gz" \
  "libilbc-master.tar.gz" \
  "nil" \
  "https://github.com/TimothyGu/libilbc/archive/"

download \
  "xvidcore-1.3.5.tar.gz" \
  "" \
  "69784ebd917413d8592688ae86d8185f" \
  "http://downloads.xvid.org/downloads/"

download \
  "x264-master.tar.gz" \
  "" \
  "nil" \
  "https://code.videolan.org/videolan/x264/-/archive/master/"

download \
  "x265_3.2.1.tar.gz" \
  "" \
  "94808045a34d88a857e5eaf3f68f4bca" \
  "https://bitbucket.org/multicoreware/x265/downloads/"

download \
  "v2.0.1.tar.gz" \
  "fdk-aac-2.0.1.tar.gz" \
  "5b85f858ee416a058574a1028a3e1b85" \
  "https://github.com/mstorsjo/fdk-aac/archive"

download \
  "fribidi-1.0.8.tar.bz2" \
  "" \
  "962c7d8ebaa711d4e306161dbe14aa55" \
  "https://github.com/fribidi/fribidi/releases/download/v1.0.8/"

download \
  "0.14.0.tar.gz" \
  "libass-0.14.0.tar.gz" \
  "3c84884aa0589486bded10f71829bf39" \
  "https://github.com/libass/libass/archive/"

download \
  "lame-3.100.tar.gz" \
  "" \
  "83e260acbe4389b54fe08e0bdbf7cddb" \
  "http://downloads.sourceforge.net/project/lame/lame/3.100"

download \
  "v1.3.1.tar.gz" \
  "opus-1.3.1.tar.gz" \
  "b27f67923ffcbc8efb4ce7f29cbe3faf" \
  "https://github.com/xiph/opus/archive/"

download \
  "v1.8.2.tar.gz" \
  "libvpx-v1.8.2.tar.gz" \
  "6dbccca688886c66a216d7e445525bce" \
  "https://github.com/webmproject/libvpx/archive/"
#git clone https://chromium.googlesource.com/webm/libvpx "$BUILD_DIR"/libvpx-clone

download \
  "rtmpdump-2.3.tgz" \
  "" \
  "eb961f31cd55f0acf5aad1a7b900ef59" \
  "https://rtmpdump.mplayerhq.hu/download/"

download \
  "soxr-0.1.3-Source.tar.xz" \
  "" \
  "3f16f4dcb35b471682d4321eda6f6c08" \
  "https://sourceforge.net/projects/soxr/files/"

download \
  "release-0.98b.tar.gz" \
  "vid.stab-release-0.98b.tar.gz" \
  "299b2f4ccd1b94c274f6d94ed4f1c5b8" \
  "https://github.com/georgmartius/vid.stab/archive/"

download \
  "release-2.9.2.tar.gz" \
  "zimg-release-2.9.2.tar.gz" \
  "a3755bff6207fcca5c06e7b1b408ce2e" \
  "https://github.com/sekrit-twc/zimg/archive/"

download \
  "v1.3.4.tar.gz" \
  "ogg-1.3.4.tar.gz" \
  "df1a9a95251a289aa5515b869db4b15f" \
  "https://github.com/xiph/ogg/archive/"

download \
  "master.tar.gz" \
  "flac-master.tar.gz" \
  "nil" \
  "https://github.com/xiph/flac/archive/"

download \
  "v1.3.6.tar.gz" \
  "vorbis-1.3.6.tar.gz" \
  "03e967efb961f65a313459c5d0f4cbfb" \
  "https://github.com/xiph/vorbis/archive/"

download \
  "Speex-1.2.0.tar.gz" \
  "Speex-1.2.0.tar.gz" \
  "4bec86331abef56129f9d1c994823f03" \
  "https://github.com/xiph/speex/archive/"

download \
  "master.tar.gz" \
  "libsndfile-master.tar.gz" \
  "nil" \
  "https://github.com/erikd/libsndfile/archive/"

#download \
#  "twolame-0.3.13.tar.gz" \
#  "" \
#  "4113d8aa80194459b45b83d4dbde8ddb" \
#  "https://github.com/njh/twolame/releases/download/0.3.13/"

download \
  "twolame-0.4.0.tar.gz" \
  "" \
  "400c164ed096c7aea82bcf8edcd3f6f9" \
  "https://github.com/njh/twolame/releases/download/0.4.0/"

#download \
#  "master.tar.gz" \
#  "twolame-master.tar.gz" \
#  "nil" \
#  "https://github.com/njh/twolame/archive/"

download \
  "libtheora-1.1.1.tar.gz" \
  "" \
  "bb4dc37f0dc97db98333e7160bfbb52b" \
  "http://downloads.xiph.org/releases/theora/"

##download \
##  "master.tar.gz" \
##  "pulseaudio-master.tar.gz" \
##  "nil" \
##  "https://github.com/pulseaudio/pulseaudio/archive/"
#git clone https://github.com/pulseaudio/pulseaudio "$BUILD_DIR"/pulseaudio-git

download \
  "n4.2.2.tar.gz" \
  "ffmpeg4.2.2.tar.gz" \
  "85c99f782dd3244a8e02ea85d29ecee2" \
  "https://github.com/FFmpeg/FFmpeg/archive"

[ $download_only -eq 1 ] && exit 0

TARGET_DIR_SED=$(echo $TARGET_DIR | awk '{gsub(/\//, "\\/"); print}')

yasm(){
  if [ $is_x86 -eq 1 ]; then
    echo
    /bin/echo -e "\e[93m*** Building yasm ***\e[39m"
    echo
    cd $BUILD_DIR/yasm*
    [ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
    [ ! -f config.status ] && ./configure --prefix=$TARGET_DIR --bindir=$BIN_DIR
    make -j $jval
    make install
  fi
}

asciidoc(){
echo
/bin/echo -e "\e[93m*** Building asciidoc (Multi Dependency) ***\e[39m"
echo
cd $BUILD_DIR/asciidoc-*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
autoconf
./configure --prefix=$TARGET_DIR
make -j $jval
make install
}

nasm(){
  if [ $is_x86 -eq 1 ]; then
    echo
    /bin/echo -e "\e[93m*** Building nasm ***\e[39m"
    echo
    cd $BUILD_DIR/nasm*
    [ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
    [ ! -f config.status ] && ./configure --prefix=$TARGET_DIR --bindir=$BIN_DIR
    make -j $jval
    make install
  fi
}

linuxPAM(){
echo
/bin/echo -e "\e[93m*** Building linux-PAM ***\e[39m"
echo
cd $BUILD_DIR/linux-pam*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
./autogen.sh
./configure --prefix=$TARGET_DIR --disable-doc --enable-static --disable-shared
make -j $jval
make install
}

libcap(){
# there's no configure, we have to edit Makefile directly
echo
/bin/echo -e "\e[93m*** Building libCap (with PAM) ***\e[39m"
echo
cd $BUILD_DIR/libcap-master
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
sed -i '/FAKEROOT=$(DESTDIR)/a prefix=${TARGET_DIR}' ./Make.Rules
sed -i 's/shared/static/' ./Make.Rules
#./configure --prefix=$TARGET_DIR
make -j $jval
cd $BUILD_DIR/libcap-master/libcap
mkdir -p $TARGET_DIR/lib/pkgconfig
mkdir -p $TARGET_DIR/include
cp libcap.a $TARGET_DIR/lib
cp libcap.so.2.* $TARGET_DIR/lib
ln -sf $TARGET_DIR/lib/libcap.so.2.* $TARGET_DIR/lib/libcap.so.2
ln -sf $TARGET_DIR/lib/libcap.so.2 $TARGET_DIR/lib/libcap.so
cp libcap.pc -t $TARGET_DIR/lib/pkgconfig
cp libpsx.pc -t $TARGET_DIR/lib/pkgconfig
#cp cap_test $TARGET_DIR/sbin
mkdir -p $TARGET_DIR/sbin
cp _makenames $TARGET_DIR/sbin
cp *.h $TARGET_DIR/include
cp -R include/* $TARGET_DIR/include
}

ALSAlib(){
echo
/bin/echo -e "\e[93m*** ALSAlib ***\e[39m"
echo
cd $BUILD_DIR/alsa-lib-*
./configure --prefix=$TARGET_DIR --enable-static --disable-shared
make -j $jval
make install
}

GIFlib(){
echo
/bin/echo -e "\e[93m*** Building GIFlib (imlib2 and libwebp Dependency) ***\e[39m"
echo
cd $BUILD_DIR/giflib-*
sed -i 's/SHARED_LIBS = libgif.so libutil.so/SHARED_LIBS = /' ./Makefile
sed -i 's/install-lib: install-static-lib install-shared-lib/install-lib: install-static-lib/' ./Makefile
make -j $jval PREFIX=$TARGET_DIR
make install PREFIX=$TARGET_DIR
#find doc \( -name Makefile\* -o -name \*.1 \
#         -o -name \*.xml \) -exec rm -v {} \;
#install -v -dm755 $TARGET_DIR/share/doc/giflib-5.2.1
#cp -v -R doc/* $TARGET_DIR/share/doc/giflib-5.2.1
}

liblzma(){
echo
/bin/echo -e "\e[93m*** Building xz to get liblzma ( Dependency) ***\e[39m"
echo
cd $BUILD_DIR/xz-*
./configure --prefix=$TARGET_DIR --disable-shared
make -j $jval
make install
}

zlib125(){
echo
/bin/echo -e "\e[93m*** Building zlib-1.2.5 (libPNG Dependency) ***\e[39m"
echo
cd $BUILD_DIR/zlib-1.2.5
sed -i 's/"shared=1"/"shared=0"/g' ./configure
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
if [ "$platform" = "linux" ]; then
  [ ! -f config.status ] && PATH="$BIN_DIR:$PATH" ./configure --prefix=$TARGET_DIR --static
elif [ "$platform" = "darwin" ]; then
  [ ! -f config.status ] && PATH="$BIN_DIR:$PATH" ./configure --prefix=$TARGET_DIR
fi
sed -i '/cp $(SHAREDLIBV)/d' ./Makefile
make -j $jval
make install
}

libjpegturbo(){
echo
/bin/echo -e "\e[93m*** Building libjpeg-turbo ***\e[39m"
echo
cd $BUILD_DIR/libjpeg-turbo-*
PATH="$BIN_DIR:$PATH" cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX=$TARGET_DIR -DENABLE_SHARED=0 -DCMAKE_INSTALL_LIBDIR=$TARGET_DIR/lib -DCMAKE_INSTALL_INCLUDEDIR=$TARGET_DIR/include -DWITH_12BIT=1
make -j $jval
make install
}

libPNG(){
echo
/bin/echo -e "\e[93m*** Building libPNG ***\e[39m"
echo
cd $BUILD_DIR/libpng-*
./configure --prefix=$TARGET_DIR --libdir=$TARGET_DIR/lib --includedir=$TARGET_DIR/include CPPFLAGS=-I$TARGET_DIR/include --disable-shared
make -j $jval
make install
}

zlib1211(){
echo
/bin/echo -e "\e[93m*** Building zlib-1.2.11 (Python Dependency) ***\e[39m"
echo
cd $BUILD_DIR/zlib-1.2.11
# Remove files from zlib-1.2.5 build
rm -f ../../target/include/zconf.h
rm -f ../../target/include/zlib.h
rm -f ../../target/lib/libz.*
rm -f ../../target/lib/pkgconfig/zlib.pc
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
sed -i 's/"shared=1"/"shared=0"/g' ./configure
if [ "$platform" = "linux" ]; then
  [ ! -f config.status ] && PATH="$BIN_DIR:$PATH" ./configure --prefix=$TARGET_DIR --static
elif [ "$platform" = "darwin" ]; then
  [ ! -f config.status ] && PATH="$BIN_DIR:$PATH" ./configure --prefix=$TARGET_DIR
fi
PATH="$BIN_DIR:$PATH" make -j $jval
make install
}

libID3tag(){
echo
/bin/echo -e "\e[93m*** Building libID3tag (imlib2 Dependency) ***\e[39m"
echo
cd $BUILD_DIR/libid3tag-*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
./configure --prefix=$TARGET_DIR --disable-shared
make -j $jval
make install
}

libzstd(){
echo
/bin/echo -e "\e[93m*** Building libzstd ***\e[39m"
echo
cd $BUILD_DIR/zstd-*
cd build/cmake
mkdir builddir
cd builddir
cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="$TARGET_DIR" -DZSTD_LEGACY_SUPPORT=ON -DCMAKE_INSTALL_LIBDIR=$TARGET_DIR/lib -DZSTD_BUILD_SHARED:BOOL=OFF -DZSTD_LZMA_SUPPORT:BOOL=ON -DZSTD_ZLIB_SUPPORT:BOOL=ON ..
#cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX=$TARGET_DIR -DBUILD_SHARED_LIBS=0 -DCMAKE_INSTALL_LIBDIR=$TARGET_DIR/lib -DCMAKE_INSTALL_INCLUDEDIR=$TARGET_DIR/include
make -j $jval
make install
}

libwebp(){
echo
/bin/echo -e "\e[93m*** Building libwebp ***\e[39m"
echo
cd $BUILD_DIR/libwebp*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
./autogen.sh
export LIBPNG_CONFIG="$TARGET_DIR/bin/libpng16-config --static"
./configure --prefix=$TARGET_DIR --enable-libwebpdecoder --enable-libwebpmux --enable-libwebpextras --disable-shared --with-pnglibdir=$TARGET_DIR/lib --with-pngincludedir=$TARGET_DIR/include
make -j $jval
make install
}

libTIFF(){
echo
/bin/echo -e "\e[93m*** Building libTIFF ***\e[39m"
echo
cd $BUILD_DIR/tiff-*
./configure --prefix=$TARGET_DIR --disable-shared
make -j $jval
make install
}

libwebpRB(){
echo
/bin/echo -e "\e[93m*** ReBuilding libwebp ***\e[39m"
echo
cd $BUILD_DIR/libwebp*
make distclean
./autogen.sh
./configure --prefix=$TARGET_DIR --disable-shared --enable-libwebpdecoder --enable-libwebpmux --enable-libwebpextras --with-pnglibdir=$TARGET_DIR/lib --with-pngincludedir=$TARGET_DIR/include
make -j $jval
make install
}

utilmacros(){
echo
/bin/echo -e "\e[93m*** Building util-macros (xorgproto Dependency) ***\e[39m"
echo
cd $BUILD_DIR/util-macros-*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
./configure --prefix=$TARGET_DIR
make install
}

xorgproto(){
echo
/bin/echo -e "\e[93m*** Building xorgproto (libXau Dependency) ***\e[39m"
echo
cd $BUILD_DIR/xorgproto-*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
mkdir build
cd build/
meson --prefix=$TARGET_DIR .. && ninja
ninja install
}

tcl(){
echo
/bin/echo -e "\e[93m*** Building tcl (tkinter Dependency) ***\e[39m"
echo
cd $BUILD_DIR/tcl*/unix
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
./configure --prefix=$TARGET_DIR --disable-shared # --enable-64bit
PATH="$BIN_DIR:$PATH" make -j $jval
make install
}

tkinter(){
echo
/bin/echo -e "\e[93m*** Building tkinter (Python Dependency) ***\e[39m"
echo
cd $BUILD_DIR/tk*/unix
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
./configure --prefix=$TARGET_DIR --with-tcl=$BUILD_DIR/tcl8.6.10/unix --enable-static --disable-shared #--enable-64bit
PATH="$BIN_DIR:$PATH" make -j $jval
make install
}

libexpat(){
echo
/bin/echo -e "\e[93m*** Building libexpat (fontconfig Dependency) ***\e[39m"
echo
cd $BUILD_DIR/libexpat-*/expat
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
./buildconf.sh
./configure --prefix=$TARGET_DIR --enable-static --disable-shared
PATH="$BIN_DIR:$PATH" make -j $jval
make install
}

Python(){
echo
/bin/echo -e "\e[93m*** Building Python (libxml2 dependency) ***\e[39m"
echo
cd $BUILD_DIR/Python-*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
[ ! -f config.status ] && PATH="$BIN_DIR:$PATH" ./configure --prefix=$TARGET_DIR --with-system-expat --disable-shared --enable-profiling LDFLAGS="-static -static-libgcc" CFLAGS="-static" CPPFLAGS="-static" CCSHARED="" --with-ensurepip=yes # --enable-unicode=ucs4
PATH="$BIN_DIR:$PATH" make -j $jval
make install
}

libXML(){
echo
/bin/echo -e "\e[93m*** Building libXML ***\e[39m"
echo
cd $BUILD_DIR/libxml*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
[ ! -f config.status ] && PATH="$BIN_DIR:$PATH" ./configure --prefix=$TARGET_DIR --disable-shared --with-history --with-python=no #--with-python=$TARGET_DIR/bin/python3
PATH="$BIN_DIR:$PATH" make -j $jval
make install
}

FreeType2(){
echo
/bin/echo -e "\e[93m*** Building FreeType2 (libass dependency) ***\e[39m"
echo
cd $BUILD_DIR/freetype*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
sed -ri "s:.*(AUX_MODULES.*valid):\1:" modules.cfg
sed -r "s:.*(#.*SUBPIXEL_RENDERING) .*:\1:" -i include/freetype/config/ftoption.h
[ ! -f config.status ] && PATH="$BIN_DIR:$PATH" ./configure --prefix=$TARGET_DIR --enable-static --disable-shared --without-harfbuzz
PATH="$BIN_DIR:$PATH" make -j $jval
make install
}

FontConfig(){
echo
/bin/echo -e "\e[93m*** Building FontConfig ***\e[39m"
echo
cd $BUILD_DIR/fontconfig*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
[ ! -f config.status ] && PATH="$BIN_DIR:$PATH" ./configure --prefix=$TARGET_DIR --enable-static --disable-shared
PATH="$BIN_DIR:$PATH" make -j $jval
make install
}

harfbuzz(){
echo
/bin/echo -e "\e[93m*** Building harfbuzz (libass dependency) ***\e[39m"
echo
cd $BUILD_DIR/harfbuzz-*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
if [ ! -f configure ]; then
  PATH="$BIN_DIR:$PATH" ./autogen.sh --prefix=$TARGET_DIR --enable-static --disable-shared --with-freetype=yes -with-icu=no
fi
#PATH="$BIN_DIR:$PATH" ./configure
make -j $jval
make install
  sed -i.bak 's/-lharfbuzz.*/-lharfbuzz -lfreetype/' "$TARGET_DIR/lib/pkgconfig/harfbuzz.pc"
  sed -i.bak 's/libfreetype.la -lbz2/libfreetype.la -lharfbuzz -lbz2/' "$TARGET_DIR/lib/libharfbuzz.la"
#  sed -i.bak 's/-lharfbuzz.*/-lharfbuzz -lharfbuzz-subset -lfreetype/' "$TARGET_DIR/lib/pkgconfig/harfbuzz.pc"
#  sed -i.bak 's/libfreetype.la -lbz2/libfreetype.la -lharfbuzz -lbz2 \/home\/tec\/DEV\/ffmpeg-static\/target\/lib\/libharfbuzz-subset.la -lharfbuzz -lbz2/' "$TARGET_DIR/lib/libharfbuzz.la"
}

FreeType2RB(){
echo
/bin/echo -e "\e[93m*** ReBuilding FreeType2 after HarfBuzz ***\e[39m"
echo
cd $BUILD_DIR/freetype*
#make distclean
#[ ! -f config.status ] && PATH="$BIN_DIR:$PATH"
./configure --prefix=$TARGET_DIR --enable-static --disable-shared --with-harfbuzz
#PATH="$BIN_DIR:$PATH" make -j $jval
make install
#  sed -i.bak 's/-lfreetype.*/-lfreetype -lharfbuzz/' "$TARGET_DIR/lib/pkgconfig/freetype2.pc"
#  sed -i.bak 's/libfreetype.la -lbz2/libfreetype.la -lharfbuzz -lbz2/' "$TARGET_DIR/lib/libfreetype.la"
}

openjpeg(){
echo
/bin/echo -e "\e[93m*** Building openjpeg ***\e[39m"
echo
cd $BUILD_DIR/openjpeg-*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
PATH="$BIN_DIR:$PATH" cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="$TARGET_DIR" -DBUILD_PKGCONFIG_FILES=on -DWITH_ASTYLE=ON -DBUILD\_SHARED\_LIBS:bool=off -DBUILD_THIRDPARTY:BOOL=ON -DBUILD_SHARED_LIBS:bool=off -DBUILD_STATIC_LIBS:bool=on -DBUILD_PKGCONFIG_FILES:bool=on -DCMAKE_BUILD_TYPE:string="Release"
# -DCMAKE_INSTALL_PREFIX="$TARGET_DIR" -DBUILD_SHARED_LIBS:bool=off -DBUILD_STATIC_LIBS:bool=on -DBUILD_PKGCONFIG_FILES:bool=on -DCMAKE_BUILD_TYPE:string="Release"
make -j $jval
make install
}

imlib2(){
echo
/bin/echo -e "\e[93m*** Building imlib2 (libcaca dependency)***\e[39m"
echo
cd $BUILD_DIR/imlib2-*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
[ ! -f config.status ] && PATH="$BIN_DIR:$PATH" ./configure --prefix=$TARGET_DIR --enable-static --disable-shared
PATH="$BIN_DIR:$PATH" make -j $jval
make install
}

libcaca(){
echo
/bin/echo -e "\e[93m*** Building libcaca... ***\e[39m"
echo
cd $BUILD_DIR/libcaca-*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
sed -i 's/"$amvers" "<" "1.5"/"$amvers" "<" "1.05"/g' ./bootstrap
./bootstrap
./configure --prefix=$TARGET_DIR --bindir="$BIN_DIR" --enable-static --disable-shared --disable-doc --disable-slang --disable-ruby --disable-csharp --disable-java --disable-cxx --disable-ncurses --disable-x11 #--disable-python --disable-cocoa
make -j $jval
make install
}

voamrwbenc(){
echo
/bin/echo -e "\e[93m*** Building vo-amrwbenc... ***\e[39m"
echo
cd $BUILD_DIR/vo-amrwbenc-*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
./configure --prefix=$TARGET_DIR --bindir="$BIN_DIR" --disable-shared --enable-static
make -j $jval
make install
}

opencoreamr(){
echo
/bin/echo -e "\e[93m*** Building opencore-amr... ***\e[39m"
echo
cd $BUILD_DIR/opencore-amr*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
./configure --prefix=$TARGET_DIR --bindir="$BIN_DIR" --disable-shared --enable-static
make -j $jval
make install
}

OpenSSL(){
echo
/bin/echo -e "\e[93m*** Building OpenSSL ***\e[39m"
echo
cd $BUILD_DIR/openssl*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
if [ "$platform" = "darwin" ]; then
  PATH="$BIN_DIR:$PATH" ./Configure darwin64-x86_64-cc --prefix=$TARGET_DIR
elif [ "$platform" = "linux" ]; then
  PATH="$BIN_DIR:$PATH" ./config --prefix=$TARGET_DIR no-shared
fi
PATH="$BIN_DIR:$PATH" make -j $jval
make install
}

libilbc(){
echo
/bin/echo -e "\e[93m*** Building libilbc ***\e[39m"
echo
cd $BUILD_DIR/libilbc-*
sed 's/lib64/lib/g' -i CMakeLists.txt
cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="$TARGET_DIR" -DBUILD_SHARED_LIBS=0 -DCMAKE_LIBRARY_OUTPUT_DIRECTORY:PATH=$TARGET_DIR/lib
make -j $jval
make install
}

Xvid(){
echo
/bin/echo -e "\e[93m*** Building Xvid ***\e[39m"
echo
cd $BUILD_DIR/xvidcore/build/generic
sed -i 's/^LN_S=@LN_S@/& -f -v/' platform.inc.in
sed -i '/AC_MSG_CHECKING(for platform specific LDFLAGS\/CFLAGS)/{n;s/.*/SPECIFIC_LDFLAGS="-static"/}' ./configure.in
sed -i '/SPECIFIC_LDFLAGS="-static"/{n;s/.*/SPECIFIC_CFLAGS="-static"/}' ./configure.in
PATH="$BIN_DIR:$PATH" ./bootstrap.sh
PATH="$BIN_DIR:$PATH" ./configure --prefix=$TARGET_DIR --disable-shared
PATH="$BIN_DIR:$PATH" make -j $jval
make install
chmod -v 755 $TARGET_DIR/lib/libxvidcore.so.4.3
install -v -m755 -d $TARGET_DIR/share/doc/xvidcore-1.3.5/examples && install -v -m644 ../../doc/* $TARGET_DIR/share/doc/xvidcore-1.3.5 && install -v -m644 ../../examples/* $TARGET_DIR/share/doc/xvidcore-1.3.5/examples
}

x264(){
echo
/bin/echo -e "\e[93m*** Building x264 ***\e[39m"
echo
cd $BUILD_DIR/x264*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
[ ! -f config.status ] && PATH="$BIN_DIR:$PATH" ./configure --prefix=$TARGET_DIR --enable-static --disable-opencl --enable-pic
PATH="$BIN_DIR:$PATH" make -j $jval
make install
}

x265(){
echo
/bin/echo -e "\e[93m*** Building x265 ***\e[39m"
echo
cd $BUILD_DIR/x265*
cd build/linux
[ $rebuild -eq 1 ] && find . -mindepth 1 ! -name 'make-Makefiles.bash' -and ! -name 'multilib.sh' -exec rm -r {} +
PATH="$BIN_DIR:$PATH" cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="$TARGET_DIR" -DENABLE_SHARED:BOOL=OFF -DSTATIC_LINK_CRT:BOOL=ON -DENABLE_CLI:BOOL=OFF ../../source
sed -i 's/-lgcc_s/-lgcc_eh/g' x265.pc
make -j $jval
make install
}

fdkaac(){
echo
/bin/echo -e "\e[93m*** Building fdk-aac ***\e[39m"
echo
cd $BUILD_DIR/fdk-aac*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
autoreconf -fiv
[ ! -f config.status ] && ./configure --prefix=$TARGET_DIR --disable-shared
make -j $jval
make install
}

fribidi(){
echo
/bin/echo -e "\e[93m*** Building fribidi (libass dependency)***\e[39m"
echo
cd $BUILD_DIR/fribidi-*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
./configure --prefix=$TARGET_DIR --disable-shared --enable-static
make -j $jval
make install
}

libass(){
echo
/bin/echo -e "\e[93m*** Building libass ***\e[39m"
echo
cd $BUILD_DIR/libass-*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
PATH="$BIN_DIR:$PATH" ./autogen.sh
PATH="$BIN_DIR:$PATH" ./configure --prefix=$TARGET_DIR --disable-shared
PATH="$BIN_DIR:$PATH" make -j $jval
make install
}

mp3lame(){
echo
/bin/echo -e "\e[93m*** Building mp3lame ***\e[39m"
echo
cd $BUILD_DIR/lame*
# The lame build script does not recognize aarch64, so need to set it manually
uname -a | grep -q 'aarch64' && lame_build_target="--build=arm-linux" || lame_build_target=''
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
[ ! -f config.status ] && PATH="$BIN_DIR:$PATH" ./configure --prefix=$TARGET_DIR --enable-nasm --disable-shared $lame_build_target
make
make install
}

opus(){
echo
/bin/echo -e "\e[93m*** Building opus ***\e[39m"
echo
cd $BUILD_DIR/opus*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
./autogen.sh
[ ! -f config.status ] && ./configure --prefix=$TARGET_DIR --enable-intrinsics --disable-shared
make -j $jval
make install
sed -i "s/Version: unknown/Version: 1.3.1/g" $TARGET_DIR/lib/pkgconfig/opus.pc
}

libpvx(){
echo
/bin/echo -e "\e[93m*** Building libvpx ***\e[39m"
echo
cd $BUILD_DIR/libvpx*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
[ ! -f config.status ] && PATH="$BIN_DIR:$PATH" ./configure --prefix=$TARGET_DIR --disable-examples --disable-unit-tests --enable-pic --enable-vp9-highbitdepth --enable-vp8 --enable-vp9 --enable-better-hw-compatibility
PATH="$BIN_DIR:$PATH" make -j $jval
make install
}

librtmp(){
echo
/bin/echo -e "\e[93m*** Building librtmp ***\e[39m"
echo
cd $BUILD_DIR/rtmpdump-*
cd librtmp
[ $rebuild -eq 1 ] && make distclean || true
# there's no configure, we have to edit Makefile directly
if [ "$platform" = "linux" ]; then
  sed -i "/INC=.*/d" ./Makefile # Remove INC if present from previous run.
  sed -i "s/prefix=.*/prefix=${TARGET_DIR_SED}\nINC=-I\$(prefix)\/include/" ./Makefile
  sed -i "s/SHARED=.*/SHARED=no/" ./Makefile
elif [ "$platform" = "darwin" ]; then
  sed -i "" "s/prefix=.*/prefix=${TARGET_DIR_SED}/" ./Makefile
fi
make install_base
}

libsoxr(){
echo
/bin/echo -e "\e[93m*** Building libsoxr ***\e[39m"
echo
cd $BUILD_DIR/soxr-*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
PATH="$BIN_DIR:$PATH" cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="$TARGET_DIR" -DBUILD_SHARED_LIBS:bool=off -DWITH_OPENMP:bool=off -DBUILD_TESTS:bool=off
make -j $jval
make install
}

libvidstab(){
echo
/bin/echo -e "\e[93m*** Building libvidstab ***\e[39m"
echo
cd $BUILD_DIR/vid.stab-release-*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
if [ "$platform" = "linux" ]; then
  sed -i "s/vidstab SHARED/vidstab STATIC/" ./CMakeLists.txt
elif [ "$platform" = "darwin" ]; then
  sed -i "" "s/vidstab SHARED/vidstab STATIC/" ./CMakeLists.txt
fi
PATH="$BIN_DIR:$PATH" cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="$TARGET_DIR"
make -j $jval
make install
}

zimg(){
echo
/bin/echo -e "\e[93m*** Building zimg ***\e[39m"
echo
cd $BUILD_DIR/zimg-release-*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
./autogen.sh
./configure --enable-static  --prefix=$TARGET_DIR --disable-shared
make -j $jval
make install
}

libogg(){
echo
/bin/echo -e "\e[93m*** Building libogg ***\e[39m"
echo
cd $BUILD_DIR/ogg*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
./autogen.sh
./configure --prefix=$TARGET_DIR --disable-shared
make -j $jval
make install
}

libflac(){
echo
/bin/echo -e "\e[93m*** Building libflac ***\e[39m"
echo
cd $BUILD_DIR/flac-*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
./autogen.sh
PATH="$BIN_DIR:$PATH" ./configure --prefix=$TARGET_DIR --disable-shared --disable-thorough-tests
make -j $jval
make install
}

libvorbis(){
echo
/bin/echo -e "\e[93m*** Building libvorbis ***\e[39m"
echo
cd $BUILD_DIR/vorbis*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
./autogen.sh
./configure --prefix=$TARGET_DIR --disable-shared
make -j $jval
make install
}

libspeex(){
echo
/bin/echo -e "\e[93m*** Building libspeex ***\e[39m"
echo
cd $BUILD_DIR/speex*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
./autogen.sh
./configure --prefix=$TARGET_DIR --disable-shared
make -j $jval
make install
}

libsndfile(){
echo
/bin/echo -e "\e[93m*** Building libsndfile ***\e[39m"
echo
cd $BUILD_DIR/libsndfile-*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
./autogen.sh
./configure --prefix=$TARGET_DIR --enable-experimental --disable-shared
make -j $jval
make install
}

libtwolame(){
echo
/bin/echo -e "\e[93m*** Building libtwolame ***\e[39m"
echo
cd $BUILD_DIR/twolame-*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
#./autogen.sh --prefix=$TARGET_DIR --bindir="$BIN_DIR" --disable-shared --enable-static 
./configure --prefix=$TARGET_DIR --bindir="$BIN_DIR" --disable-shared --enable-static 
make -j $jval
make install
}

libtheora(){
echo
/bin/echo -e "\e[93mCompiling libtheora...\e[39m"
echo
cd $BUILD_DIR/libtheora-*
sed -i 's/png_\(sizeof\)/\1/g' examples/png2theora.c
./configure --prefix=$TARGET_DIR --disable-oggtest --disable-vorbistest --with-ogg-includes="$TARGET_DIR/include" --with-ogg-libraries="$TARGET_DIR/build/lib" --with-vorbis-includes="$TARGET_DIR/include" --with-vorbis-libraries="$TARGET_DIR/build/lib" --disable-shared --enable-static
make -j $jval
make install
}

PulseAudio(){
echo
/bin/echo -e "\e[93m*** Building PulseAudio ***\e[39m"
echo
cd $BUILD_DIR/pulseaudio-*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
NOCONFIGURE=1 ./bootstrap.sh
#./bootstrap.sh
#./configure --prefix=$TARGET_DIR --enable-static --with-udev-rules-dir=$TARGET_DIR/lib/udev/rules.d --with-systemduserunitdir=$TARGET_DIR/etc/systemd/user --without-caps --disable-shared
./configure --prefix=$TARGET_DIR --enable-static --disable-shared --disable-rpath --disable-fast-install --disable-tests --disable-x11 --disable-atomic-arm-linux-helpers --disable-memfd --disable-coreaudio-output --disable-solaris --disable-solaris --disable-glib2 --disable-gtk3 --disable-gsettings --disable-gconf --disable-avahi --disable-jack --disable-asyncns --disable-bluez5 --disable-systemd-daemon --disable-systemd-login --disable-systemd-journal --disable-manpages --disable-gstreamer
make
make install
}

ffmpeg(){
# FFMpeg
echo
/bin/echo -e "\e[93m*** Building FFmpeg ***\e[39m"
date +%H:%M:%S
echo
cd $BUILD_DIR/FFmpeg*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true

if [ "$platform" = "linux" ]; then
  [ ! -f config.status ] && PATH="$BIN_DIR:$PATH" \
  PKG_CONFIG_PATH="$TARGET_DIR/lib/pkgconfig" ./configure \
    --prefix="$TARGET_DIR" \
    --pkg-config-flags="--static" \
    --extra-version=Tec-3.1s \
    --extra-cflags="-I$TARGET_DIR/include" \
    --extra-ldflags="-L$TARGET_DIR/lib" \
    --extra-libs="-lpthread -lm -lz -ldl -lharfbuzz" \
    --extra-ldexeflags="-static" \
    --bindir="$BIN_DIR" \
    --enable-pic \
    --enable-ffplay \
    --enable-gpl \
    --enable-nonfree \
    --enable-version3 \
  --enable-alsa \
    --enable-bzlib \
  --disable-chromaprint \
    --enable-fontconfig \
    --enable-frei0r \
    --enable-iconv \
    --enable-libass \
    --enable-libcaca \
    --enable-libfdk-aac \
    --enable-libfreetype \
    --enable-libfribidi \
    --enable-libilbc \
    --enable-libmp3lame \
    --enable-libopencore-amrnb \
    --enable-libopencore-amrwb \
    --enable-libopenjpeg \
    --enable-libopus \
  --disable-libpulse \
    --enable-librtmp \
    --enable-libsoxr \
    --enable-libspeex \
    --enable-libtheora \
    --enable-libtwolame \
    --enable-libvidstab \
    --enable-libvo-amrwbenc \
    --enable-libvorbis \
    --enable-libvpx \
    --enable-libwebp \
    --enable-libx264 \
    --enable-libx265 \
    --enable-libxcb \
    --enable-libxcb-shm \
    --enable-libxcb-xfixes \
    --enable-libxcb-shape \
    --enable-libxml2 \
    --enable-libxvid \
    --enable-libzimg \
    --enable-lzma \
    --enable-openssl \
  --disable-sndio \
  --disable-sdl2 \
  --disable-vaapi \
    --enable-vdpau \
  --disable-xlib \
    --enable-zlib
# Not working yet
#    
# ---------------
# Not tested yet
#
#  --enable-gnutls
#  --enable-ladspa          enable LADSPA audio filtering [no]
#  --enable-libaom          enable AV1 video encoding/decoding via libaom [no]
#  --enable-libaribb24      enable ARIB text and caption decoding via libaribb24 [no]
#  --enable-libbluray       enable BluRay reading using libbluray [no]
#  --enable-libbs2b         enable bs2b DSP library [no]
#  --enable-libcelt         enable CELT decoding via libcelt [no]
#  --enable-libcdio         enable audio CD grabbing with libcdio [no]
#  --enable-libcodec2       enable codec2 en/decoding using libcodec2 [no]
#  --enable-libdav1d        enable AV1 decoding via libdav1d [no]
#  --enable-libdavs2        enable AVS2 decoding via libdavs2 [no]
#  --enable-libdc1394       enable IIDC-1394 grabbing using libdc1394 and libraw1394 [no]
#  --enable-libflite        enable flite (voice synthesis) support via libflite [no]
#  --enable-libgme          enable Game Music Emu via libgme [no]
#  --enable-libgsm          enable GSM de/encoding via libgsm [no]
#  --enable-libiec61883     enable iec61883 via libiec61883 [no]
#  --enable-libjack         enable JACK audio sound server [no]
#  --enable-libklvanc       enable Kernel Labs VANC processing [no]
#  --enable-libkvazaar      enable HEVC encoding via libkvazaar [no]
#  --enable-liblensfun      enable lensfun lens correction [no]
#  --enable-libmodplug      enable ModPlug via libmodplug [no]
#  --enable-libopencv       enable video filtering via libopencv [no]
#  --enable-libopenh264     enable H.264 encoding via OpenH264 [no]
#  --enable-libopenmpt      enable decoding tracked files via libopenmpt [no]
#  --enable-librav1e        enable AV1 encoding via rav1e [no] (unknown option?)
#  --enable-librsvg         enable SVG rasterization via librsvg [no]
#  --enable-librubberband   enable rubberband needed for rubberband filter [no]
#  --enable-libshine        enable fixed-point MP3 encoding via libshine [no]
#  --enable-libsmbclient    enable Samba protocol via libsmbclient [no]
#  --enable-libsnappy       enable Snappy compression, needed for hap encoding [no]
#  --enable-libsrt          enable Haivision SRT protocol via libsrt [no]
#  --enable-libssh          enable SFTP protocol via libssh [no]
#  --enable-libtensorflow   enable TensorFlow as a DNN module backend for DNN based filters like sr [no]
#  --enable-libtesseract    enable Tesseract, needed for ocr filter [no]
#  --enable-libtls          enable LibreSSL (via libtls), needed for https support if openssl, gnutls or mbedtls is not used [no]
#  --enable-libv4l2         enable libv4l2/v4l-utils [no]
#  --enable-libwavpack      enable wavpack encoding via libwavpack [no]
#  --enable-libxavs         enable AVS encoding via xavs [no]
#  --enable-libxavs2        enable AVS2 encoding via xavs2 [no]
#  --enable-libzmq          enable message passing via libzmq [no]
#  --enable-libzvbi         enable teletext support via libzvbi [no]
#  --enable-lv2             enable LV2 audio filtering [no]
#  --enable-decklink        enable Blackmagic DeckLink I/O support [no]
#  --enable-mbedtls         enable mbedTLS, needed for https support if openssl, gnutls or libtls is not used [no]
#  --enable-mediacodec      enable Android MediaCodec support [no] (requires --enable-jni)
#  --enable-libmysofa       enable libmysofa, needed for sofalizer filter [no]
#  --enable-openal          enable OpenAL 1.1 capture support [no]
#  --enable-opencl          enable OpenCL processing [no]
#  --enable-opengl          enable OpenGL rendering [no]
#  --enable-pocketsphinx    enable PocketSphinx, needed for asr filter [no]
#  --enable-vapoursynth     enable VapourSynth demuxer [no]
#
# ---------------
# Deprecated
#    --enable-avresample \
# ---------------
elif [ "$platform" = "darwin" ]; then
  [ ! -f config.status ] && PATH="$BIN_DIR:$PATH" \
  PKG_CONFIG_PATH="${TARGET_DIR}/lib/pkgconfig:/usr/local/lib/pkgconfig:/usr/local/share/pkgconfig:/usr/local/Cellar/openssl/1.0.2o_1/lib/pkgconfig" ./configure \
    --cc=/usr/bin/clang \
    --prefix="$TARGET_DIR" \
    --pkg-config-flags="--static" \
    --extra-version=Tec-3.1s \
    --extra-cflags="-I$TARGET_DIR/include" \
    --extra-ldflags="-L$TARGET_DIR/lib" \
    --extra-ldexeflags="-Bstatic" \
    --bindir="$BIN_DIR" \
    --enable-pic \
    --enable-ffplay \
    --enable-fontconfig \
    --enable-frei0r \
    --enable-gpl \
    --enable-version3 \
    --enable-libass \
    --enable-libfribidi \
    --enable-libfdk-aac \
    --enable-libfreetype \
    --enable-libmp3lame \
    --enable-libopencore-amrnb \
    --enable-libopencore-amrwb \
    --enable-libopenjpeg \
    --enable-libopus \
    --enable-librtmp \
    --enable-libsoxr \
    --enable-libspeex \
    --enable-libvidstab \
    --enable-libvorbis \
    --enable-libvpx \
    --enable-libwebp \
    --enable-libx264 \
    --enable-libx265 \
    --enable-libxvid \
    --enable-libzimg \
    --enable-nonfree \
    --enable-openssl
fi

PATH="$BIN_DIR:$PATH" make -j $jval
make install
make distclean
}

spd-say --rate -25 "Starting dependencies"
#yasm
asciidoc
nasm
#linuxPAM
#libcap
ALSAlib
GIFlib
liblzma
zlib125
libjpegturbo
libPNG
zlib1211
libID3tag
libzstd
libwebp
libTIFF
libwebpRB
#utilmacros
#xorgproto
tcl
tkinter
libexpat
#Python
libXML
FreeType2
FontConfig
harfbuzz
#FreeType2RB
openjpeg
imlib2
libcaca
voamrwbenc
opencoreamr
OpenSSL
libilbc
Xvid
x264
x265
fdkaac
fribidi
libass
mp3lame
opus
libpvx
librtmp
libsoxr
libvidstab
zimg
libogg
libflac
libvorbis
libspeex
libsndfile
libtwolame
libtheora
#PulseAudio #Doesn't work yet
spd-say --rate -25 "Dependencies built"
ffmpeg

date +%H:%M:%S
spd-say --rate -25 "Build Complete"
hash -r
