#!/bin/sh

# ffmpeg static build 3.9s

set -e
set -u
echo
start_time=$(date +%H:%M)
echo $start_time

jflag=
jval=$(nproc)
rebuild=0
download_only=0
git_get_latest=n
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
mkdir -pv "$BUILD_DIR" "$TARGET_DIR" "$DOWNLOAD_DIR" "$BIN_DIR"

#download and extract package
download() {
  filename="$1"
  if [ ! -z "$2" ];then
    filename="$2"
  fi
  ../download.pl "$DOWNLOAD_DIR" "$1" "$filename" "$3" "$4"
  #disable uncompress
  REPLACE="$rebuild" CACHE_DIR="$DOWNLOAD_DIR" ../fetchurl "http://cache/$filename"
}

do_svn_checkout() {
  repo_url="$1"
  to_dir="$2"
  desired_revision="$3"
  if [ ! -d $to_dir ]; then
    echo "svn checking out to $to_dir"
    if [ -z "$desired_revision" ]; then
      svn checkout $repo_url $to_dir.tmp  --non-interactive --trust-server-cert || exit 1
    else
      svn checkout -r $desired_revision $repo_url $to_dir.tmp || exit 1
    fi
    mv $to_dir.tmp $to_dir
  else
    cd $to_dir
    echo "not svn Updating $to_dir since usually svn repo's aren't updated frequently enough..."
    # XXX accomodate for desired revision here if I ever uncomment the next line...
    # svn up
    cd ..
  fi
}

do_git_checkout() {
  local repo_url="$1"
  local to_dir="$2"
  if [ -z $to_dir ]; then
    to_dir=$(basename $repo_url | sed s/\.git/-git/) # http://y/abc.git -> abc_git
  fi
  local desired_branch="$3"
  if [ ! -d $to_dir ]; then
    echo "Downloading (via git clone) $to_dir from $repo_url"
    rm -rf $to_dir.tmp # just in case it was interrupted previously...
    git clone $repo_url $to_dir.tmp || exit 1
    # prevent partial checkouts by renaming it only after success
    mv $to_dir.tmp $to_dir
    echo "done git cloning to $to_dir"
    cd $to_dir
  else
    cd $to_dir
    if [ $git_get_latest = "y" ]; then
      git fetch # want this for later...
    else
      echo "not doing git get latest pull for latest code $to_dir" # too slow'ish...
    fi
  fi

  # reset will be useless if they didn't git_get_latest but pretty fast so who cares...plus what if they changed branches? :)
  old_git_version=`git rev-parse HEAD`
  if [ -z $desired_branch ]; then
    desired_branch="master"
  fi
  echo "doing git checkout $desired_branch" 
  git checkout "$desired_branch" || (git_hard_reset && git checkout "$desired_branch") || (git reset --hard "$desired_branch") || exit 1 # can't just use merge -f because might "think" patch files already applied when their changes have been lost, etc...
  # vmaf on 16.04 needed that weird reset --hard? huh?
  if git show-ref --verify --quiet "refs/remotes/origin/$desired_branch"; then # $desired_branch is actually a branch, not a tag or commit
    git merge "origin/$desired_branch" || exit 1 # get incoming changes to a branch
  fi
  new_git_version=`git rev-parse HEAD`
  if [ "$old_git_version" != "$new_git_version" ]; then
    echo "got upstream changes, forcing re-configure. Doing git clean -f"
    git_hard_reset
  else
    echo "fetched no code changes, not forcing reconfigure for that..."
  fi
  cd ..
}

git_hard_reset() {
  git reset --hard # throw away results of patch files
  git clean -f # throw away local changes; 'already_*' and bak-files for instance.
}

apply_patch() {
  local url=$1 # if you want it to use a local file instead of a url one [i.e. local file with local modifications] specify it like file://localhost/full/path/to/filename.patch
  local patch_type=$2
  if [ -z $patch_type ]; then
    patch_type="-p0" # some are -p1 unfortunately, git's default
  fi
  local patch_name=$(basename $url)
  local patch_done_name="$patch_name.done"
  if [ ! -e $patch_done_name ]; then
    if [ -f $patch_name ]; then
      rm $patch_name || exit 1 # remove old version in case it has been since updated on the server...
    fi
    curl -4 --retry 5 $url -O --fail || echo_and_exit "unable to download patch file $url"
    echo "applying patch $patch_name"
    patch $patch_type < "$patch_name" || exit 1
    touch $patch_done_name || exit 1
    # too crazy, you can't do do_configure then apply a patch?
    # rm -f already_ran* # if it's a new patch, reset everything too, in case it's really really really new
  #else
  #  echo "patch $patch_name already applied" # too chatty
  fi
}

echo_and_exit() {
  echo "failure, exiting: $1"
  exit 1
}

echo
/bin/echo -e "\e[93m#### FFmpeg static build ####\e[39m"
echo

#this is our working directory
cd $BUILD_DIR

