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
    ppp_bin=/opt/tc-io-simd/ppp
elif [ "$ENABLE_TC" = "true" ] && [ "$ENABLE_SIMD" = "true" ] && [ -f /opt/tc-simd/ppp ]; then
    echo "检测到TC-SIMD版本且ENABLE_TC/ENABLE_SIMD=true，使用TC-SIMD版本启动"
    ppp_bin=/opt/tc-simd/ppp
elif [ "$ENABLE_TC" = "true" ] && [ "$ENABLE_IO" = "true" ] && [ -f /opt/tc-io/ppp ]; then
    echo "检测到TC-IO版本且ENABLE_TC/ENABLE_IO=true，使用TC-IO版本启动"
    ppp_bin=/opt/tc-io/ppp
elif [ "$ENABLE_TC" = "true" ] && [ -f /opt/tc/ppp ]; then
    echo "检测到TC版本且ENABLE_TC=true，使用TC版本启动"
    ppp_bin=/opt/tc/ppp
elif [ "$ENABLE_SIMD" = "true" ] && [ "$ENABLE_IO" = "true" ] && [ -f /opt/io-simd/ppp ]; then
    echo "检测到IO-SIMD版本且ENABLE_SIMD=true，使用IO-SIMD版本启动"
    ppp_bin=/opt/io-simd/ppp
elif [ "$ENABLE_SIMD" = "true" ] && [ -f /opt/simd/ppp ]; then
    echo "检测到SIMD版本且ENABLE_SIMD=true，使用SIMD版本启动"
    ppp_bin=/opt/simd/ppp
elif [ "$ENABLE_IO" = "true" ] && [ -f /opt/io/ppp ]; then
    echo "检测到IO版本且ENABLE_IO=true，使用IO版本启动"
    ppp_bin=/opt/io/ppp
else
    echo "使用标准版本启动"
    ppp_bin=/opt/ppp
fi

if [ "$ENABLE_BYPASS" = "true" ]; then
    bypass_country=${BYPASS_COUNTRY:-CN}
    bypass_iplist_path=${BYPASS_IPLIST_PATH:-/opt/ip.txt}
    bypass_refresh=${BYPASS_REFRESH:-true}
    bypass_pull_on_start=${BYPASS_PULL_ON_START:-true}
    bypass_pull_arg="${bypass_iplist_path}<${bypass_country}"
    bypass_pull_mux_mode=
    bypass_pull_mux_mode_next=false

    for arg in "$@"; do
        if [ "$bypass_pull_mux_mode_next" = "true" ]; then
            bypass_pull_mux_mode="$arg"
            break
        fi

        case "$arg" in
            --mux-mode=*)
                bypass_pull_mux_mode=${arg#--mux-mode=}
                break
                ;;
            --mux-mode)
                bypass_pull_mux_mode_next=true
                ;;
        esac
    done

    mkdir -p "$(dirname "$bypass_iplist_path")"

    if [ "$bypass_pull_on_start" = "true" ] || [ ! -s "$bypass_iplist_path" ]; then
        echo "自动分流: 拉取 ${bypass_country} IP 列表到 ${bypass_iplist_path}"
        if [ -n "$bypass_pull_mux_mode" ]; then
            "$ppp_bin" "--mux-mode=${bypass_pull_mux_mode}" --pull-iplist "$bypass_pull_arg"
            bypass_pull_status=$?
        else
            "$ppp_bin" --pull-iplist "$bypass_pull_arg"
            bypass_pull_status=$?
        fi

        if [ "$bypass_pull_status" -ne 0 ]; then
            echo "自动分流: IP 列表拉取失败，继续启动"
        fi
    fi

    set -- "$@" "--bypass=${bypass_iplist_path}"
    if [ "$bypass_refresh" = "true" ]; then
        set -- "$@" "--virr=${bypass_pull_arg}"
    fi
fi

exec "$ppp_bin" "$@"
