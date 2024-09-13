#!/bin/sh

# 从环境变量获取版本号
VERSION="${VERSION:-v1.0.0}"

# 获取系统架构信息
ARCH=$(uname -m)

echo "平台: ${ARCH}"

# 获取系统位数
BITS=$(getconf LONG_BIT)

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

# 设置下载URL
DOWNLOAD_URL="https://github.com/rebecca554owen/toys/releases/download/${VERSION}/openppp2-${ARCH}.zip"

echo "下载地址: ${DOWNLOAD_URL}"

# 下载文件
curl -L "$DOWNLOAD_URL" -o "/opt/openppp2.zip"

# 检查下载是否成功
if [ $? -ne 0 ]; then
  echo "下载失败，请检查下载链接或网络连接。"
  exit 1
fi

# 解压并安装
unzip /opt/openppp2.zip -d /opt/

# 检查解压是否成功
if [ $? -ne 0 ]; then
  echo "解压失败，请检查压缩包是否完整。"
  exit 1
fi

# 设置可执行权限
chmod +x /opt/ppp

echo "openppp2 ${VERSION} 已成功安装到 /opt/ppp"
