#!/bin/bash
# 系统优化脚本
# 作者：周宇航

SCRIPT_VERSION="1.3.0"
SYSCTL_CONF="/etc/sysctl.d/00-bbr.conf"
KCC_REPO_URL="https://github.com/rebecca554owen/kcc.git"
KCC_SRC_DIR="/usr/local/src/kcc"
KCC_PATCH_DIR="$KCC_SRC_DIR/google/patch"

qdisc="fq"
congestion_control="bbr1"
KCC_OFFICIAL_LOW_GAIN_NUM=100
KCC_OFFICIAL_LOW_GAIN_DEN=100
KCC_AGGRESSIVE_LOW_GAIN_NUM=125
KCC_AGGRESSIVE_LOW_GAIN_DEN=100
KCC_HIGH_GAIN_NUM=200
KCC_HIGH_GAIN_DEN=100

get_sysctl_value() {
    sysctl -n "$1" 2>/dev/null || echo "未知"
}

get_available_congestion_controls() {
    get_sysctl_value net.ipv4.tcp_available_congestion_control
}

has_congestion_control() {
    local name=$1
    echo " $(get_available_congestion_controls) " | grep -qw "$name"
}

get_kcc_module_status() {
    if lsmod 2>/dev/null | grep -qw tcp_kcc; then
        echo "已加载"
    elif command -v modinfo >/dev/null 2>&1 && modinfo tcp_kcc >/dev/null 2>&1; then
        echo "已安装未加载"
    else
        echo "未安装"
    fi
}

get_bbr_module_status() {
    if lsmod 2>/dev/null | grep -qw tcp_bbr; then
        echo "已加载"
    elif command -v modinfo >/dev/null 2>&1 && modinfo tcp_bbr >/dev/null 2>&1; then
        echo "已安装未加载"
    else
        echo "未安装"
    fi
}

get_patched_bbr_module_status() {
    if lsmod 2>/dev/null | grep -qw tcp_bbr1; then
        echo "已加载"
    elif command -v modinfo >/dev/null 2>&1 && modinfo tcp_bbr1 >/dev/null 2>&1; then
        echo "已安装未加载"
    else
        echo "未安装"
    fi
}

require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "错误：该操作需要 root 权限，请使用 sudo 或 root 用户运行。"
        return 1
    fi
    return 0
}

require_linux() {
    if [ "$(uname -s)" != "Linux" ]; then
        echo "错误：该脚本仅支持 Linux。"
        return 1
    fi
    return 0
}

# 显示系统信息
get_system_info() {
    local available_controls
    available_controls=$(get_available_congestion_controls)

    echo "====== 系统信息 ======"
    echo "脚本版本: $SCRIPT_VERSION"
    echo "架构: $(uname -m) 内核版本: $(uname -r) 日期: $(date +%Y-%m-%d)"
    echo "当前队列规则: $(get_sysctl_value net.core.default_qdisc)"
    echo "当前拥塞控制: $(get_sysctl_value net.ipv4.tcp_congestion_control)"
    echo "可用拥塞控制: $available_controls"

    if has_congestion_control bbr; then
        echo "BBR 状态: 可用 ($(get_bbr_module_status))"
    else
        echo "BBR 状态: 不可用 ($(get_bbr_module_status))"
    fi

    if has_congestion_control bbr1; then
        echo "补丁 BBR1 状态: 可用 ($(get_patched_bbr_module_status))"
    else
        echo "补丁 BBR1 状态: 不可用 ($(get_patched_bbr_module_status))"
    fi

    if has_congestion_control kcc; then
        echo "KCC 状态: 可用 ($(get_kcc_module_status))"
    else
        echo "KCC 状态: 不可用 ($(get_kcc_module_status))"
    fi
    echo "====================="
}

show_current_scheme() {
    local current_qdisc current_cc available_controls

    current_qdisc=$(get_sysctl_value net.core.default_qdisc)
    current_cc=$(get_sysctl_value net.ipv4.tcp_congestion_control)
    available_controls=$(get_available_congestion_controls)

    echo "====== 当前方案 ======"
    echo "队列规则: $current_qdisc"
    echo "拥塞控制: $current_cc"
    echo "可用算法: $available_controls"
    echo "KCC: $(get_kcc_module_status) | BBR1: $(get_patched_bbr_module_status) | BBR: $(get_bbr_module_status)"
    echo "====================="
}

