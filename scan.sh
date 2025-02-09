#!/bin/bash
# 文件名: scan.sh

# 颜色定义
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
RESET='\033[0m'

# 全局配置
CONFIG_FILE="ip_list.txt"
RESULT_FILE="results.txt"
OLLAMA_FILE="ollama.txt"
PORT=11434

# 权限检查
if [ "$(id -u)" != "0" ]; then
    echo -e "${RED}错误：请使用sudo运行此脚本！${RESET}"
    exit 1
fi

# 初始化界面
clear
echo -e "${BLUE}
███████╗ ██████╗ █████╗ ███╗   ██╗
██╔════╝██╔════╝██╔══██╗████╗  ██║
███████╗██║     ███████║██╔██╗ ██║
╚════██║██║     ██╔══██║██║╚██╗██║
███████║╚██████╗██║  ██║██║ ╚████║
╚══════╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═══╝
${RESET}"

# 依赖检查安装
check_dependencies() {
    echo -e "\n${YELLOW}[+] 正在验证系统环境...${RESET}"

    # 安装libpcap-dev
    if ! dpkg -s libpcap-dev >/dev/null 2>&1; then
        echo -e "${YELLOW}[!] 正在安装libpcap-dev...${RESET}"
        apt-get install -y libpcap-dev || {
            echo -e "${RED}依赖安装失败，请手动执行：sudo apt install libpcap-dev${RESET}"
            exit 1
        }
    fi

    # 安装masscan
    if ! command -v masscan &>/dev/null; then
        echo -e "${YELLOW}[!] 正在安装masscan...${RESET}"
        apt-get install -y masscan || {
            echo -e "${RED}依赖安装失败，请手动执行：sudo apt install masscan${RESET}"
            exit 1
        }
    fi

    # 安装curl
    if ! command -v curl &>/dev/null; then
        echo -e "${YELLOW}[!] 正在安装curl...${RESET}"
        apt-get install -y curl || {
            echo -e "${RED}依赖安装失败，请手动执行：sudo apt install curl${RESET}"
            exit 1
        }
    fi

    # 安装jq
    if ! command -v jq &>/dev/null; then
        echo -e "${YELLOW}[!] 正在安装jq...${RESET}"
        apt-get install -y jq || {
            echo -e "${RED}依赖安装失败，请手动执行：sudo apt install jq${RESET}"
            exit 1
        }
    fi

    echo -e "${GREEN}[√] 所有依赖已安装，环境验证通过${RESET}"
}

# IP验证函数
validate_ip() {
    local ip_cidr=$1
    [[ $ip_cidr =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}(/[0-9]{1,2})?$ ]] || return 1
    
    IFS='/.' read -ra parts <<< "$ip_cidr"
    for i in {0..3}; do
        [ "${parts[$i]}" -gt 255 ] && return 1
    done
    [ -n "${parts[4]}" ] && [ "${parts[4]}" -gt 32 ] && return 1
    
    return 0
}

# 流程化操作
start_workflow() {
    # 清空旧配置
    > "$CONFIG_FILE"

    # 输入IP段
    echo -e "\n${BLUE}==== 步骤1/3：输入目标IP范围 ====${RESET}"
    echo -e "格式示例：\n192.168.1.0/24\n10.0.0.1"
    echo -e "（输入空行结束）\n"
    
    while read -r -p "IP/CIDR > " input; do
        [ -z "$input" ] && break
        if validate_ip "$input"; then
            echo "$input" >> "$CONFIG_FILE"
            echo -e "${GREEN}+ 已添加 $input${RESET}"
        else
            echo -e "${RED}! 无效格式 $input${RESET}"
        fi
    done

    # 设置端口
    echo -e "\n${BLUE}==== 步骤2/3：设置扫描端口 ====${RESET}"
    read -p "请输入端口号（默认11434）: " port_input
    PORT=${port_input:-11434}
    [[ $PORT =~ ^[0-9]+$ ]] && [ $PORT -le 65535 ] || {
        echo -e "${RED}非法端口，已重置为11434${RESET}"
        PORT=11434
    }

    # 确认扫描
    echo -e "\n${BLUE}==== 步骤3/3：扫描确认 ====${RESET}"
    echo -e "扫描目标："
    cat "$CONFIG_FILE" | sed 's/^/• /'
    echo -e "扫描端口：${GREEN}$PORT${RESET}"
    echo -e "结果文件：${YELLOW}$RESULT_FILE${RESET}"
    
    read -p "是否立即开始扫描？(y/n): " confirm
    [[ $confirm =~ ^[Yy]$ ]] || return

    # 执行扫描
    echo -e "\n${GREEN}[+] 扫描启动时间: $(date +'%Y-%m-%d %H:%M:%S')${RESET}"
    masscan --exclude 255.255.255.255 \
            -p"$PORT" \
            --max-rate 5000 \
            --append-output \
            -oG "$RESULT_FILE" \
            -iL "$CONFIG_FILE"

    # 结果查看
    echo -e "\n${GREEN}[√] 扫描完成！输入以下命令查看结果："
    echo -e "查看全部结果：${YELLOW}cat $RESULT_FILE${RESET}"
    echo -e "过滤有效结果：${YELLOW}grep 'open' $RESULT_FILE${RESET}"
}

