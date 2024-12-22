#!/bin/sh

# ffmpeg static build 7.1.0

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
ubuntu_version=`lsb_release -rs`

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
#do_git_checkout http://git.savannah.gnu.org/r/autoconf.git "$BUILD_DIR"/autoconf-git v2.71

#do_git_checkout http://git.savannah.gnu.org/r/automake.git "$BUILD_DIR"/automake-git v1.17


#[ $is_x86 -eq 1 ] && download \
#  "yasm-1.3.0.tar.gz" \
#  "" \
#  "fc9e586751ff789b34b1f21d572d96af" \
#  "http://www.tortall.net/projects/yasm/releases/"

do_git_checkout https://github.com/asciidoc-py/asciidoc-py.git "$BUILD_DIR"/asciidoc-git 9.x

[ $is_x86 -eq 1 ] && download \
  "nasm-2.16.03.tar.bz2" \
  "" \
  "f345060369183eaa7ef22a64cb6a4309" \
  "https://www.nasm.us/pub/nasm/releasebuilds/2.16.03/"
#[ $is_x86 -eq 1 ] && do_git_checkout https://github.com/netwide-assembler/nasm.git "$BUILD_DIR"/nasm-git master

do_git_checkout https://github.com/mesonbuild/meson.git "$BUILD_DIR"/meson-git 1.5 #0.56 #master

download \
  "cmake-3.30.5-Linux-x86_64.tar.gz" \
  "" \
  "049c7c453965ce66f073de55e51fdaa1" \
  "https://github.com/Kitware/CMake/releases/download/v3.30.5/"

download \
  "ninja-linux.zip" \
  "ninja-linux-1.12.1.zip" \
  "ea173b992d1b9640ac6e0fdd556f9959" \
  "https://github.com/ninja-build/ninja/releases/download/v1.12.1/"
#do_git_checkout https://github.com/ninja-build/ninja.git "$BUILD_DIR"/ninja-build/ninja-git  #master

# v3.4.6 and higher require Autoconf 2.7.1
do_git_checkout https://github.com/libffi/libffi.git "$BUILD_DIR"/libffi-git v3.4.2

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

# Download XZ to build liblzma
# v5.6.0, v5.6.1 causes Segmentation fault (core dumped)
do_git_checkout https://git.tukaani.org/xz.git "$BUILD_DIR"/xz-git v5.6.3 #v5.4.7 #v5.2.4 # master # v5.2.4

do_git_checkout https://github.com/madler/zlib.git "$BUILD_DIR"/zlib-git 51b7f2abdade71cd9bb0e7a373ef2610ec6f9daf

do_git_checkout https://github.com/facebook/zstd.git "$BUILD_DIR"/zstd-git v1.5.6 #release #dev

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

do_git_checkout https://github.com/libexpat/libexpat.git "$BUILD_DIR"/libexpat-git R_2_6_3 #master

do_git_checkout https://github.com/openssl/openssl.git "$BUILD_DIR"/openssl-old-git OpenSSL_1_0_2u

do_git_checkout https://git.ffmpeg.org/rtmpdump "$BUILD_DIR"/rtmpdump-git 6f6bb1353fc84f4cc37138baa99f586750028a01

#do_git_checkout https://github.com/openssl/openssl.git "$BUILD_DIR"/openssl-git OpenSSL_1_1_1d #OpenSSL_1_1_0l

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

# For ffmpeg 5.x and older use n11.1.5.1
# For ffmpeg 6.x use sdk/12.0
# For ffmpeg 7.x use sdk/12.1
do_git_checkout https://git.videolan.org/git/ffmpeg/nv-codec-headers.git "$BUILD_DIR"/nv-codec-headers-git sdk/12.1 #n11.1.5.1 #master

do_git_checkout https://gitlab.gnome.org/GNOME/glib.git "$BUILD_DIR"/glib-git 2.82.2 #2.56.3

# Partial update of configure.ac.. (2023-03-26) and newer require Autoconf version 2.71 or higher
do_git_checkout https://git.savannah.gnu.org/git/libcdio.git "$BUILD_DIR"/libcdio-git 3a737bc656504576c97685cae9ca4afecbb7e0a4 #569c452f8d1650c0ec50ebeef7869b54ed9c8be6 #rr-deep-directory #release-2.1.0 #master

do_git_checkout https://github.com/rocky/libcdio-paranoia.git "$BUILD_DIR"/libcdio-paranoia-git release-10.2+2.0.1 #master

do_git_checkout https://github.com/rocky/vcdimager.git "$BUILD_DIR"/vcdimager-git 23f0738652e1cc0cab52b6e8a44f806e9e5e5739 #master

### adeps

do_git_checkout https://github.com/hoene/libmysofa.git "$BUILD_DIR"/libmysofa-git dd315a8ec1fee7193d40e4a59b12c5590a4a918c #latest #v1.3.3 #v1.1 #1.0

do_git_checkout https://github.com/alsa-project/alsa-lib.git "$BUILD_DIR"/alsa-lib-git 352cbc5eb94a271a9c3c0ff5bf1742232a69e0d0 #master #v1.2.12 #v1.2.1.2 #master
#v1.2.1.2 1c7e46d5d8bc3c213d7963056240b385f3d8727b #v1.2.12 34422861f5549aee3e9df9fd8240d10b530d9abd #1.2.13pre a3865b2439ce686024bc83b3b9b1cd60fa75986c

