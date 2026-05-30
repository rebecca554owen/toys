#!/bin/bash
# 系统优化脚本
# 作者：周宇航

SCRIPT_VERSION="1.3.0"
SYSCTL_CONF="/etc/sysctl.d/00-bbr-optimization.conf"
FINAL_SYSCTL_CONF="/etc/sysctl.conf"
UCP_REPO_URL="https://github.com/rebecca554owen/ucp.git"
UCP_SRC_DIR="/usr/local/src/tcp_ucp"
PATCHED_BBR_SRC_DIR="$UCP_SRC_DIR/google/patch"
FINAL_OVERRIDE_BEGIN="# BEGIN bbr.sh final override"
FINAL_OVERRIDE_END="# END bbr.sh final override"

qdisc="fq"
congestion_control="bbr1"

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

get_ucp_module_status() {
    if lsmod 2>/dev/null | grep -qw tcp_ucp; then
        echo "已加载"
    elif command -v modinfo >/dev/null 2>&1 && modinfo tcp_ucp >/dev/null 2>&1; then
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

    if has_congestion_control ucp; then
        echo "UCP 状态: 可用 ($(get_ucp_module_status))"
    else
        echo "UCP 状态: 不可用 ($(get_ucp_module_status))"
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
    echo "UCP: $(get_ucp_module_status) | BBR1: $(get_patched_bbr_module_status) | BBR: $(get_bbr_module_status)"
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

check_ucp_build_requirements() {
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

    if ! check_ucp_build_requirements; then
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

    if ! check_ucp_build_requirements; then
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
    echo "可以安装软件源提供的最新内核和 headers，重启后再回来编译 UCP。"
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
                    echo "已取消立即重启。未重启前无法为当前运行内核编译 UCP。"
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

prepare_ucp_source() {
    mkdir -p "$(dirname "$UCP_SRC_DIR")" || return 1

    if [ -d "$UCP_SRC_DIR/.git" ]; then
        echo "更新 UCP 源码: $UCP_SRC_DIR"
        if git -C "$UCP_SRC_DIR" pull --ff-only; then
            return 0
        fi

        echo "常规 fast-forward 更新失败，尝试对齐远端分支。"
        if [ -n "$(git -C "$UCP_SRC_DIR" status --porcelain --untracked-files=no)" ]; then
            echo "UCP 源码目录存在本地改动，为避免覆盖，请先手动处理: $UCP_SRC_DIR"
            return 1
        fi

        local current_branch upstream_ref
        current_branch=$(git -C "$UCP_SRC_DIR" branch --show-current)
        upstream_ref=$(git -C "$UCP_SRC_DIR" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)
        if [ -z "$upstream_ref" ] && [ -n "$current_branch" ]; then
            upstream_ref="origin/$current_branch"
        fi
        if [ -z "$upstream_ref" ]; then
            upstream_ref="origin/main"
        fi

        git -C "$UCP_SRC_DIR" fetch --prune origin || return 1
        if ! git -C "$UCP_SRC_DIR" rev-parse --verify "$upstream_ref" >/dev/null 2>&1; then
            echo "无法找到远端分支: $upstream_ref"
            return 1
        fi
        git -C "$UCP_SRC_DIR" reset --hard "$upstream_ref"
    else
        echo "克隆 UCP 源码到: $UCP_SRC_DIR"
        rm -rf "$UCP_SRC_DIR"
        git clone "$UCP_REPO_URL" "$UCP_SRC_DIR"
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

install_ucp_module_file() {
    install_module_file "$UCP_SRC_DIR/tcp_ucp.ko" "tcp_ucp" "UCP"
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
    install_module_file "$PATCHED_BBR_SRC_DIR/tcp_bbr1.ko" "tcp_bbr1" "补丁 BBR"
}

install_bbr_module() {
    require_linux || return 1
    require_root || return 1

    echo "====== 编译/安装/更新补丁 BBR 模块 ======"
    ensure_build_environment "补丁 BBR 安装" || return 1

    prepare_ucp_source || return 1
    if [ ! -d "$PATCHED_BBR_SRC_DIR" ] || [ ! -f "$PATCHED_BBR_SRC_DIR/tcp_bbr1.c" ]; then
        echo "未找到补丁 BBR 源码目录: $PATCHED_BBR_SRC_DIR"
        return 1
    fi

    echo "开始编译补丁 BBR..."
    build_kernel_module "$PATCHED_BBR_SRC_DIR" || return 1

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

install_ucp_module() {
    require_linux || return 1
    require_root || return 1

    echo "====== 编译/安装/更新 UCP 模块 ======"
    ensure_build_environment "UCP 安装" || return 1

    prepare_ucp_source || return 1

    echo "开始编译 UCP..."
    build_kernel_module "$UCP_SRC_DIR" || return 1

    echo "安装 UCP 模块..."
    install_ucp_module_file || return 1

    echo "加载 tcp_ucp 模块..."
    if ! reload_congestion_module tcp_ucp ucp; then
        echo "UCP 模块加载失败。若系统启用了 Secure Boot，可能会阻止未签名内核模块加载。"
        return 1
    fi

    if has_congestion_control ucp; then
        echo "UCP 安装并加载成功。"
        echo
        get_system_info
        return 0
    fi

    echo "UCP 模块已尝试加载，但系统可用拥塞控制列表中未发现 ucp。"
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
        ucp)
            modprobe tcp_ucp 2>/dev/null || true
            ;;
    esac

    has_congestion_control "$name"
}

ensure_ucp_ready() {
    if ensure_congestion_control_available ucp; then
        return 0
    fi

    echo "UCP 未安装或未加载，无法直接应用 ucp + fq。"
    read -p "是否立即编译/安装/加载 UCP 模块？[Y/n]: " install_now
    case $install_now in
        ""|y|Y)
            install_ucp_module
            ;;
        *)
            echo "已取消应用 UCP。"
            return 1
            ;;
    esac
}

ensure_bbr_ready() {
    if ensure_congestion_control_available bbr1; then
        return 0
    fi

    echo "BBR1 未安装或未加载，无法直接应用 bbr1。"
    echo "将使用 UCP 仓库 google/patch 目录中的补丁 BBR1 模块。"
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
    echo "1. ucp + fq (默认)"
    echo
    echo "UCP:"
    echo "2. ucp + cake"
    echo "3. ucp + fq_pie"
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
            apply_optimization "fq" "ucp"
            ;;
        2)
            apply_optimization "cake" "ucp"
            ;;
        3)
            apply_optimization "fq_pie" "ucp"
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
            echo "无效选择，使用默认值 ucp + fq"
            apply_optimization "fq" "ucp"
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

    if [ "$congestion_control" = "ucp" ]; then
        ensure_ucp_ready || return 1
    elif [ "$congestion_control" = "bbr1" ]; then
        ensure_bbr_ready || return 1
    elif ! ensure_congestion_control_available "$congestion_control"; then
        echo "拥塞控制算法 $congestion_control 不可用，未写入配置。"
        return 1
    fi

    generate_sysctl_conf
}

