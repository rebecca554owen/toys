FROM alpine:latest

# 设置时区
ENV TZ=Asia/Shanghai

# 复制安装脚本
COPY miaospeed/install.sh /tmp

# 安装依赖并配置环境
RUN apk add --no-cache curl && \
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && \
    echo $TZ > /etc/timezone && \
    chmod +x /tmp/install.sh && \
    sh /tmp/install.sh

# 设置容器入口点
ENTRYPOINT ["/opt/miaospeed"]