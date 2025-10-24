#!/bin/bash

# 全局配置
PPP_DIR="/opt/ppp"
BACKUP_DIR="${PPP_DIR}/backup"
CONFIG_FILE="${PPP_DIR}/appsettings.json"
SERVICE_FILE="/etc/systemd/system/ppp.service"
GITHUB_REPO="rebecca554owen/toys"
DEFAULT_CONFIG_URL="https://raw.githubusercontent.com/liulilittle/openppp2/main/appsettings.json"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# 初始化系统信息
function init_system_info() {
    # 加载OS信息
    if [ -f /etc/os-release ]; then
        . /etc/os-release
    else
        echo -e "${RED}错误: 无法确定操作系统类型${NC}"
        exit 1
    fi

    # 获取系统架构和内核版本
    ARCH=$(uname -m)
    KERNEL_VERSION=$(uname -r | cut -d- -f1)
    echo -e "${GREEN}系统: ${ID} ${VERSION_ID}, 架构: ${ARCH}, 内核: ${KERNEL_VERSION}${NC}"
}

# 安装依赖
function install_dependencies() {
    echo -e "${YELLOW}安装系统依赖...${NC}"
    
    case "$ID" in
        ubuntu|debian)
            apt update && apt install -y file jq screen sudo unzip uuid-runtime wget
            ;;
        *)
            echo -e "${RED}不支持的操作系统: ${ID}${NC}"
            exit 1
            ;;
    esac
}

# 检查IO_URING支持
function check_io_uring_support() {
    local major=$(echo $KERNEL_VERSION | cut -d. -f1)
    local minor=$(echo $KERNEL_VERSION | cut -d. -f2)
    
    # 内核版本 >= 5.10 支持IO_URING
    if [ $major -gt 5 ] || { [ $major -eq 5 ] && [ $minor -ge 10 ]; }; then
        return 0
    else
        return 1
    fi
}

# 获取最新版本
function get_latest_version() {
    local release_info=$(curl -s "https://api.github.com/repos/${GITHUB_REPO}/releases/latest")
    local latest_version=$(echo "$release_info" | jq -r '.tag_name')

    if [ -z "$latest_version" ] || [ "$latest_version" == "null" ]; then
        return 1
    fi

    echo "$latest_version"
}

# 下载和解压PPP
function download_and_extract() {
    local version=$1
    local asset_name=$2
    
    echo -e "${YELLOW}下载版本: ${version} (${asset_name})${NC}"
    
    # 获取下载URL
    local release_info
    if [ "$version" == "$(get_latest_version)" ]; then
        release_info=$(curl -s "https://api.github.com/repos/${GITHUB_REPO}/releases/latest")
    else
        release_info=$(curl -s "https://api.github.com/repos/${GITHUB_REPO}/releases/tags/${version}")
    fi
    
    local download_url=$(echo "$release_info" | jq -r --arg name "$asset_name" '.assets[] | select(.name == $name) | .browser_download_url')
    
    if [ -z "$download_url" ] || [ "$download_url" == "null" ]; then
        echo -e "${RED}无法获取下载链接${NC}"
        return 1
    fi
    
    # 检查系统类型
    if [[ "$ID" != "ubuntu" && "$ID" != "debian" ]]; then
        echo -e "${RED}仅支持Ubuntu和Debian系统${NC}"
        return 1
    fi
    
    # 下载文件
    echo -e "${YELLOW}正在下载: ${download_url}${NC}"
    if ! wget -q --show-progress "$download_url" -O openppp2.zip; then
        echo -e "${RED}下载失败${NC}"
        return 1
    fi
    
    # 验证和解压
    if ! file openppp2.zip | grep -q "Zip archive data"; then
        echo -e "${RED}下载的文件不是有效的ZIP文件${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}解压文件中...${NC}"
    unzip -o openppp2.zip -x 'appsettings.json' && rm -f openppp2.zip
    chmod +x ppp
    
    return 0
}

