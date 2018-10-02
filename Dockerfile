FROM ubuntu:16.04 as build

RUN apt-get update && apt-get install -y \
     build-essential \
     libtool \
     automake \
     git \
     tree \
     rpm \
     libboost-dev \
     libpcap-dev \
     libsndfile1-dev \
     libapr1-dev \
     libspeex-dev \
     liblog4cxx10-dev \
     libace-dev \
     libopus-dev \
     libxerces-c3.1 \
     libxerces-c-dev

RUN git clone --depth 1 https://github.com/havoc83/oreka.git /oreka-src

#build silk dependency
RUN mkdir -p /opt/silk \
  && git clone --depth 1 https://github.com/havoc83/SILKCodec.git /opt/silk/SILKCodec \
  && cd /opt/silk/SILKCodec/SILK_SDK_SRC_FIX \
  && CFLAGS='-fPIC' make all

#make orkbase
WORKDIR /oreka-src/orkbasecxx
RUN  aclocal && libtoolize --force && autoreconf --install\
  && automake --add-missing \
  && make -f Makefile.cvs \
  && ./configure \
  && make \ 
  && make install

#g729
RUN mkdir -p /opt/bcg729 \
  && git clone --depth 1 https://github.com/havoc83/bcg729.git /opt/bcg729 \
  && cd /opt/bcg729 \ 
  && sh ./autogen.sh \
  && CFLAGS=-fPIC ./configure --prefix /usr \ 
  && make \
  && make install

#orkaudio
WORKDIR  /oreka-src/orkaudio
RUN aclocal \
  && libtoolize --force \
  && autoreconf --install \
  && automake -a \
  && make -f Makefile.cvs \
  && ./configure LIBS='-ldl' \
  && make \
  && make install 

FROM ubuntu:16.04 as final
ENV TZ="America/Chicago"
LABEL maintainer="Joseph Havlik"

COPY --from=build /usr/lib/liborkbase.so.0 /usr/lib/liborkbase.so.0
COPY --from=build /usr/lib/libvoip.so /usr/lib/libbcg729.so.0 /usr/lib/
RUN  apt-get update && apt-get install -y --no-install-recommends \
     libace-6.3.3 \
     libxerces-c3.1 \
     liblog4cxx10v5 \
     libspeex1 \
     libc6 \
     libstdc++6 \
     libsndfile1 \
     libgcc1 \
     libicu55 \
     libapr1 \
     libaprutil1 \
     libflac8 \
     libvorbisenc2 \
     libpcap0.8 \
     libuuid1 \
     libexpat1 \
     libogg0 \
     libopus0 \
     libvorbis0a \
     tzdata

COPY --from=build /etc/orkaudio /etc/orkaudio
COPY --from=build /usr/sbin/orkaudio /usr/sbin/orkaudio
COPY --from=build /usr/lib/orkaudio /usr/lib/orkaudio

RUN mkdir -p /var/log/orkaudio \
 && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
 && echo $TZ > /etc/timezone 

CMD ["/usr/sbin/orkaudio", "debug"]