install_packages() {
    local packages=("$@")

    if command -v apt-get >/dev/null 2>&1; then
        apt-get update
        apt-get install -y "${packages[@]}"
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y "${packages[@]}"
    elif command -v yum >/dev/null 2>&1; then
        yum install -y "${packages[@]}"
    elif command -v pacman >/dev/null 2>&1; then
        pacman -Sy --noconfirm "${packages[@]}"
    elif command -v zypper >/dev/null 2>&1; then
        zypper --non-interactive install "${packages[@]}"
    else
        echo "未识别包管理器，请手动安装: ${packages[*]}"
        return 1
    fi
}

install_build_dependencies() {
    local kernel_release
    kernel_release=$(uname -r)

    if command -v apt-get >/dev/null 2>&1; then
        install_packages git make gcc || return 1
        if ! kernel_build_tree_ready; then
            apt-get install -y "linux-headers-$kernel_release" || true
        fi
    elif command -v dnf >/dev/null 2>&1; then
        install_packages git make gcc kernel-headers || return 1
        if ! kernel_build_tree_ready; then
            dnf install -y "kernel-devel-$kernel_release" || true
        fi
    elif command -v yum >/dev/null 2>&1; then
        install_packages git make gcc kernel-headers || return 1
        if ! kernel_build_tree_ready; then
            yum install -y "kernel-devel-$kernel_release" || true
        fi
    elif command -v pacman >/dev/null 2>&1; then
        install_packages git make gcc linux-headers
    elif command -v zypper >/dev/null 2>&1; then
        install_packages git make gcc kernel-devel kernel-default-devel
    else
        echo "未识别包管理器，请手动安装 git、make、gcc 和当前内核 headers。"
        return 1
    fi
}

install_kernel_update_for_headers() {
    if command -v apt-get >/dev/null 2>&1; then
        install_packages linux-image-amd64 linux-headers-amd64
    elif command -v dnf >/dev/null 2>&1; then
        install_packages kernel kernel-devel kernel-headers
    elif command -v yum >/dev/null 2>&1; then
        install_packages kernel kernel-devel kernel-headers
    elif command -v pacman >/dev/null 2>&1; then
        install_packages linux linux-headers
    elif command -v zypper >/dev/null 2>&1; then
        install_packages kernel-default kernel-devel kernel-default-devel
    else
        echo "未识别包管理器，请手动安装最新内核和对应 headers 后重启。"
        return 1
    fi
}

check_kcc_build_requirements() {
    local missing=0

    for cmd in git make gcc; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo "缺少命令: $cmd"
            missing=1
        fi
    done

    if [ ! -d "/lib/modules/$(uname -r)/build" ]; then
        echo "缺少当前内核构建目录: /lib/modules/$(uname -r)/build"
        missing=1
    fi

    return "$missing"
}

ensure_build_environment() {
    local action_name=$1

    if ! check_kcc_build_requirements; then
        read -p "检测到构建依赖缺失，是否尝试自动安装？[Y/n]: " install_deps
        case $install_deps in
            ""|y|Y)
                install_build_dependencies || {
                    echo "构建依赖安装失败，请手动安装后重试。"
                    return 1
                }
                ;;
            *)
                echo "已取消 $action_name。"
                return 1
                ;;
        esac
    fi

    if ! kernel_build_tree_ready; then
        prompt_kernel_update_if_headers_missing
        return 1
    fi

    if ! check_kcc_build_requirements; then
        echo "构建环境仍不完整，请确认 git、make、gcc 和当前内核 headers 已安装。"
        return 1
    fi
}

kernel_build_tree_ready() {
    [ -d "/lib/modules/$(uname -r)/build" ]
}

