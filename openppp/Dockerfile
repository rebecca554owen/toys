FROM ghcr.io/rebecca554owen/openppp2:env AS builder
# 设置工作目录
WORKDIR /opt
ENV THIRD_PARTY_LIBRARY_DIR=/opt

# 克隆openppp2仓库，并构建openppp2
RUN git clone --depth=1 https://github.com/liulilittle/openppp2.git $THIRD_PARTY_LIBRARY_DIR/openppp2 && \
    sed -i 's|SET(THIRD_PARTY_LIBRARY_DIR /root/dev)|SET(THIRD_PARTY_LIBRARY_DIR '"$THIRD_PARTY_LIBRARY_DIR"')|' $THIRD_PARTY_LIBRARY_DIR/openppp2/CMakeLists.txt && \
    cd $THIRD_PARTY_LIBRARY_DIR/openppp2 && \
    mkdir build && cd build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release && \
    make -j$(nproc)

# 准备最终镜像
FROM ubuntu:latest

# 设置工作目录
WORKDIR /opt

# 复制构建好的应用到最终镜像
COPY --from=builder /opt/openppp2/bin /opt

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
    netperf \
    tzdata \
    unzip \
    vim && \
    ln -fs /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    dpkg-reconfigure -f noninteractive tzdata && \
    chmod +x /opt/ppp && \
    rm -rf /var/lib/apt/lists/*

# 设置启动脚本为容器启动时运行的命令
ENTRYPOINT ["/opt/ppp"]
