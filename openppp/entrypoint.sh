#!/bin/sh

chmod +x /opt/ppp
[ -f /opt/io/ppp ] && chmod +x /opt/io/ppp || true
[ -f /opt/simd/ppp ] && chmod +x /opt/simd/ppp || true
[ -f /opt/io-simd/ppp ] && chmod +x /opt/io-simd/ppp || true
[ -f /opt/tc/ppp ] && chmod +x /opt/tc/ppp || true
[ -f /opt/tc-io/ppp ] && chmod +x /opt/tc-io/ppp || true
[ -f /opt/tc-simd/ppp ] && chmod +x /opt/tc-simd/ppp || true
[ -f /opt/tc-io-simd/ppp ] && chmod +x /opt/tc-io-simd/ppp || true

echo "检查版本可用性..."

if [ "$ENABLE_TC" = "true" ] && [ "$ENABLE_SIMD" = "true" ] && [ "$ENABLE_IO" = "true" ] && [ -f /opt/tc-io-simd/ppp ]; then
    echo "检测到TC-IO-SIMD版本且ENABLE_TC/ENABLE_IO/ENABLE_SIMD=true，使用TC-IO-SIMD版本启动"
    exec /opt/tc-io-simd/ppp "$@"
elif [ "$ENABLE_TC" = "true" ] && [ "$ENABLE_SIMD" = "true" ] && [ -f /opt/tc-simd/ppp ]; then
    echo "检测到TC-SIMD版本且ENABLE_TC/ENABLE_SIMD=true，使用TC-SIMD版本启动"
    exec /opt/tc-simd/ppp "$@"
elif [ "$ENABLE_TC" = "true" ] && [ "$ENABLE_IO" = "true" ] && [ -f /opt/tc-io/ppp ]; then
    echo "检测到TC-IO版本且ENABLE_TC/ENABLE_IO=true，使用TC-IO版本启动"
    exec /opt/tc-io/ppp "$@"
elif [ "$ENABLE_TC" = "true" ] && [ -f /opt/tc/ppp ]; then
    echo "检测到TC版本且ENABLE_TC=true，使用TC版本启动"
    exec /opt/tc/ppp "$@"
elif [ "$ENABLE_SIMD" = "true" ] && [ "$ENABLE_IO" = "true" ] && [ -f /opt/io-simd/ppp ]; then
    echo "检测到IO-SIMD版本且ENABLE_SIMD=true，使用IO-SIMD版本启动"
    exec /opt/io-simd/ppp "$@"
elif [ "$ENABLE_SIMD" = "true" ] && [ -f /opt/simd/ppp ]; then
    echo "检测到SIMD版本且ENABLE_SIMD=true，使用SIMD版本启动"
    exec /opt/simd/ppp "$@"
elif [ "$ENABLE_IO" = "true" ] && [ -f /opt/io/ppp ]; then
    echo "检测到IO版本且ENABLE_IO=true，使用IO版本启动"
    exec /opt/io/ppp "$@"
else
    echo "使用标准版本启动"
    exec /opt/ppp "$@"
fi
