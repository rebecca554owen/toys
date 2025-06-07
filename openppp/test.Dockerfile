# 准备最终镜像
FROM ubuntu:24.04

# 设置工作目录
WORKDIR /opt

# 环境变量
ENV USE_IO=false

# 安装必要的依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    dnsutils \
    file \
    iptables \
    iproute2 \
    iputils-ping \
    jq \
    lsof \
    net-tools && \
    rm -rf /var/lib/apt/lists/*

# 复制 Openppp2 二进制
COPY openppp/opt/ /opt/

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