prompt_kernel_update_if_headers_missing() {
    if kernel_build_tree_ready; then
        return 0
    fi

    echo "当前运行内核缺少构建目录: /lib/modules/$(uname -r)/build"
    echo "这通常表示当前内核对应 headers 已不在软件源中，或尚未安装。"
    echo "可以安装软件源提供的最新内核和 headers，重启后再回来编译 KCC。"
    read -p "是否安装/更新最新内核和 headers？[Y/n]: " update_kernel
    case $update_kernel in
        ""|y|Y)
            install_kernel_update_for_headers || {
                echo "内核和 headers 更新失败，请手动处理后重试。"
                return 1
            }
            echo "内核和 headers 已安装/更新。"
            echo "请现在重启系统，重启后再次运行脚本并选择对应的“安装/更新”模块选项。"
            read -p "是否立即重启？[y/N]: " reboot_now
            case $reboot_now in
                y|Y)
                    systemctl reboot
                    ;;
                *)
                    echo "已取消立即重启。未重启前无法为当前运行内核编译 KCC。"
                    ;;
            esac
            return 1
            ;;
        *)
            echo "已取消内核和 headers 更新。"
            return 1
            ;;
    esac
}

prepare_kcc_source() {
    mkdir -p "$(dirname "$KCC_SRC_DIR")" || return 1

    if [ -d "$KCC_SRC_DIR/.git" ]; then
        echo "更新 KCC 源码: $KCC_SRC_DIR"
        if git -C "$KCC_SRC_DIR" pull --ff-only; then
            return 0
        fi

        echo "常规 fast-forward 更新失败，尝试对齐远端分支。"
        if [ -n "$(git -C "$KCC_SRC_DIR" status --porcelain --untracked-files=no)" ]; then
            echo "KCC 源码目录存在本地改动，为避免覆盖，请先手动处理: $KCC_SRC_DIR"
            return 1
        fi

        local current_branch upstream_ref
        current_branch=$(git -C "$KCC_SRC_DIR" branch --show-current)
        upstream_ref=$(git -C "$KCC_SRC_DIR" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)
        if [ -z "$upstream_ref" ] && [ -n "$current_branch" ]; then
            upstream_ref="origin/$current_branch"
        fi
        if [ -z "$upstream_ref" ]; then
            upstream_ref="origin/main"
        fi

        git -C "$KCC_SRC_DIR" fetch --prune origin || return 1
        if ! git -C "$KCC_SRC_DIR" rev-parse --verify "$upstream_ref" >/dev/null 2>&1; then
            echo "无法找到远端分支: $upstream_ref"
            return 1
        fi
        git -C "$KCC_SRC_DIR" reset --hard "$upstream_ref"
    else
        echo "克隆 KCC 源码到: $KCC_SRC_DIR"
        rm -rf "$KCC_SRC_DIR"
        git clone "$KCC_REPO_URL" "$KCC_SRC_DIR"
    fi
}

install_module_file() {
    local module_file=$1
    local module_name=$2
    local display_name=$3
    local module_dir="/lib/modules/$(uname -r)/extra"

    if [ ! -f "$module_file" ]; then
        echo "未找到已编译模块: $module_file"
        return 1
    fi

    echo "安装 $display_name 模块到: $module_dir"
    mkdir -p "$module_dir" || return 1
    install -m 0644 "$module_file" "$module_dir/$module_name.ko" || return 1
    depmod "$(uname -r)" || return 1
}

install_kcc_module_file() {
    install_module_file "$KCC_SRC_DIR/tcp_kcc.ko" "tcp_kcc" "KCC"
}

build_kernel_module() {
    local source_dir=$1

    make -C "/lib/modules/$(uname -r)/build" M="$source_dir" clean || return 1
    make -C "/lib/modules/$(uname -r)/build" M="$source_dir" modules
}

reload_congestion_module() {
    local module_name=$1
    local congestion_name=$2
    local old_congestion_control

    old_congestion_control=$(get_sysctl_value net.ipv4.tcp_congestion_control)
    if [ "$old_congestion_control" = "$congestion_name" ] && has_congestion_control cubic; then
        sysctl -w net.ipv4.tcp_congestion_control=cubic || return 1
    fi

    modprobe -r "$module_name" 2>/dev/null || true
    modprobe "$module_name" || return 1

    if [ "$old_congestion_control" = "$congestion_name" ]; then
        sysctl -w "net.ipv4.tcp_congestion_control=$congestion_name" || return 1
    fi
}

install_bbr_module_file() {
    install_module_file "$KCC_PATCH_DIR/tcp_bbr1.ko" "tcp_bbr1" "补丁 BBR"
}

