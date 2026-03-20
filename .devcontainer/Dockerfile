FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive

# Kernel build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    bc \
    flex \
    bison \
    libssl-dev \
    libelf-dev \
    libncurses-dev \
    kmod \
    cpio \
    # Device tree and boot image tools
    device-tree-compiler \
    u-boot-tools \
    squashfs-tools \
    p7zip-full \
    # General utilities
    git \
    wget \
    curl \
    ca-certificates \
    file \
    xz-utils \
    python3 \
    rsync \
    && rm -rf /var/lib/apt/lists/*

# Non-root build user
RUN useradd -m -s /bin/bash builder
USER builder
WORKDIR /workspaces/terastation