alldownloads() {
#download \
#  "autoconf-2.71.tar.xz" \
#  "" \
#  "12cfa1687ffa2606337efe1a64416106" \
#  "http://ftp.gnu.org/gnu/autoconf/"
#do_git_checkout https://git.sv.gnu.org/r/autoconf.git "$BUILD_DIR"/autoconf-git v2.71


#[ $is_x86 -eq 1 ] && download \
#  "yasm-1.3.0.tar.gz" \
#  "" \
#  "fc9e586751ff789b34b1f21d572d96af" \
#  "http://www.tortall.net/projects/yasm/releases/"

do_git_checkout https://github.com/asciidoc-py/asciidoc-py.git "$BUILD_DIR"/asciidoc-git 9.x

[ $is_x86 -eq 1 ] && download \
  "nasm-2.15.05.tar.bz2" \
  "" \
  "b8985eddf3a6b08fc246c14f5889147c" \
  "https://www.nasm.us/pub/nasm/releasebuilds/2.15.05/"
#[ $is_x86 -eq 1 ] && do_git_checkout https://github.com/netwide-assembler/nasm.git "$BUILD_DIR"/nasm-git master

do_git_checkout https://github.com/mesonbuild/meson.git "$BUILD_DIR"/meson-git 0.56 #master

do_git_checkout https://github.com/libffi/libffi.git "$BUILD_DIR"/libffi-git master

download \
  "cmake-3.16.4-Linux-x86_64.tar.gz" \
  "" \
  "d3ac45c550a1b6799ff370cdb6b7bbe0" \
  "https://github.com/Kitware/CMake/releases/download/v3.16.4/"

if [ ! -f "$DOWNLOAD_DIR"/ninja-linux.zip ]; then
  wget -L -P "$DOWNLOAD_DIR" https://github.com/ninja-build/ninja/releases/download/v1.10.0/ninja-linux.zip
fi

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

do_git_checkout https://git.tukaani.org/xz.git "$BUILD_DIR"/xz-git master # v5.2.4

do_git_checkout https://github.com/madler/zlib.git "$BUILD_DIR"/zlib-git master

do_git_checkout https://github.com/facebook/zstd.git "$BUILD_DIR"/zstd-git master

#download \
#  "tcl8.6.10-src.tar.gz" \
#  "" \
#  "97c55573f8520bcab74e21bfd8d0aadc" \
#  "https://netcologne.dl.sourceforge.net/project/tcl/Tcl/8.6.10/"

#download \
#  "tk8.6.10-src.tar.gz" \
#  "" \
#  "602a47ad9ecac7bf655ada729d140a94" \
#  "https://netix.dl.sourceforge.net/project/tcl/Tcl/8.6.10/"

do_git_checkout https://github.com/libexpat/libexpat.git "$BUILD_DIR"/libexpat-git master

#download \
#  "OpenSSL_1_0_2o.tar.gz" \
#  "" \
#  "5b5c050f83feaa0c784070637fac3af4" \
#  "https://github.com/openssl/openssl/archive/"
do_git_checkout https://github.com/openssl/openssl.git "$BUILD_DIR"/openssl-old-git OpenSSL_1_0_2u
#do_git_checkout https://github.com/openssl/openssl.git "$BUILD_DIR"/openssl-git OpenSSL_1_1_1d #OpenSSL_1_1_0l OpenSSL_1_0_2u

do_git_checkout https://git.ffmpeg.org/rtmpdump "$BUILD_DIR"/rtmpdump-git master

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

do_git_checkout https://git.videolan.org/git/ffmpeg/nv-codec-headers.git "$BUILD_DIR"/nv-codec-headers-git master

# there's a 2.58 but guess I'd need to use meson for that
# there's also a 2.56.4 2.57.1 2.57.2 2.57.3
do_git_checkout https://gitlab.gnome.org/GNOME/glib.git "$BUILD_DIR"/glib-git 2.56.3

do_git_checkout https://git.savannah.gnu.org/git/libcdio.git "$BUILD_DIR"/libcdio-git master

do_git_checkout https://github.com/rocky/libcdio-paranoia.git "$BUILD_DIR"/libcdio-paranoia-git master

do_git_checkout https://github.com/rocky/vcdimager.git "$BUILD_DIR"/vcdimager-git master

do_git_checkout https://code.videolan.org/videolan/libbluray.git "$BUILD_DIR"/libbluray-git master

do_git_checkout https://github.com/hoene/libmysofa.git "$BUILD_DIR"/libmysofa-git v1.0

#download \
#  "alsa-lib-1.2.1.2.tar.bz2" \
#  "" \
#  "82ddd3698469beec147e4f4a67134ea0" \
#  "https://www.alsa-project.org/files/pub/lib/"
do_git_checkout https://git.alsa-project.org/http/alsa-lib.git "$BUILD_DIR"/alsa-lib-git master

#download \
#  "vo-amrwbenc-0.1.3.tar.gz" \
#  "" \
#  "f63bb92bde0b1583cb3cb344c12922e0" \
#  "http://downloads.sourceforge.net/opencore-amr/vo-amrwbenc/"
do_git_checkout https://github.com/mstorsjo/vo-amrwbenc.git "$BUILD_DIR"/vo-amrwbenc-git master

#download \
#  "opencore-amr-0.1.3.tar.gz" \
#  "" \
#  "09d2c5dfb43a9f6e9fec8b1ae678e725" \
#  "http://downloads.sourceforge.net/opencore-amr/opencore-amr/"
do_git_checkout https://github.com/BelledonneCommunications/opencore-amr.git "$BUILD_DIR"/opencore-amr-git master

#download \
#  "v2.0.1.tar.gz" \
#  "fdk-aac-2.0.1.tar.gz" \
#  "5b85f858ee416a058574a1028a3e1b85" \
#  "https://github.com/mstorsjo/fdk-aac/archive"
do_git_checkout https://github.com/mstorsjo/fdk-aac.git "$BUILD_DIR"/fdk-aac-git master

#download \
#  "lame-3.100.tar.gz" \
#  "" \
#  "83e260acbe4389b54fe08e0bdbf7cddb" \
#  "http://downloads.sourceforge.net/project/lame/lame/3.100"
do_svn_checkout https://svn.code.sf.net/p/lame/svn/trunk/lame "$BUILD_DIR"/lame-svn 6449

#download \
#  "v1.3.1.tar.gz" \
#  "opus-1.3.1.tar.gz" \
#  "b27f67923ffcbc8efb4ce7f29cbe3faf" \
#  "https://github.com/xiph/opus/archive/"
do_git_checkout https://github.com/xiph/opus.git "$BUILD_DIR"/opus-git master

#download \
#  "v1.8.2.tar.gz" \
#  "libvpx-v1.8.2.tar.gz" \
#  "6dbccca688886c66a216d7e445525bce" \
#  "https://github.com/webmproject/libvpx/archive/"
do_git_checkout https://chromium.googlesource.com/webm/libvpx "$BUILD_DIR"/libvpx-git master

#download \
#  "soxr-0.1.3-Source.tar.xz" \
#  "" \
#  "3f16f4dcb35b471682d4321eda6f6c08" \
#  "https://sourceforge.net/projects/soxr/files/"
do_git_checkout https://git.code.sf.net/p/soxr/code "$BUILD_DIR"/soxr-git master

do_git_checkout https://github.com/kubo/flite.git $BUILD_DIR/flite-git master

do_git_checkout https://github.com/google/snappy.git $BUILD_DIR/snappy-git main
cd $BUILD_DIR/snappy-git
git submodule update --init
cd $BUILD_DIR

#download \
#  "vamp-plugin-sdk-v2.7.1.tar.gz" \
#  "vamp-plugin-sdk-vamp-plugin-sdk-v2.7.1.tar.gz" \
#  "0199b4cc0bc817566f6840c9ae8dc315" \
#  "https://github.com/c4dm/vamp-plugin-sdk/archive/"
do_git_checkout https://github.com/c4dm/vamp-plugin-sdk.git "$BUILD_DIR"/vamp-plugin-sdk-git master

#download \
#  "fftw-3.3.6-pl2.tar.gz" \
#  "" \
#  "927e481edbb32575397eb3d62535a856" \
#  "http://fftw.org/"
do_git_checkout https://github.com/FFTW/fftw3.git $BUILD_DIR/fftw3-git master

do_git_checkout https://github.com/erikd/libsamplerate.git $BUILD_DIR/libsamplerate-git master

do_git_checkout https://github.com/breakfastquay/rubberband.git $BUILD_DIR/rubberband-git v1.9 #default


#download \
#  "v1.3.4.tar.gz" \
#  "ogg-1.3.4.tar.gz" \
#  "df1a9a95251a289aa5515b869db4b15f" \
#  "https://github.com/xiph/ogg/archive/"
do_git_checkout https://github.com/xiph/ogg.git $BUILD_DIR/ogg-git master

#download \
#  "master.tar.gz" \
#  "flac-master.tar.gz" \
#  "nil" \
#  "https://github.com/xiph/flac/archive/"
do_git_checkout https://github.com/xiph/flac.git $BUILD_DIR/flac-git master

#download \
#  "v1.3.6.tar.gz" \
#  "vorbis-1.3.6.tar.gz" \
#  "03e967efb961f65a313459c5d0f4cbfb" \
#  "https://github.com/xiph/vorbis/archive/"
do_git_checkout https://github.com/xiph/vorbis.git $BUILD_DIR/vorbis-git master

do_git_checkout https://github.com/xiph/speexdsp.git "$BUILD_DIR"/speexdsp-git master

#download \
#  "Speex-1.2.0.tar.gz" \
#  "Speex-1.2.0.tar.gz" \
#  "4bec86331abef56129f9d1c994823f03" \
#  "https://github.com/xiph/speex/archive/"
do_git_checkout https://github.com/xiph/speex.git $BUILD_DIR/speex-git master

#download \
#  "master.tar.gz" \
#  "libsndfile-master.tar.gz" \
#  "nil" \
#  "https://github.com/erikd/libsndfile/archive/"
do_git_checkout https://github.com/erikd/libsndfile.git $BUILD_DIR/libsndfile-git master

#download \
#  "twolame-0.4.0.tar.gz" \
#  "" \
#  "400c164ed096c7aea82bcf8edcd3f6f9" \
#  "https://github.com/njh/twolame/releases/download/0.4.0/"
do_git_checkout https://github.com/njh/twolame.git $BUILD_DIR/twolame-git main

#download \
#  "libtheora-1.1.1.tar.gz" \
#  "" \
#  "bb4dc37f0dc97db98333e7160bfbb52b" \
#  "http://downloads.xiph.org/releases/theora/"
do_git_checkout https://github.com/xiph/theora.git $BUILD_DIR/libtheora-git master

##download \
##  "master.tar.gz" \
##  "pulseaudio-master.tar.gz" \
##  "nil" \
##  "https://github.com/pulseaudio/pulseaudio/archive/"
#do_git_checkout https://github.com/pulseaudio/pulseaudio.git "$BUILD_DIR"/pulseaudio-git master

do_git_checkout https://git.code.sf.net/u/ffontaine35/giflib "$BUILD_DIR"/giflib-ffontaine35-git master

#download \
#  "master.tar.gz" \
#  "libjpeg-turbo-master.tar.gz" \
#  "nil" \
#  "https://github.com/libjpeg-turbo/libjpeg-turbo/archive/"
do_git_checkout https://github.com/libjpeg-turbo/libjpeg-turbo.git $BUILD_DIR/libjpeg-turbo-git main

#download \
#  "master.tar.gz" \
#  "libpng-master.tar.gz" \
#  "nil" \
#  "https://github.com/glennrp/libpng/archive/"
do_git_checkout https://github.com/glennrp/libpng.git "$BUILD_DIR"/libpng-git master

download \
  "libid3tag-0.15.1b.tar.gz" \
  "" \
  "e5808ad997ba32c498803822078748c3" \
  "https://sourceforge.net/projects/mad/files/"

#download \
#  "v1.1.0.tar.gz" \
#  "libwebp-1.1.0.tar.gz" \
#  "35831dd0f8d42119691eb36f2b9d23b7" \
#  "https://github.com/webmproject/libwebp/archive/"
do_git_checkout https://github.com/webmproject/libwebp "$BUILD_DIR"/libwebp-git master

#download \
#  "tiff-4.1.0.tar.gz" \
#  "" \
#  "nil" \
#  "http://download.osgeo.org/libtiff/"
do_git_checkout https://gitlab.com/libtiff/libtiff.git "$BUILD_DIR"/tiff-git master

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

#download \
#  "libxml2-2.9.10.tar.gz" \
#  "" \
#  "10942a1dc23137a8aa07f0639cbfece5" \
#  "http://xmlsoft.org/sources/"
do_git_checkout https://gitlab.gnome.org/GNOME/libxml2.git "$BUILD_DIR"/libxml2-git master

download \
  "freetype-2.10.1.tar.xz" \
  "" \
  "bd42e75127f8431923679480efb5ba8f" \
  "https://downloads.sourceforge.net/freetype/"
#do_git_checkout https://git.savannah.gnu.org/git/freetype/freetype2.git "$BUILD_DIR"/freetype-2-git VER-2-10-1

#download \
#  "fontconfig-2.13.92.tar.xz" \
#  "" \
#  "d5431bf5456522380d4c2c9c904a6d96" \
#  "https://www.freedesktop.org/software/fontconfig/release/"
do_git_checkout https://gitlab.freedesktop.org/fontconfig/fontconfig.git "$BUILD_DIR"/fontconfig-git main

# libass dependency
#download \
#  "2.6.4.tar.gz" \
#  "harfbuzz-2.6.4.tar.gz" \
#  "188407981048daf6d92d554cfeeed48e" \
#  "https://github.com/harfbuzz/harfbuzz/archive/"
do_git_checkout https://github.com/harfbuzz/harfbuzz.git "$BUILD_DIR"/harfbuzz-git main

#download \
#  "v2.3.1.tar.gz" \
#  "openjpeg-2.3.1.tar.gz" \
#  "3b9941dc7a52f0376694adb15a72903f" \
#  "https://github.com/uclouvain/openjpeg/archive/"
do_git_checkout https://github.com/uclouvain/openjpeg.git "$BUILD_DIR"/openjpeg-git master

do_git_checkout https://github.com/DanBloomberg/leptonica.git "$BUILD_DIR"/leptonica-git 1.81.0 #master

#download \
#  "lensfun-0.3.95.tar.gz" \
#  "" \
#  "21107eaf72303706256481fef2dc8013" \
#  "https://sourceforge.net/projects/lensfun/files/0.3.95/"
do_git_checkout https://github.com/lensfun/lensfun.git "$BUILD_DIR"/lensfun-git master

do_git_checkout https://github.com/tesseract-ocr/tesseract.git tesseract-git 4.1
#do_git_checkout https://github.com/tesseract-ocr/tesseract.git tesseract-git a2e72f258a3bd6811cae226a01802d891407409f # #315
#do_git_checkout https://github.com/tesseract-ocr/tesseract.git tesseract-git a2e72f258a3bd6811cae226a01802d # #315

#download \
#  "imlib2-1.6.1.tar.bz2" \
#  "" \
#  "7b3fbcb974b48822b32b326c6a47764b" \
#  "https://netix.dl.sourceforge.net/project/enlightenment/imlib2-src/1.6.1/"
do_git_checkout https://git.enlightenment.org/old/legacy-imlib2.git "$BUILD_DIR"/imlib2-git master

#download \
#  "v0.99.beta19.tar.gz" \
#  "libcaca-0.99.beta19.tar.gz" \
#  "2e1ed59dc3cb2f69d3d98fd0e6a205b4" \
#  "https://github.com/cacalabs/libcaca/archive/"
# Autoconf version 2.71 or higher is required for main
do_git_checkout https://github.com/cacalabs/libcaca.git "$BUILD_DIR"/libcaca-git v0.99.beta19

#download \
#  "master.tar.gz" \
#  "libilbc-master.tar.gz" \
#  "nil" \
#  "https://github.com/TimothyGu/libilbc/archive/"
do_git_checkout https://github.com/TimothyGu/libilbc.git "$BUILD_DIR"/libilbc-git debian

do_git_checkout https://github.com/dyne/frei0r.git "$BUILD_DIR"/frei0r-git master

do_git_checkout https://aomedia.googlesource.com/aom "$BUILD_DIR"/aom-git master

do_git_checkout https://code.videolan.org/videolan/dav1d.git "$BUILD_DIR"/libdav1d-git master

#download \
#  "xvidcore-1.3.5.tar.gz" \
#  "" \
#  "69784ebd917413d8592688ae86d8185f" \
#  "http://downloads.xvid.org/downloads/"
svn checkout http://svn.xvid.org/trunk/xvidcore "$BUILD_DIR"/xvidcore-svn --username anonymous --password ""

#download \
#  "x264-master.tar.gz" \
#  "" \
#  "nil" \
#  "https://code.videolan.org/videolan/x264/-/archive/master/"
do_git_checkout https://code.videolan.org/videolan/x264.git "$BUILD_DIR"/x264-git master

#download \
#  "x265_3.2.1.tar.gz" \
#  "" \
#  "94808045a34d88a857e5eaf3f68f4bca" \
#  "https://bitbucket.org/multicoreware/x265/downloads/"
#rm -rf "$BUILD_DIR"/x265-git
#hg clone http://hg.videolan.org/x265 "$BUILD_DIR"/x265-git
do_git_checkout https://bitbucket.org/multicoreware/x265_git.git "$BUILD_DIR"/x265-git master

#download \
#  "fribidi-1.0.8.tar.bz2" \
#  "" \
#  "962c7d8ebaa711d4e306161dbe14aa55" \
#  "https://github.com/fribidi/fribidi/releases/download/v1.0.8/"
do_git_checkout https://github.com/fribidi/fribidi.git "$BUILD_DIR"/fribidi-git master
#do_git_checkout https://github.com/Oxalin/fribidi.git "$BUILD_DIR"/fribidi-git doxygen

#download \
#  "0.14.0.tar.gz" \
#  "libass-0.14.0.tar.gz" \
#  "3c84884aa0589486bded10f71829bf39" \
#  "https://github.com/libass/libass/archive/"
do_git_checkout https://github.com/libass/libass.git "$BUILD_DIR"/libass-git master

#download \
#  "release-0.98b.tar.gz" \
#  "vid.stab-release-0.98b.tar.gz" \
#  "299b2f4ccd1b94c274f6d94ed4f1c5b8" \
#  "https://github.com/georgmartius/vid.stab/archive/"
do_git_checkout https://github.com/georgmartius/vid.stab.git vid.stab-git master

#download \
#  "release-2.9.2.tar.gz" \
#  "zimg-release-2.9.2.tar.gz" \
#  "a3755bff6207fcca5c06e7b1b408ce2e" \
#  "https://github.com/sekrit-twc/zimg/archive/"
do_git_checkout https://github.com/sekrit-twc/zimg.git "$BUILD_DIR"/zimg-git master

#download \
#  "n4.2.2.tar.gz" \
#  "ffmpeg4.2.2.tar.gz" \
#  "85c99f782dd3244a8e02ea85d29ecee2" \
#  "https://github.com/FFmpeg/FFmpeg/archive"
do_git_checkout https://github.com/FFmpeg/FFmpeg.git "$BUILD_DIR"/FFmpeg-git n4.4.2 #n4.3.1 #n4.2.2 #master
}