# 选择下载版本
function select_download_version() {
    local version=$1
    local use_io_uring=$2
    
    # 根据架构确定可用版本
    local assets=()
    if [ "$ARCH" == "x86_64" ]; then
        assets=(
            "openppp2-linux-amd64-io-uring-simd.zip"
            "openppp2-linux-amd64-io-uring.zip"
            "openppp2-linux-amd64-simd.zip"
            "openppp2-linux-amd64.zip"
        )
    elif [ "$ARCH" == "aarch64" ]; then
        assets=(
            "openppp2-linux-aarch64-io-uring-simd.zip"
            "openppp2-linux-aarch64-io-uring.zip"
            "openppp2-linux-aarch64-simd.zip"
            "openppp2-linux-aarch64.zip"
        )
    else
        echo -e "${RED}不支持的架构: ${ARCH}${NC}"
        return 1
    fi
    
    # 显示版本选择菜单
    echo -e "\n${GREEN}请选择要下载的版本类型:${NC}"
    echo "1) IO_URING + SIMD 优化版 (最高性能)"
    echo "2) IO_URING 优化版"
    echo "3) SIMD 优化版"
    echo "4) 标准版"
    echo "0) 取消"

    local choice
    read -p "输入选择 (0-4)，默认 1: " choice
    choice=${choice:-1}
    
    case $choice in
        1) download_and_extract "$version" "${assets[0]}" ;;
        2) download_and_extract "$version" "${assets[1]}" ;;
        3) download_and_extract "$version" "${assets[2]}" ;;
        4) download_and_extract "$version" "${assets[3]}" ;;
        *) return 1 ;;
    esac
    
    return $?
}

# 配置系统服务
function configure_service() {
    local mode=$1
    
    echo -e "${YELLOW}配置系统服务...${NC}"
    
    local exec_start
    local restart_policy
    
    if [ "$mode" == "client" ]; then
        exec_start="/usr/bin/screen -DmS ppp ${PPP_DIR}/ppp --mode=client --tun-host=no"
        restart_policy="no"
    else
        exec_start="/usr/bin/screen -DmS ppp ${PPP_DIR}/ppp --mode=server"
        restart_policy="always"
    fi
    
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=PPP Service with Screen
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=${PPP_DIR}
ExecStart=${exec_start}
Restart=${restart_policy}
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}服务配置失败${NC}"
        return 1
    fi
    
    systemctl daemon-reload
    return 0
}

# 备份配置文件
function backup_ppp() {
    
    # 删除旧的backup文件夹
    if [ -d "$BACKUP_DIR" ]; then
        rm -rf "$BACKUP_DIR"
    fi
    
    # 创建新的backup文件夹
    mkdir -p "$BACKUP_DIR"

    # 复制 ppp和配置文件 到备份目录
    cp ppp "$CONFIG_FILE" "$BACKUP_DIR"

    echo -e "${GREEN}已备份当前目录到: ${BACKUP_DIR}${NC}"
}

# 下载默认配置
function download_default_config() {
    echo -e "${YELLOW}下载默认配置文件...${NC}"
    
    if ! wget -q "$DEFAULT_CONFIG_URL" -O "$CONFIG_FILE"; then
        echo -e "${RED}下载默认配置文件失败${NC}"
        return 1
    fi
    
    return 0
}

# 生成随机GUID
function generate_guid() {
    if command -v uuidgen &> /dev/null; then
        uuidgen
    else
        openssl rand -hex 16 | sed 's/$........$$....$$....$$....$$............$/\1-\2-\3-\4-\5/'
    fi
}