# 快捷功能菜单
quick_menu() {
    while true; do
        echo -e "\n${BLUE}==== 快捷菜单 ====${RESET}"
        echo "1. 开始新的扫描"
        echo "2. 处理扫描结果"
        echo "3. 清空历史数据"
        echo "4. 退出系统"
        echo -e "${BLUE}================${RESET}"

        read -p "请选择 (1-4): " choice
        case $choice in
            1) start_workflow ;;
            2) process_results ;;
            3) clear_data ;;
            4) exit 0 ;;
            *) echo -e "${RED}无效输入！${RESET}" ;;
        esac
    done
}

# 处理扫描结果
process_results() {
    echo -e "\n${BLUE}==== 结果处理 ====${RESET}"
    if [ -s "$RESULT_FILE" ]; then
        echo -e "${GREEN}正在验证最新扫描结果...${RESET}"
        > "$OLLAMA_FILE"
        while read -r ip; do
            url="http://$ip:$PORT/api/tags"
            if curl --max-time 2 -s "$url" | grep -q '"models"'; then
                echo "$url" >> "$OLLAMA_FILE"
                echo -e "${GREEN}[√] 服务可用: $url${RESET}"
                # 获取并显示模型信息
                RESPONSE=$(curl --max-time 2 -s "$url")
                echo -e "支持的模型："
                MODEL_NAMES=$(echo "$RESPONSE" | jq -r '.models[].name')
                echo "$MODEL_NAMES" | sed 's/^/  /'
                # 将模型名称写入文件
                while read -r model; do
                    echo "$model" >> "$OLLAMA_FILE"
                done <<< "$MODEL_NAMES"
            else
                echo -e "${RED}[×] 连接失败: $url${RESET}"
            fi
        done < <(grep 'open' "$RESULT_FILE" | awk '{print $4}' | tail -n10)
        
        echo -e "\n${GREEN}最新10条成功结果：${RESET}"
        tail -n10 "$OLLAMA_FILE" | sed 's/^/  /'
        echo -e "\n可用服务列表：${YELLOW}cat $OLLAMA_FILE${RESET}"
    else
        echo -e "${YELLOW}暂无需要处理的扫描结果${RESET}"
    fi
}

# 清空数据
clear_data() {
    while true; do
        echo -e "\n${BLUE}==== 清空选项 ====${RESET}"
        echo "1. 清空IP列表"
        echo "2. 清空扫描结果"
        echo "3. 清空服务列表"
        echo "4. 清空所有数据"
        echo "5. 返回主菜单"
        echo -e "${BLUE}================${RESET}"
        
        read -p "请选择 (1-5): " choice
        case $choice in
            1) > "$CONFIG_FILE"; echo -e "${GREEN}IP列表已清空！${RESET}" ;;
            2) > "$RESULT_FILE"; echo -e "${GREEN}扫描结果已清空！${RESET}" ;;
            3) > "$OLLAMA_FILE"; echo -e "${GREEN}服务列表已清空！${RESET}" ;;
            4) 
                > "$CONFIG_FILE"
                > "$RESULT_FILE"
                > "$OLLAMA_FILE"
                echo -e "${GREEN}所有数据已清空！${RESET}"
                ;;
            5) return ;;
            *) echo -e "${RED}无效输入！${RESET}" ;;
        esac
    done
}

# 主程序
check_dependencies
quick_menu
