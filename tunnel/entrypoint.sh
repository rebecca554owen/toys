#!/bin/sh

# 检查并提示缺少的环境变量
if [ -z "$MODE" ]; then
    echo "缺少 MODE 环境变量。"
    exit 1
fi

if [ -z "$LISTEN_PORT" ]; then
    echo "缺少 LISTEN_PORT 环境变量。"
    exit 1
fi

if [ -z "$PROXY_PASS_TARGET" ]; then
    echo "缺少 PROXY_PASS_TARGET 环境变量。"
    exit 1
fi

if [ -z "$PROXY_PASS_PORT" ]; then
    echo "缺少 PROXY_PASS_PORT 环境变量。"
    exit 1
fi

# 检查 MODE 是否为 in 或 out
if [ "$MODE" != "in" ] && [ "$MODE" != "out" ]; then
    echo "MODE 必须为 'in' 或 'out'。"
    exit 1
fi

# 检查 LISTEN_PORT 是否为有效端口号
if ! echo "$LISTEN_PORT" | grep -Eq '^[0-9]+$' || [ "$LISTEN_PORT" -lt 1 ] || [ "$LISTEN_PORT" -gt 65535 ]; then
    echo "LISTEN_PORT 无效。"
    exit 1
fi

# 检查 PROXY_PASS_PORT 是否为有效端口号
if ! echo "$PROXY_PASS_PORT" | grep -Eq '^[0-9]+$' || [ "$PROXY_PASS_PORT" -lt 1 ] || [ "$PROXY_PASS_PORT" -gt 65535 ]; then
    echo "PROXY_PASS_PORT 无效。"
    exit 1
fi

# 设置 SSL 证书路径，允许通过环境变量自定义
SSL_CERTIFICATE=${SSL_CERTIFICATE:-/etc/nginx/ecc/fullchain.cer}
SSL_CERTIFICATE_KEY=${SSL_CERTIFICATE_KEY:-/etc/nginx/ecc/ecc.key}

# 生成 stream.conf
cat <<EOF > /etc/nginx/tunnel/stream.conf
EOF

if [ "$MODE" = "in" ]; then
    cat <<EOF >> /etc/nginx/tunnel/stream.conf
server {
    listen $LISTEN_PORT reuseport;
    listen [::]:$LISTEN_PORT reuseport;

    proxy_ssl on;
    proxy_ssl_server_name on;

    proxy_ssl_name www.icloud.com;
    proxy_ssl_protocols TLSv1.3;

    proxy_pass $PROXY_PASS_TARGET:$PROXY_PASS_PORT;

    proxy_timeout 10s;
    proxy_connect_timeout 5s;
}
EOF
elif [ "$MODE" = "out" ]; then
    cat <<EOF >> /etc/nginx/tunnel/stream.conf
server {
    listen $LISTEN_PORT ssl reuseport;
    listen [::]:$LISTEN_PORT ssl reuseport;

    ssl_certificate $SSL_CERTIFICATE;
    ssl_certificate_key $SSL_CERTIFICATE_KEY;

    ssl_protocols TLSv1.3;
    ssl_ciphers AES128-GCM-SHA256;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:Tunnel:10m;
    ssl_session_timeout 10m;
    ssl_conf_command Ciphersuites TLS_AES_128_GCM_SHA256;

    proxy_pass $PROXY_PASS_TARGET:$PROXY_PASS_PORT;

    proxy_timeout 10s;
    proxy_connect_timeout 5s;
}
EOF
fi

# 输出启动成功的消息
echo "Nginx 配置生成成功。模式: $MODE, 监听端口: $LISTEN_PORT, 转发目标: $PROXY_PASS_TARGET:$PROXY_PASS_PORT"

if [ "$MODE" = "out" ]; then
    echo "SSL_CERTIFICATE 路径: $SSL_CERTIFICATE"
    echo "SSL_CERTIFICATE_KEY 路径: $SSL_CERTIFICATE_KEY"
fi

# 启动 Nginx
exec "$@"
