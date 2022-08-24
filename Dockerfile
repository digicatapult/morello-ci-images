# syntax=docker/dockerfile:1.4

FROM ubuntu:20.04 AS base

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
  make ninja-build gcc g++ git python3-minimal lsb-release wget samba telnet texlive-base texinfo libtool \
  pkg-config autotools-dev automake autoconf libglib2.0-dev libpixman-1-dev bison groff-base libarchive-dev \
  flex cmake clang-12 lld-12 time \
  && rm -rf /var/lib/apt/lists/*

RUN <<EOF
  useradd -ms /bin/sh cheri
  mkdir /output
  mkdir /sources
  chown cheri:cheri -R /output /sources
EOF

USER cheri

ARG CHERIBUILD_BRANCH="master"
ARG CLONE_OPTS="--single-branch --recurse-submodules --depth 1 --no-shallow-submodules"
RUN <<EOF
  #!/usr/bin/env bash
  set -ex
  git clone https://github.com/CTSRD-CHERI/cheribuild.git --branch $CHERIBUILD_BRANCH $CLONE_OPTS /sources/cheribuild
EOF

COPY --chown=cheri:cheri extra-files /sources/extra-files

WORKDIR /sources/cheribuild
COPY --chown=cheri:cheri cheribuild.json /sources/cheribuild.json

FROM base AS llvm-build

USER cheri
ARG LLVM_BRANCH="morello/dev"
ARG CLONE_OPTS="--single-branch --recurse-submodules --depth 1 --no-shallow-submodules"
RUN <<EOF
  #!/usr/bin/env bash
  set -ex
  git clone https://git.morello-project.org/morello/llvm-project.git --branch $LLVM_BRANCH $CLONE_OPTS /sources/morello-llvm-project
  ./cheribuild.py morello-llvm-native --config-file /sources/cheribuild.json
  rm -rf /sources/morello-llvm-project
EOF

FROM llvm-build AS qemu-build

USER cheri
ARG QEMU_BRANCH="qemu-morello-merged"
ARG CLONE_OPTS="--single-branch --recurse-submodules --depth 1 --no-shallow-submodules"
RUN <<EOF
  #!/usr/bin/env bash
  set -ex
  git clone https://github.com/CTSRD-CHERI/qemu.git --branch $QEMU_BRANCH $CLONE_OPTS /sources/morello-qemu
  ./cheribuild.py qemu --config-file /sources/cheribuild.json
  rm -rf /sources/morello-qemu
EOF

FROM qemu-build as bsd-build

USER cheri
ARG CHERIBSD_BRANCH="caprevoke"
ARG CLONE_OPTS="--single-branch --recurse-submodules --depth 1 --no-shallow-submodules"
RUN <<EOF
  #!/usr/bin/env bash
  set -ex
  git clone https://github.com/CTSRD-CHERI/cheribsd.git --branch $CHERIBSD_BRANCH $CLONE_OPTS /sources/cheribsd
  ./cheribuild.py cheribsd-morello-purecap --config-file /sources/cheribuild.json
  rm -rf /sources/morello-qemu
  ./cheribuild.py disk-image-minimal-morello-purecap --config-file /sources/cheribuild.json
EOF

FROM ubuntu:20.04 as prod

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y libglib2.0-dev libpixman-1-dev bison groff-base libarchive-dev make && rm -rf /var/lib/apt/lists/*
RUN useradd -ms /bin/sh cheri
USER cheri
COPY --chown=cheri:cheri --from=bsd-build /output /home/cheri
ENV PATH /home/cheri/morello-sdk/bin:$PATH
ENV PATH /home/cheri/sdk/bin:$PATH
