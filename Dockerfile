FROM lsiobase/alpine:3.8 as buildstage
############## build stage ##############

# package versions
ARG FFMPEG_VER="4.0.2"
ARG LIBMFX_VER="1.23"

# copy patches
COPY patches/ /tmp/patches/

RUN \
 echo http://ftp.yzu.edu.tw/Linux/alpine/latest-stable/main/ > /etc/apk/repositories && \
 echo http://ftp.yzu.edu.tw/Linux/alpine/latest-stable/community/ >> /etc/apk/repositories && \
 echo "**** install build packages ****" && \
 apk add --no-cache --virtual=build-dependencies \
	alsa-lib-dev \
	bzip2-dev \
	coreutils \
	curl \
	g++ \
	gcc \
	git \
	gnutls-dev \
	imlib2-dev \
	jasper-dev \
	jpeg-dev \
	lame-dev \
	lcms2-dev \
	libass-dev \
	libtheora-dev \
	libva-dev \
	libvorbis-dev \
	libvpx-dev \
	libvpx-dev \
	libxfixes-dev \
	make \
	opus-dev \
	perl \
	rtmpdump-dev \
	sdl-dev \
	tar \
	v4l-utils-dev \
	x264-dev \
	x265-dev \
	xvidcore-dev \
	yasm \
	zlib-dev \
	autoconf \
	automake \
	libtool

RUN \
 echo "**** compile libmfx ****" && \
 mkdir -p /tmp/libmfx-src && \
 curl -o \
 /tmp/libmfx.tar.gz -L \
	"https://github.com/lu-zero/mfx_dispatch/archive/${LIBMFX_VER}.tar.gz" && \
 tar xf \
 /tmp/libmfx.tar.gz -C \
	/tmp/libmfx-src --strip-components=1 && \
 cd /tmp/libmfx-src && \
autoreconf -i && \
./configure \
    --prefix='/usr' \
    --enable-static='yes' \
    --enable-shared='no' \
    --enable-fast-install='yes' \
    --with-libva_drm='yes' \
    --with-libva_x11='yes' \
    --with-pic && \
    make -j$(nproc) && \
    make -j$(nproc) install && \
    make -j$(nproc) DESTDIR=/tmp/libmfx-build install

RUN \
 echo "**** compile ffmpeg ****" && \
 mkdir -p /tmp/ffmpeg && \
 curl -o \
 /tmp/ffmpeg-src.tar.bz2 -L \
	"http://ffmpeg.org/releases/ffmpeg-${FFMPEG_VER}.tar.bz2" && \
 tar xf \
 /tmp/ffmpeg-src.tar.bz2 -C \
	/tmp/ffmpeg --strip-components=1 && \
 cd /tmp/ffmpeg && \
 for i in /tmp/patches/*.patch; do patch -p1 -i $i; done && \
 ./configure \
	--disable-debug \
	--disable-static \
	--disable-stripping \
	--enable-avfilter \
	--enable-avresample \
	--enable-gnutls \
	--enable-gpl \
	--enable-libass \
	--enable-libmp3lame \
	--enable-libopus \
	--enable-librtmp \
	--enable-libtheora \
	--enable-libv4l2 \
	--enable-libvorbis \
	--enable-libvpx \
	--enable-libx264 \
	--enable-libx265 \
	--enable-libxcb \
	--enable-libxvid \
	--enable-pic \
	--enable-postproc \
	--enable-pthreads \
	--enable-shared \
	--enable-vaapi \
	--enable-libmfx \
	--enable-encoder=h264_qsv \
	--enable-decoder=h264_qsv \
	--enable-nonfree \
	--prefix=/usr && \
 make -j$(nproc) && \
 gcc -o tools/qt-faststart $CFLAGS tools/qt-faststart.c && \
 make -j$(nproc) doc/ffmpeg.1 doc/ffplay.1 && \
 make -j$(nproc) DESTDIR=/tmp/ffmpeg-build install install-man && \
 install -D -m755 tools/qt-faststart /tmp/ffmpeg-build/usr/bin/qt-faststart

RUN \
 echo "**** compile dcraw ****" && \
 cp /tmp/patches/dcraw.c /tmp/ffmpeg-build/usr/bin/dcraw.c && \
 cd /tmp/ffmpeg-build/usr/bin && \
 gcc -o dcraw -O4 dcraw.c -lm -ljasper -ljpeg -llcms2
############## runtime stage ##############

FROM lsiobase/alpine:3.8

# set version label
ARG BUILD_DATE
ARG VERSION
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="sparklyballs"

# package versions
ARG SERVIIO_VER="1.9.2"

# environment settings
ENV JAVA_HOME="/usr/bin/java"

RUN \
 echo "**** change abc home folder ****" && \
 usermod -a -G root abc && \
 usermod -d /config/serviio abc && \
 echo "**** install runtime packages ****" && \
 apk add --no-cache \
	alsa-lib \
	curl \
	expat \
	gmp \
	gnutls \
	jasper \
	jpeg \
	lame \
	lcms2 \
	libass \
	libbz2 \
	libdrm \
	libffi \
	libgcc \
	libjpeg-turbo \
	libogg \
	libpciaccess \
	librtmp \
	libstdc++ \
	libtasn1 \
	libtheora \
	libva \
	libvorbis \
	libvpx \
	libx11 \
	libxau \
	libxcb \
	libxdamage \
	libxdmcp \
	libxext \
	libxfixes \
	libxshmfence \
	libxxf86vm \
	mesa-gl \
	mesa-glapi \
	nettle \
	openjdk8-jre \
	opus \
	p11-kit \
	sdl \
	ttf-dejavu \
	v4l-utils-libs \
	x264-libs \
	x265 \
	xvidcore \
	libva-intel-driver && \
 echo "**** install serviio app ****" && \
 mkdir -p \
	/app/serviio && \
 curl -o \
 /tmp/serviio.tar.gz -L \
	http://download.serviio.org/releases/serviio-$SERVIIO_VER-linux.tar.gz && \
 tar xf /tmp/serviio.tar.gz -C \
	/app/serviio --strip-components=1 && \
 echo "**** cleanup ****" && \
 rm -rf \
	/tmp/*

# copy files from build stage and local files
COPY --from=buildstage /tmp/ffmpeg-build/usr/ /usr/
COPY --from=buildstage /tmp/libmfx-build/usr/ /usr/
COPY root/ /

# ports and volumes
EXPOSE 23423/tcp 23424/tcp 8895/tcp 1900/udp
VOLUME /config /transcode
