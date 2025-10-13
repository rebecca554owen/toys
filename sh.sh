#!/usr/bin/env bash
set -euo pipefail

ARCH="${1:-amd64}"
DOWNLOAD_URL="https://gitee.com/fit2cloud-feizhiyun/1panel-migrator/releases/download/v2.0.10/1panel-migrator-linux-${ARCH}"
TMP_DIR="$(mktemp -d)"
TMP_BIN="${TMP_DIR}/1panel-migrator-linux-${ARCH}"
TARGET_BIN="/usr/local/bin/1panel-migrator"

if ! command -v curl >/dev/null 2>&1; then
  echo "缺少 curl，无法继续。" >&2
  exit 1
fi

printf '>> 下载 1panel-migrator (%s)...\n' "${ARCH}"
if ! curl -fL "${DOWNLOAD_URL}" -o "${TMP_BIN}"; then
  echo "下载失败，请检查架构参数或网络连接。" >&2
  exit 1
fi

printf '>> 授予执行权限...\n'
chmod +x "${TMP_BIN}"

printf '>> 安装到 %s...\n' "${TARGET_BIN}"
sudo install -m 0755 "${TMP_BIN}" "${TARGET_BIN}"

printf '>> 清理临时目录...\n'
rm -rf "${TMP_DIR}"

printf '>> 升级核心服务...\n'
sudo 1panel-migrator upgrade core

cat <<'NOTICE'
请确认 V2 服务已经成功启动后再执行网站升级。
NOTICE

read -r -p "确认继续执行网站升级？(y/N) " answer
if [[ "${answer}" =~ ^[Yy]$ ]]; then
  printf '>> 升级网站...\n'
  sudo 1panel-migrator upgrade website
else
  echo "已取消网站升级操作。"
fi