do_git_checkout https://github.com/mstorsjo/vo-amrwbenc.git "$BUILD_DIR"/vo-amrwbenc-git 3b3fcd0d250948e74cd67e7ea81af431ab3928f9 #master #0.1.3

do_git_checkout https://github.com/BelledonneCommunications/opencore-amr.git "$BUILD_DIR"/opencore-amr-git 3b67218fb8efb776bcd79e7445774e02d778321d #master #0.1.3

do_git_checkout https://github.com/mstorsjo/fdk-aac.git "$BUILD_DIR"/fdk-aac-git 716f4394641d53f0d79c9ddac3fa93b03a49f278 #master #2.0.1

do_svn_checkout https://svn.code.sf.net/p/lame/svn/trunk/lame "$BUILD_DIR"/lame-svn 6509 #6507 #6449 #3.100
# build 6510 and newer require libtool 2.4.7

do_git_checkout https://github.com/xiph/opus.git "$BUILD_DIR"/opus-git 7db26934e4156597cb0586bb4d2e44dccdde1a59 #main #1.3.1

do_git_checkout https://git.code.sf.net/p/soxr/code "$BUILD_DIR"/soxr-git 945b592b70470e29f917f4de89b4281fbbd540c0 #master #0.1.3

#do_git_checkout https://github.com/kubo/flite.git $BUILD_DIR/flite-git master #4681a5fb82afb9036c6dd6a9303892f8dc7b8e69
version=`echo $ubuntu_version'<=20.04' | bc -l`
if [ $version -eq 1 ]; then
    do_git_checkout https://github.com/TNTPro/ffmpeg-libflite2.0.0.git $BUILD_DIR/flite-git a193a909265fc6a91b15d8d5f136d30d000c2ea3 #main
else
    do_git_checkout https://github.com/festvox/flite.git $BUILD_DIR/flite-git 6c9f20dc915b17f5619340069889db0aa007fcdc #master
fi

do_git_checkout https://github.com/google/snappy.git $BUILD_DIR/snappy-git 32ded457c0b1fe78ceb8397632c416568d6714a0 #main #1.1.9
cd $BUILD_DIR/snappy-git
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
git submodule update --init
cd $BUILD_DIR

do_git_checkout https://github.com/vamp-plugins/vamp-plugin-sdk.git "$BUILD_DIR"/vamp-plugin-sdk-git vamp-plugin-sdk-v2.10 #vamp-plugin-sdk-v2.7.1

download \
  "fftw-3.3.10.tar.gz" \
  "" \
  "8ccbf6a5ea78a16dbc3e1306e234cc5c" \
  "http://fftw.org/"
#do_git_checkout https://github.com/FFTW/fftw3.git $BUILD_DIR/fftw3-git fftw-3.3.6-pl2 #master
# need ocaml, ocamlbuild & special tools to build from git

do_git_checkout https://github.com/xiph/ogg.git $BUILD_DIR/ogg-git db5c7a49ce7ebda47b15b78471e78fb7f2483e22 #master #1.3.4

do_git_checkout https://github.com/xiph/flac.git $BUILD_DIR/flac-git 30cdb4d397087e5f4949b8ce114571306544f346 #master #5152c6cace63ee11d422c1ef9589a9a0a5d034b2

do_git_checkout https://github.com/xiph/vorbis.git $BUILD_DIR/vorbis-git 84c023699cdf023a32fa4ded32019f194afcdad0 #master #1.3.6

do_git_checkout https://github.com/xiph/speexdsp.git "$BUILD_DIR"/speexdsp-git dbd421d149a9c362ea16150694b75b63d757a521 #master

do_git_checkout https://github.com/xiph/speex.git $BUILD_DIR/speex-git aca6801183bad01458140dbbab71a68a02e5a561 #master #1.2.0

do_git_checkout https://github.com/erikd/libsndfile.git $BUILD_DIR/libsndfile-git 0d3f80b7394368623df558d8ba3fee6348584d4d #master #58c05b87162264200b1aa7790be260fd74c9deee

do_git_checkout https://github.com/erikd/libsamplerate.git $BUILD_DIR/libsamplerate-git 4858fb016550d677de2356486bcceda5aed85a72 #master

# Versions >1.9 require meson
do_git_checkout https://github.com/breakfastquay/rubberband.git $BUILD_DIR/rubberband-git v1.9 #default

do_git_checkout https://github.com/njh/twolame.git $BUILD_DIR/twolame-git 90b694b6125dbe23a346bd5607a7fb63ad2785dc #main #0.4.0

do_git_checkout https://github.com/xiph/theora.git $BUILD_DIR/libtheora-git 7180717276af1ebc7da15c83162d6c5d6203aabf #master #1.1.1

##download \
##  "master.tar.gz" \
##  "pulseaudio-master.tar.gz" \
##  "nil" \
##  "https://github.com/pulseaudio/pulseaudio/archive/"
#do_git_checkout https://github.com/pulseaudio/pulseaudio.git "$BUILD_DIR"/pulseaudio-git master

### pdeps

do_git_checkout https://git.code.sf.net/u/ffontaine35/giflib "$BUILD_DIR"/giflib-ffontaine35-git 5.2.1 #dd8b375e2a5ddfabb9709c99e38bbe0fd3b212a4 #master

do_git_checkout https://github.com/libjpeg-turbo/libjpeg-turbo.git $BUILD_DIR/libjpeg-turbo-git e0e18dea5433e600ea92d60814f13efa40a0d7dd #main #d7932a270921391c303b6ede6f1dfbd94290a3d8