install_bbr_module() {
    require_linux || return 1
    require_root || return 1

    echo "====== 编译/安装/更新补丁 BBR 模块 ======"
    ensure_build_environment "补丁 BBR 安装" || return 1

    prepare_kcc_source || return 1
    if [ ! -d "$KCC_PATCH_DIR" ] || [ ! -f "$KCC_PATCH_DIR/tcp_bbr1.c" ]; then
        echo "未找到补丁 BBR 源码目录: $KCC_PATCH_DIR"
        return 1
    fi

    echo "开始编译补丁 BBR..."
    build_kernel_module "$KCC_PATCH_DIR" || return 1

    install_bbr_module_file || return 1

    echo "加载 tcp_bbr1 模块..."
    if ! reload_congestion_module tcp_bbr1 bbr1; then
        echo "补丁 BBR 模块加载失败。若系统启用了 Secure Boot，可能会阻止未签名模块加载。"
        return 1
    fi

    if has_congestion_control bbr1; then
        echo "补丁 BBR 安装并加载成功。"
        echo
        get_system_info
        return 0
    fi

    echo "补丁 BBR 模块已尝试加载，但系统可用拥塞控制列表中未发现 bbr1。"
    return 1
}

install_kcc_module() {
    require_linux || return 1
    require_root || return 1

    echo "====== 编译/安装/更新 KCC 模块 ======"
    ensure_build_environment "KCC 安装" || return 1

    prepare_kcc_source || return 1

    echo "开始编译 KCC..."
    build_kernel_module "$KCC_SRC_DIR" || return 1

    echo "安装 KCC 模块..."
    install_kcc_module_file || return 1

    echo "加载 tcp_kcc 模块..."
    if ! reload_congestion_module tcp_kcc kcc; then
        echo "KCC 模块加载失败。若系统启用了 Secure Boot，可能会阻止未签名内核模块加载。"
        return 1
    fi

    if has_congestion_control kcc; then
        echo "KCC 安装并加载成功。"
        echo
        get_system_info
        return 0
    fi

    echo "KCC 模块已尝试加载，但系统可用拥塞控制列表中未发现 kcc。"
    return 1
}

ensure_congestion_control_available() {
    local name=$1

    if has_congestion_control "$name"; then
        return 0
    fi

    case $name in
        bbr)
            modprobe tcp_bbr 2>/dev/null || true
            ;;
        bbr1)
            modprobe tcp_bbr1 2>/dev/null || true
            ;;
        kcc)
            modprobe tcp_kcc 2>/dev/null || true
            ;;
    esac

    has_congestion_control "$name"
}

ensure_kcc_ready() {
    if ensure_congestion_control_available kcc; then
        return 0
    fi

    echo "KCC 未安装或未加载，无法直接应用 kcc + fq。"
    read -p "是否立即编译/安装/加载 KCC 模块？[Y/n]: " install_now
    case $install_now in
        ""|y|Y)
            install_kcc_module
            ;;
        *)
            echo "已取消应用 KCC。"
            return 1
            ;;
    esac
}

ensure_bbr_ready() {
    if ensure_congestion_control_available bbr1; then
        return 0
    fi

    echo "BBR1 未安装或未加载，无法直接应用 bbr1。"
    echo "将使用 KCC 仓库 google/patch 目录中的补丁 BBR1 模块。"
    read -p "是否立即编译/安装/加载 BBR1 模块？[Y/n]: " install_now
    case $install_now in
        ""|y|Y)
            install_bbr_module
            ;;
        *)
            echo "已取消应用 BBR1。"
            return 1
            ;;
    esac
}

# 应用优化方案
apply_optimization_menu() {
    local choice

    echo "====== 应用优化方案 ======"
    echo
    echo "推荐:"
    echo "1. kcc + fq (默认)"
    echo
    echo "KCC:"
    echo "2. kcc + cake"
    echo "3. kcc + fq_pie"
    echo
    echo "优化版 BBR:"
    echo "4. bbr1 + fq"
    echo "5. bbr1 + cake"
    echo "6. bbr1 + fq_pie"
    echo
    echo "系统默认 BBR:"
    echo "7. bbr + fq"
    echo "8. bbr + cake"
    echo "9. bbr + fq_pie"
    echo
    echo "0. 返回主菜单"
    read -p "请输入选择 [0-9] (默认1): " choice

    case $choice in
        1|"")
            apply_optimization "fq" "kcc"
            ;;
        2)
            apply_optimization "cake" "kcc"
            ;;
        3)
            apply_optimization "fq_pie" "kcc"
            ;;
        4)
            apply_optimization "fq" "bbr1"
            ;;
        5)
            apply_optimization "cake" "bbr1"
            ;;
        6)
            apply_optimization "fq_pie" "bbr1"
            ;;
        7)
            apply_optimization "fq" "bbr"
            ;;
        8)
            apply_optimization "cake" "bbr"
            ;;
        9)
            apply_optimization "fq_pie" "bbr"
            ;;
        0)
            return 0
            ;;
        *)
            echo "无效选择，使用默认值 kcc + fq"
            apply_optimization "fq" "kcc"
            ;;
    esac
}

