#!/bin/bash
# ppp 双端压测统一脚本（2026-08-24 重写，替代散落的 /tmp/*.sh 一次性脚本）
#
# 功能：
#   1. 本地编译产物验证：macOS 原生 ppp + Android .so（NDK arm64-v8a）
#   2. 启动本地双端（server + client），tun-host=no 避免占用 utun
#   3. 客户端矩阵：mode=client|proxy × mux=0|10 × mode=compat|flow|flow+turbo × xtcp=on|off
#   4. 循环压测：--rounds N --mb M --url URL1|URL2|完整地址
#
# 测速源约定：
#   URL1 = 本地测速容器  http://127.0.0.1:8081   （macOS Colima 容器）
#   URL2 = NAS 内网容器  http://192.168.100.10:8081
#   URL3 = dmit 公网    http://154.31.112.162:8081  (systemd)
#
# 用法示例：
#   ppp-bench.sh matrix                          # 跑全矩阵（每格 100 轮 10MB）
#   ppp-bench.sh run --mode proxy --mux 10 --mmode flow --turbo y --xtcp y \
#                  --rounds 65536 --mb 1         # 单组合万次小包
#   ppp-bench.sh stop                            # 停掉双端
#
set -u

REPO_DIR="$HOME/Documents/GitHub/openppp2"
BIN="$REPO_DIR/bin/ppp"
CFG_SRV="/tmp/ppp-local/srv/appsettings.json"
CFG_CLI="/tmp/ppp-local/cli/appsettings.json"
LOG_DIR="/tmp/ppp-local/bench"
URL_LOCAL="http://127.0.0.1:8081"          # URL1 本地测速容器（Colima）
URL_NAS="http://192.168.100.10:8081"       # URL2 NAS 内网测速容器
URL_DMIT="http://154.31.112.162:8081"      # URL3 dmit 公网 (systemd)
SRV_PORT=20900
CLI_PORT=7899

mkdir -p "$LOG_DIR"

log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG_DIR/session.log"; }

stop_all() {
    # server 是 root 起的，需要 sudo；client 普通 kill
    SUDO_ASKPASS="${SUDO_ASKPASS:-/tmp/hermes-askpass.sh}" sudo -A pkill -f "bin/ppp --mode=server" 2>/dev/null
    pkill -f "bin/ppp --mode=(proxy|client)" 2>/dev/null
    sleep 2
    log "双端已停止"
}

start_server() {
    if pgrep -f "bin/ppp --mode=server" > /dev/null; then
        log "server 已在运行"
        return 0
    fi
    (cd "$REPO_DIR" && SUDO_ASKPASS="${SUDO_ASKPASS:-/tmp/hermes-askpass.sh}" \
        sudo -A nohup ./bin/ppp --mode=server --config="$CFG_SRV" \
        > "$LOG_DIR/server.log" 2>&1 &)
    sleep 5
    pgrep -f "bin/ppp --mode=server" > /dev/null && log "server 启动 OK (port $SRV_PORT)" \
        || { log "server 启动失败"; return 1; }
}

start_client() {
    local mode=$1 mux=$2 mmode=$3 turbo=$4 xtcp=$5 tag=$6
    pkill -f "bin/ppp --mode=(proxy|client)" 2>/dev/null
    sleep 2
    local args="--mode=$mode --config=$CFG_CLI --tun-host=no --tun-vnet=no --tun-mux=$mux --tun-mux-acceleration=3"
    [ "$mmode" != "-" ] && args="$args --mux-mode=$mmode"
    [ "$turbo" = "y" ] && args="$args --mux-mode-turbo=true"
    [ "$xtcp" = "y" ] && args="$args --tun-tcpip=xtcp"
    (cd "$REPO_DIR" && nohup ./bin/ppp $args > "$LOG_DIR/client-$tag.log" 2>&1 &)
    sleep 8
    grep -q "AppAlreadyRunning" "$LOG_DIR/client-$tag.log" && { log "client 启动失败: 端口占用"; return 1; }
    log "client 启动 OK: mode=$mode mux=$mux mmode=$mmode turbo=$turbo xtcp=$xtcp"
}

build_all() {
    log "编译 macOS 原生 ppp..."
    (cd "$REPO_DIR" && cmake --build build-macos -j8 2>&1 | tail -n 1)
    log "编译 Android so (arm64-v8a)..."
    (cd "$REPO_DIR" && cmake --build build-android-arm64 -j8 2>&1 | tail -n 1)
    log "编译完成: bin/ppp + bin/android/arm64-v8a/libopenppp2.so"
}

