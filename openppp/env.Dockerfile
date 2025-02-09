# 准备最终镜像环境
FROM ubuntu:24.04

# 设置工作目录为/opt
WORKDIR /opt

# 安装运行时依赖，并配置系统环境
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    dnsutils \
    iptables \
    iproute2 \
    iputils-ping \
    lsof \
    net-tools \
    tzdata \
    unzip \
    file && \ 
    ln -fs /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    dpkg-reconfigure -f noninteractive tzdata && \
    rm -rf /var/lib/apt/lists/*
