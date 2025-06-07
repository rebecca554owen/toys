# 多阶段构建 - 下载阶段
FROM ubuntu:24.04 AS downloader

# 构建参数
ARG VERSION=v2.0.0
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
        wget "https://github.com/rebecca554owen/toys/releases/latest/download/openppp2-${io_suffix}.zip" -O io.zip || echo "跳过不存在的IO版本"; \
    else \
        wget "https://github.com/rebecca554owen/toys/releases/download/${VERSION}/openppp2-${io_suffix}.zip" -O io.zip || echo "跳过不存在的IO版本"; \
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
    fi

# 多阶段构建 - 运行阶段
FROM ubuntu:24.04

# 设置工作目录
WORKDIR /opt

# 环境变量
ENV USE_IO=false

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

# 生成启动脚本并设置执行权限
RUN echo '#!/bin/sh\n\
echo "检查IO版本可用性..."\n\
if [ -f /opt/io/ppp ] && [ "$USE_IO" = "true" ]; then\n\
    echo "检测到IO版本且USE_IO=true，使用IO版本启动"\n\
    exec /opt/io/ppp "$@"\n\
else\n\
    echo "使用标准版本启动"\n\
    exec /opt/ppp "$@"\n\
fi' > /opt/entrypoint.sh \
    && chmod +x /opt/ppp \
    && ( [ -f /opt/io/ppp ] && chmod +x /opt/io/ppp || true ) \
    && chmod +x /opt/entrypoint.sh

# 设置入口点
ENTRYPOINT ["/opt/entrypoint.sh"]
