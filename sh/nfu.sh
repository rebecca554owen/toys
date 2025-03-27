#!/bin/bash

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
RESET='\033[0m'

# 定义UserUUID变量
UserUUID=$(jq -r '.UUID' /etc/nfu/config.json)

# 定义OutAreaName,OutArea,OutPort变量
OutAreaName=$(jq -r '.OutArea' /etc/nfu/config.json)
NewOutAreaName=""
OutArea=""
OutPort=""

# 定义NewUUID
NewUUID=""

# 定义NFUVersion
NFUVersion=$(jq -r '.Version' /etc/nfu/version.json)

show_menu() {
    echo ""
    echo -e "${GREEN}NF UNLock 快速配置脚本${RESET}"
    echo ""
    echo -e "${CYAN}使用前请确保您的系统支持 sudo, sed, wget, jq${RESET}"
    echo ""
    echo -e "${BLUE}TG群组: https://t.me/nfdns_group${RESET}"
    echo -e "${BLUE}TG频道: https://t.me/nfdns_channel${RESET}"
    echo "————————————————"
    echo -e "${GREEN}[0]${RESET} 退出脚本"
    echo -e "${GREEN}[1]${RESET} 更新脚本"
    echo -e "${GREEN}[2]${RESET} 卸载脚本"
    echo -e "${GREEN}[3]${RESET} 设置UUID"
    echo -e "————${YELLOW}快速配置${RESET}————"
    echo -e "${GREEN}[4]${RESET} x-ui"
    echo -e "${GREEN}[5]${RESET} XrayR"
    echo -e "${GREEN}[6]${RESET} soga"
    echo -e "${GREEN}[7]${RESET} V2bX (Xray)"
    echo -e "${GREEN}[8]${RESET} V2bX (Sing)"
    echo "————————————————"
    echo -e "${GREEN}[9]${RESET} 修改配置"
    echo -e "${GREEN}[10]${RESET} 自动更新配置 ${RED}未支持${RESET}"
    echo "————————————————"
    echo -e "当前版本: ${GREEN}$NFUVersion${RESET}"
    echo -e "您当前的UUID: ${GREEN}$UserUUID${RESET}"
    echo -e "当前选择的地区: ${GREEN}$OutAreaName${RESET}"
    read -p "请输入选择 [数字]: " choice
}

show_services() {
    services=$(jq -r '.[] | .name' /tmp/service-information.json)
    echo -e "${YELLOW}可用服务列表:${RESET}"
    i=1
    while IFS= read -r service; do
        echo -e "${GREEN}[$i]${RESET} $service"
        ((i++))
    done <<< "$services"
    read -p "请输入选择 [数字]: " service_choice
    selected_service=$(jq -r ".[$((service_choice-1))]" /tmp/service-information.json)
    NewOutAreaName=$(echo $selected_service | jq -r '.name')
    OutArea=$(echo $selected_service | jq -r '.domain')
    OutPort=$(echo $selected_service | jq -r '.port')

    sed -i "s/$OutAreaName/$NewOutAreaName/g" /etc/nfu/config.json
    echo -e "${GREEN}您选择了 $OutArea:$OutPort${RESET}"
}

confirm_overwrite() {
    while true; do
        read -p "该操作会覆盖您的部分配置文件，是否进行下一步？[默认y]: " yn
        yn=${yn:-y}  # 如果用户直接回车，设置默认值为 'y'
        case $yn in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "请输入 y 或 n.";;
        esac
    done
}

UpdateNFU() {
    wget -O /usr/bin/nfu https://config.nfdns.xyz/nfu_sh/nfu.sh
    wget -O /etc/nfu/version.json https://config.nfdns.xyz/nfu_sh/version.json
    chmod +x /usr/bin/nfu
    # 刷新变量内容
    NFUVersion=$(jq -r '.Version' /etc/nfu/version.json)
    echo -e "${GREEN}更新完成 当前版本: $NFUVersion${RESET}"
}


XrayRConfig() {
    echo -e "${GREEN}您选择了 XrayR${RESET}"
    # 下载服务信息文件
    sudo wget -O /tmp/service-information.json https://config.nfdns.xyz/service-information.json
    if [ $? -eq 0 ]; then
        show_services
    else
        echo -e "${RED}无法下载服务信息文件，请检查您的网络连接${RESET}"
    fi

    if confirm_overwrite; then
        # 下载配置文件
        sudo wget -O /etc/XrayR/route.json https://config.nfdns.xyz/nfu_sh/config/xrayr/route.json
        sudo wget -O /etc/XrayR/custom_outbound.json https://config.nfdns.xyz/nfu_sh/config/xrayr/custom_outbound.json

        echo -e "${GREEN}文件已下载到 /etc/XrayR 目录下${RESET}"
        
        # 修改配置文件
        sudo sed -i 's|# /etc/XrayR/route.json|/etc/XrayR/route.json|' /etc/XrayR/config.yml
        sudo sed -i 's|# /etc/XrayR/custom_outbound.json|/etc/XrayR/custom_outbound.json|' /etc/XrayR/config.yml
        sudo sed -i "s/{UUID}/$UserUUID/g" /etc/XrayR/custom_outbound.json
        sudo sed -i "s/{Out}/$OutArea/g" /etc/XrayR/custom_outbound.json
        sudo sed -i "s/{OutPort}/$OutPort/g" /etc/XrayR/custom_outbound.json
        # 重启 XrayR
        sudo xrayr restart

        # 输出选择的出口信息
        echo -e "${GREEN}配置的出口信息: ${OutArea}:${OutPort}${RESET}"
        echo ""

        nfu

        exit 0
    else
        echo -e "${RED}操作已取消${RESET}" && sleep 1
    fi
}