remove_final_sysctl_override() {
    local tmp_file

    [ -f "$FINAL_SYSCTL_CONF" ] || return 0
    tmp_file=$(mktemp) || return 1
    awk -v begin="$FINAL_OVERRIDE_BEGIN" -v end="$FINAL_OVERRIDE_END" '
        $0 == begin { skip = 1; next }
        $0 == end { skip = 0; next }
        !skip { print }
    ' "$FINAL_SYSCTL_CONF" > "$tmp_file" || {
        rm -f "$tmp_file"
        return 1
    }
    cat "$tmp_file" > "$FINAL_SYSCTL_CONF"
    rm -f "$tmp_file"
}

write_final_sysctl_override() {
    remove_final_sysctl_override || return 1
    cat >> "$FINAL_SYSCTL_CONF" << EOF

$FINAL_OVERRIDE_BEGIN
net.core.default_qdisc = $qdisc
net.ipv4.tcp_congestion_control = $congestion_control
$FINAL_OVERRIDE_END
EOF
}

# 生成sysctl配置并应用
generate_sysctl_conf() {
    cat > "$SYSCTL_CONF" << EOF
# /etc/sysctl.conf - 系统变量配置文件
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

# BBR/UCP 配置
net.core.default_qdisc = $qdisc
net.ipv4.tcp_congestion_control = $congestion_control
EOF
    write_final_sysctl_override || {
        echo "写入 $FINAL_SYSCTL_CONF 最终覆盖配置失败"
        return 1
    }
    echo "配置已写入 $SYSCTL_CONF"
    sysctl --system
    sysctl -w "net.core.default_qdisc=$qdisc" "net.ipv4.tcp_congestion_control=$congestion_control"
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
        echo "1. 安装/更新 UCP 模块"
        echo "2. 安装/更新 BBR1 模块"
        echo "3. 应用优化"
        echo "4. 恢复默认 BBR (bbr + fq)"
        echo "5. 重启系统"
        echo "0. 退出"
        read -p "请输入选项 [0-5]: " option

        case $option in
            1)
                install_ucp_module
                ;;
            2)
                install_bbr_module
                ;;
            3)
                apply_optimization_menu
                ;;
            4)
                restore_default_bbr
                ;;
            5)
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