do_git_checkout https://github.com/glennrp/libpng.git "$BUILD_DIR"/libpng-git c1cc0f3f4c3d4abd11ca68c59446a29ff6f95003 #master

# >1.3.0 cause tessaract pkg_config errors
do_git_checkout https://github.com/webmproject/libwebp "$BUILD_DIR"/libwebp-git 1.3.0 #1.3.0 #1.2.4 #1.1.0 main 

download \
  "tiff-4.7.0.tar.gz" \
  "" \
  "nil" \
  "https//download.osgeo.org/libtiff/" #4.2.0 #4.7.0
#do_git_checkout https://gitlab.com/libtiff/libtiff.git "$BUILD_DIR"/tiff-git v4.1.0 #master #4.1.0

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

# >v2.10.1 needs Automake 1.16.3
do_git_checkout https://gitlab.gnome.org/GNOME/libxml2.git "$BUILD_DIR"/libxml2-git v2.10.1 #v2.9.14 #master

do_git_checkout https://github.com/uclouvain/openjpeg.git "$BUILD_DIR"/openjpeg-git eb25a5ec777ff6699f4bb1187740467dcfa64dd6 #master #2.3.1

# >v0.3.3 causes "can't find setuptools error" used instead of distutils (python)
do_git_checkout https://github.com/lensfun/lensfun.git "$BUILD_DIR"/lensfun-git v0.3.3 #v0.3.1 #v0.3.95 #master

do_git_checkout https://github.com/sekrit-twc/zimg.git "$BUILD_DIR"/zimg-git release-3.0.5 #master

### tdeps

download \
  "freetype-2.13.3.tar.xz" \
  "" \
  "f3b4432c4212064c00500e1ad63fbc64" \
  "https://downloads.sourceforge.net/freetype/"
#do_git_checkout https://git.savannah.gnu.org/git/freetype/freetype2.git "$BUILD_DIR"/freetype-2-git VER-2-10-1

# 2.15 requires Autoconf 2.71 # can use meson
do_git_checkout https://gitlab.freedesktop.org/fontconfig/fontconfig.git "$BUILD_DIR"/fontconfig-git 2.14.2 #main

# libass dependency 
do_git_checkout https://github.com/harfbuzz/harfbuzz.git "$BUILD_DIR"/harfbuzz-git 3258b1f2482a522f7edebecb11ffb061cd050abd #main #0b7beefd0b268c1ec52935937f4abc7e7a3bc3e5 #8.5.0

do_git_checkout https://github.com/fribidi/fribidi.git "$BUILD_DIR"/fribidi-git cfc71cda065db859d8b4f1e3c6fe5da7ab02469a #master #v1.0.16 #1.0.8
#do_git_checkout https://github.com/Oxalin/fribidi.git "$BUILD_DIR"/fribidi-git doxygen

do_git_checkout https://github.com/libass/libass.git "$BUILD_DIR"/libass-git 7d8e335b094f00c57fb557b01e93b60a17e63434 #master #4df64d060a8a89b2cd54678190426079bb9d49a6 #0.14.0

# >1.82.0 causes tesseract not found using pkg-config error
do_git_checkout https://github.com/DanBloomberg/leptonica.git "$BUILD_DIR"/leptonica-git 1.82.0 #1.81.0 #master

version=`echo $ubuntu_version'<=18.04' | bc -l`
if [ $version -eq 1 ]; then
    do_git_checkout https://github.com/tesseract-ocr/tesseract.git tesseract-git 4.1
else
    do_git_checkout https://github.com/tesseract-ocr/tesseract.git tesseract-git 2a944fbe98ed4408a5f0fd5693c398a9cebaf6d4 #main #66cf74f2dd82790444ef321d3bf03fa303e9caef #4.0.0-beta.3
fi
#do_git_checkout https://github.com/tesseract-ocr/tesseract.git tesseract-git a2e72f258a3bd6811cae226a01802d891407409f # #315


download \
  "libid3tag-0.15.1b.tar.gz" \
  "" \
  "e5808ad997ba32c498803822078748c3" \
  "https://sourceforge.net/projects/mad/files/"

do_git_checkout https://git.enlightenment.org/old/legacy-imlib2.git "$BUILD_DIR"/imlib2-git b03d3f042bdfb3ee3f66c08c0e41f10b2aaba172 #master #62d8e45523b1e2dde5ca59b0bc552ff3971beb44 #1.6.1

# >v0.99.beta19 requires Autoconf 2.71
do_git_checkout https://github.com/cacalabs/libcaca.git "$BUILD_DIR"/libcaca-git v0.99.beta19 # 

do_git_checkout https://github.com/TimothyGu/libilbc.git "$BUILD_DIR"/libilbc-git 7b350230ac8793078be081ed8386f20c80681046 #debian

version=`echo $ubuntu_version'<=16.04' | bc -l`
if [ $version -eq 1 ]; then
    do_git_checkout https://github.com/dyne/frei0r.git "$BUILD_DIR"/frei0r-git v1.9.6;
else
    do_git_checkout https://github.com/dyne/frei0r.git "$BUILD_DIR"/frei0r-git v1.10.0 #master
fi

### vdeps

do_git_checkout https://code.videolan.org/videolan/libbluray.git "$BUILD_DIR"/libbluray-git bb5bc108ec695889855f06df338958004ff289ef #master

