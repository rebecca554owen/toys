# 准备最终镜像
FROM ubuntu:24.04

# 设置工作目录为/opt
WORKDIR /opt

# 设置版本号和架构
ARG VERSION=v1.0.0
RUN ARCH=$(uname -m) && \
    BITS=$(getconf LONG_BIT) && \
    if [ "$ARCH" = "x86_64" ] && [ "$BITS" = "64" ]; then \
        if [ "$VERSION" = "io" ]; then \
            ARCH="linux-amd64-io-uring"; \
        else \
            ARCH="linux-amd64"; \
        fi; \
    elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then \
        if [ "$VERSION" = "io" ]; then \
            ARCH="linux-aarch64-io-uring"; \
        else \
            ARCH="linux-aarch64"; \
        fi; \
    elif [ "$ARCH" = "armv7l" ]; then \
        ARCH="linux-armv7l"; \
    else \
        echo "不支持的架构: ${ARCH} 位数: ${BITS}"; \
        exit 1; \
    fi && \
    DOWNLOAD_URL="https://github.com/rebecca554owen/toys/releases/download/${VERSION}/openppp2-${ARCH}.zip" && \
    apt-get update && apt-get install -y wget && \
    wget "$DOWNLOAD_URL" -O "/opt/openppp2.zip"

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
    vim && \
    ln -fs /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    dpkg-reconfigure -f noninteractive tzdata && \
    rm -rf /var/lib/apt/lists/* && \
    unzip /opt/openppp2.zip -d /opt/ && \
    chmod +x /opt/ppp && \
    rm /opt/openppp2.zip

# 设置入口点
ENTRYPOINT ["/opt/ppp"]