# 初始化配置
function init_config() {

    if [ ! -f "$CONFIG_FILE" ]; then
        if ! download_default_config; then
            return 1
        fi
    fi
    
    # 设置默认值
    local public_ip="::"
    local interface_ip="::"
    local listen_port=2025
    local concurrent=$(nproc)
    local client_guid=$(generate_guid)
    
    declare -A config_changes=(
        [".concurrent"]=${concurrent}
        [".cdn"]="[]"
        [".ip.public"]="${public_ip}"
        [".ip.interface"]="${interface_ip}"
        [".vmem.size"]=0
        [".tcp.listen.port"]=${listen_port}
        [".udp.listen.port"]=${listen_port}
        [".udp.static.\"keep-alived\""]="[1,10]"
        [".udp.static.aggligator"]=0
        [".udp.static.servers"]="[\"${public_ip}:${listen_port}\"]"
        [".websocket.host"]="openppp2.ai"
        [".websocket.path"]="/tun"
        [".websocket.listen.ws"]=2095
        [".websocket.listen.wss"]=2096
        [".server.log"]="/dev/null"
        [".server.mapping"]=true
        [".server.backend"]=""
        [".client.guid"]="{${client_guid}}"
        [".client.server"]="ppp://${public_ip}:${listen_port}/"
        [".client.bandwidth"]=0
        [".client.\"server-proxy\""]=""
        [".client.\"http-proxy\".bind"]="0.0.0.0"
        [".client.\"http-proxy\".port"]=$((listen_port + 1))
        [".client.\"socks-proxy\".bind"]="::"
        [".client.\"socks-proxy\".port"]=$((listen_port + 2))
        [".client.\"socks-proxy\".username"]="admin"
        [".client.\"socks-proxy\".password"]="password"
        [".client.mappings[0].\"local-ip\""]="127.0.0.1"
        [".client.mappings[0].\"local-port\""]=$((listen_port + 3))
        [".client.mappings[0].\"remote-port\""]=$((listen_port + 3))
        [".client.mappings[1].\"local-ip\""]="127.0.0.1"
        [".client.mappings[1].\"local-port\""]=$((listen_port + 4))
        [".client.mappings[1].\"remote-port\""]=$((listen_port + 4))
    )
    
    echo -e "\n正在初始化配置文件..."
    tmp_file=$(mktemp)

    for key in "${!config_changes[@]}"; do
        value=${config_changes[$key]}
        if [[ $value =~ ^\[.*\]$ ]]; then
            if ! jq --argjson val "${value}" "${key} = \$val" "${CONFIG_FILE}" > "${tmp_file}" 2>/dev/null; then
                echo "修改配置项 ${key} 失败"
                rm -f "${tmp_file}"
                return 1
            fi
        elif [[ $value =~ ^[0-9]+$ ]] || [[ $value == "true" ]] || [[ $value == "false" ]]; then
            if ! jq "${key} = ${value}" "${CONFIG_FILE}" > "${tmp_file}" 2>/dev/null; then
                echo "修改配置项 ${key} 失败"
                rm -f "${tmp_file}"
                return 1
            fi
        else
            if ! jq "${key} = \"${value}\"" "${CONFIG_FILE}" > "${tmp_file}" 2>/dev/null; then
                echo "修改配置项 ${key} 失败"
                rm -f "${tmp_file}"
                return 1
            fi
        fi
        mv "${tmp_file}" "${CONFIG_FILE}"
    done
}

# 安装PPP
function install_ppp() {
    install_dependencies
    
    echo -e "${YELLOW}创建安装目录...${NC}"
    mkdir -p "$PPP_DIR"
    cd "$PPP_DIR" || return 1
    
    # 获取版本信息
    echo -e "${YELLOW}获取最新版本信息...${NC}"
    local latest_version=$(get_latest_version)
    if [ -z "$latest_version" ]; then
        echo -e "${RED}获取最新版本失败${NC}"
        return 1
    fi

    echo -e "${GREEN}最新版本: ${latest_version}${NC}"
    
    local version
    read -p "输入要安装的版本 (回车使用最新版本): " version
    version=${version:-$latest_version}
    
    # 选择模式
    echo -e "\n${GREEN}请选择运行模式:${NC}"
    echo "1) 服务端"
    echo "2) 客户端"
    
    local mode_choice
    read -p "输入选择 (1-2)，默认： 服务端 " mode_choice
    mode_choice=${mode_choice:-1}
    
    case $mode_choice in
        1) local mode="server" ;;
        2) local mode="client" ;;
        *) 
            echo -e "${RED}无效选择${NC}"
            return 1
            ;;
    esac
    
    # 选择下载版本
    if ! select_download_version "$version" "$(check_io_uring_support && echo true || echo false)"; then
        return 1
    fi
    
    # 初始化配置
    if ! init_config; then
        return 1
    fi
    
    # 配置服务
    if ! configure_service "$mode"; then
        return 1
    fi
    
    # 启动服务
    systemctl enable ppp.service
    systemctl start ppp.service
    
    echo -e "${GREEN}PPP ${mode} 安装完成!${NC}"
}

# 卸载PPP
function uninstall_ppp() {
    echo -e "${YELLOW}卸载PPP...${NC}"
    
    # 停止服务
    systemctl stop ppp.service 2>/dev/null
    systemctl disable ppp.service 2>/dev/null
    
    # 删除服务文件
    rm -f "$SERVICE_FILE"
    systemctl daemon-reload
    systemctl reset-failed
    
    # 杀死残留进程
    pkill -f "${PPP_DIR}/ppp"
    
    # 删除安装目录
    rm -rf "$PPP_DIR"
    
    echo -e "${GREEN}PPP已完全卸载${NC}"
}

