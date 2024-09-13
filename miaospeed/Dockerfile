FROM alpine:latest

ENV TZ=Asia/Shanghai

COPY miaospeed/install.sh /tmp

RUN apk add --no-cache \
    curl && \
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && \
    echo $TZ > /etc/timezone && \
    chmod +x /tmp/install.sh && \
    sh /tmp/install.sh

ENTRYPOINT ["/opt/miaospeed"]