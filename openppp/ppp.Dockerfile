# 多阶段构建 - 下载阶段
FROM ubuntu:latest AS downloader

# 构建参数
ARG VERSION=latest
ARG TARGETARCH

# 设置工作目录
WORKDIR /tmp

# 安装下载工具
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    file \
    unzip \
    wget && \
    rm -rf /var/lib/apt/lists/*

# 下载和准备二进制文件
RUN set -ex && \
    # 根据架构设置文件名后缀
    case "${TARGETARCH}" in \
        amd64) \
            normal_suffix="linux-amd64" && \
            io_suffix="linux-amd64-io-uring" ;; \
        arm64) \
            normal_suffix="linux-aarch64" && \
            io_suffix="linux-aarch64-io-uring" ;; \
        *) \
            echo "不支持的架构: ${TARGETARCH}" && \
            exit 1 ;; \
    esac && \
    # 下载正常版本（强制要求存在）
    if [ "${VERSION}" = "latest" ]; then \
        wget "https://github.com/rebecca554owen/toys/releases/latest/download/openppp2-${normal_suffix}.zip" -O normal.zip; \
    else \
        wget "https://github.com/rebecca554owen/toys/releases/download/${VERSION}/openppp2-${normal_suffix}.zip" -O normal.zip; \
    fi && \
    # 尝试下载io版本（可选）
    if [ "${VERSION}" = "latest" ]; then \
        wget "https://github.com/rebecca554owen/toys/releases/latest/download/openppp2-${io_suffix}.zip" -O io.zip || true; \
    else \
        wget "https://github.com/rebecca554owen/toys/releases/download/${VERSION}/openppp2-${io_suffix}.zip" -O io.zip || true; \
    fi && \
    # 尝试下载simd版本（可选） \
    if [ "${VERSION}" = "latest" ]; then \
        wget "https://github.com/rebecca554owen/toys/releases/latest/download/openppp2-${normal_suffix}-simd.zip" -O normal_simd.zip || true; \
        wget "https://github.com/rebecca554owen/toys/releases/latest/download/openppp2-${io_suffix}-simd.zip" -O io_simd.zip || true; \
    else \
        wget "https://github.com/rebecca554owen/toys/releases/download/${VERSION}/openppp2-${normal_suffix}-simd.zip" -O normal_simd.zip || true; \
        wget "https://github.com/rebecca554owen/toys/releases/download/${VERSION}/openppp2-${io_suffix}-simd.zip" -O io_simd.zip || true; \
    fi && \
    # 处理正常版本
    if file normal.zip | grep -q "Zip archive data"; then \
        unzip normal.zip -d /opt && \
        rm normal.zip; \
    else \
        echo "正常版本ZIP文件损坏或格式错误" && \
        exit 1; \
    fi && \
    # 处理io版本（如果存在）
    if [ -f io.zip ]; then \
        if file io.zip | grep -q "Zip archive data"; then \
            mkdir -p /opt/io && \
            unzip io.zip -d /opt/io/ && \
            rm io.zip; \
        else \
            echo "IO版本ZIP文件损坏，已忽略" && \
            rm -f io.zip; \
        fi; \
    fi && \
    # 处理simd版本（如果存在）
    if [ -f normal_simd.zip ]; then \
        if file normal_simd.zip | grep -q "Zip archive data"; then \
            mkdir -p /opt/simd && \
            unzip normal_simd.zip -d /opt/simd/ && \
            rm normal_simd.zip; \
        else \
            echo "SIMD版本ZIP文件损坏，已忽略" && \
            rm -f normal_simd.zip; \
        fi; \
    fi && \
    # 处理io-simd版本（如果存在）
    if [ -f io_simd.zip ]; then \
        if file io_simd.zip | grep -q "Zip archive data"; then \
            mkdir -p /opt/io-simd && \
            unzip io_simd.zip -d /opt/io-simd/ && \
            rm io_simd.zip; \
        else \
            echo "IO-SIMD版本ZIP文件损坏，已忽略" && \
            rm -f io_simd.zip; \
        fi; \
    fi

# 多阶段构建 - 运行阶段
FROM ubuntu:22.04

# 设置工作目录
WORKDIR /opt

# 环境变量
ENV ENABLE_IO=false
ENV ENABLE_SIMD=false

# 安装运行时依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    dnsutils \
    iptables \
    iproute2 \
    iputils-ping \
    lsof \
    net-tools && \
    rm -rf /var/lib/apt/lists/*

# 从下载阶段复制二进制文件
COPY --from=downloader /opt/ /opt/

# 复制启动脚本并设置执行权限
COPY openppp/entrypoint.sh /opt/entrypoint.sh
RUN chmod +x /opt/entrypoint.sh

# 设置入口点
ENTRYPOINT ["/opt/entrypoint.sh"]