do_git_checkout https://code.videolan.org/videolan/dav1d.git "$BUILD_DIR"/libdav1d-git 8291a66e50f2a1f5fcfa8615379d31ff15626991 #master

#svn checkout http://svn.xvid.org/trunk/xvidcore "$BUILD_DIR"/xvidcore-svn --username anonymous --password ""
#svn checkout http://svn.xvid.org/tags/release-1_3_7/xvidcore "$BUILD_DIR"/xvidcore-svn --username anonymous --password ""
svn checkout https://svn.xvid.org/tags/release-1_3_7/xvidcore "$BUILD_DIR"/xvidcore-svn --username anonymous --password ""

do_git_checkout https://code.videolan.org/videolan/x264.git "$BUILD_DIR"/x264-git da14df5535fd46776fb1c9da3130973295c87aca #master

do_git_checkout https://bitbucket.org/multicoreware/x265_git.git "$BUILD_DIR"/x265-git fa2770934b8f3d88aa866c77f27cb63f69a9ed39 #master #3.2.1

do_git_checkout https://chromium.googlesource.com/webm/libvpx "$BUILD_DIR"/libvpx-git 2c38ade434e51c6b1980a675b1c8cbee229b49ff #main #1.8.2

do_git_checkout https://github.com/georgmartius/vid.stab.git vid.stab-git 8dff7ad3c10ac663745f2263037f6e42b993519c #master #0.98b

# Also a main. Weird
do_git_checkout https://aomedia.googlesource.com/aom "$BUILD_DIR"/aom-git 402e264b94fd74bdf66837da216b6251805b4ae4 #master

do_git_checkout https://github.com/FFmpeg/FFmpeg.git "$BUILD_DIR"/FFmpeg-git n7.1 #n6.1.2 #n6.0 #n5.1.6 #n5.0 #n4.4.5 #n4.4.2 #n4.3.1 #n4.2.2 #master
}

TARGET_DIR_SED=$(echo $TARGET_DIR | awk '{gsub(/\//, "\\/"); print}')