V2bXxrayConfig() {
    echo -e "${GREEN}您选择了 V2bX (xray)${RESET}"
    # 下载服务信息文件
    sudo wget -O /tmp/service-information.json https://config.nfdns.xyz/service-information.json
    if [ $? -eq 0 ]; then
        show_services
    else
        echo -e "${RED}无法下载服务信息文件，请检查您的网络连接${RESET}"
    fi

    if confirm_overwrite; then
        # 下载配置文件
        sudo wget -O /etc/V2bX/route.json https://config.nfdns.xyz/nfu_sh/config/xrayr/route.json
        sudo wget -O /etc/V2bX/custom_outbound.json https://config.nfdns.xyz/nfu_sh/config/xrayr/custom_outbound.json

        echo -e "${GREEN}文件已下载到 /etc/V2bX 目录下${RESET}"
        
        # 修改配置文件
        sudo sed -i "s/{UUID}/$UserUUID/g" /etc/V2bX/custom_outbound.json
        sudo sed -i "s/{Out}/$OutArea/g" /etc/V2bX/custom_outbound.json
        sudo sed -i "s/{OutPort}/$OutPort/g" /etc/V2bX/custom_outbound.json
        # 重启 V2bX
        sudo v2bx restart

        # 输出选择的出口信息
        echo -e "${GREEN}配置的出口信息: ${OutArea}:${OutPort}${RESET}"
        echo ""

        nfu

        exit 0
    else
        echo -e "${RED}操作已取消${RESET}" && sleep 1
    fi
}

V2bXsingConfig() {
    echo -e "${GREEN}您选择了 V2bX (sing)${RESET}"
    # 下载服务信息文件
    sudo wget -O /tmp/service-information.json https://config.nfdns.xyz/service-information.json
    if [ $? -eq 0 ]; then
        show_services
    else
        echo -e "${RED}无法下载服务信息文件，请检查您的网络连接${RESET}"
    fi

    if confirm_overwrite; then
        # 下载配置文件
        sudo wget -O /etc/V2bX/sing_origin.json https://config.nfdns.xyz/nfu_sh/config/v2bx/sing_origin.json

        echo -e "${GREEN}文件已下载到 /etc/V2bX 目录下${RESET}"
        
        # 修改配置文件
        sudo sed -i "s/{UUID}/$UserUUID/g" /etc/V2bX/sing_origin.json
        sudo sed -i "s/{Out}/$OutArea/g" /etc/V2bX/sing_origin.json
        sudo sed -i "s/{OutPort}/$OutPort/g" /etc/V2bX/sing_origin.json
        # 重启 V2bX
        sudo v2bx restart

        # 输出选择的出口信息
        echo -e "${GREEN}配置的出口信息: ${OutArea}:${OutPort}${RESET}"
        echo ""

        nfu

        exit 0
    else
        echo -e "${RED}操作已取消${RESET}" && sleep 1
    fi
}

SogaConfing() {
    echo -e "${GREEN}您选择了 soga${RESET}"
    # 下载服务信息文件
    sudo wget -O /tmp/service-information.json https://config.nfdns.xyz/service-information.json
    if [ $? -eq 0 ]; then
        show_services
    else
        echo -e "${RED}无法下载服务信息文件，请检查您的网络连接${RESET}"
    fi
    
    if confirm_overwrite; then
        # 下载配置文件
        sudo wget -O /etc/soga/routes.toml https://config.nfdns.xyz/nfu_sh/config/soga/routes.toml
        
        echo -e "${GREEN}文件已下载到 /etc/soga 目录下${RESET}"
        
        # 修改配置文件
        sudo sed -i "s/{UUID}/$UserUUID/g" /etc/soga/routes.toml
        sudo sed -i "s/{Out}/$OutArea/g" /etc/soga/routes.toml
        sudo sed -i "s/{OutPort}/$OutPort/g" /etc/soga/routes.toml
        
        #重启 Soga
        sudo soga restart

        # 输出选择的出口信息
        echo -e "${GREEN}配置的出口信息: ${OutArea}:${OutPort}${RESET}"
        echo ""

        nfu

        exit 0
    else
        echo -e "${RED}操作已取消${RESET}" && sleep 1
    fi
}

