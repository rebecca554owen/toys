#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# 检查是否为root用户
[[ $EUID -ne 0 ]] && echo -e "${red}错误：${plain} 必须使用root用户运行此脚本！\n" && exit 1

# 定义变量
UserUUID=""

# 检查并安装必要的软件包
install_dependencies() {
    # 检查并安装 sudo
    if ! command -v sudo &> /dev/null; then
        echo -e "${yellow}sudo 未安装，正在安装...${plain}"
        if [ -x "$(command -v apt-get)" ]; then
            apt-get update
            apt-get install -y sudo
        elif [ -x "$(command -v yum)" ]; then
            yum install -y sudo
        fi
    fi

    # 检查并安装 sed
    if ! command -v sed &> /dev/null; then
        echo -e "${yellow}sed 未安装，正在安装...${plain}"
        if [ -x "$(command -v apt-get)" ]; then
            apt-get update
            apt-get install -y sed
        elif [ -x "$(command -v yum)" ]; then
            yum install -y sed
        fi
    fi

    # 检查并安装 wget
    if ! command -v wget &> /dev/null; then
        echo -e "${yellow}wget 未安装，正在安装...${plain}"
        if [ -x "$(command -v apt-get)" ]; then
            apt-get update
            apt-get install -y wget
        elif [ -x "$(command -v yum)" ]; then
            yum install -y wget
        fi
    fi

    # 检查并安装 jq
    if ! command -v jq &> /dev/null; then
        echo -e "${yellow}jq 未安装，正在安装...${plain}"
        if [ -x "$(command -v apt-get)" ]; then
            apt-get update
            apt-get install -y jq
        elif [ -x "$(command -v yum)" ]; then
            yum install -y jq
        fi
    fi
}

install_dependencies

echo -e "${green}开始安装${plain}"

mkdir -p /etc/nfu/

if [ ! -f "/etc/nfu/config.json" ]; then
    wget -O /etc/nfu/config.json https://config.nfdns.xyz/nfu_sh/config.json
    # 循环直到用户输入有效的 UUID
    while [ -z "$UserUUID" ]; do
        read -p "请输入您的UUID: " UserUUID
        # 移除可能的控制字符
        UserUUID=$(echo "$UserUUID" | tr -d '\000-\031')
        if [ -z "$UserUUID" ]; then
            echo -e "${yellow}UUID不能为空，请重新输入。${plain}"
        elif ! [[ "$UserUUID" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
            echo -e "${yellow}UUID格式不正确，请重新输入。${plain}"
            UserUUID=""
        fi
    done
    sed -i "s|\"UUID\": *\".*\"|\"UUID\": \"$UserUUID\"|" /etc/nfu/config.json
else
    echo -e "${yellow}提示：${plain} 文件 /etc/nfu/config.json 已存在，跳过下载。"
fi



wget -O /etc/nfu/version.json https://config.nfdns.xyz/nfu_sh/version.json

wget -O /usr/bin/nfu https://raw.githubusercontents.com/rebecca554owen/toys/main/sh/nfu.sh

chmod +x /usr/bin/nfu

# 定义NFUVersion
NFUVersion=$(jq -r '.Version' /etc/nfu/version.json)

echo -e ""
echo -e "nfu ${green}$NFUVersion${plain} 管理脚本使用方法: "
echo "------------------------------------------"
echo "nfu                    - 显示管理菜单 (功能更多)"
echo "nfu update             - 升级 nfu 脚本"
echo "nfu xrayr              - 快速配置 XrayR"
echo "nfu soga               - 快速配置 soga"
echo "nfu x-ui               - 快速配置 x-ui"
echo "nfu V2bX (xray)        - 快速配置 V2bX (xray)"
echo "nfu V2bX (sing)        - 快速配置 V2bX (sing)"
echo "------------------------------------------"