[ $download_only -eq 1 ] && exit 0

TARGET_DIR_SED=$(echo $TARGET_DIR | awk '{gsub(/\//, "\\/"); print}')

yasm() {
  if [ $is_x86 -eq 1 ]; then
    echo
    /bin/echo -e "\e[93m*** Building yasm ***\e[39m"
    echo
    cd $BUILD_DIR/yasm*
    [ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
    [ ! -f config.status ] && ./configure --prefix=$TARGET_DIR #--bindir=$BIN_DIR
    make -j $jval
    make install
  fi
}

build_asciidoc() {
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

build_nasm() {
  if [ $is_x86 -eq 1 ]; then
    echo
    /bin/echo -e "\e[93m*** Building nasm ***\e[39m"
    echo
    cd $BUILD_DIR/nasm-*
    [ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
    [ ! -f configure ] && ./autogen.sh
    [ ! -f config.status ] && ./configure --prefix=$TARGET_DIR #--bindir=$BIN_DIR
    make -j $jval
    make install
  fi
}

extract_cmake() {
echo
/bin/echo -e "\e[93m*** Extracting cmake ***\e[39m"
echo
cd $DOWNLOAD_DIR/
tar --wildcards --strip-components 1 --directory=$TARGET_DIR/ -zxvf cmake-3.16.4-Linux-x86_64.tar.gz cmake-3.16.4-Linux-x86_64/bin/*
tar --wildcards --strip-components 1 --directory=$TARGET_DIR/ -zxvf cmake-3.16.4-Linux-x86_64.tar.gz cmake-3.16.4-Linux-x86_64/doc/*
tar --wildcards --strip-components 1 --directory=$TARGET_DIR/ -zxvf cmake-3.16.4-Linux-x86_64.tar.gz cmake-3.16.4-Linux-x86_64/man/*
tar --wildcards --strip-components 1 --directory=$TARGET_DIR/ -zxvf cmake-3.16.4-Linux-x86_64.tar.gz cmake-3.16.4-Linux-x86_64/share/*
}

extract_ninja() {
echo
/bin/echo -e "\e[93m*** Extracting ninja ***\e[39m"
echo
cd $DOWNLOAD_DIR/
unzip -o -d "$TARGET_DIR"/bin ninja-linux.zip
}

build_libffi() {
echo
/bin/echo -e "\e[93m*** Building libffi ***\e[39m"
echo
cd $BUILD_DIR/libffi-*
[ ! -f configure ] && ./autogen.sh
./configure --prefix=$TARGET_DIR --enable-static --disable-shared
make -j $jval
make install
}

linuxPAM() {
echo
/bin/echo -e "\e[93m*** Building linux-PAM ***\e[39m"
echo
cd $BUILD_DIR/linux-pam*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
[ ! -f configure ] && ./autogen.sh
./configure --prefix=$TARGET_DIR --disable-doc --enable-static --disable-shared
make -j $jval
make install
}

libcap() {
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
mkdir -pv $TARGET_DIR/lib/pkgconfig
mkdir -pv $TARGET_DIR/include
cp libcap.a $TARGET_DIR/lib
cp libcap.so.2.* $TARGET_DIR/lib
ln -sf $TARGET_DIR/lib/libcap.so.2.* $TARGET_DIR/lib/libcap.so.2
ln -sf $TARGET_DIR/lib/libcap.so.2 $TARGET_DIR/lib/libcap.so
cp libcap.pc -t $TARGET_DIR/lib/pkgconfig
cp libpsx.pc -t $TARGET_DIR/lib/pkgconfig
#cp cap_test $TARGET_DIR/sbin
mkdir -pv $TARGET_DIR/sbin
cp _makenames $TARGET_DIR/sbin
cp *.h $TARGET_DIR/include
cp -R include/* $TARGET_DIR/include
}

build_liblzma() {
echo
/bin/echo -e "\e[93m*** Building xz to get liblzma ( Dependency) ***\e[39m"
echo
cd $BUILD_DIR/xz-*
[ ! -f configure ] && ./autogen.sh
./configure --prefix=$TARGET_DIR --enable-static --disable-shared --disable-xz --disable-xzdec --disable-lzmadec --disable-lzmainfo --disable-scripts --disable-doc #--disable-nls
make -j $jval
make install
}

zlib125() {
echo
/bin/echo -e "\e[93m*** Building zlib-1.2.5 (libPNG Dependency) ***\e[39m"
echo
cd $BUILD_DIR/zlib-1.2.5
sed -i 's/"shared=1"/"shared=0"/g' ./configure
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
if [ "$platform" = "linux" ]; then
  [ ! -f config.status ] && ./configure --prefix=$TARGET_DIR --static
elif [ "$platform" = "darwin" ]; then
  [ ! -f config.status ] && ./configure --prefix=$TARGET_DIR --static
fi
sed -i '/cp $(SHAREDLIBV)/d' ./Makefile
make -j $jval
make install
}

build_zlib() {
echo
/bin/echo -e "\e[93m*** Building zlib-1.2.11 (Python Dependency) ***\e[39m"
echo
cd $BUILD_DIR/zlib-git
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
if [ "$platform" = "linux" ]; then
  [ ! -f config.status ] && ./configure --prefix=$TARGET_DIR --static
elif [ "$platform" = "darwin" ]; then
  [ ! -f config.status ] && ./configure --prefix=$TARGET_DIR --static
fi
make -j $jval
make install
}

build_libzstd() {
echo
/bin/echo -e "\e[93m*** Building libzstd ***\e[39m"
echo
cd $BUILD_DIR/zstd-*
cd build/cmake
mkdir -pv builddir
cd builddir
cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="$TARGET_DIR" -DZSTD_LEGACY_SUPPORT=ON -DCMAKE_INSTALL_LIBDIR=$TARGET_DIR/lib -DZSTD_BUILD_SHARED:BOOL=OFF -DZSTD_LZMA_SUPPORT:BOOL=ON -DZSTD_ZLIB_SUPPORT:BOOL=ON ..
#cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX=$TARGET_DIR -DBUILD_SHARED_LIBS=0 -DCMAKE_INSTALL_LIBDIR=$TARGET_DIR/lib -DCMAKE_INSTALL_INCLUDEDIR=$TARGET_DIR/include
make -j $jval
make install
}

tcl() {
echo
/bin/echo -e "\e[93m*** Building tcl (tkinter Dependency) ***\e[39m"
echo
cd $BUILD_DIR/tcl*/unix
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
./configure --prefix=$TARGET_DIR --disable-shared --enable-64bit
make -j $jval
make install
}

tkinter() {
echo
/bin/echo -e "\e[93m*** Building tkinter (Python Dependency) ***\e[39m"
echo
cd $BUILD_DIR/tk*/unix
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
./configure --prefix=$TARGET_DIR --with-tcl=$BUILD_DIR/tcl8.6.10/unix --enable-static --disable-shared
make -j $jval
make install
}

build_libexpat() {
echo
/bin/echo -e "\e[93m*** Building libexpat (fontconfig Dependency) ***\e[39m"
echo
cd $BUILD_DIR/libexpat-*/expat
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
./buildconf.sh
./configure --prefix=$TARGET_DIR --enable-static --disable-shared
make -j $jval
make install
}

build_OpenSSL_RTMP() {
echo
/bin/echo -e "\e[93m*** Building OpenSSL for libRTMP ***\e[39m"
echo
cd $BUILD_DIR/openssl-old*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
if [ "$platform" = "darwin" ]; then
  ./Configure darwin64-x86_64-cc --prefix=$TARGET_DIR
elif [ "$platform" = "linux" ]; then
  ./config --prefix=$TARGET_DIR no-shared
fi
make -j $jval
make install
}

build_librtmp() {
# needs old version of openSSL
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

build_OpenSSL() {
echo
/bin/echo -e "\e[93m*** Building OpenSSL ***\e[39m"
echo
cd $BUILD_DIR/openssl-git
git_hard_reset
git checkout master
git_hard_reset
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
if [ "$platform" = "darwin" ]; then
  ./Configure darwin64-x86_64-cc --prefix=$TARGET_DIR
elif [ "$platform" = "linux" ]; then
  ./config --prefix=$TARGET_DIR no-shared
fi
make -j $jval
make install
}

Python() {
echo
/bin/echo -e "\e[93m*** Building Python (libxml2 dependency) ***\e[39m"
echo
cd $BUILD_DIR/Python-*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
[ ! -f config.status ] && ./configure --prefix=$TARGET_DIR --with-system-expat --disable-shared --enable-profiling LDFLAGS="-static -static-libgcc" CFLAGS="-static" CPPFLAGS="-static" CCSHARED="" --with-ensurepip=yes # --enable-unicode=ucs4
make -j $jval
make install
}

build_nv_headers() {
echo
/bin/echo -e "\e[93m*** Building nv_headers ***\e[39m"
echo
cd $BUILD_DIR/nv-codec-headers-git
make install "PREFIX=$TARGET_DIR" # just copies in headers
}

build_glib() {
echo
/bin/echo -e "\e[93m*** Building glib ***\e[39m"
echo
#  export CPPFLAGS='-DLIBXML_STATIC' # gettext build...
#  generic_download_and_make_and_install  https://ftp.gnu.org/pub/gnu/gettext/gettext-0.19.8.1.tar.xz
#  unset CPPFLAGS
#  generic_download_and_make_and_install  http://sourceware.org/pub/libffi/libffi-3.2.1.tar.gz # also dep
cd $BUILD_DIR/glib-*
#    export CPPFLAGS='-liconv -pthread' # I think gettext wanted this but has no .pc file??
#    if [[ $compiler_flavors != "native" ]]; then # seemingly unneeded for OS X
#      apply_patch file://$patch_dir/glib_msg_fmt.patch # needed for configure
#      apply_patch  file://$patch_dir/glib-prefer-constructors-over-DllMain.patch # needed for static. weird.
#    fi
#export ZLIB_CFLAGS="-I$TARGET_DIR/include"
#export ZLIB_LIBS="-L$TARGET_DIR/lib"
#export LIBFFI_CFLAGS="-I$TARGET_DIR/include"
#export LIBFFI_LIBS="-L$TARGET_DIR/lib"
if [ ! -f configure ]; then
  ./autogen.sh --prefix=$TARGET_DIR --enable-static --disable-shared --with-pcre=internal # too lazy for pcre :) XXX
else
  ./configure --prefix=$TARGET_DIR --enable-static --disable-shared --with-pcre=internal # too lazy for pcre :) XXX
fi
make -j $jval
make install
}

#Requires: glib-2.0 maybe?
build_libcdio() {
echo
/bin/echo -e "\e[93m*** Building libcdio ***\e[39m"
echo
cd "$BUILD_DIR"/libcdio-git
./autogen.sh --prefix=$TARGET_DIR --disable-shared --disable-cddb
make -j $(nproc)
make install
}

build_libcdio_paranoia() {
echo
/bin/echo -e "\e[93m*** Building libcdio_paranoia ***\e[39m"
echo
cd "$BUILD_DIR"/libcdio-paranoia-git
./autogen.sh --prefix=$TARGET_DIR --disable-shared
make -j $(nproc)
make install
}

build_vcdimager() {
echo
/bin/echo -e "\e[93m*** Building VCDImager ***\e[39m"
echo
cd "$BUILD_DIR"/vcdimager-*
./autogen.sh --prefix=$TARGET_DIR --disable-shared
make -j $(nproc)
make install
}

rebuild_libcdio() {
echo
/bin/echo -e "\e[93m*** Rebuilding libcdio ***\e[39m"
echo
cd "$BUILD_DIR"/libcdio-git
git reset --hard
git clean -f
./autogen.sh --prefix=$TARGET_DIR --disable-shared --disable-cddb --enable-vcd-info
make -j $(nproc)
make install
}

build_libmysofa() {
echo
/bin/echo -e "\e[93m***  Building libmysofa ***\e[39m"
echo
cd $BUILD_DIR/libmysofa-*
cmake -G "Unix Makefiles" -DBUILD_SHARED_LIBS=0 -DCMAKE_INSTALL_PREFIX="$TARGET_DIR" -DBUILD_TESTS=0
apply_patch file://$PATCH_DIR/libmysofa.patch -p1
make -j $jval
make install
}

build_ALSAlib() {
echo
/bin/echo -e "\e[93m***  Building ALSAlib ***\e[39m"
echo
cd $BUILD_DIR/alsa-lib-*
if [ ! -f configure ]; then
  libtoolize --force --copy --automake
  aclocal
  autoheader
  automake --foreign --copy --add-missing
  autoconf
fi
./configure --prefix=$TARGET_DIR --enable-static --disable-shared
make -j $jval
make install
}

build_voamrwbenc() {
echo
/bin/echo -e "\e[93m*** Building vo-amrwbenc... ***\e[39m"
echo
cd $BUILD_DIR/vo-amrwbenc-*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
#sed -i.bak "s/AM_INIT_AUTOMAKE(\[/AM_INIT_AUTOMAKE(\[subdir-objects /g" ./configure.ac
[ ! -f configure ] && autoreconf -fiv
./configure --prefix=$TARGET_DIR --disable-shared --enable-static #--bindir="$BIN_DIR"
make -j $jval
make install
}

build_opencoreamr() {
echo
/bin/echo -e "\e[93m*** Building opencore-amr... ***\e[39m"
echo
cd $BUILD_DIR/opencore-amr*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
#sed -i.bak "s/AM_INIT_AUTOMAKE(\[/AM_INIT_AUTOMAKE(\[subdir-objects /g" ./configure.ac
[ ! -f configure ] && autoreconf -fiv
./configure --prefix=$TARGET_DIR --disable-shared --enable-static #--bindir="$BIN_DIR"
make -j $jval
make install
}

build_fdkaac() {
echo
/bin/echo -e "\e[93m*** Building fdk-aac ***\e[39m"
echo
cd $BUILD_DIR/fdk-aac*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
[ ! -f configure ] && autoreconf -fiv
[ ! -f config.status ] && ./configure --prefix=$TARGET_DIR --disable-shared
make -j $jval
make install
}

build_mp3lame() {
echo
/bin/echo -e "\e[93m*** Building mp3lame ***\e[39m"
echo
cd $BUILD_DIR/lame*
# The lame build script does not recognize aarch64, so need to set it manually
uname -a | grep -q 'aarch64' && lame_build_target="--build=arm-linux" || lame_build_target=''
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
[ ! -f config.status ] && ./configure --prefix=$TARGET_DIR --enable-nasm --disable-shared $lame_build_target
make -j 1
make install
}

build_opus() {
echo
/bin/echo -e "\e[93m*** Building opus ***\e[39m"
echo
cd $BUILD_DIR/opus*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
[ ! -f configure ] && ./autogen.sh
[ ! -f config.status ] && ./configure --prefix=$TARGET_DIR --enable-intrinsics --disable-shared
make -j $jval
make install
sed -i "s/Version: unknown/Version: 1.3.1/g" $TARGET_DIR/lib/pkgconfig/opus.pc
}

build_libvpx() {
echo
/bin/echo -e "\e[93m*** Building libvpx ***\e[39m"
echo
cd $BUILD_DIR/libvpx*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
[ ! -f config.status ] && ./configure --prefix=$TARGET_DIR --disable-examples --disable-unit-tests --enable-pic --enable-vp9-highbitdepth --enable-vp8 --enable-vp9 --enable-better-hw-compatibility
make -j $jval
make install
}

build_libsoxr() {
echo
/bin/echo -e "\e[93m*** Building libsoxr ***\e[39m"
echo
cd $BUILD_DIR/soxr-*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
mkdir -pv build
cd build
cmake -G "Unix Makefiles" -DBUILD_SHARED_LIBS=0 -DCMAKE_INSTALL_PREFIX="$TARGET_DIR" -DWITH_OPENMP=0 -DBUILD_TESTS=0 -DBUILD_EXAMPLES=0 ..
make -j $jval
make install
}

build_libflite() {
echo
/bin/echo -e "\e[93m*** Building libflite ***\e[39m"
echo
cd $BUILD_DIR/flite-*
#      sed -i.bak "s|i386-mingw32-|$cross_prefix|" configure
      #sed -i.bak "/define const/i\#include <windows.h>" tools/find_sts_main.c # Needed for x86_64? Untested.
#      sed -i.bak "128,134d" main/Makefile # Library only. else fails with cannot copy bin/libflite or someodd
#      sed -i.bak "s/cp -pd/cp -p/" main/Makefile # friendlier cp for OS X
unset CFLAGS
./configure --prefix=$TARGET_DIR --disable-shared # --with-audio=none
#cd $BUILD_DIR/flite-*/src/utils 
#make -j $jval
#cd $BUILD_DIR/flite-*/tools 
#make -j $jval
#cd $BUILD_DIR/flite-*
make -j $jval
export CFLAGS="-I${TARGET_DIR}/include $LDFLAGS"
make install
}

build_libsnappy() {
echo
/bin/echo -e "\e[93m*** Building libsnappy ***\e[39m"
echo
cd $BUILD_DIR/snappy-*
cmake -G "Unix Makefiles" -DBUILD_SHARED_LIBS=0 -DCMAKE_INSTALL_PREFIX="$TARGET_DIR" -DCMAKE_BUILD_TYPE=Release -DSNAPPY_BUILD_TESTS=OFF # extra params from deadsix27 and from new cMakeLists.txt content
make -j $jval
make install
}

build_vamp_plugin() {
echo
/bin/echo -e "\e[93m*** Building vamp_plugin ***\e[39m"
echo
cd $BUILD_DIR/vamp-plugin-sdk-*
apply_patch file://$PATCH_DIR/vamp-plugin-sdk-2.7.1_static-lib.diff -p0
#    if [[ ! -f configure.bak ]]; then # Fix for "'M_PI' was not declared in this scope" (see https://stackoverflow.com/a/29264536).
#      sed -i.bak "s/c++98/gnu++98/" configure
#    fi
./configure --prefix=$TARGET_DIR --disable-programs
make install-static # No need for 'do_make_install', because 'install-static' already has install-instructions.
}

build_fftw() {
echo
/bin/echo -e "\e[93m*** Building fftw ***\e[39m"
echo
cd $BUILD_DIR/fftw*
if [ ! -f configure ]; then
  ./bootstrap.sh --prefix=$TARGET_DIR --disable-shared --enable-static --disable-doc
else
  ./configure --prefix=$TARGET_DIR --enable-maintainer-mode --enable-threads --disable-shared --enable-static --disable-doc
fi
make -j $jval
make install
}

build_libsamplerate() {
# I think this didn't work with ubuntu 14.04 [too old automake or some odd] :|
echo
/bin/echo -e "\e[93m*** Building libsamplerate ***\e[39m"
echo
cd $BUILD_DIR/libsamplerate-git
[ ! -f configure ] && ./autogen.sh
./configure --prefix=$TARGET_DIR --disable-shared --enable-static
make -j $jval
make install
  # but OS X can't use 0.1.9 :|
  # rubberband can use this, but uses speex bundled by default [any difference? who knows!]
}

build_libogg() {
echo
/bin/echo -e "\e[93m*** Building libogg ***\e[39m"
echo
cd $BUILD_DIR/ogg*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
[ ! -f configure ] && ./autogen.sh
./configure --prefix=$TARGET_DIR --disable-shared
make -j $jval
make install
}

build_libflac() {
echo
/bin/echo -e "\e[93m*** Building libflac ***\e[39m"
echo
cd $BUILD_DIR/flac-*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
[ ! -f configure ] && ./autogen.sh
./configure --prefix=$TARGET_DIR --disable-shared --disable-thorough-tests
make -j $jval
make install
}

build_libvorbis() {
echo
/bin/echo -e "\e[93m*** Building libvorbis ***\e[39m"
echo
cd $BUILD_DIR/vorbis*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
[ ! -f configure ] && ./autogen.sh
./configure --prefix=$TARGET_DIR --disable-shared --disable-docs --disable-examples --disable-oggtest
make -j $jval
make install
}

build_libspeexdsp() {
echo
/bin/echo -e "\e[93m*** Building libspeexDSP ***\e[39m"
echo
cd $BUILD_DIR/speexdsp-git
[ ! -f configure ] && ./autogen.sh
./configure --prefix=$TARGET_DIR --disable-shared --enable-static --disable-examples
make -j $jval
make install
}

build_libspeex() {
echo
/bin/echo -e "\e[93m*** Building libspeex ***\e[39m"
echo
cd $BUILD_DIR/speex-*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
export SPEEXDSP_CFLAGS="-I$TARGET_DIR/include"
export SPEEXDSP_LIBS="-L$TARGET_DIR/lib -lspeexdsp" # 'configure' somehow can't find SpeexDSP with 'pkg-config'.
[ ! -f configure ] && ./autogen.sh
./configure --prefix=$TARGET_DIR --disable-shared --disable-binaries
make -j $jval
make install
unset SPEEXDSP_CFLAGS
unset SPEEXDSP_LIBS
}

build_libsndfile() {
echo
/bin/echo -e "\e[93m*** Building libsndfile ***\e[39m"
echo
cd $BUILD_DIR/libsndfile-*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
[ ! -f configure ] && ./autogen.sh
./configure --prefix=$TARGET_DIR --disable-shared --enable-experimental --disable-full-suite # --disable-sqlite --disable-external-libs
make -j $jval
make install
if [ ! -f $TARGET_DIR/lib/libgsm.a ]; then
  install -m644 src/GSM610/gsm.h $TARGET_DIR/include/gsm.h || exit 1
  install -m644 src/GSM610/.libs/libgsm.a $TARGET_DIR/lib/libgsm.a || exit 1
else
  echo "already installed GSM 6.10 ..."
fi
}

build_librubberband() {
echo
/bin/echo -e "\e[93m*** Building librubberband ***\e[39m"
echo
cd $BUILD_DIR/rubberband-git
apply_patch file://$PATCH_DIR/rubberband_git_static-lib.diff -p0 # create install-static target
./configure --prefix=$TARGET_DIR --disable-ladspa
make install-static # AR=${cross_prefix}ar # No need for 'do_make_install', because 'install-static' already has install-instructions.
    sed -i.bak 's/-lrubberband.*$/-lrubberband -lfftw3 -lsamplerate -lstdc++/' $TARGET_DIR/lib/pkgconfig/rubberband.pc
}

build_libtwolame() {
echo
/bin/echo -e "\e[93m*** Building libtwolame ***\e[39m"
echo
cd $BUILD_DIR/twolame-*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
if [ ! -f configure ]; then
  ./autogen.sh --prefix=$TARGET_DIR --disable-shared --enable-static #--bindir="$BIN_DIR"
else
  ./configure --prefix=$TARGET_DIR --disable-shared --enable-static #--bindir="$BIN_DIR"
fi
make -j $jval
make install
}

build_libtheora() {
echo
/bin/echo -e "\e[93m*** Building libtheora ***\e[39m"
echo
cd $BUILD_DIR/libtheora-*
sed -i 's/png_\(sizeof\)/\1/g' examples/png2theora.c
[ ! -f configure ] && ./autogen.sh
./configure --prefix=$TARGET_DIR --disable-shared --enable-static --disable-oggtest --disable-vorbistest --with-ogg-includes="$TARGET_DIR/include" --with-ogg-libraries="$TARGET_DIR/build/lib" --with-vorbis-includes="$TARGET_DIR/include" --with-vorbis-libraries="$TARGET_DIR/build/lib" --disable-doc --disable-examples --disable-spec
make -j $jval
make install
}

build_PulseAudio() {
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

build_GIFlib() {
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

build_libjpegturbo() {
echo
/bin/echo -e "\e[93m*** Building libjpeg-turbo ***\e[39m"
echo
cd $BUILD_DIR/libjpeg-turbo-*
cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX=$TARGET_DIR -DENABLE_SHARED=0 -DCMAKE_INSTALL_LIBDIR=$TARGET_DIR/lib -DCMAKE_INSTALL_INCLUDEDIR=$TARGET_DIR/include -DWITH_12BIT=1
make -j $jval
make install
}

build_libPNG() {
echo
/bin/echo -e "\e[93m*** Building libPNG ***\e[39m"
echo
cd $BUILD_DIR/libpng-*
./configure --disable-shared --prefix=$TARGET_DIR --libdir=$TARGET_DIR/lib --includedir=$TARGET_DIR/include CPPFLAGS=-I$TARGET_DIR/include
make -j $jval
make install
}

build_libID3tag() {
echo
/bin/echo -e "\e[93m*** Building libID3tag (imlib2 Dependency) ***\e[39m"
echo
cd $BUILD_DIR/libid3tag-*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
./configure --prefix=$TARGET_DIR --disable-shared
make -j $jval
make install
}

build_libwebp() {
echo
/bin/echo -e "\e[93m*** Building libwebp ***\e[39m"
echo
cd $BUILD_DIR/libwebp*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
[ ! -f configure ] && ./autogen.sh
export LIBPNG_CONFIG="$TARGET_DIR/bin/libpng16-config --static" # LibPNG somehow doesn't get autodetected.
./configure --prefix=$TARGET_DIR --disable-shared --enable-libwebpdecoder --enable-libwebpmux --enable-libwebpextras # --with-pnglibdir=$TARGET_DIR/lib --with-pngincludedir=$TARGET_DIR/include
make -j $jval
make install
}

# No jbig and zstd, else 'tesseract not found using pkg-config'
build_libTIFF() {
echo
/bin/echo -e "\e[93m*** Building libTIFF ***\e[39m"
echo
mv "$TARGET_DIR/lib/pkgconfig/libzstd.pc" "$TARGET_DIR/lib/pkgconfig/libzstd.pc.bak"
mv "$TARGET_DIR/include/zstd.h" "$TARGET_DIR/include/zstd.h.bak"
cd $BUILD_DIR/tiff-*
[ ! -f configure ] && ./autogen.sh
./configure --prefix=$TARGET_DIR --disable-shared
make -j $jval
make install
mv "$TARGET_DIR/lib/pkgconfig/libzstd.pc.bak" "$TARGET_DIR/lib/pkgconfig/libzstd.pc"
mv "$TARGET_DIR/include/zstd.h.bak" "$TARGET_DIR/include/zstd.h"
#sed -i.bak 's/-ltiff.*$/-ltiff -ljpeg -ljbig -lzstd -lz -llzma -lm/' $PKG_CONFIG_PATH/libtiff-4.pc # static deps
}

rebuild_libwebp() {
echo
/bin/echo -e "\e[93m*** ReBuilding libwebp ***\e[39m"
echo
cd $BUILD_DIR/libwebp*
make distclean
[ ! -f configure ] && ./autogen.sh
./configure --prefix=$TARGET_DIR --disable-shared --enable-libwebpdecoder --enable-libwebpmux --enable-libwebpextras # --with-pnglibdir=$TARGET_DIR/lib --with-pngincludedir=$TARGET_DIR/include
make -j $jval
make install
}

utilmacros() {
echo
/bin/echo -e "\e[93m*** Building util-macros (xorgproto Dependency) ***\e[39m"
echo
cd $BUILD_DIR/util-macros-*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
./configure --prefix=$TARGET_DIR
make install
}

xorgproto() {
echo
/bin/echo -e "\e[93m*** Building xorgproto (libXau Dependency) ***\e[39m"
echo
cd $BUILD_DIR/xorgproto-*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
mkdir -pv build
cd build/
${BUILD_DIR}/meson-git/meson.py --prefix=$TARGET_DIR .. && ninja
ninja install
}

build_libXML() {
echo
/bin/echo -e "\e[93m*** Building libXML ***\e[39m"
echo
cd $BUILD_DIR/libxml*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
    if [ ! -f libxml.h.bak ]; then # Otherwise you'll get "libxml.h:...: warning: "LIBXML_STATIC" redefined". Not an error, but still.
      sed -i.bak "/NOLIBTOOL/s/.*/& \&\& !defined(LIBXML_STATIC)/" libxml.h
    fi
if [ ! -f configure ]; then
  ./autogen.sh --prefix=$TARGET_DIR --disable-shared --with-history --with-python=no --with-ftp=no --with-http=no
else
  [ ! -f config.status ] && ./configure --prefix=$TARGET_DIR --disable-shared --with-history --with-python=no --with-ftp=no --with-http=no #--with-python=$TARGET_DIR/bin/python3
fi
make -j $jval
make install
}

build_FreeType2() {
echo
/bin/echo -e "\e[93m*** Building FreeType2 (libass dependency) ***\e[39m"
echo
cd $BUILD_DIR/freetype*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
#sed -ri "s:.*(AUX_MODULES.*valid):\1:" modules.cfg
#sed -r "s:.*(#.*SUBPIXEL_RENDERING) .*:\1:" -i include/freetype/config/ftoption.h
if [ "$platform" = "linux" ]; then
  [ ! -f ./builds/unix/configure ] && ./autogen.sh
fi
[ ! -f config.status ] && ./configure --prefix=$TARGET_DIR --enable-static --disable-shared --without-harfbuzz --with-bzip2 
make -j $jval
make install
}

build_FontConfig() {
echo
/bin/echo -e "\e[93m*** Building FontConfig ***\e[39m"
echo
cd $BUILD_DIR/fontconfig*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
if [ ! -f configure ]; then
  ./autogen.sh --prefix=$TARGET_DIR --enable-static --disable-shared --enable-iconv --disable-docs --with-libiconv
else
  [ ! -f config.status ] && ./configure --prefix=$TARGET_DIR --enable-static --disable-shared --enable-iconv --disable-docs --with-libiconv #  --enable-libxml2 # Use Libxml2 instead of Expat.
fi
make -j $jval
make install
}

build_harfbuzz() {
echo
/bin/echo -e "\e[93m*** Building harfbuzz (libass dependency) ***\e[39m"
echo
cd $BUILD_DIR/harfbuzz-*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
./autogen.sh --prefix=$TARGET_DIR --enable-static --disable-shared --with-freetype=yes -with-icu=no # --with-fontconfig=no
make -j $jval
make install
#  sed -i.bak 's/-lharfbuzz.*/-lharfbuzz -lfreetype/' "$TARGET_DIR/lib/pkgconfig/harfbuzz.pc"
#  sed -i.bak 's/libfreetype.la -lbz2/libfreetype.la -lharfbuzz -lbz2/' "$TARGET_DIR/lib/libharfbuzz.la"
#  sed -i.bak 's/-lharfbuzz.*/-lharfbuzz -lharfbuzz-subset -lfreetype/' "$TARGET_DIR/lib/pkgconfig/harfbuzz.pc"
#  sed -i.bak 's/libfreetype.la -lbz2/libfreetype.la -lharfbuzz -lbz2 \/home\/tec\/DEV\/ffmpeg-static\/target\/lib\/libharfbuzz-subset.la -lharfbuzz -lbz2/' "$TARGET_DIR/lib/libharfbuzz.la"
}

rebuild_FreeType2() {
echo
/bin/echo -e "\e[93m*** ReBuilding FreeType2 after HarfBuzz ***\e[39m"
echo
cd $BUILD_DIR/freetype*
#make distclean
#[ ! -f config.status ] ./configure --prefix=$TARGET_DIR --enable-static --disable-shared --with-harfbuzz --with-bzip2
#make -j $jval
make install
  sed -i.bak 's/-lfreetype.*/-lfreetype -lharfbuzz/' "$TARGET_DIR/lib/pkgconfig/freetype2.pc"
  sed -i.bak 's/libfreetype.la -lbz2/libfreetype.la -lharfbuzz -lbz2/' "$TARGET_DIR/lib/libfreetype.la"
  sed -i.bak 's/-lharfbuzz.*/-lharfbuzz -lfreetype/' "$TARGET_DIR/lib/pkgconfig/harfbuzz.pc"
  sed -i.bak 's/libfreetype.la -lbz2/libfreetype.la -lharfbuzz -lbz2/' "$TARGET_DIR/lib/libharfbuzz.la"
}

build_openjpeg() {
echo
/bin/echo -e "\e[93m*** Building openjpeg ***\e[39m"
echo
cd $BUILD_DIR/openjpeg-*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
cmake -G "Unix Makefiles" -DBUILD_SHARED_LIBS=0 -DCMAKE_INSTALL_PREFIX="$TARGET_DIR" -DBUILD_CODEC=0 # -DBUILD_PKGCONFIG_FILES=on -DWITH_ASTYLE=ON -DBUILD\_SHARED\_LIBS:bool=off -DBUILD_THIRDPARTY:BOOL=ON -DBUILD_SHARED_LIBS:bool=off -DBUILD_STATIC_LIBS:bool=on -DBUILD_PKGCONFIG_FILES:bool=on -DCMAKE_BUILD_TYPE:string="Release"
make -j $jval
make install
}

build_libleptonica() {
#  build_libjpeg_turbo
echo
/bin/echo -e "\e[93m*** Building libleptonica ***\e[39m"
echo
cd $BUILD_DIR/leptonica-*
[ ! -f configure ] && ./autogen.sh
./configure --prefix=$TARGET_DIR --enable-static --disable-shared --without-libopenjpeg # never could quite figure out how to get it to work with jp2 stuffs...I think OPJ_STATIC or something, see issue for tesseract
make -j $jval
make install
}

build_lensfun() {
# build_glib
echo
/bin/echo -e "\e[93m*** Building lensfun ***\e[39m"
echo
cd $BUILD_DIR/lensfun-*
export CMAKE_STATIC_LINKER_FLAGS='-lws2_32 -pthread'
cmake -G "Unix Makefiles" -DBUILD_SHARED_LIBS=0 -DCMAKE_INSTALL_PREFIX="$TARGET_DIR" -DBUILD_STATIC=on -DCMAKE_INSTALL_DATAROOTDIR=$TARGET_DIR
make -j $jval
make install
sed -i.bak 's/-llensfun/-llensfun -lstdc++/' "$PKG_CONFIG_PATH/lensfun.pc"
unset CMAKE_STATIC_LINKER_FLAGS
}

build_libtesseract() {
# build_libleptonica
# build_libtiff # no disable configure option for this in tesseract? odd...
echo
/bin/echo -e "\e[93m*** Building libtesseract ***\e[39m"
echo
cd $BUILD_DIR/tesseract-*
[ ! -f configure ] && ./autogen.sh
./configure --prefix=$TARGET_DIR --enable-static --disable-shared
make -j $jval
make install
sed -i.bak 's/-ltesseract.*$/-ltesseract -lstdc++ -llept -ltiff -llzma -ljpeg -lz -lgomp/' $PKG_CONFIG_PATH/tesseract.pc # see above, gomp for }
}

build_imlib2() {
echo
/bin/echo -e "\e[93m*** Building imlib2 (libcaca dependency)***\e[39m"
echo
cd $BUILD_DIR/imlib2-*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
if [ ! -f configure ]; then
  ./autogen.sh --prefix=$TARGET_DIR --enable-static --disable-shared
else
  [ ! -f config.status ] && ./configure --prefix=$TARGET_DIR --enable-static --disable-shared
fi
make -j $jval
make install
}

build_libcaca() {
echo
/bin/echo -e "\e[93m*** Building libcaca... ***\e[39m"
echo
cd $BUILD_DIR/libcaca-*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
sed -i 's/"$amvers" "<" "1.5"/"$amvers" "<" "1.05"/g' ./bootstrap
./bootstrap
./configure --prefix=$TARGET_DIR --enable-static --disable-shared --disable-slang --disable-doc --disable-ruby --disable-csharp --disable-java --disable-cxx --disable-ncurses --disable-x11 #--disable-python --disable-cocoa --bindir="$BIN_DIR" 
make -j $jval
make install
}

build_libilbc() {
echo
/bin/echo -e "\e[93m*** Building libilbc ***\e[39m"
echo
cd $BUILD_DIR/libilbc-*
#sed 's/lib64/lib/g' -i CMakeLists.txt
#cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="$TARGET_DIR" -DBUILD_SHARED_LIBS=0 -DCMAKE_LIBRARY_OUTPUT_DIRECTORY:PATH=$TARGET_DIR/lib
autoreconf --force --install --verbose
./configure --prefix=$TARGET_DIR --disable-shared
make -j $jval
make install
}

build_frei0r() {
echo
/bin/echo -e "\e[93m*** Building frei0r ***\e[39m"
echo
cd $BUILD_DIR/frei0r-*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
[ ! -f configure ] && ./autogen.sh
./configure --prefix=$TARGET_DIR --enable-static # --disable-shared
make -j $jval
make install
}

# needs libxml2, freetype, fontconfig, (ANT & javac for compiling OR --disable-bdjava-jar)
build_libbluray() {
echo
/bin/echo -e "\e[93m*** Building libbluray ***\e[39m"
echo
cd "$BUILD_DIR"/libbluray-git
git submodule update --init
./bootstrap
./configure --prefix=$TARGET_DIR --disable-shared --disable-bdjava-jar
make -j $(nproc)
make install
}

build_libaom() {
echo
/bin/echo -e "\e[93m*** Building libaom ***\e[39m"
echo
cd $BUILD_DIR/aom-*
mkdir -pv aom_build
cd aom_build
cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="$TARGET_DIR" -DBUILD_SHARED_LIBS=0 ..
make -j $jval
make install
}

build_dav1d() {
echo
/bin/echo -e "\e[93m*** Building dav1d ***\e[39m"
echo
cd $BUILD_DIR/libdav1d-*
${BUILD_DIR}/meson-git/meson.py --prefix=${TARGET_DIR} --libdir=${TARGET_DIR}/lib --buildtype=release --strip --default-library=static build
cd build/
ninja -j 1
ninja install
#cp build/src/libdav1d.a $TARGET_DIR/lib || exit 1 # avoid 'run ranlib' weird failure, possibly older meson's https://github.com/mesonbuild/meson/issues/4138 :|
}

build_Xvid() {
echo
/bin/echo -e "\e[93m*** Building Xvid ***\e[39m"
echo
cd $BUILD_DIR/xvid*/build/generic
#sed -i 's/^LN_S=@LN_S@/& -f -v/' platform.inc.in
#sed -i '/AC_MSG_CHECKING(for platform specific LDFLAGS\/CFLAGS)/{n;s/.*/SPECIFIC_LDFLAGS="-static"/}' ./configure.in
#sed -i '/SPECIFIC_LDFLAGS="-static"/{n;s/.*/SPECIFIC_CFLAGS="-static"/}' ./configure.in
./bootstrap.sh
apply_patch file://$PATCH_DIR/xvidcore-git_static-lib.diff -p0
./configure --prefix=$TARGET_DIR --disable-shared
make -j $jval
make install
#chmod -v 755 $TARGET_DIR/lib/libxvidcore.so.4.3
#install -v -m755 -d $TARGET_DIR/share/doc/xvidcore-1.3.5/examples && install -v -m644 ../../doc/* $TARGET_DIR/share/doc/xvidcore-1.3.5 && install -v -m644 ../../examples/* $TARGET_DIR/share/doc/xvidcore-1.3.5/examples
}

build_x264() {
echo
/bin/echo -e "\e[93m*** Building x264 ***\e[39m"
echo
cd $BUILD_DIR/x264*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
[ ! -f config.status ] && ./configure --prefix=$TARGET_DIR --enable-static --disable-opencl --enable-pic
make -j $jval
make install
}

build_x265() {
echo
/bin/echo -e "\e[93m*** Building x265 ***\e[39m"
echo
cd $BUILD_DIR/x265*
cd build/linux
[ $rebuild -eq 1 ] && find . -mindepth 1 ! -name 'make-Makefiles.bash' -and ! -name 'multilib.sh' -exec rm -r {} +
cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="$TARGET_DIR" -DENABLE_SHARED:BOOL=OFF -DSTATIC_LINK_CRT:BOOL=ON -DENABLE_CLI:BOOL=OFF ../../source
sed -i 's/-lgcc_s/-lgcc_eh/g' x265.pc
make -j $jval
make install
}

build_fribidi() {
echo
/bin/echo -e "\e[93m*** Building fribidi (libass dependency)***\e[39m"
echo
cd $BUILD_DIR/fribidi-*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
if [ ! -f configure ]; then
  ./autogen.sh --prefix=$TARGET_DIR --disable-shared --enable-static --disable-debug --disable-deprecated
else
  ./configure --prefix=$TARGET_DIR --disable-shared --enable-static --disable-debug --disable-deprecated
fi
make
make install
}

build_libass() {
echo
/bin/echo -e "\e[93m*** Building libass ***\e[39m"
echo
cd $BUILD_DIR/libass-*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
[ ! -f configure ] && ./autogen.sh
./configure --prefix=$TARGET_DIR --disable-shared
make -j $jval
make install
}

build_libvidstab() {
echo
/bin/echo -e "\e[93m*** Building libvidstab ***\e[39m"
echo
cd $BUILD_DIR/vid.stab-*
  if [ ! -f CMakeLists.txt.bak ]; then # Change CFLAGS.
    sed -i.bak "s/O3/O2/;s/ -fPIC//" CMakeLists.txt
  fi
#cd $BUILD_DIR/vid.stab-release-*
#[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
#if [ "$platform" = "linux" ]; then
#  sed -i "s/vidstab SHARED/vidstab STATIC/" ./CMakeLists.txt
#elif [ "$platform" = "darwin" ]; then
#  sed -i "" "s/vidstab SHARED/vidstab STATIC/" ./CMakeLists.txt
#fi
cmake -G "Unix Makefiles" -DBUILD_SHARED_LIBS=0 -DCMAKE_INSTALL_PREFIX="$TARGET_DIR"
make -j $jval
make install
}

build_zimg() {
echo
/bin/echo -e "\e[93m*** Building zimg ***\e[39m"
echo
cd $BUILD_DIR/zimg-*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
[ ! -f configure ] && ./autogen.sh
./configure --enable-static  --prefix=$TARGET_DIR --disable-shared
make -j $jval
make install
}

build_ffmpeg() {
echo
/bin/echo -e "\e[93m*** Building FFmpeg ***\e[39m"
date +%H:%M:%S
echo
cd $BUILD_DIR/FFmpeg-*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true

if [ "$platform" = "linux" ]; then
  [ ! -f config.status ] && ./configure \
    --prefix="$TARGET_DIR" \
    --pkg-config-flags="--static" \
    --extra-version=Tec-3.9s \
    --extra-libs="-lpthread -lm -lz -ldl -lharfbuzz" \
    --extra-ldexeflags="-static" \
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
    --enable-libaom  \
    --enable-libass \
    --enable-libbluray \
    --enable-libcaca \
    --enable-libcdio \
    --enable-libdav1d \
    --enable-libfdk-aac \
    --enable-libflite \
    --enable-libfreetype \
    --enable-libfribidi \
    --enable-libilbc \
    --enable-liblensfun \
    --enable-libmp3lame \
    --enable-libmysofa \
    --enable-libopencore-amrnb \
    --enable-libopencore-amrwb \
    --enable-libopenjpeg \
    --enable-libopus \
  --disable-libpulse \
    --enable-librtmp \
    --enable-librubberband \
    --enable-libsnappy \
    --enable-libsoxr \
    --enable-libspeex \
    --enable-libtesseract \
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
    --enable-cuda \
  --disable-cuda-nvcc \
    --enable-cuvid \
    --enable-ffnvcodec \
    --enable-nvenc \
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
#  --enable-gnutls          enable gnutls, needed for https support if openssl, libtls or mbedtls is not used [no]
#  --enable-ladspa          enable LADSPA audio filtering [no]
#  --enable-libaribb24      enable ARIB text and caption decoding via libaribb24 [no]
#  --enable-libbs2b         enable bs2b DSP library [no]
#  --enable-libcelt         enable CELT decoding via libcelt [no]
#  --enable-libcodec2       enable codec2 en/decoding using libcodec2 [no]
#  --enable-libdavs2        enable AVS2 decoding via libdavs2 [no]
#  --enable-libdc1394       enable IIDC-1394 grabbing using libdc1394 and libraw1394 [no]
#  --enable-libgme          enable Game Music Emu via libgme [no]
#  --enable-libgsm          enable GSM de/encoding via libgsm [no]
#  --enable-libiec61883     enable iec61883 via libiec61883 [no]
#  --enable-libjack         enable JACK audio sound server [no]
#  --enable-libklvanc       enable Kernel Labs VANC processing [no]
#  --enable-libkvazaar      enable HEVC encoding via libkvazaar [no]
#  --enable-libmodplug      enable ModPlug via libmodplug [no]
#  --enable-libopencv       enable video filtering via libopencv [no]
#  --enable-libopenh264     enable H.264 encoding via OpenH264 [no]
#  --enable-libopenmpt      enable decoding tracked files via libopenmpt [no]
#  --enable-librav1e        enable AV1 encoding via rav1e [no] (unknown option?)
#  --enable-librsvg         enable SVG rasterization via librsvg [no]
#  --enable-libshine        enable fixed-point MP3 encoding via libshine [no]
#  --enable-libsmbclient    enable Samba protocol via libsmbclient [no]
#  --enable-libsrt          enable Haivision SRT protocol via libsrt [no]
#  --enable-libssh          enable SFTP protocol via libssh [no]
#  --enable-libtensorflow   enable TensorFlow as a DNN module backend for DNN based filters like sr [no]
#  --enable-libv4l2         enable libv4l2/v4l-utils [no]
#  --enable-libwavpack      enable wavpack encoding via libwavpack [no]
#  --enable-libxavs         enable AVS encoding via xavs [no]
#  --enable-libxavs2        enable AVS2 encoding via xavs2 [no]
#  --enable-libzmq          enable message passing via libzmq [no]
#  --enable-libzvbi         enable teletext support via libzvbi [no]
#  --enable-lv2             enable LV2 audio filtering [no]
#  --enable-decklink        enable Blackmagic DeckLink I/O support [no]
#  --enable-mediacodec      enable Android MediaCodec support [no] (requires --enable-jni)
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
    --extra-version=Tec-3.9s \
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
    --enable-libflite \
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

make -j $jval
make install
make distclean
}

deps() {
spd-say --rate -25 "Starting dependencies"
#yasm
build_asciidoc #wants docbook-xsl-1.79.2, fop-2.5, libxslt-1.1.34, Lynx-2.8.9rel.1, dblatex, and W3m
build_nasm #wants asciidoc-9.0.4 and xmlto-0.0.28
extract_cmake
extract_ninja
build_libffi #wants DejaGnu-1.6
#linuxPAM
#libcap
build_liblzma
build_zlib
build_libzstd #wants zlib, lzma
#tcl #tkinter dependecy
#tkinter #python dependency
build_libexpat #
#Python
build_nv_headers #
build_glib #wants python, iconv, zlib, libffi, libmount, libFAM, libELF
build_OpenSSL_RTMP # Should be before Python. Wants ZLIB
build_librtmp # wants old openssl, 1.0.2u works
#build_OpenSSL # Should be before Python. Wants ZLIB
build_libcdio #wants icovn, ncurses, libvcd
build_libcdio_paranoia #wants libcdio
build_vcdimager #wants libpopt, libcdio, libiso9660, libxml
rebuild_libcdio #wants icovn, ncurses, libvcd
}

adeps() {
spd-say --rate -25 "Starting audio dependencies"
build_libmysofa # wants zlib
build_ALSAlib #
build_voamrwbenc #
build_opencoreamr #
build_fdkaac #
build_mp3lame #wants ncurses, iconv. GTK
build_opus #
build_libvpx #
build_libsoxr #
build_libflite #
build_libsnappy # wants zlib
build_vamp_plugin #
build_fftw # wants f77 compiler
build_libogg # 
build_libflac # wants ogg, XMMS
build_libvorbis # needs ogg
build_libspeexdsp
build_libspeex # needs libspeexdsp
build_libsndfile # wants flac, ogg, speex, vorbis, opus, sqlite3, alsa
build_libsamplerate # wants libsndfile, alsa, fftw3
build_librubberband # wants libsndfile, fftw, samplerate
build_libtwolame # wants libsndfile
build_libtheora # needs ogg, wants vorbis, png
#build_PulseAudio #Doesn't work yet
#sdl1
}

pdeps() {
spd-say --rate -25 "Starting picture dependencies"
build_GIFlib #
build_libjpegturbo #
build_libPNG #wants zlib
build_libID3tag #wants zlib,
build_libwebp #wants giflib, jpeg, libtiff, wic, sdl, png, glut, opengl
build_libTIFF #wants lzw, zlib, jpeg, jbig, lzma, zstd, webp, glut, opengl
rebuild_libwebp #wants giflib, jpeg, libtiff, wic, sdl, png, glut, opengl
#utilmacros
#xorgproto
build_libXML #wants iconv, icu, lzma, zlib
build_openjpeg #
build_lensfun #wants glib
}

tdeps() {
spd-say --rate -25 "Starting text dependencies"
build_FreeType2 #wants harfbuzz, zlib,linpng,bzip2
build_FontConfig #wants iconv, freetype2, expat, XML, jsonc
build_harfbuzz #wants glib, icu, freetype2, cairo, fontconfig, graphite2, coretext, directwrite, GDI, uniscribe
#rebuild_FreeType2
build_fribidi # wants c2man (if compiling from git)
build_libass #wants nasm, iconv, FreeType2, fribidi, FontConfig, coretext, directwrite, harfbuzz
build_libleptonica #wants zlib, png, jpeg, giflib, libtiff, libwebp
build_libtesseract #wants opencl, tiff, asciidoc, libleptonica, icu, pango, cairo
build_imlib2 #wants freetype, x-libs, jpeg, png, webp, tiff, giflib, zlib, bz2, id3tag
build_libcaca #wants zlib, slang, opencl, ftgl, imlib2, pangoft2, cppunit, zzuf
build_libilbc #
build_frei0r # opencv, gavl, cairo
}

vdeps() {
spd-say --rate -25 "Starting video dependencies"
build_libbluray #wants libxml2, freetype2, fontconfig
build_libaom #
build_dav1d #wants nasm, meson, ninja, doxygen, dot
build_Xvid #wants yasm,
build_x264 #
build_x265 #wants numa, nasm
build_libvidstab #
build_zimg #
#sdl2
}

alldownloads
#echo "Press ENTER to continue" && bash -c read -p

dp_time=$(date +%H:%M)
echo
echo $dp_time
deps

adp_time=$(date +%H:%M)
echo
echo $adp_time
adeps

pdp_time=$(date +%H:%M)
echo
echo $pdp_time
pdeps

tdp_time=$(date +%H:%M)
echo
echo $tdp_time
tdeps

vdp_time=$(date +%H:%M)
echo
echo $vdp_time
vdeps

spd-say --rate -25 "Dependencies built"

ff_time=$(date +%H:%M)
echo
echo $ff_time
build_ffmpeg

echo Started:				$start_time
echo Dependencies Started:		$dp_time
echo Audio Dependencies Started:	$adp_time
echo Picture Dependencies Started:	$pdp_time
echo Text Dependencies Started:		$tdp_time
echo Video Dependencies Started:	$vdp_time
echo ffmpeg Started:			$ff_time
finish_time=$(date +%H:%M)
echo $finish_time
spd-say --rate -25 "Build Complete"
hash -r