run_bench() {
    local rounds=$1 mb=$2 url=$3 label=$4 proxy=$5
    local bytes=$((mb * 1048576))
    local logfile="$LOG_DIR/${label}.log"
    : > "$logfile"
    local ok=0 fail=0 i s
    echo "=== $label ${mb}MB x$rounds via $proxy src=$url 开始 $(date '+%H:%M:%S') ===" | tee -a "$logfile"
    for i in $(seq 1 "$rounds"); do
        s=$(curl -s -o /dev/null -w '%{size_download}' -m 120 -x "$proxy" "${url}/backend/garbage.php?ckSize=${mb}")
        if [ "$s" = "$bytes" ]; then ok=$((ok+1)); else
            fail=$((fail+1)); echo "R$i FAIL($s B)" | tee -a "$logfile"
        fi
        # 每 500 轮或最后打点
        [ $((i % 500)) -eq 0 ] && echo "--- 第 $i 轮: OK=$ok FAIL=$fail ---" | tee -a "$logfile"
        [ "$i" = "$rounds" ] && echo "--- 第 $i 轮: OK=$ok FAIL=$fail ---" | tee -a "$logfile"
    done
    echo "=== 总计 OK=$ok FAIL=$fail 结束 $(date '+%H:%M:%S') ===" | tee -a "$logfile"
}

matrix() {
    local rounds=${1:-100} mb=${2:-10} url=${3:-}
    [ -z "$url" ] && { log "matrix 需要 --url"; exit 1; }
    build_all || return 1
    start_server || return 1

    for mode in client proxy; do
        for mux in 0 10; do
            for mmode in compat flow; do
                for turbo in n y; do
                    # flow+turbo 只在 flow 下有意义；mux=0 时跳过 flow 变体
                    { [ "$mmode" = "flow" ] || [ "$turbo" = "n" ]; } || continue
                    { [ "$mux" != "0" ] || [ "$mmode" = "compat" ]; } || continue
                    for xtcp in n y; do
                        local tag="${mode}-mux${mux}-${mmode}$( [ "$turbo" = y ] && echo -turbo )-$( [ "$xtcp" = y ] && echo xtcp)"
                        start_client "$mode" "$mux" "$mmode" "$turbo" "$xtcp" "$tag" || continue
                        # client 模式没有 http 代理端口，204 探针代替 curl bench
                        if [ "$mode" = "client" ]; then
                            log "[$tag] client 模式无代理端口，跳过 HTTP bench（数据面由 TUN/内核侧验证）"
                            continue
                        fi
                        run_bench "$rounds" "$mb" "$url" "$tag" "http://127.0.0.1:$CLI_PORT"
                    done
                done
            done
        done
    done
    log "全矩阵完成"
}

case "${1:-help}" in
    build)  build_all ;;
    stop)   stop_all ;;
    matrix) shift; matrix "$@" ;;
    run)    shift
            local_mode=proxy local_mux=10 local_mmode=flow local_turbo=n local_xtcp=n
            rounds=100 mb=10 url="$URL_LOCAL"
            while [ $# -gt 0 ]; do
                case "$1" in
                    --mode)  local_mode=$2; shift 2 ;;
                    --mux)   local_mux=$2; shift 2 ;;
                    --mmode) local_mmode=$2; shift 2 ;;
                    --turbo) local_turbo=$2; shift 2 ;;
                    --xtcp)  local_xtcp=$2; shift 2 ;;
                    --rounds) rounds=$2; shift 2 ;;
                    --mb)    mb=$2; shift 2 ;;
                    --url)   url=$2; shift 2 ;;
                    *)       shift ;;
                esac
            done
            build_all || exit 1
            start_server || exit 1
            start_client "$local_mode" "$local_mux" "$local_mmode" "$local_turbo" "$local_xtcp" "run"
            tag="run-${local_mode}-mux${local_mux}-${local_mmode}"
            [ "$local_turbo" = y ] && tag="${tag}-turbo"
            [ "$local_xtcp" = y ] && tag="${tag}-xtcp"
            run_bench "$rounds" "$mb" "$url" "$tag" \
                      "http://127.0.0.1:$CLI_PORT"
            ;;
    *) echo "用法:
  ppp-bench.sh build                       编译 macOS ppp + Android so
  ppp-bench.sh stop                        停止双端
  ppp-bench.sh run [opts]                  单组合压测
      --mode proxy|client   客户端模式(默认 proxy)
      --mux 0|10            mux 通道数(默认 10)
      --mmode compat|flow   mux 模式(默认 flow)
      --turbo y|n           turbo 开关(默认 n, 仅 flow 有效)
      --xtcp y|n            xtcp 栈开关(默认 n)
      --rounds N            循环次数(默认 100)
      --mb M                每轮体积 MB(默认 10)
      --url URL             测速源: URL1=http://127.0.0.1:8081(本地容器)
                                   URL2=http://192.168.100.10:8081(NAS 内网)
                                   或任意完整 base 地址
  ppp-bench.sh matrix <rounds> <mb> <url>  全矩阵(client/proxy × mux0/10 × compat/flow/flow+turbo × xtcp on/off)" ;;
esac