X_UIConfing() {
    echo -e "${GREEN}您选择了 x-ui${RESET}"
    # 下载服务信息文件
    sudo wget -O /tmp/service-information.json https://config.nfdns.xyz/service-information.json
    if [ $? -eq 0 ]; then
        show_services
    else
        echo -e "${RED}无法下载服务信息文件，请检查您的网络连接${RESET}"
    fi
    
    if confirm_overwrite; then
        # 创建文件夹
        mkdir /etc/nfu/x-ui
        
        # 下载配置文件
        sudo wget --no-check-certificate -O /etc/nfu/x-ui/config.json https://config.nfdns.xyz/nfu_sh/config/x_ui/config.json
        
        echo -e "${GREEN}文件已下载到 /etc/nfu/x-ui/ 目录下${RESET}"
        
        # 修改配置文件
        sudo sed -i "s/{UUID}/$UserUUID/g" /etc/nfu/x-ui/config.json
        sudo sed -i "s/{Out}/$OutArea/g" /etc/nfu/x-ui/config.json
        sudo sed -i "s/{OutPort}/$OutPort/g" /etc/nfu/x-ui/config.json

        # 输出选择的出口信息
        echo -e "${GREEN}配置的出口信息: ${OutArea}:${OutPort}${RESET}"
        
        # 输出教程
        echo ""
        echo ""
        echo -e "${YELLOW}使用教程${RESET}"
        echo -e "${YELLOW}-------------------------------${RESET}"
        echo -e "${YELLOW}登录x-ui面板后依次点击 “面板设置” “xray 相关设置” ${RESET}"
        echo -e "${YELLOW}请将/etc/nfu/x-ui/目录下的config.json文件内容复制到右侧输入框中${RESET}"
        echo -e "${YELLOW}随后依次点击 “保存配置” “重启面板” 即可${RESET}"
        echo ""
        echo -e "${YELLOW}如果 xray 无法运行请尝试升级 xray 到更高版本${RESET}"
        echo ""

        nfu

        exit 0
    else
        echo -e "${RED}操作已取消${RESET}" && sleep 1
    fi
}

# 如果用户输入 nfu xrayr 则快速执行 XrayRConfig
if [ "$1" == "xrayr" ]; then
    XrayRConfig
    exit 0
fi

# 如果用户输入 nfu soga 则快速执行 SogaConfig
if [ "$1" == "soga" ]; then
    SogaConfing
    exit 0
fi

# 如果用户输入 nfu x-ui 则快速执行 X_UIConfig
if [ "$1" == "x-ui" ]; then
    X_UIConfing
    exit 0
fi

# 如果用户输入 nfu v2bx-xray 则快速执行 V2bXxrayConfig
if [ "$1" == "v2bx-xray" ]; then
    V2bXxrayConfig
    exit 0
fi

# 如果用户输入 nfu v2bx-sing 则快速执行 V2bXsingConfig
if [ "$1" == "v2bx-sing" ]; then
    V2bXsingConfig
    exit 0
fi

# 如果用户输入 nfu update 则快速执行升级
if [ "$1" == "update" ]; then
    UpdateNFU
    exit 0
fi

while true; do
    show_menu
    case $choice in
        0)# 退出脚本
            exit 0
            ;;
            
        1)# 更新脚本
            UpdateNFU
            exit 0
            ;;
        
        2)# 卸载脚本
        read -p "确定要卸载吗？[默认n]: " confirm
        confirm=${confirm:-n}  # 如果用户未输入内容，默认值为 'n'
        if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
            sudo rm -f /usr/bin/nfu
            echo -e "${GREEN}已卸载。${RESET}"
        else
            echo -e "${YELLOW}卸载已取消。${RESET}"
        fi
        exit 0
        ;;
            
        3)# 设置 UUID
            # 循环直到用户输入有效的 UUID
            while [ -z "$NewUUID" ]; do
                read -p "请输入您的UUID: " NewUUID
                # 移除可能的控制字符
                NewUUID=$(echo "$NewUUID" | tr -d '\000-\031')
                if [ -z "$NewUUID" ]; then
                    echo -e "${YELLOW}UUID不能为空，请重新输入。${RESET}"
                elif ! [[ "$NewUUID" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
                    echo -e "${YELLOW}UUID格式不正确，请重新输入。${RESET}"
                    NewUUID=""
                fi
            done
            # 使用正确的sed语法替换UUID
            sed -i "s|\"UUID\": *\".*\"|\"UUID\": \"$NewUUID\"|" /etc/nfu/config.json
            echo -e "${GREEN}UUID已成功设置：$NewUUID${RESET}" && sleep 2
            nfu
            exit 0
            ;;

        4)# X-UI
            X_UIConfing
            exit 0
            ;;
            
        5)# XrayR
            XrayRConfig
            exit 0
            ;;
            
        6)# Soga
            SogaConfing
            exit 0
            ;;

        7)# V2bX Xray
            V2bXxrayConfig
            exit 0
            ;;
        
        8)# V2bX sing
            V2bXsingConfig
            exit 0
            ;;

        9)# Edit config.json
            vi /etc/nfu/config.json
            exit 0
            ;;

        *)
            echo ""
            echo -e "${RED}无效的选择，请重试${RESET}" && sleep 2
            ;;
    esac
done