apply_optimization() {
    local selected_qdisc=$1
    local selected_congestion_control=$2

    require_linux || return 1
    require_root || return 1

    qdisc=$selected_qdisc
    congestion_control=$selected_congestion_control

    if [ "$congestion_control" = "kcc" ]; then
        ensure_kcc_ready || return 1
    elif [ "$congestion_control" = "bbr1" ]; then
        ensure_bbr_ready || return 1
    elif ! ensure_congestion_control_available "$congestion_control"; then
        echo "拥塞控制算法 $congestion_control 不可用，未写入配置。"
        return 1
    fi

    generate_sysctl_conf
}

is_positive_integer() {
    case "$1" in
        ''|*[!0-9]*)
            return 1
            ;;
        *)
            [ "$1" -gt 0 ]
            ;;
    esac
}

format_kcc_gain() {
    local num=$1
    local den=$2

    if ! is_positive_integer "$num" || ! is_positive_integer "$den"; then
        echo "未知"
        return 0
    fi

    awk -v num="$num" -v den="$den" 'BEGIN { printf "%.2fx", num / den }'
}

get_kcc_runtime_value() {
    local name=$1
    local value

    value=$(sysctl -n "net.kcc.$name" 2>/dev/null || true)
    if [ -z "$value" ]; then
        echo "未知"
    else
        echo "$value"
    fi
}

read_sysctl_conf_value() {
    local key=$1

    [ -f "$SYSCTL_CONF" ] || return 1
    awk -F= -v key="$key" '
        {
            lhs = $1
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", lhs)
        }
        lhs == key {
            rhs = $2
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", rhs)
            print rhs
            found = 1
            exit
        }
        END { if (!found) exit 1 }
    ' "$SYSCTL_CONF"
}

get_kcc_persistent_value() {
    local name=$1
    local key="net.kcc.$name"
    local value

    value=$(read_sysctl_conf_value "$key" 2>/dev/null || true)
    if [ -z "$value" ]; then
        echo "未配置"
    else
        echo "$value"
    fi
}

get_kcc_effective_value() {
    local name=$1
    local default_value=$2
    local key="net.kcc.$name"
    local value

    value=$(read_sysctl_conf_value "$key" 2>/dev/null || true)
    if is_positive_integer "$value"; then
        echo "$value"
        return 0
    fi

    value=$(sysctl -n "$key" 2>/dev/null || true)
    if is_positive_integer "$value"; then
        echo "$value"
        return 0
    fi

    echo "$default_value"
}

show_kcc_gain_line() {
    local label=$1
    local name_num=$2
    local name_den=$3
    local runtime_num runtime_den persistent_num persistent_den

    runtime_num=$(get_kcc_runtime_value "$name_num")
    runtime_den=$(get_kcc_runtime_value "$name_den")
    persistent_num=$(get_kcc_persistent_value "$name_num")
    persistent_den=$(get_kcc_persistent_value "$name_den")

    echo "$label 运行时: $runtime_num/$runtime_den = $(format_kcc_gain "$runtime_num" "$runtime_den")"
    echo "$label 持久化: $persistent_num/$persistent_den = $(format_kcc_gain "$persistent_num" "$persistent_den")"
}

show_kcc_tuning_status() {
    echo "====== KCC 参数 ======"
    show_kcc_gain_line "low_gain " kcc_inflight_low_gain_num kcc_inflight_low_gain_den
    show_kcc_gain_line "high_gain" kcc_inflight_high_gain_num kcc_inflight_high_gain_den
    echo "====================="
}