# 服务管理
function manage_service() {
    local action=$1
    
    case $action in
        start)
            systemctl start ppp.service
            echo -e "${GREEN}PPP服务已启动${NC}"
            ;;
        stop)
            systemctl stop ppp.service
            echo -e "${GREEN}PPP服务已停止${NC}"
            ;;
        restart)
            systemctl restart ppp.service
            echo -e "${GREEN}PPP服务已重启${NC}"
            ;;
        status)
            systemctl status ppp.service
            ;;
        *)
            echo -e "${RED}无效操作${NC}"
            return 1
            ;;
    esac
}

# 更新PPP
function update_ppp() {
    echo -e "${YELLOW}更新PPP...${NC}"
    
    if [ ! -d "$PPP_DIR" ]; then
        echo -e "${RED}PPP未安装${NC}"
        return 1
    fi
    
    cd "$PPP_DIR" || return 1
    
    # 获取最新版本号
    echo -e "${YELLOW}获取最新版本信息...${NC}"
    local latest_version=$(get_latest_version)
    if [ -z "$latest_version" ]; then
        echo -e "${RED}获取最新版本失败${NC}"
        return 1
    fi

    echo -e "${GREEN}最新版本: ${latest_version}${NC}"
    
    local version
    read -p "输入要更新的版本 (回车使用最新版本): " version
    version=${version:-$latest_version}
    
    # 停止服务
    systemctl stop ppp.service

    # 备份当前版本
    backup_ppp

    # 下载新版本
    if ! select_download_version "$version" "$(check_io_uring_support && echo true || echo false)"; then
        echo -e "${RED}更新失败, 已恢复备份${NC}"
        cp -a "$BACKUP_DIR"/* "$PPP_DIR/"
        systemctl start ppp.service
        return 1
    fi
    
    # 启动服务
    systemctl start ppp.service
    
    echo -e "${GREEN}PPP已更新到 ${version}${NC}"
}

# 查看会话
function view_session() {
    if ! screen -list | grep -q "ppp"; then
        echo -e "${RED}没有找到PPP会话${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}正在进入PPP会话...${NC}"
    echo -e "${GREEN}提示: 使用 'Ctrl+a d' 退出而不关闭会话${NC}"
    screen -r ppp
}

# 查看配置
function show_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${RED}配置文件不存在${NC}"
        return 1
    fi
    
    echo -e "\n${GREEN}当前配置:${NC}"
    echo "1) 接口IP: $(jq -r '.ip.interface' "$CONFIG_FILE")"
    echo "2) 公网IP: $(jq -r '.ip.public' "$CONFIG_FILE")"
    echo "3) 监听端口: $(jq -r '.tcp.listen.port' "$CONFIG_FILE")"
    echo "4) 并发数: $(jq -r '.concurrent' "$CONFIG_FILE")"
    echo "5) 客户端GUID: $(jq -r '.client.guid' "$CONFIG_FILE")"
    echo "6) key.protocol: $(jq -r '.key.protocol' "$CONFIG_FILE")"
    echo "7) key.transport: $(jq -r '.key.transport' "$CONFIG_FILE")"
}

# 修改配置
function edit_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${RED}配置文件不存在${NC}"
        return 1
    fi
    
    while true; do
        show_config
        
        echo -e "\n${YELLOW}选择要修改的配置项:${NC}"
        echo "1) 修改接口IP"
        echo "2) 修改公网IP"
        echo "3) 修改监听端口"
        echo "4) 修改并发数"
        echo "5) 修改客户端GUID"
        echo "6) 修改key.protocol"
        echo "7) 修改key.transport"
        echo "0) 返回"
        
        local choice
        read -p "输入选择 (0-7), 默认 0: " choice
        choice=${choice:-0}
        
        case $choice in
            0) break ;;
            1|2|3|4|5|6|7)
                modify_config_item "$choice"
                ;;
            *)
                echo -e "${RED}无效选择${NC}"
                ;;
        esac
    done
    
    # 重启服务应用配置
    systemctl restart ppp.service
    echo -e "${GREEN}配置已更新并应用${NC}"
}

# 修改配置项
function modify_config_item() {
    local choice=$1
    
    case $choice in
        1)
            read -p "输入新的接口IP，默认是 :: ,支持同时监听 IPv4/IPv6 协议: " new_value
            new_value=${new_value:-::}
            jq ".ip.interface = \"$new_value\"" "$CONFIG_FILE" > tmp.json && mv tmp.json "$CONFIG_FILE"
            ;;
        2)
            read -p "输入新的公网IP，默认是 :: ,支持同时监听 IPv4/IPv6 协议: " new_value
            new_value=${new_value:-::}
            jq ".ip.public = \"$new_value\"" "$CONFIG_FILE" > tmp.json && mv tmp.json "$CONFIG_FILE"
            ;;
        3)
            read -p "输入新的监听端口，默认 $(date +%Y) : " new_value
            new_value=${new_value:-$(date +%Y)}
            jq ".tcp.listen.port = $new_value | .udp.listen.port = $new_value" "$CONFIG_FILE" > tmp.json && mv tmp.json "$CONFIG_FILE"
            ;;
        4)
            read -p "输入新的并发数，默认 $(nproc): " new_value
            new_value=${new_value:-$(nproc)}
            jq ".concurrent = $new_value" "$CONFIG_FILE" > tmp.json && mv tmp.json "$CONFIG_FILE"
            ;;
        5)
            read -p "输入新的客户端GUID，默认是 $(generate_guid) 生成: " new_value
            new_value=${new_value:-$(generate_guid)}
            jq ".client.guid = \"$new_value\"" "$CONFIG_FILE" > tmp.json && mv tmp.json "$CONFIG_FILE"
            ;;
        6)
            new_value=$(select_crypto_algorithm "key.protocol")
            [ -n "$new_value" ] && jq ".key.protocol = \"$new_value\"" "$CONFIG_FILE" > tmp.json && mv tmp.json "$CONFIG_FILE"
            ;;
        7)
            new_value=$(select_crypto_algorithm "key.transport")
            [ -n "$new_value" ] && jq ".key.transport = \"$new_value\"" "$CONFIG_FILE" > tmp.json && mv tmp.json "$CONFIG_FILE"
            ;;
        *)
            echo -e "${RED}无效选择${NC}"
            return 1
            ;;
    esac
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}修改配置失败${NC}"
        return 1
    fi
    
    echo -e "${GREEN}配置已更新${NC}"
}

# 选择加密算法
function select_crypto_algorithm() {
    local key_name=$1
    
    # 显示提示信息
    echo -e "\n${GREEN}选择 $key_name 加密算法:${NC}" >&2
    echo "1) aes-128-cfb" >&2
    echo "2) aes-256-cfb" >&2
    echo "3) simd-aes-128-cfb" >&2
    echo "4) simd-aes-256-cfb" >&2
    
    local choice
    read -p "输入选择 (1-4)，默认 1: " choice
    choice=${choice:-1}
    
    # 仅返回选择的算法字符串
    case $choice in
        1) echo "aes-128-cfb" ;;
        2) echo "aes-256-cfb" ;;
        3) echo "simd-aes-128-cfb" ;;
        4) echo "simd-aes-256-cfb" ;;
        *) 
            echo -e "${RED}无效选择，使用默认值 aes-128-cfb${NC}" >&2
            echo "aes-128-cfb"
            ;;
    esac
}

# 显示主菜单
function show_menu() {
    while true; do
        echo -e "${GREEN}PPP2 服务管理${NC}"
        echo "1) 安装PPP"
        echo "2) 启动PPP"
        echo "3) 停止PPP"
        echo "4) 重启PPP"
        echo "5) 更新PPP"
        echo "6) 卸载PPP"
        echo "7) 查看PPP"
        echo "8) 查看配置"
        echo "9) 修改配置"
        echo "10) 退出"
        
        local choice
        read -p "请输入选项 (1-10): " choice
        
        case $choice in
            1) install_ppp ;;
            2) manage_service start ;;
            3) manage_service stop ;;
            4) manage_service restart ;;
            5) update_ppp ;;
            6) uninstall_ppp ;;
            7) view_session ;;
            8) show_config ;;
            9) edit_config ;;
            10)
                echo -e "${GREEN}退出脚本${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}无效选项${NC}"
                ;;
        esac
    done
}

# 主入口
clear
# 检查root权限
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}错误: 此脚本需要root权限${NC}"
    exit 1
fi
echo -e "${GREEN}PPP2 管理脚本 版本: ${NC}${RED} v1.0.0 ${NC}"
echo -e "${GREEN}作者: 周宇航${NC}"
init_system_info
show_menu
