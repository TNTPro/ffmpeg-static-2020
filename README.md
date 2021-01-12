FFmpeg non-free static build
===================

*STATUS*: Working

A script to make a static build of ffmpeg for linux, with all the latest codecs (av1 + webm + h264 + vp9 + hevc).
Note: The was forked from zimbatm/ffmpeg-static and then I updated the build-ubuntu.sh & build.sh scripts to add a lot more fuctionality and the env.source file for a bit of restructuring.
It aims to build as much as possible from source, so as to get the latest versions of libs etc. and will compile on clean install of ubuntu 16.04.
I didn't touch any of the other stuff (Docker file etc.) as I know nothing of this stuff and do not have the time to learn. 

The following is from the original instructions, so they are somewhat correct.


Just follow the instructions below. Once you have the build dependencies,
run ./build.sh, wait and you should get the ffmpeg binary in target/bin

Build dependencies
------------------

    # Debian & Ubuntu
    $ apt-get install build-essential curl tar libass-dev libtheora-dev libvorbis-dev libtool cmake automake autoconf

    Ubuntu users can download dependencies and compile in one command:

    $ sudo ./build-ubuntu.sh

    # OS X
    # 1. install XCode
    # 2. install XCode command line tools
    # 3. install homebrew
    # brew install openssl frei0r sdl2

Build & "install"
-----------------

    $ ./build.sh [-j <jobs>] [-B] [-d]
    # ... wait ...
    # binaries can be found in ./target/bin/


If you have built ffmpeg before with `build.sh`, the default behaviour is to keep the previous configuration. If you would like to reconfigure and rebuild all packages, use the `-B` flag. `-d` flag will only download and unpack the dependencies but not build.

NOTE: If you're going to use the h264 presets, make sure to copy them along the binaries. For ease, you can put them in your home folder like this:

    $ mkdir ~/.ffmpeg
    $ cp ./target/share/ffmpeg/*.ffpreset ~/.ffmpeg


Build in docker
---------------

    $ docker build -t ffmpeg-static .
    $ docker run -it ffmpeg-static
    $ ./build.sh [-j <jobs>] [-B] [-d]

The binaries will be created in `/ffmpeg-static-2020/bin` directory.
Method of getting them out of the Docker container is up to you.
`/ffmpeg-static` is a Docker volume.

Debug
-----

On the top-level of the project, run:

    $ . env.source

You can then enter the source folders and make the compilation yourself

    $ cd build/ffmpeg-*
    $ ./configure --prefix=$TARGET_DIR #...
    # ...

Remaining links
---------------

I'm not sure it's a good idea to statically link those, but it probably
means the executable won't work across distributions or even across releases.

    # On Ubuntu 10.04:
    $ ldd ./target/bin/ffmpeg
    not a dynamic executable

    # on OSX 10.6.4:
    $ otool -L ffmpeg
    ffmpeg:
        /usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 125.2.0)

Community, bugs and reports
---------------------------

This repository is community-supported. If you make a useful PR then you will
be added as a contributor to the repo. All changes are assumed to be licensed
under the same license as the project.

License
-------

This project is licensed under the ISC. See the [LICENSE](LICENSE) file for
the legalities.