write_sysctl_conf_value() {
    local key=$1
    local value=$2
    local conf_dir tmp_file

    conf_dir=$(dirname "$SYSCTL_CONF")
    mkdir -p "$conf_dir" || return 1
    touch "$SYSCTL_CONF" || return 1
    tmp_file=$(mktemp "$conf_dir/.bbr-sysctl.XXXXXX") || return 1

    awk -F= -v key="$key" -v value="$value" '
        {
            lhs = $1
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", lhs)
        }
        lhs == key {
            if (!written) {
                print key " = " value
                written = 1
            }
            next
        }
        { print }
        END {
            if (!written) {
                print key " = " value
            }
        }
    ' "$SYSCTL_CONF" > "$tmp_file" || {
        rm -f "$tmp_file"
        return 1
    }

    chmod --reference="$SYSCTL_CONF" "$tmp_file" 2>/dev/null || chmod 0644 "$tmp_file"
    chown --reference="$SYSCTL_CONF" "$tmp_file" 2>/dev/null || true
    mv "$tmp_file" "$SYSCTL_CONF"
}

persist_kcc_tuning() {
    local low_num=$1
    local low_den=$2
    local high_num=$3
    local high_den=$4

    write_sysctl_conf_value net.kcc.kcc_inflight_low_gain_num "$low_num" || return 1
    write_sysctl_conf_value net.kcc.kcc_inflight_low_gain_den "$low_den" || return 1
    write_sysctl_conf_value net.kcc.kcc_inflight_high_gain_num "$high_num" || return 1
    write_sysctl_conf_value net.kcc.kcc_inflight_high_gain_den "$high_den" || return 1
}

apply_kcc_tuning_runtime() {
    local low_num=$1
    local low_den=$2
    local high_num=$3
    local high_den=$4

    if ! ensure_congestion_control_available kcc; then
        echo "KCC 未安装或未加载，当前只完成持久化配置。"
        read -p "是否立即编译/安装/加载 KCC 模块并尝试运行时生效？[y/N]: " install_now
        case $install_now in
            y|Y)
                install_kcc_module || {
                    echo "KCC 模块安装失败；持久化配置已保留。"
                    return 0
                }
                ;;
            *)
                echo "跳过运行时生效；重启或加载 KCC 后会由 sysctl 配置生效。"
                return 0
                ;;
        esac
    fi

    echo "写入 KCC 运行时参数..."
    if sysctl -w \
        "net.kcc.kcc_inflight_low_gain_num=$low_num" \
        "net.kcc.kcc_inflight_low_gain_den=$low_den" \
        "net.kcc.kcc_inflight_high_gain_num=$high_num" \
        "net.kcc.kcc_inflight_high_gain_den=$high_den"; then
        echo "KCC 运行时参数已生效。"
    else
        echo "KCC 运行时参数写入失败；持久化配置已保留，重启或加载 KCC 后再检查。"
    fi
}

apply_kcc_tuning() {
    local low_num=$1
    local low_den=$2
    local high_num=$3
    local high_den=$4

    require_linux || return 1
    require_root || return 1

    if ! is_positive_integer "$low_num" || ! is_positive_integer "$low_den" || \
        ! is_positive_integer "$high_num" || ! is_positive_integer "$high_den"; then
        echo "KCC 参数必须是大于 0 的整数。"
        return 1
    fi

    persist_kcc_tuning "$low_num" "$low_den" "$high_num" "$high_den" || {
        echo "写入 $SYSCTL_CONF 持久配置失败"
        return 1
    }
    echo "KCC 参数已持久化到 $SYSCTL_CONF"

    apply_kcc_tuning_runtime "$low_num" "$low_den" "$high_num" "$high_den"
    show_kcc_tuning_status
}

custom_kcc_low_gain() {
    local low_num low_den high_num high_den

    high_num=$(get_kcc_effective_value kcc_inflight_high_gain_num "$KCC_HIGH_GAIN_NUM")
    high_den=$(get_kcc_effective_value kcc_inflight_high_gain_den "$KCC_HIGH_GAIN_DEN")

    read -p "请输入 low_gain 分子，例如 100/125/150: " low_num
    read -p "请输入 low_gain 分母，例如 100: " low_den

    apply_kcc_tuning "$low_num" "$low_den" "$high_num" "$high_den"
}

