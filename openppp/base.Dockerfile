# 使用Ubuntu 24.04 作为基础镜像
FROM ubuntu:24.04 AS base

# 阻止交互式提示
ARG DEBIAN_FRONTEND=noninteractive

# 设置工作目录
WORKDIR /opt

# 更新系统并安装必要的构建工具和库
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