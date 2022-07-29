FROM ubuntu:20.04 AS base

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
  make ninja-build gcc g++ git python3-minimal lsb-release wget samba telnet texlive-base texinfo libtool \
  pkg-config autotools-dev automake autoconf libglib2.0-dev libpixman-1-dev bison groff-base libarchive-dev \
  flex cmake clang-12 lld-12 time \
  && rm -rf /var/lib/apt/lists/*

# RUN git config --global http.sslVerify false
# RUN cd /tmp && git clone https://github.com/arichardson/bmake && cd bmake \
#  && ./configure --with-default-sys-path=/usr/local/share/mk --with-machine=amd64 --without-meta --without-filemon --prefix=/usr/local \
#  && sh ./make-bootstrap.sh && make install && rm -rf /tmp/bmake

RUN useradd -ms /bin/sh cheri
COPY --chown=cheri:cheri cheribuild /home/cheri/cheri/cheribuild
COPY --chown=cheri:cheri cheribsd /home/cheri/cheri/cheribsd
COPY --chown=cheri:cheri morello-llvm-project /home/cheri/cheri/morello-llvm-project
COPY --chown=cheri:cheri morello-qemu /home/cheri/cheri/morello-qemu
RUN chown cheri:cheri -R /home/cheri
RUN mkdir /output
RUN chown cheri:cheri -R /output

FROM base AS intermediate
COPY --chown=cheri:cheri cheribuild.json /home/cheri/.config/cheribuild.json
USER cheri
ARG builditems=sdk-morello-purecap
WORKDIR /home/cheri/cheri/cheribuild

RUN ./cheribuild.py $builditems -d && rm -rf /home/cheri/cheri

FROM bitnami/minideb:buster as prod

RUN install_packages libglib2.0-dev libpixman-1-dev bison groff-base libarchive-dev
RUN useradd -ms /bin/sh cheri
USER cheri
COPY --from=intermediate /output /home/cheri
ENV PATH /home/cheri/morello-sdk/bin:$PATH