kcc_tuning_menu() {
    local choice

    while true; do
        echo "====== KCC 参数调优 ======"
        echo
        echo "说明:"
        echo "  low_gain 控制 KCC 稳态 inflight 下限。"
        echo "  1.0x 更稳，RETR 更低，适合作为通用默认。"
        echo "  1.25x 更激进，可在 BBR/CUBIC 竞争中抢占更多带宽。"
        echo
        show_kcc_tuning_status
        echo
        echo "1. 官方通用稳态：low_gain = 1.0x，降低 RETR"
        echo "2. 激进竞争模式：low_gain = 1.25x，抢占带宽"
        echo "3. 查看当前 KCC 参数"
        echo "4. 自定义 low_gain"
        echo "5. 恢复官方推荐参数"
        echo "0. 返回主菜单"
        read -p "请输入选择 [0-5]: " choice

        case $choice in
            1)
                apply_kcc_tuning "$KCC_OFFICIAL_LOW_GAIN_NUM" "$KCC_OFFICIAL_LOW_GAIN_DEN" "$KCC_HIGH_GAIN_NUM" "$KCC_HIGH_GAIN_DEN"
                ;;
            2)
                apply_kcc_tuning "$KCC_AGGRESSIVE_LOW_GAIN_NUM" "$KCC_AGGRESSIVE_LOW_GAIN_DEN" "$KCC_HIGH_GAIN_NUM" "$KCC_HIGH_GAIN_DEN"
                ;;
            3)
                show_kcc_tuning_status
                ;;
            4)
                custom_kcc_low_gain
                ;;
            5)
                apply_kcc_tuning "$KCC_OFFICIAL_LOW_GAIN_NUM" "$KCC_OFFICIAL_LOW_GAIN_DEN" "$KCC_HIGH_GAIN_NUM" "$KCC_HIGH_GAIN_DEN"
                ;;
            0)
                return 0
                ;;
            *)
                echo "无效选择"
                ;;
        esac
        echo
    done
}

append_kcc_tuning_to_sysctl_conf() {
    local low_num=$1
    local low_den=$2
    local high_num=$3
    local high_den=$4

    [ "$congestion_control" = "kcc" ] || return 0

    cat >> "$SYSCTL_CONF" << EOF
net.kcc.kcc_inflight_low_gain_num = $low_num
net.kcc.kcc_inflight_low_gain_den = $low_den
net.kcc.kcc_inflight_high_gain_num = $high_num
net.kcc.kcc_inflight_high_gain_den = $high_den
EOF
}

