FROM ubuntu:24.04 AS base

ARG DEBIAN_FRONTEND=noninteractive

WORKDIR /opt

RUN apt-get update -y && apt-get install -y --no-install-recommends \
    autoconf \
    automake \
    build-essential \
    ca-certificates \
    clang \
    cmake \
    curl \
    g++ \
    gcc \
    gdb \
    git \
    libicu-dev \
    libkrb5-dev \
    libssl-dev \
    libunwind8 \
    net-tools \
    openssl \
    unzip \
    zip \
    && rm -rf /var/lib/apt/lists/*