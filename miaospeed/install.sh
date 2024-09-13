#!/bin/sh

# 获取系统架构信息
ARCH=$(uname -m)

echo "平台: ${ARCH}"

# 获取系统位数
BITS=$(getconf LONG_BIT)

# 获取最新的发布（包括预发布）标签名称
LATEST_TAG=$(curl -s https://api.github.com/repos/AirportR/miaospeed/releases | grep '"tag_name":' | head -n 1 | cut -d '"' -f 4) 

# 判断是否成功获取到标签
if [ -z "$LATEST_TAG" ]; then
  echo "未能获取到最新的发布标签。"
  exit 1
fi

# 根据架构信息设置下载路径
if [ "$ARCH" = "x86_64" ] && [ "$BITS" = "64" ]; then
  echo "架构: linux/amd64"
  ARCH="linux-amd64"
elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
  echo "架构: linux/arm64"
  ARCH="linux-arm64"
elif [ "$ARCH" = "armv7l" ]; then
  echo "架构: linux/arm/v7"
  ARCH="linux-armv7"
elif [ "$ARCH" = "x86_64" ] && [ "$BITS" = "32" ]; then
  echo "架构: linux/386"
  ARCH="linux-386"
else
  echo "不支持的架构: ${ARCH} 位数: ${BITS}"
  exit 1
fi

# 下载最新的发布包（包括预发布）
DOWNLOAD_URL="https://github.com/AirportR/miaospeed/releases/download/${LATEST_TAG}/miaospeed-${ARCH}-${LATEST_TAG}.tar.gz"

echo "下载地址: ${DOWNLOAD_URL}"

curl -L "$DOWNLOAD_URL" -o "/opt/miaospeed.tar.gz"

# 检查下载是否成功
if [ $? -ne 0 ]; then
  echo "下载失败，请检查下载链接或网络连接。"
  exit 1
fi

# 解压并安装
tar -xzf /opt/miaospeed.tar.gz -C /opt/

# 检查解压是否成功
if [ $? -ne 0 ]; then
  echo "解压失败，请检查压缩包是否完整。"
  exit 1
fi

mv /opt/miaospeed-${ARCH} /opt/miaospeed

# 检查移动是否成功
if [ $? -ne 0 ]; then
  echo "移动文件失败，请检查目录权限。"
  exit 1
fi

chmod +x /opt/miaospeed

echo "miaospeed 已成功安装到 /opt/miaospeed"