build_autoconf() {
echo
/bin/echo -e "\e[93m*** building Autoconf ***\e[39m"
echo
  cd $BUILD_DIR/autoconf-*
  [ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
  ./bootstrap
  ./configure --prefix=$TARGET_DIR #--disable-shared --enable-static --with-freetype=yes
  make && make install
}

build_automake() {
echo
/bin/echo -e "\e[93m*** building Automake ***\e[39m"
echo
  cd $BUILD_DIR/automake-*
  [ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
  ./bootstrap
  ./configure --prefix=$TARGET_DIR #--disable-shared --enable-static
  make && make install
}

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
#      [ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
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
  cd $BUILD_DIR/cmake-*
  cp --recursive ./* "$TARGET_DIR"/
}

extract_ninja() {
echo
/bin/echo -e "\e[93m*** Extracting ninja ***\e[39m"
echo
  cd $BUILD_DIR/
  cp ./ninja "$TARGET_DIR"/bin/
}

build_libffi() {
echo
/bin/echo -e "\e[93m*** Building libffi ***\e[39m"
echo
  cd $BUILD_DIR/libffi-*
  [ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
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
#  [ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
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
#  [ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
  sed -i '/FAKEROOT=$(DESTDIR)/a prefix=${TARGET_DIR}' ./Make.Rules
  sed -i 's/shared/static/' ./Make.Rules
#  ./configure --prefix=$TARGET_DIR
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
#  cp cap_test $TARGET_DIR/sbin
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
  [ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
  [ ! -f configure ] && ./autogen.sh --no-po4a
  ./configure --prefix=$TARGET_DIR --enable-static --disable-shared --disable-xz --disable-xzdec --disable-lzmadec --disable-lzmainfo --disable-scripts --disable-doc #--disable-nls
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
  [ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
  cd build/cmake
  mkdir -pv builddir
  cd builddir
  cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="$TARGET_DIR" -DZSTD_LEGACY_SUPPORT=ON -DCMAKE_INSTALL_LIBDIR=$TARGET_DIR/lib -DZSTD_BUILD_SHARED:BOOL=OFF -DZSTD_LZMA_SUPPORT:BOOL=ON -DZSTD_ZLIB_SUPPORT:BOOL=ON ..
#  cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX=$TARGET_DIR -DBUILD_SHARED_LIBS=0 -DCMAKE_INSTALL_LIBDIR=$TARGET_DIR/lib -DCMAKE_INSTALL_INCLUDEDIR=$TARGET_DIR/include
  make -j $jval
  make install
}

tcl() {
echo
/bin/echo -e "\e[93m*** Building tcl (tkinter Dependency) ***\e[39m"
echo
  cd $BUILD_DIR/tcl*/unix
#  [ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
  ./configure --prefix=$TARGET_DIR --disable-shared --enable-64bit
  make -j $jval
  make install
}

tkinter() {
echo
/bin/echo -e "\e[93m*** Building tkinter (Python Dependency) ***\e[39m"
echo
  cd $BUILD_DIR/tk*/unix
#  [ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
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
#  [ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
  [ ! -f config.status ] && ./configure --prefix=$TARGET_DIR --with-system-expat --disable-shared --enable-profiling LDFLAGS="-static -static-libgcc" CFLAGS="-static" CPPFLAGS="-static" CCSHARED="" --with-ensurepip=yes # --enable-unicode=ucs4
  make -j $jval
  make install
}

build_nv_headers() {
echo
/bin/echo -e "\e[93m*** Building nv_headers ***\e[39m"
echo
  cd $BUILD_DIR/nv-codec-headers-git
  [ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
  make install "PREFIX=$TARGET_DIR" # just copies in headers
}

# wants libunwind-generic
build_glib() {
echo
/bin/echo -e "\e[93m*** Building glib ***\e[39m"
echo
  cd $BUILD_DIR/glib-*
  [ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
  ${BUILD_DIR}/meson-git/meson.py setup --prefix=${TARGET_DIR} --buildtype=release --default-library=static build
  ${BUILD_DIR}/meson-git/meson.py compile -C build
  ${BUILD_DIR}/meson-git/meson.py install -C build
}

build_glib_old() {
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

build_libcdio() {
#Requires: glib-2.0 maybe?
echo
/bin/echo -e "\e[93m*** Building libcdio ***\e[39m"
echo
  cd "$BUILD_DIR"/libcdio-git
  [ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
  ./autogen.sh --prefix=$TARGET_DIR --disable-shared --disable-cddb
  make -j $(nproc)
  make install
}

build_libcdio_paranoia() {
echo
/bin/echo -e "\e[93m*** Building libcdio_paranoia ***\e[39m"
echo
  cd "$BUILD_DIR"/libcdio-paranoia-git
  [ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
  ./autogen.sh --prefix=$TARGET_DIR --disable-shared
  make -j $(nproc)
  make install
}

build_vcdimager() {
echo
/bin/echo -e "\e[93m*** Building VCDImager ***\e[39m"
echo
  cd "$BUILD_DIR"/vcdimager-*
  [ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
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

###adeps

build_libmysofa() {
echo
/bin/echo -e "\e[93m***  Building libmysofa ***\e[39m"
echo
  cd $BUILD_DIR/libmysofa-*
  [ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
  cmake -G "Unix Makefiles" -DBUILD_SHARED_LIBS=0 -DCMAKE_INSTALL_PREFIX="$TARGET_DIR" -DBUILD_TESTS=0 -DCODE_COVERAGE=0
#  apply_patch file://$PATCH_DIR/libmysofa1.0.diff -p1
  make -j $jval
  make install
}

build_ALSAlib() {
echo
/bin/echo -e "\e[93m***  Building ALSAlib ***\e[39m"
echo
  cd $BUILD_DIR/alsa-lib-*
  [ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
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
  [ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
  # The lame build script does not recognize aarch64, so need to set it manually
  uname -a | grep -q 'aarch64' && lame_build_target="--build=arm-linux" || lame_build_target=''
  [ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
  [ ! -f config.status ] && ./configure --prefix=$TARGET_DIR --enable-nasm --enable-static --disable-shared --disable-decoder $lame_build_target
#  [ ! -f config.status ] && ./configure --prefix=$TARGET_DIR --enable-nasm --disable-shared $lame_build_target
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
  [ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
  unset CFLAGS
  ./configure --prefix=$TARGET_DIR --disable-shared # --with-langvox=all --with-audio=none 
  make -j $jval
#  make get_voices -j $jval
  export CFLAGS="-I${TARGET_DIR}/include $LDFLAGS"
  make install
}

build_libsnappy() {
echo
/bin/echo -e "\e[93m*** Building libsnappy ***\e[39m"
echo
  cd $BUILD_DIR/snappy-*
  [ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
  cmake -G "Unix Makefiles" -DBUILD_SHARED_LIBS=0 -DCMAKE_INSTALL_PREFIX="$TARGET_DIR" -DCMAKE_BUILD_TYPE=Release -DSNAPPY_BUILD_TESTS=OFF # extra params from deadsix27 and from new cMakeLists.txt content
  make -j $jval
  make install
}

build_vamp_pluginTEST() {
echo
/bin/echo -e "\e[93m*** Building vamp_plugin ***\e[39m"
echo
  cd $BUILD_DIR/vamp-plugin-sdk-*
  [ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
  mkdir -p build && cd build
#  cmake .. -DVAMPSDK_BUILD_EXAMPLE_PLUGINS=ON -DVAMPSDK_BUILD_SIMPLE_HOST=ON -DVAMPSDK_BUILD_RDFGEN=ON -DCMAKE_INSTALL_PREFIX="$TARGET_DIR" -DLIBSNDFILE_INCLUDE_DIR="$BUILD_DIR/libsndfile-git/include" -DLIBSNDFILE_LIBRARY="$TARGET_DIR/lib/" -DCMAKE_INSTALL_LIBDIR=$TARGET_DIR/lib -DBUILD_SHARED_LIBS=0 
  cmake -G "Unix Makefiles" .. -DVAMPSDK_BUILD_EXAMPLE_PLUGINS=ON -DVAMPSDK_BUILD_SIMPLE_HOST=ON -DVAMPSDK_BUILD_RDFGEN=ON -DCMAKE_INSTALL_PREFIX="$TARGET_DIR" -DLIBSNDFILE_INCLUDE_DIR="$BUILD_DIR/libsndfile-git/include" -DLIBSNDFILE_LIBRARY="$TARGET_DIR/lib/" -DCMAKE_INSTALL_LIBDIR=$TARGET_DIR/lib -DBUILD_SHARED_LIBS=0
#  cmake --build .
  make -j $jval
  make install

  exit
}

build_vamp_plugin() {
echo
/bin/echo -e "\e[93m*** Building vamp_plugin ***\e[39m"
echo
  cd $BUILD_DIR/vamp-plugin-sdk-*
  [ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
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
#  [ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
  if [ ! -f configure ]; then
    ./bootstrap.sh --prefix=$TARGET_DIR --disable-shared --enable-static --disable-doc
  else
    ./configure --prefix=$TARGET_DIR --enable-maintainer-mode --enable-threads --disable-shared --enable-static --disable-doc
  fi
  make -j $jval
  make install
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
  [ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
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
  [ ! -f configure ] && autoreconf -vif
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

build_libsndfileOLD() {
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

build_librubberband() {
echo
/bin/echo -e "\e[93m*** Building librubberband ***\e[39m"
echo
  cd $BUILD_DIR/rubberband-git
  [ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
  apply_patch file://$PATCH_DIR/rubberband_git_1.9_static-lib.diff -p0 # create install-static target
  ./configure --prefix=$TARGET_DIR --disable-ladspa
  make install-static # AR=${cross_prefix}ar # No need for 'do_make_install', because 'install-static' already has install-instructions.
  sed -i.bak 's/-lrubberband.*$/-lrubberband -lfftw3 -lsamplerate -lstdc++/' $TARGET_DIR/lib/pkgconfig/rubberband.pc
}

build_librubberbandMESON() {
echo
/bin/echo -e "\e[93m*** Building librubberband ***\e[39m"
echo
  cd $BUILD_DIR/rubberband-git
  [ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
#  apply_patch file://$PATCH_DIR/rubberband_git_static-lib.diff -p0 # create install-static target
  ${BUILD_DIR}/meson-git/meson.py setup --prefix=${TARGET_DIR} build --buildtype=release --default-library=static -Dfft=fftw -Dresampler=libsamplerate -Dcmdline=disabled -Dvamp=disabled -Dextra_include_dirs=${TARGET_DIR}/include -Dextra_lib_dirs=${TARGET_DIR}/lib
  ninja -C build
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
  [ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
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
  ./configure --prefix=$TARGET_DIR --enable-static --disable-shared --disable-rpath --disable-fast-install --disable-tests --disable-x11 --disable-atomic-arm-linux-helpers --disable-memfd --disable-coreaudio-output --disable-solaris --disable-glib2 --disable-gtk3 --disable-gsettings --disable-gconf --disable-avahi --disable-jack --disable-asyncns --disable-bluez5 --disable-systemd-daemon --disable-systemd-login --disable-systemd-journal --disable-manpages --disable-gstreamer
  make
  make install
}

### pdeps

build_GIFlib() {
echo
/bin/echo -e "\e[93m*** Building GIFlib (imlib2 and libwebp Dependency) ***\e[39m"
echo
  cd $BUILD_DIR/giflib-*
  [ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
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
  [ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
  cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX=$TARGET_DIR -DENABLE_SHARED=0 -DCMAKE_INSTALL_LIBDIR=$TARGET_DIR/lib -DCMAKE_INSTALL_INCLUDEDIR=$TARGET_DIR/include -DWITH_12BIT=1
  make -j $jval
  make install
}

build_libPNG() {
echo
/bin/echo -e "\e[93m*** Building libPNG ***\e[39m"
echo
  cd $BUILD_DIR/libpng-*
  [ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
  ./configure --disable-shared --prefix=$TARGET_DIR --libdir=$TARGET_DIR/lib --includedir=$TARGET_DIR/include CPPFLAGS=-I$TARGET_DIR/include
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

build_libTIFF() {
# No jbig and zstd, else 'tesseract not found using pkg-config'
echo
/bin/echo -e "\e[93m*** Building libTIFF ***\e[39m"
echo
  mv "$TARGET_DIR/lib/pkgconfig/libzstd.pc" "$TARGET_DIR/lib/pkgconfig/libzstd.pc.bak"
  mv "$TARGET_DIR/include/zstd.h" "$TARGET_DIR/include/zstd.h.bak"
  cd $BUILD_DIR/tiff-*
#  [ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
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
#  [ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
  ./configure --prefix=$TARGET_DIR
  make install
}

xorgproto() {
echo
/bin/echo -e "\e[93m*** Building xorgproto (libXau Dependency) ***\e[39m"
echo
  cd $BUILD_DIR/xorgproto-*
#  [ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
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

build_lensfun() {
# build_glib
echo
/bin/echo -e "\e[93m*** Building lensfun ***\e[39m"
echo
  cd $BUILD_DIR/lensfun-*
  [ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
  export CMAKE_STATIC_LINKER_FLAGS='-lws2_32 -pthread'
  cmake -G "Unix Makefiles" -DBUILD_SHARED_LIBS=0 -DCMAKE_INSTALL_PREFIX="$TARGET_DIR" -DBUILD_STATIC=on -DCMAKE_INSTALL_DATAROOTDIR=$TARGET_DIR
  make -j $jval
  make install
  sed -i.bak 's/-llensfun/-llensfun -lstdc++/' "$PKG_CONFIG_PATH/lensfun.pc"
  unset CMAKE_STATIC_LINKER_FLAGS
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

###tdeps

build_FreeType2() {
echo
/bin/echo -e "\e[93m*** Building FreeType2 (libass dependency) ***\e[39m"
echo
  cd $BUILD_DIR/freetype*
#  [ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
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
#  ${BUILD_DIR}/meson-git/meson.py setup --prefix=${TARGET_DIR} build --buildtype=release --default-library=static --prefer-static --bindir=${TARGET_DIR}/bin --includedir=${TARGET_DIR}/include --libdir=${TARGET_DIR}/lib -Dcpp_args=-DHB_HAVE_ICU=OFF -Dc_args=-DHB_HAVE_ICU=OFF -Dcpp_args=-DHB_HAVE_FREETYPE=ON -Dc_args=-DHB_HAVE_FREETYPE=ON -Dcpp_args=-DHB_HAVE_GLIB=ON -Dc_args=-DHB_HAVE_GLIB=ON -Dcpp_args=-DHB_HAVE_CAIRO=ON -Dc_args=-DHB_HAVE_CAIRO=ON
  ${BUILD_DIR}/meson-git/meson.py setup --prefix=${TARGET_DIR} build --buildtype=release --default-library=static --prefer-static --bindir=${TARGET_DIR}/bin --includedir=${TARGET_DIR}/include --libdir=${TARGET_DIR}/lib
  ${BUILD_DIR}/meson-git/meson.py install -Cbuild
}

build_harfbuzzOLD() {
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
  cd $BUILD_DIR
  rm -f $BUILD_DIR/freetype-git
  download \
    "freetype-2.13.3.tar.xz" \
    "" \
    "f3b4432c4212064c00500e1ad63fbc64" \
    "https://downloads.sourceforge.net/freetype/"
  cd $BUILD_DIR/freetype*
  if [ "$platform" = "linux" ]; then
    [ ! -f ./builds/unix/configure ] && ./autogen.sh
  fi
  [ ! -f config.status ] && ./configure --prefix=$TARGET_DIR --enable-static --disable-shared --with-harfbuzz --with-bzip2 
  make -j $jval
  make install
}

rebuild_FreeType2OLD() {
echo
/bin/echo -e "\e[93m*** ReBuilding FreeType2 after HarfBuzz ***\e[39m"
echo
  cd $BUILD_DIR/freetype*
#  make distclean
#  [ ! -f config.status ] ./configure --prefix=$TARGET_DIR --enable-static --disable-shared --with-harfbuzz --with-bzip2
#  make -j $jval
  make install
  sed -i.bak 's/-lfreetype.*/-lfreetype -lharfbuzz/' "$TARGET_DIR/lib/pkgconfig/freetype2.pc"
  sed -i.bak 's/libfreetype.la -lbz2/libfreetype.la -lharfbuzz -lbz2/' "$TARGET_DIR/lib/libfreetype.la"
  sed -i.bak 's/-lharfbuzz.*/-lharfbuzz -lfreetype/' "$TARGET_DIR/lib/pkgconfig/harfbuzz.pc"
  sed -i.bak 's/libfreetype.la -lbz2/libfreetype.la -lharfbuzz -lbz2/' "$TARGET_DIR/lib/libharfbuzz.la"
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

build_libtesseract() {
# build_libleptonica
# build_libtiff # no disable configure option for this in tesseract? odd...
echo
/bin/echo -e "\e[93m*** Building libtesseract ***\e[39m"
echo
  cd $BUILD_DIR/tesseract-*
#  sed -i.bak 's/libcurl/libbcurl_disabled/g' configure.ac # --disable-curl hard disable, sometimes it's here but they link it wrong so punt...
  [ ! -f configure ] && ./autogen.sh
  ./configure --prefix=$TARGET_DIR --enable-static --disable-shared
  make -j $jval
  make install
  sed -i.bak 's/-ltesseract.*$/-ltesseract -lstdc++ -llept -ltiff -llzma -ljpeg -lz -lgomp/' $PKG_CONFIG_PATH/tesseract.pc # see above, gomp for }
}

build_libID3tag() {
echo
/bin/echo -e "\e[93m*** Building libID3tag (imlib2 Dependency) ***\e[39m"
echo
  cd $BUILD_DIR/libid3tag-*
#  [ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
  ./configure --prefix=$TARGET_DIR --disable-shared
  make -j $jval
  make install
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
  [ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
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

### vdeps

build_libbluray() {
# needs libxml2, freetype, fontconfig, (ANT & javac for compiling OR --disable-bdjava-jar)
echo
/bin/echo -e "\e[93m*** Building libbluray ***\e[39m"
echo
  cd "$BUILD_DIR"/libbluray-*
  [ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
  git submodule update --init
  apply_patch file://$PATCH_DIR/temp-ffmpeg7-libbluray-1.3.4.diff -p0
  ./bootstrap
  ./configure --prefix=$TARGET_DIR --disable-shared --disable-bdjava-jar
  make -j $(nproc)
  make install
}

build_dav1d() {
echo
/bin/echo -e "\e[93m*** Building dav1d ***\e[39m"
echo
  cd $BUILD_DIR/libdav1d-*
  [ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
  ${BUILD_DIR}/meson-git/meson.py setup --prefix=${TARGET_DIR} --libdir=${TARGET_DIR}/lib --buildtype=release --strip --default-library=static build
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
  [ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
  #sed -i 's/^LN_S=@LN_S@/& -f -v/' platform.inc.in
  #sed -i '/AC_MSG_CHECKING(for platform specific LDFLAGS\/CFLAGS)/{n;s/.*/SPECIFIC_LDFLAGS="-static"/}' ./configure.in
  #sed -i '/SPECIFIC_LDFLAGS="-static"/{n;s/.*/SPECIFIC_CFLAGS="-static"/}' ./configure.in
  ./bootstrap.sh
  apply_patch file://$PATCH_DIR/xvidcore-1.3.7_static-lib.diff -p0
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
# CMake Warning:
# No source or binary directory provided.  Both will be assumed to be the same as the current working directory,
# but note that this warning will become a fatal error in future CMake releases.

  make -j $jval
  make install
}

build_libaom() {
echo
/bin/echo -e "\e[93m*** Building libaom ***\e[39m"
echo
  cd $BUILD_DIR/aom-*
  [ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
  mkdir -pv aom_build
  cd aom_build
  cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="$TARGET_DIR" -DBUILD_SHARED_LIBS=0 ..
  make -j $jval
  make install
}

### ffmpeg

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
    --extra-version=Tec-7.1.0 \
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
#    --enable-liblensfun \

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
    --extra-version=Tec-7.1.0 \
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
echo -en "\007"
#yasm
build_asciidoc #wants docbook-xsl-1.79.2, fop-2.5, libxslt-1.1.34, Lynx-2.8.9rel.1, dblatex, and W3m
build_nasm #wants asciidoc-9.0.4 and xmlto-0.0.28
#meson
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
build_glib #wants python, iconv, zlib, libffi, libmount, libFAM, libELF, gtk-doc
build_OpenSSL_RTMP # Should be before Python. Wants ZLIB
build_librtmp # wants old openssl, 1.0.2u works
#build_OpenSSL # Should be before Python. Wants ZLIB
#######build_autoconf
#######build_automake
build_libcdio #wants icovn, ncurses, libvcd
build_libcdio_paranoia #wants libcdio
build_vcdimager #wants libpopt, libcdio, libiso9660, libxml
rebuild_libcdio #wants icovn, ncurses, libvcd
}

adeps() {
echo -en "\007"
build_libmysofa # wants zlib
build_ALSAlib # need to fix for libflite
build_voamrwbenc #
build_opencoreamr #
build_fdkaac #
build_mp3lame #wants ncurses, iconv. GTK
build_opus #
build_libsoxr #
build_libflite # wants alsa
build_libsnappy # wants zlib
build_vamp_plugin #
build_fftw # wants f77 compiler
build_libogg # 
build_libflac # wants ogg, XMMS
build_libvorbis # needs ogg
build_libspeexdsp
build_libspeex # needs libspeexdsp
build_libsndfile # wants flac, ogg, speex, vorbis, opus, sqlite3, alsa
        ##checking for libmpg123 >= 1.25.10 ... no
	##configure: WARNING: "MPEG support selected but external MPG123 library cannot be found.
	##configure: WARNING: *** MPEG support disabled.
build_libsamplerate # wants libsndfile, alsa, fftw3
build_librubberband # wants libsndfile, fftw, samplerate
build_libtwolame # wants libsndfile
build_libtheora # needs ogg, wants vorbis, png
#build_PulseAudio #Doesn't work yet
#sdl1
}

pdeps() {
echo -en "\007"
build_GIFlib #
build_libjpegturbo #
build_libPNG #wants zlib
build_libwebp #wants giflib, jpeg, libtiff, wic, sdl, png, glut, opengl
build_libTIFF #wants lzw, zlib, jpeg, jbig, lzma, zstd, webp, glut, opengl
rebuild_libwebp #wants giflib, jpeg, libtiff, wic, sdl, png, glut, opengl
##utilmacros
##xorgproto
build_libXML #wants iconv, icu, lzma, zlib
build_openjpeg #
build_lensfun #wants glib
build_zimg #
}

tdeps() {
echo -en "\007"
build_FreeType2 #wants harfbuzz, zlib, linpng, bzip2
build_FontConfig #wants iconv, freetype2, expat, XML, jsonc
build_harfbuzz #wants glib, icu, freetype2, cairo, fontconfig, graphite2, coretext, directwrite, GDI, uniscribe
#rebuild_FreeType2 # causes imlib2 build, freetype error
build_fribidi # wants c2man (if compiling from git)
build_libass #wants nasm, iconv, FreeType2, fribidi, FontConfig, coretext, directwrite, harfbuzz
build_libleptonica #wants zlib, png, jpeg, giflib, libtiff, libwebp
build_libtesseract #wants opencl, tiff, asciidoc, libleptonica, icu, pango, cairo
build_libID3tag #wants zlib,
build_imlib2 #wants freetype, x-libs, jpeg, png, webp, tiff, giflib, zlib, bz2, id3tag
build_libcaca #wants zlib, slang, opencl, ftgl, imlib2, pangoft2, cppunit, zzuf
build_libilbc #
build_frei0r # opencv, gavl, cairo
}

vdeps() {
echo -en "\007"
build_libbluray #wants libxml2, freetype2, fontconfig
build_dav1d #wants nasm, meson, ninja, doxygen, dot
build_Xvid #wants yasm,
build_x264 #
build_x265 #wants numa, nasm
build_libvpx #
build_libvidstab #
build_libaom #
#sdl2
}

alldownloads
[ $download_only -eq 1 ] && exit 0

dp_time=$(date +%H:%M)
echo
echo $dp_time
deps
#echo "Press ENTER to continue" && bash -c read -p

adp_time=$(date +%H:%M)
echo
echo $adp_time
adeps
#echo "Press ENTER to continue" && bash -c read -p

pdp_time=$(date +%H:%M)
echo
echo $pdp_time
pdeps
#echo "Press ENTER to continue" && bash -c read -p

tdp_time=$(date +%H:%M)
echo
echo $tdp_time
tdeps
#echo "Press ENTER to continue" && bash -c read -p

vdp_time=$(date +%H:%M)
echo
echo $vdp_time
vdeps

echo -en "\007"

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
echo -en "\007"
hash -r

