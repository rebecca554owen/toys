#!/bin/bash
# 高强度本地双端压测：并发多流大文件 + 小包延迟探针混合循环。
# 目的：把 seq 快速推过回绕点、压出丢帧/重传/teardown 竞态——修复自测一次拉满，
#       别做最小验证就去等 CI/部署（用户 2026-08-23 明确要求）。
#
# 用法: bash stress-local.sh <源URL> <代理端口> [轮数] [并发数]
# 例:
#   # 准备干净源站（garbage.php 会自己断流，不可用作大流量源）:
#   dd if=/dev/zero of=/tmp/1000mb.bin bs=1m count=1000
#   python3 -m http.server 8002 --directory /tmp &   # 后台常驻
#   # 压测: 经隧道 8 轮 × 4 并发 × 1000MB ≈ 32GB
#   bash stress-local.sh http://127.0.0.1:8002/1000mb.bin 7899 8 4
#
# 验收口径:
#   - 全部 par 流 size_download = 源大小 且 exit 0（无截断）
#   - probe 全 204 且 t 稳定
#   - server 日志 grep -c "rtx exhausted" 不增长
SRC=${1:?usage: stress-local.sh <source-url> <proxy-port> [rounds] [parallel]}
PORT=${2:?usage: stress-local.sh <source-url> <proxy-port> [rounds] [parallel]}
ROUNDS=${3:-8}
PAR=${4:-4}

for r in $(seq 1 "$ROUNDS"); do
  echo "=== Round $r/$ROUNDS ==="
  for i in $(seq 1 "$PAR"); do
    curl -s -m 300 -o /dev/null \
      -w "  par$i: %{size_download}B %{speed_download} B/s\n" \
      -x "http://127.0.0.1:$PORT" "$SRC" &
  done
  # 混合小包延迟探针，模拟生产负载形态
  for p in 1 2 3; do
    curl -s -m 15 -o /dev/null \
      -w "  probe$p: %{http_code} t=%{time_total}s\n" \
      -x "http://127.0.0.1:$PORT" https://www.gstatic.com/generate_204
  done
  wait
done
echo "STRESS_DONE rounds=$ROUNDS par=$PAR"