# 生成sysctl配置并应用
generate_sysctl_conf() {
    local kcc_low_num kcc_low_den kcc_high_num kcc_high_den

    kcc_low_num=$(get_kcc_effective_value kcc_inflight_low_gain_num "$KCC_OFFICIAL_LOW_GAIN_NUM")
    kcc_low_den=$(get_kcc_effective_value kcc_inflight_low_gain_den "$KCC_OFFICIAL_LOW_GAIN_DEN")
    kcc_high_num=$(get_kcc_effective_value kcc_inflight_high_gain_num "$KCC_HIGH_GAIN_NUM")
    kcc_high_den=$(get_kcc_effective_value kcc_inflight_high_gain_den "$KCC_HIGH_GAIN_DEN")

    cat > "$SYSCTL_CONF" << EOF
# /etc/sysctl.d/00-bbr.conf - BBR/KCC 系统变量配置文件
# 作者：周宇航
# Date: $(date +%Y-%m-%d)

# 内核相关配置
kernel.pid_max = 65535
kernel.panic = 1
kernel.sysrq = 1
kernel.core_pattern = core_%e
kernel.printk = 3 4 1 3
kernel.numa_balancing = 0
kernel.sched_autogroup_enabled = 0

# 虚拟内存相关配置
vm.swappiness = 10
vm.dirty_ratio = 10
vm.dirty_background_ratio = 5
vm.panic_on_oom = 1
vm.overcommit_memory = 1
vm.min_free_kbytes = 90214

# 网络核心参数配置
net.core.netdev_max_backlog = 2000
net.core.rmem_max = 14745600
net.core.wmem_max = 14745600
net.core.rmem_default = 87380
net.core.wmem_default = 65536
net.core.somaxconn = 883
net.core.optmem_max = 65536

# IPv4 TCP 基础参数配置
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_max_tw_buckets = 32768
net.ipv4.tcp_sack = 1
net.ipv4.tcp_fack = 0

# IPv4 TCP 内存和拥塞控制配置
net.ipv4.tcp_rmem = 8192 87380 14745600
net.ipv4.tcp_wmem = 8192 65536 14745600
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_notsent_lowat = 4096
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_adv_win_scale = 4
net.ipv4.tcp_moderate_rcvbuf = 1
net.ipv4.tcp_no_metrics_save = 0

# IPv4 TCP 连接管理参数配置
net.ipv4.tcp_max_syn_backlog = 3533
net.ipv4.tcp_max_orphans = 65536
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 3
net.ipv4.tcp_abort_on_overflow = 0
net.ipv4.tcp_stdurg = 0
net.ipv4.tcp_rfc1337 = 0
net.ipv4.tcp_syncookies = 1

# IPv4 网络参数配置
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.ip_no_pmtu_disc = 0
net.ipv4.route.gc_timeout = 100
net.ipv4.neigh.default.gc_stale_time = 120
net.ipv4.neigh.default.gc_thresh3 = 8192
net.ipv4.neigh.default.gc_thresh2 = 4096
net.ipv4.neigh.default.gc_thresh1 = 1024

# IPv4 ICMP 安全配置
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.arp_announce = 2
net.ipv4.conf.default.arp_announce = 2
net.ipv4.conf.all.arp_ignore = 1
net.ipv4.conf.default.arp_ignore = 1

# IPv6 相关配置
net.ipv6.conf.all.forwarding = 1
net.ipv6.conf.default.forwarding = 1
net.ipv6.conf.lo.forwarding = 1
net.ipv6.conf.all.disable_ipv6 = 0
net.ipv6.conf.default.disable_ipv6 = 0
net.ipv6.conf.lo.disable_ipv6 = 0
net.ipv6.conf.all.accept_ra = 2
net.ipv6.conf.default.accept_ra = 2

# IPv6 路由与邻居参数配置
net.ipv6.neigh.default.gc_thresh1 = 1024
net.ipv6.neigh.default.gc_thresh2 = 4096
net.ipv6.neigh.default.gc_thresh3 = 8192

# 文件系统相关配置
fs.file-max = 1024000
fs.inotify.max_user_instances = 65536

# BBR/KCC 配置
net.core.default_qdisc = $qdisc
net.ipv4.tcp_congestion_control = $congestion_control
EOF
    append_kcc_tuning_to_sysctl_conf "$kcc_low_num" "$kcc_low_den" "$kcc_high_num" "$kcc_high_den" || {
        echo "写入 KCC 调优参数失败"
        return 1
    }
    echo "配置已写入 $SYSCTL_CONF"
    if ! sysctl --system; then
        echo "警告：sysctl --system 执行失败，请检查上方错误。"
        return 1
    fi
    if ! sysctl -w "net.core.default_qdisc=$qdisc" "net.ipv4.tcp_congestion_control=$congestion_control"; then
        echo "警告：运行时应用队列规则或拥塞控制失败。"
        return 1
    fi
    echo "系统已重新加载配置"
    echo
    get_system_info
}

restore_default_bbr() {
    echo "恢复默认 BBR 方案: bbr + fq"
    apply_optimization "fq" "bbr"
}

# 菜单
menu() {
    while true; do
        show_current_scheme
        echo
        echo "====== 系统优化菜单 ======"
        echo "1. 安装/更新 KCC 模块"
        echo "2. 安装/更新 BBR1 模块"
        echo "3. 应用优化方案"
        echo "4. KCC 参数调优"
        echo "5. 查看当前系统状态"
        echo "6. 恢复默认 BBR (bbr + fq)"
        echo "7. 重启系统"
        echo "0. 退出"
        read -p "请输入选项 [0-7]: " option

        case $option in
            1)
                install_kcc_module
                ;;
            2)
                install_bbr_module
                ;;
            3)
                apply_optimization_menu
                ;;
            4)
                kcc_tuning_menu
                ;;
            5)
                get_system_info
                ;;
            6)
                restore_default_bbr
                ;;
            7)
                require_root && systemctl reboot
                ;;
            0)
                exit 0
                ;;
            *)
                echo "无效选项"
                ;;
        esac
        echo
    done
}

# 启动菜单
menu
