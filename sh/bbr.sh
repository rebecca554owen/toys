#!/bin/bash
# 系统优化脚本
# 作者：周宇航

SCRIPT_VERSION="1.5.5"
set -euo pipefail

SYSCTL_CONF="/etc/sysctl.d/99-bbr-kcc.conf"
LEGACY_SYSCTL_CONF="/etc/sysctl.d/00-bbr.conf"
MODULES_LOAD_CONF="/etc/modules-load.d/99-bbr-kcc.conf"
BOOT_APPLY_SCRIPT="/usr/local/sbin/bbr-kcc-apply"
BOOT_APPLY_SERVICE="/etc/systemd/system/bbr-kcc-apply.service"
KCC_REPO_URL="https://github.com/rebecca554owen/kcc.git"
KCC_BRANCH="main"
KCC_SRC_DIR="/usr/local/src/kcc"
KCC_PATCH_DIR="$KCC_SRC_DIR/google/patch"

qdisc="cake"
congestion_control="kcc"
KCC_KF_ENABLE=1
KCC_KF_DISCOUNT_NUM=50
KCC_KF_DISCOUNT_DEN=100
KCC_KF_STEADY_MODE=1
KCC_RTT_MODE=0
KCC_INJECTION_DIVISOR=2.885

# Temp file tracking for cleanup on unexpected exit
TEMP_FILES=()
cleanup_temp_files() {
    local exit_code=$?
    for f in "${TEMP_FILES[@]}"; do
        [ -f "$f" ] && rm -f "$f" 2>/dev/null || true
    done
    exit $exit_code
}
trap cleanup_temp_files EXIT

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

get_kcc_version_label() {
    local status running_ver

    status=$(get_kcc_module_status)
    running_ver=$(get_running_module_srcversion tcp_kcc)

    if [ -n "$running_ver" ]; then
        echo "$status (src:$running_ver)"
    else
        echo "$status"
    fi
}

show_current_scheme() {
    local socket_mode=${1:-compact}
    local current_qdisc current_cc available_controls persistent_qdisc persistent_cc

    current_qdisc=$(get_sysctl_value net.core.default_qdisc)
    current_cc=$(get_sysctl_value net.ipv4.tcp_congestion_control)
    available_controls=$(get_available_congestion_controls)
    persistent_qdisc=$(read_sysctl_conf_value net.core.default_qdisc 2>/dev/null || echo "未配置")
    persistent_cc=$(read_sysctl_conf_value net.ipv4.tcp_congestion_control 2>/dev/null || echo "未配置")

    echo "====== 当前状态 v$SCRIPT_VERSION ======"
    echo "内核版本: $(uname -r)"
    echo "运行方案: qdisc=$current_qdisc, cc=$current_cc"
    echo "持久方案: qdisc=$persistent_qdisc, cc=$persistent_cc"
    if [ "$current_qdisc" != "$persistent_qdisc" ] || [ "$current_cc" != "$persistent_cc" ]; then
        echo "提示：运行方案与持久方案不一致，可能被其它启动配置或服务覆盖。"
    fi
    echo "可用算法: $available_controls"
    echo "KCC: $(get_kcc_version_label) | BBR1: $(get_patched_bbr_module_status) | BBR: $(get_bbr_module_status)"
    echo "开机加载: tcp_kcc=$(get_modules_load_status tcp_kcc), tcp_bbr1=$(get_modules_load_status tcp_bbr1), 启动应用=$(get_boot_apply_status)"
    show_tcp_congestion_socket_status "$socket_mode"
    echo "====================="
}

remove_legacy_sysctl_overrides() {
    local conf disabled_file

    for conf in "$LEGACY_SYSCTL_CONF" /etc/sysctl.d/00-bbr-optimization.conf; do
        [ -e "$conf" ] || continue
        disabled_file="$conf.disabled-by-bbr-kcc"
        if [ -e "$disabled_file" ]; then
            disabled_file="$conf.disabled-by-bbr-kcc.$(date +%Y%m%d%H%M%S)"
        fi
        mv "$conf" "$disabled_file" || {
            echo "警告：无法清理旧 sysctl 残留: $conf"
        }
    done
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
        local deb_arch
        deb_arch=$(dpkg --print-architecture 2>/dev/null || true)
        if [ -n "$deb_arch" ] && apt-cache show "linux-image-$deb_arch" >/dev/null 2>&1; then
            install_packages "linux-image-$deb_arch" "linux-headers-$deb_arch"
        else
            install_packages linux-image-generic linux-headers-generic
        fi
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
        read -r -p "检测到构建依赖缺失，是否尝试自动安装？[Y/n]: " install_deps
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
    read -r -p "是否安装/更新最新内核和 headers？[Y/n]: " update_kernel
    case $update_kernel in
        ""|y|Y)
            install_kernel_update_for_headers || {
                echo "内核和 headers 更新失败，请手动处理后重试。"
                return 1
            }
            echo "内核和 headers 已安装/更新。"
            echo "请现在重启系统，重启后再次运行脚本并选择对应的“安装/更新”模块选项。"
            read -r -p "是否立即重启？[y/N]: " reboot_now
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
        git -C "$KCC_SRC_DIR" remote set-url origin "$KCC_REPO_URL" || return 1
        git -C "$KCC_SRC_DIR" fetch --prune origin || return 1
        if ! git -C "$KCC_SRC_DIR" rev-parse --verify "origin/$KCC_BRANCH" >/dev/null 2>&1; then
            echo "无法找到远端分支: origin/$KCC_BRANCH"
            return 1
        fi
        _KCC_PRE_RESET_COMMIT=$(git -C "$KCC_SRC_DIR" rev-parse HEAD 2>/dev/null || true)
        echo "丢弃源码本地改动并对齐远端分支: origin/$KCC_BRANCH"
        git -C "$KCC_SRC_DIR" checkout -B "$KCC_BRANCH" "origin/$KCC_BRANCH" || return 1
        git -C "$KCC_SRC_DIR" reset --hard "origin/$KCC_BRANCH" || return 1
    else
        echo "克隆 KCC 源码到: $KCC_SRC_DIR"
        [ -n "$KCC_SRC_DIR" ] && rm -rf "$KCC_SRC_DIR"
        git clone --branch "$KCC_BRANCH" "$KCC_REPO_URL" "$KCC_SRC_DIR"
        _KCC_PRE_RESET_COMMIT=""
    fi

    echo "KCC 源码版本: $(git -C "$KCC_SRC_DIR" log -1 --oneline)"
}

install_module_file() {
    local module_file=$1
    local module_name=$2
    local display_name=$3
    local module_dir="/lib/modules/$(uname -r)/extra"
    local installed_module module_srcversion installed_srcversion

    if [ ! -f "$module_file" ]; then
        echo "未找到已编译模块: $module_file"
        return 1
    fi

    module_srcversion=$(modinfo -F srcversion "$module_file" 2>/dev/null || true)

    echo "安装 $display_name 模块到: $module_dir"
    mkdir -p "$module_dir" || return 1
    rm -f "$module_dir/$module_name.ko" "$module_dir/$module_name.ko.gz" \
          "$module_dir/$module_name.ko.xz" "$module_dir/$module_name.ko.zst" || return 1
    install -m 0644 "$module_file" "$module_dir/$module_name.ko" || return 1
    depmod "$(uname -r)" || return 1

    installed_module=$(modinfo -k "$(uname -r)" -n "$module_name" 2>/dev/null || true)
    if [ -z "$installed_module" ] || [ ! -f "$installed_module" ]; then
        echo "$display_name 模块安装后未被 modinfo 识别，请检查 depmod 输出。"
        return 1
    fi
    installed_srcversion=$(modinfo -F srcversion "$installed_module" 2>/dev/null || true)
    if [ -n "$module_srcversion" ] && [ "$installed_srcversion" != "$module_srcversion" ]; then
        echo "$display_name 模块安装校验失败：磁盘模块 srcversion 不一致。"
        echo "编译模块: $module_srcversion"
        echo "安装模块: ${installed_srcversion:-未知}"
        return 1
    fi
    echo "$display_name 模块已安装: $installed_module"
    [ -n "$installed_srcversion" ] && echo "$display_name 模块磁盘版本: $installed_srcversion"
}

install_kcc_module_file() {
    install_module_file "$KCC_SRC_DIR/tcp_kcc.ko" "tcp_kcc" "KCC" || return 1
    ensure_module_autoload tcp_kcc || return 1
    ensure_boot_apply_service
}

build_kernel_module() {
    local source_dir=$1

    make -C "/lib/modules/$(uname -r)/build" M="$source_dir" clean || return 1
    make -C "/lib/modules/$(uname -r)/build" M="$source_dir" modules
}

get_running_module_srcversion() {
    local module_name=$1

    cat "/sys/module/$module_name/srcversion" 2>/dev/null || true
}

get_module_file_srcversion() {
    local module_file=$1

    modinfo -F srcversion "$module_file" 2>/dev/null || true
}

get_installed_module_file() {
    local module_name=$1

    modinfo -k "$(uname -r)" -n "$module_name" 2>/dev/null || true
}

get_installed_module_srcversion() {
    local module_name=$1
    local installed_module

    installed_module=$(get_installed_module_file "$module_name")
    if [ -n "$installed_module" ] && [ -f "$installed_module" ]; then
        get_module_file_srcversion "$installed_module"
    fi
}

get_module_git_version() {
    local source_dir=$1
    [ -d "$source_dir/.git" ] || return 1
    git -C "$source_dir" log -1 --format="%h %s" 2>/dev/null
}

show_module_versions() {
    local module_name=$1
    local new_srcversion=$2
    local installed_srcversion=$3
    local source_dir=${4:-}
    local loaded_srcversion git_version

    loaded_srcversion=$(get_running_module_srcversion "$module_name")
    echo "$module_name 运行中版本: ${loaded_srcversion:-未加载}"
    [ -n "$new_srcversion" ] && echo "$module_name 目标版本: $new_srcversion"
    if [ -n "$installed_srcversion" ] && [ "$installed_srcversion" != "$new_srcversion" ]; then
        echo "$module_name 磁盘版本: $installed_srcversion"
    fi
    if [ -n "$source_dir" ]; then
        git_version=$(get_module_git_version "$source_dir" 2>/dev/null || true)
        [ -n "$git_version" ] && echo "$module_name git版本: $git_version"
    fi
}

select_fallback_congestion_control() {
    local congestion_name=$1
    local preferred available candidate

    available=" $(get_available_congestion_controls) "
    for preferred in cubic reno bbr bbr1; do
        if [ "$preferred" != "$congestion_name" ] && echo "$available" | grep -qw "$preferred"; then
            echo "$preferred"
            return 0
        fi
    done

    for candidate in $available; do
        if [ "$candidate" != "$congestion_name" ] && [ "$candidate" != "未知" ]; then
            echo "$candidate"
            return 0
        fi
    done

    return 1
}

switch_to_fallback_before_module_reload() {
    local congestion_name=$1
    local current_congestion_control fallback_congestion_control

    current_congestion_control=$(get_sysctl_value net.ipv4.tcp_congestion_control)
    if [ "$current_congestion_control" != "$congestion_name" ]; then
        return 0
    fi

    fallback_congestion_control=$(select_fallback_congestion_control "$congestion_name") || {
        echo "当前默认拥塞控制为 $congestion_name，但未找到其它可用拥塞控制算法作为兜底。"
        return 1
    }

    echo "热替换前临时切换默认拥塞控制到 $fallback_congestion_control，避免新连接继续引用旧 $congestion_name 模块。"
    sysctl -w "net.ipv4.tcp_congestion_control=$fallback_congestion_control" || return 1
}

show_congestion_module_users() {
    local module_name=$1
    local congestion_name=$2
    local use_count
    local has_non_listen=0 has_listen=0

    use_count=$(awk -v module="$module_name" '$1 == module { print $3 }' /proc/modules 2>/dev/null || true)
    [ -n "$use_count" ] && echo "$module_name 当前引用计数: $use_count"

    if command -v ss >/dev/null 2>&1; then
        echo "仍在使用 $congestion_name 的 socket 进程摘要:"
        ss -tanpi 2>/dev/null | awk -v cc="$congestion_name" '
            /^[^[:space:]]/ { state = $1; line = $0; next }
            ($0 ~ (" " cc " ") || $0 ~ ("cong:" cc)) {
                name = "unknown"
                pid = "?"
                if (match(line, /users:\(\("[^"]+",pid=[0-9]+/)) {
                    user = substr(line, RSTART, RLENGTH)
                    sub(/^users:\(\("/, "", user)
                    split(user, parts, "\",pid=")
                    name = parts[1]
                    pid = parts[2]
                }
                key = state " " name " pid=" pid
                count[key]++
            }
            END {
                found = 0
                for (key in count) {
                    print "  " count[key] " " key
                    found = 1
                }
                if (!found) {
                    print "  未从 ss 输出中找到具体 socket；可能是内核内部引用或连接刚变化。"
                }
            }
        '

        if ss -tanpi 2>/dev/null | awk -v cc="$congestion_name" '
            /^[^[:space:]]/ { state = $1; next }
            ($0 ~ (" " cc " ") || $0 ~ ("cong:" cc)) && state != "LISTEN" { found = 1 }
            END { exit found ? 0 : 1 }
        '; then
            has_non_listen=1
        fi
        if ss -tanpi 2>/dev/null | awk -v cc="$congestion_name" '
            /^[^[:space:]]/ { state = $1; next }
            ($0 ~ (" " cc " ") || $0 ~ ("cong:" cc)) && state == "LISTEN" { found = 1 }
            END { exit found ? 0 : 1 }
        '; then
            has_listen=1
        fi

        if [ "$has_non_listen" -eq 1 ]; then
            echo "警告：以下命令会中断系统中对应状态的全部 TCP 连接，包括当前 SSH，不仅限于 $congestion_name。"
            echo "强烈建议在 screen 或 tmux 会话中执行，以免 SSH 断线后操作中断。"
            echo "如需强制中断非 LISTEN 长连接，可手动执行："
            echo "  ss -K state established"
            echo "  ss -K state close-wait"
        fi
        if [ "$has_listen" -eq 1 ]; then
            echo "LISTEN socket 无法通过 ss -K 清理；请用 'ss -tlnp' 找到占用服务后重启，或手动重启服务器后生效。"
        fi
    fi
}

reload_congestion_module() {
    local module_name=$1
    local congestion_name=$2
    local module_file=$3
    local restore_congestion_control=${4:-}
    local source_dir=${5:-}
    local expected_srcversion installed_srcversion loaded_srcversion
    local switched_to_fallback=0

    expected_srcversion=$(get_module_file_srcversion "$module_file")
    installed_srcversion=$(get_installed_module_srcversion "$module_name")
    loaded_srcversion=$(get_running_module_srcversion "$module_name")

    show_module_versions "$module_name" "$expected_srcversion" "$installed_srcversion" "$source_dir"

    if [ -n "$expected_srcversion" ] && [ "$loaded_srcversion" = "$expected_srcversion" ]; then
        echo "$module_name 运行中版本已是最新，无需重新加载模块。"
        return 0
    fi

    if lsmod 2>/dev/null | grep -qw "$module_name"; then
        if [ "$restore_congestion_control" = "$congestion_name" ]; then
            switch_to_fallback_before_module_reload "$congestion_name" || return 1
            switched_to_fallback=1
        fi
        if ! modprobe -r "$module_name"; then
            if [ "$switched_to_fallback" -eq 1 ]; then
                sysctl -q -w "net.ipv4.tcp_congestion_control=$restore_congestion_control" 2>/dev/null || true
            fi
            echo "$module_name 当前仍被内核引用，无法热替换旧模块。"
            show_module_versions "$module_name" "$expected_srcversion" "$installed_srcversion" "$source_dir"
            echo "新模块已安装到磁盘，但当前运行中仍是旧模块。"
            echo "请重启占用进程，或手动重启服务器后生效。"
            show_congestion_module_users "$module_name" "$congestion_name"
            return 2
        fi
    fi
    if ! modprobe "$module_name"; then
        if [ "$switched_to_fallback" -eq 1 ]; then
            sysctl -q -w "net.ipv4.tcp_congestion_control=$restore_congestion_control" 2>/dev/null || true
        fi
        return 1
    fi

    loaded_srcversion=$(get_running_module_srcversion "$module_name")
    if [ -n "$expected_srcversion" ] && [ "$loaded_srcversion" != "$expected_srcversion" ]; then
        if [ "$switched_to_fallback" -eq 1 ]; then
            sysctl -q -w "net.ipv4.tcp_congestion_control=$restore_congestion_control" 2>/dev/null || true
        fi
        echo "$module_name 加载校验失败：内存模块 srcversion 与新安装模块不一致。"
        echo "期望版本: $expected_srcversion"
        echo "加载版本: ${loaded_srcversion:-未知}"
        return 1
    fi
    [ -n "$loaded_srcversion" ] && echo "$module_name 已加载版本: $loaded_srcversion"
    [ -n "$expected_srcversion" ] && echo "$module_name 运行版本与磁盘版本一致。"

    if [ "$restore_congestion_control" = "$congestion_name" ]; then
        sysctl -w "net.ipv4.tcp_congestion_control=$congestion_name" || return 1
    fi
}

install_bbr_module_file() {
    install_module_file "$KCC_PATCH_DIR/tcp_bbr1.ko" "tcp_bbr1" "补丁 BBR" || return 1
    ensure_module_autoload tcp_bbr1 || return 1
    ensure_boot_apply_service
}

ensure_module_autoload() {
    local module_name=$1
    local conf_dir

    conf_dir=$(dirname "$MODULES_LOAD_CONF")
    mkdir -p "$conf_dir" || return 1
    touch "$MODULES_LOAD_CONF" || return 1
    if ! grep -qxF "$module_name" "$MODULES_LOAD_CONF"; then
        echo "$module_name" >> "$MODULES_LOAD_CONF" || return 1
    fi
}

ensure_boot_apply_service() {
    local script_dir service_dir

    command -v systemctl >/dev/null 2>&1 || return 0

    script_dir=$(dirname "$BOOT_APPLY_SCRIPT")
    service_dir=$(dirname "$BOOT_APPLY_SERVICE")
    mkdir -p "$script_dir" "$service_dir" || return 1

    cat > "$BOOT_APPLY_SCRIPT" << EOF
#!/bin/sh
set -eu

SYSCTL_CONF="$SYSCTL_CONF"

read_conf_value() {
    key=\$1
    [ -f "\$SYSCTL_CONF" ] || return 1
    awk -F= -v key="\$key" '
        {
            lhs = \$1
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", lhs)
        }
        lhs == key {
            rhs = \$2
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", rhs)
            print rhs
            found = 1
            exit
        }
        END { if (!found) exit 1 }
    ' "\$SYSCTL_CONF"
}

qdisc=\$(read_conf_value net.core.default_qdisc 2>/dev/null || echo cake)
cc=\$(read_conf_value net.ipv4.tcp_congestion_control 2>/dev/null || echo kcc)

if [ "\$cc" = "kcc" ]; then
    modprobe tcp_kcc 2>/dev/null || true
elif [ "\$cc" = "bbr1" ]; then
    modprobe tcp_bbr1 2>/dev/null || true
elif [ "\$cc" = "bbr" ]; then
    modprobe tcp_bbr 2>/dev/null || true
fi

sysctl -q -w "net.core.default_qdisc=\$qdisc" || true
sysctl -q -w "net.ipv4.tcp_congestion_control=\$cc" || true
sysctl -e -q -p "\$SYSCTL_CONF" || true
EOF
    chmod 0755 "$BOOT_APPLY_SCRIPT" || return 1

    cat > "$BOOT_APPLY_SERVICE" << EOF
[Unit]
Description=Apply BBR/KCC congestion control defaults before services listen
DefaultDependencies=no
After=local-fs.target systemd-modules-load.service
Before=network-pre.target network.target multi-user.target docker.service nginx.service ssh.service sshd.service smbd.service
Wants=network-pre.target

[Service]
Type=oneshot
ExecStart=$BOOT_APPLY_SCRIPT
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload || return 1
    systemctl enable "$(basename "$BOOT_APPLY_SERVICE")" >/dev/null 2>&1 || return 1
}

persist_scheme_if_module_selected() {
    local congestion_name=$1
    local saved_congestion_control=$2
    local saved_qdisc=$3

    if [ "$saved_congestion_control" != "$congestion_name" ]; then
        return 0
    fi

    if [ -z "$saved_qdisc" ] || [ "$saved_qdisc" = "未知" ]; then
        return 0
    fi

    qdisc=$saved_qdisc
    congestion_control=$saved_congestion_control
    echo "持久化当前运行方案: $congestion_control + $qdisc"
    generate_sysctl_conf
}

kcc_source_changed() {
    local post_commit
    post_commit=$(git -C "$KCC_SRC_DIR" rev-parse HEAD 2>/dev/null || true)
    [ -z "$_KCC_PRE_RESET_COMMIT" ] || [ "$_KCC_PRE_RESET_COMMIT" != "$post_commit" ]
}

install_bbr_module() {
    local restore_congestion_control restore_qdisc reload_status loaded_srcversion installed_srcversion installed_module

    require_linux || return 1
    require_root || return 1

    echo "====== 编译/安装/更新补丁 BBR 模块 ======"

    restore_congestion_control=$(get_sysctl_value net.ipv4.tcp_congestion_control)
    restore_qdisc=$(get_sysctl_value net.core.default_qdisc)
    ensure_build_environment "补丁 BBR 安装" || return 1

    prepare_kcc_source || return 1
    if [ ! -d "$KCC_PATCH_DIR" ] || [ ! -f "$KCC_PATCH_DIR/tcp_bbr1.c" ]; then
        echo "未找到补丁 BBR 源码目录: $KCC_PATCH_DIR"
        return 1
    fi

    if kcc_source_changed; then
        echo "检测到源码有更新，开始编译补丁 BBR..."
        build_kernel_module "$KCC_PATCH_DIR" || return 1
        install_bbr_module_file || return 1
    else
        loaded_srcversion=$(get_running_module_srcversion tcp_bbr1)
        installed_srcversion=$(get_installed_module_srcversion tcp_bbr1)
        installed_module=$(get_installed_module_file tcp_bbr1)
        if [ -z "$installed_module" ] || [ ! -f "$installed_module" ]; then
            echo "源码无变化，但当前内核未安装 tcp_bbr1 模块，开始编译补丁 BBR..."
            build_kernel_module "$KCC_PATCH_DIR" || return 1
            install_bbr_module_file || return 1
        elif [ ! -f "$KCC_PATCH_DIR/tcp_bbr1.ko" ]; then
            echo "源码无变化，但源码目录缺少已编译模块，开始重新编译补丁 BBR..."
            build_kernel_module "$KCC_PATCH_DIR" || return 1
            install_bbr_module_file || return 1
        elif [ -n "$installed_srcversion" ] && [ "$loaded_srcversion" = "$installed_srcversion" ]; then
            echo "源码无变化，运行中版本已是最新 (src:$loaded_srcversion)。"
            ensure_module_autoload tcp_bbr1 || return 1
            ensure_boot_apply_service || return 1
            persist_scheme_if_module_selected bbr1 "$restore_congestion_control" "$restore_qdisc" || return 1
            return 0
        else
            echo "源码无变化，磁盘已有更新版本，尝试热替换..."
        fi
    fi

    echo "加载 tcp_bbr1 模块..."
    reload_congestion_module tcp_bbr1 bbr1 "$(get_installed_module_file tcp_bbr1)" "$restore_congestion_control" "$KCC_PATCH_DIR"
    reload_status=$?
    if [ "$reload_status" -eq 2 ]; then
        echo "补丁 BBR 模块已安装到磁盘，但旧模块仍在运行中。"
        echo "请重启占用进程或手动重启服务器后生效。"
        return 2
    elif [ "$reload_status" -ne 0 ]; then
        echo "补丁 BBR 模块加载失败。若系统启用了 Secure Boot，可能会阻止未签名模块加载。"
        return 1
    fi
    if has_congestion_control bbr1; then
        echo "补丁 BBR 安装并加载成功。"
        persist_scheme_if_module_selected bbr1 "$restore_congestion_control" "$restore_qdisc" || return 1
        echo
        show_current_scheme
        return 0
    fi

    echo "补丁 BBR 模块已尝试加载，但系统可用拥塞控制列表中未发现 bbr1。"
    return 1
}

install_kcc_module() {
    local restore_congestion_control restore_qdisc reload_status loaded_srcversion installed_srcversion installed_module

    require_linux || return 1
    require_root || return 1

    echo "====== 编译/安装/更新 KCC 模块 ======"

    restore_congestion_control=$(get_sysctl_value net.ipv4.tcp_congestion_control)
    restore_qdisc=$(get_sysctl_value net.core.default_qdisc)
    ensure_build_environment "KCC 安装" || return 1

    prepare_kcc_source || return 1

    if kcc_source_changed; then
        echo "检测到源码有更新，开始编译 KCC..."
        build_kernel_module "$KCC_SRC_DIR" || return 1
        echo "安装 KCC 模块..."
        install_kcc_module_file || return 1
    else
        loaded_srcversion=$(get_running_module_srcversion tcp_kcc)
        installed_srcversion=$(get_installed_module_srcversion tcp_kcc)
        installed_module=$(get_installed_module_file tcp_kcc)
        if [ -z "$installed_module" ] || [ ! -f "$installed_module" ]; then
            echo "源码无变化，但当前内核未安装 tcp_kcc 模块，开始编译 KCC..."
            build_kernel_module "$KCC_SRC_DIR" || return 1
            echo "安装 KCC 模块..."
            install_kcc_module_file || return 1
        elif [ ! -f "$KCC_SRC_DIR/tcp_kcc.ko" ]; then
            echo "源码无变化，但源码目录缺少已编译模块，开始重新编译 KCC..."
            build_kernel_module "$KCC_SRC_DIR" || return 1
            echo "安装 KCC 模块..."
            install_kcc_module_file || return 1
        elif [ -n "$installed_srcversion" ] && [ "$loaded_srcversion" = "$installed_srcversion" ]; then
            echo "源码无变化，运行中版本已是最新 (src:$loaded_srcversion)。"
            ensure_module_autoload tcp_kcc || return 1
            ensure_boot_apply_service || return 1
            persist_scheme_if_module_selected kcc "$restore_congestion_control" "$restore_qdisc" || return 1
            return 0
        else
            echo "源码无变化，磁盘已有更新版本，尝试热替换..."
        fi
    fi

    echo "加载 tcp_kcc 模块..."
    reload_congestion_module tcp_kcc kcc "$KCC_SRC_DIR/tcp_kcc.ko" "$restore_congestion_control" "$KCC_SRC_DIR"
    reload_status=$?
    if [ "$reload_status" -eq 2 ]; then
        echo "KCC 模块已安装到磁盘，但旧模块仍在运行中。"
        persist_scheme_if_module_selected kcc "$restore_congestion_control" "$restore_qdisc" || return 1
        echo "请重启占用进程或手动重启服务器后生效。"
        return 2
    elif [ "$reload_status" -ne 0 ]; then
        echo "KCC 模块加载失败。若系统启用了 Secure Boot，可能会阻止未签名内核模块加载。"
        return 1
    fi
    if has_congestion_control kcc; then
        echo "KCC 安装并加载成功。"
        persist_scheme_if_module_selected kcc "$restore_congestion_control" "$restore_qdisc" || return 1
        echo
        show_current_scheme
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

try_reload_module_if_stale() {
    local module_name=$1
    local congestion_name=$2
    local installed_module installed_srcversion loaded_srcversion source_dir

    loaded_srcversion=$(get_running_module_srcversion "$module_name")
    installed_srcversion=$(get_installed_module_srcversion "$module_name")

    [ -z "$installed_srcversion" ] && return 0
    [ "$loaded_srcversion" = "$installed_srcversion" ] && return 0

    echo "$module_name 磁盘版本与运行中版本不一致，尝试热替换..."
    installed_module=$(get_installed_module_file "$module_name")
    case $module_name in
        tcp_kcc)  source_dir="$KCC_SRC_DIR" ;;
        tcp_bbr1) source_dir="$KCC_PATCH_DIR" ;;
    esac
    reload_congestion_module "$module_name" "$congestion_name" "$installed_module" "$congestion_name" "$source_dir"
}

ensure_kcc_ready() {
    local reload_status

    if ensure_congestion_control_available kcc; then
        ensure_module_autoload tcp_kcc || return 1
        ensure_boot_apply_service || return 1
        try_reload_module_if_stale tcp_kcc kcc
        reload_status=$?
        [ "$reload_status" -eq 2 ] && return 2
        return 0
    fi

    echo "KCC 未安装或未加载，无法直接应用 KCC 方案。"
    read -r -p "是否立即编译/安装/加载 KCC 模块？[Y/n]: " install_now
    case $install_now in
        ""|y|Y)
            install_kcc_module
            return $?
            ;;
        *)
            echo "已取消应用 KCC。"
            return 1
            ;;
    esac
}

ensure_bbr_ready() {
    local reload_status

    if ensure_congestion_control_available bbr1; then
        ensure_module_autoload tcp_bbr1 || return 1
        ensure_boot_apply_service || return 1
        try_reload_module_if_stale tcp_bbr1 bbr1
        reload_status=$?
        [ "$reload_status" -eq 2 ] && return 2
        return 0
    fi

    echo "BBR1 未安装或未加载，无法直接应用 bbr1。"
    echo "将使用 KCC 仓库 google/patch 目录中的补丁 BBR1 模块。"
    read -r -p "是否立即编译/安装/加载 BBR1 模块？[Y/n]: " install_now
    case $install_now in
        ""|y|Y)
            install_bbr_module
            return $?
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
    echo "1. kcc + cake (默认)"
    echo
    echo "KCC:"
    echo "2. kcc + fq"
    echo "3. kcc + fq_pie"
    echo
    echo "优化版 BBR:"
    echo "4. bbr1 + cake"
    echo "5. bbr1 + fq"
    echo "6. bbr1 + fq_pie"
    echo
    echo "系统默认 BBR:"
    echo "7. bbr + cake"
    echo "8. bbr + fq"
    echo "9. bbr + fq_pie"
    echo
    echo "0. 返回主菜单"
    read -r -p "请输入选择 [0-9] (默认1): " choice

    case $choice in
        1|"")
            apply_optimization "cake" "kcc"
            ;;
        2)
            apply_optimization "fq" "kcc"
            ;;
        3)
            apply_optimization "fq_pie" "kcc"
            ;;
        4)
            apply_optimization "cake" "bbr1"
            ;;
        5)
            apply_optimization "fq" "bbr1"
            ;;
        6)
            apply_optimization "fq_pie" "bbr1"
            ;;
        7)
            apply_optimization "cake" "bbr"
            ;;
        8)
            apply_optimization "fq" "bbr"
            ;;
        9)
            apply_optimization "fq_pie" "bbr"
            ;;
        0)
            return 0
            ;;
        *)
            echo "无效选择，使用默认值 kcc + cake"
            apply_optimization "cake" "kcc"
            ;;
    esac
}

apply_optimization() {
    local selected_qdisc=$1
    local selected_congestion_control=$2
    local reload_status

    require_linux || return 1
    require_root || return 1

    qdisc=$selected_qdisc
    congestion_control=$selected_congestion_control

    if [ "$congestion_control" = "kcc" ]; then
        ensure_kcc_ready || {
            reload_status=$?
            if [ "$reload_status" -eq 2 ]; then
                echo "KCC 模块热替换失败，配置仍会写入，重启后生效。"
            else
                return 1
            fi
        }
    elif [ "$congestion_control" = "bbr1" ]; then
        ensure_bbr_ready || {
            reload_status=$?
            if [ "$reload_status" -eq 2 ]; then
                echo "BBR1 模块热替换失败，配置仍会写入，重启后生效。"
            else
                return 1
            fi
        }
    elif ! ensure_congestion_control_available "$congestion_control"; then
        echo "拥塞控制算法 $congestion_control 不可用，未写入配置。"
        return 1
    fi

    generate_sysctl_conf
}

is_non_negative_integer() {
    case "$1" in
        ''|*[!0-9]*)
            return 1
            ;;
        *)
            return 0
            ;;
    esac
}

is_positive_integer() {
    is_non_negative_integer "$1" && [ "$1" -gt 0 ]
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

format_kcc_injection_percent() {
    local num=$1
    local den=$2

    if ! is_positive_integer "$num" || ! is_positive_integer "$den"; then
        echo "未知"
        return 0
    fi

    awk -v num="$num" -v den="$den" -v div="$KCC_INJECTION_DIVISOR" 'BEGIN { printf "%.1f%%", (num / den / div) * 100 }'
}

format_kcc_enabled_label() {
    if [ "$1" = "1" ]; then
        echo "启用"
    else
        echo "禁用"
    fi
}

format_kcc_rtt_mode_label() {
    case "$1" in
        0)
            echo "FILTER=0 通用稳定，KCC 默认"
            ;;
        1)
            echo "BBR=1 传统 min_rtt 窗口，轻载/单流特定场景"
            ;;
        *)
            echo "未知=$1"
            ;;
    esac
}


read_sysctl_conf_value() {
    local key=$1
    local conf

    for conf in "$SYSCTL_CONF" "$LEGACY_SYSCTL_CONF"; do
        [ -f "$conf" ] || continue
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
        ' "$conf" && return 0
    done
    return 1
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
    if is_non_negative_integer "$value"; then
        echo "$value"
        return 0
    fi

    value=$(sysctl -n "$key" 2>/dev/null || true)
    if is_non_negative_integer "$value"; then
        echo "$value"
        return 0
    fi

    echo "$default_value"
}

get_kcc_runtime_preferred_value() {
    local name=$1
    local default_value=$2
    local key="net.kcc.$name"
    local value

    value=$(sysctl -n "$key" 2>/dev/null || true)
    if is_non_negative_integer "$value"; then
        echo "$value"
        return 0
    fi

    value=$(read_sysctl_conf_value "$key" 2>/dev/null || true)
    if is_non_negative_integer "$value"; then
        echo "$value"
        return 0
    fi

    echo "$default_value"
}

show_kcc_tuning_status() {
    local kf_enable discount_num discount_den kfsm rtt_mode inactive_note

    kf_enable=$(get_kcc_effective_value kcc_kf_enable "$KCC_KF_ENABLE")
    discount_num=$(get_kcc_effective_value kcc_kf_discount_num "$KCC_KF_DISCOUNT_NUM")
    discount_den=$(get_kcc_effective_value kcc_kf_discount_den "$KCC_KF_DISCOUNT_DEN")
    kfsm=$(get_kcc_effective_value kcc_kf_steady_mode "$KCC_KF_STEADY_MODE")
    rtt_mode=$(get_kcc_runtime_preferred_value kcc_rtt_mode "$KCC_RTT_MODE")
    [ "$kf_enable" = "1" ] || inactive_note="（未生效）"

    echo "====== KCC 参数 ======"
    echo "KF 注入: $(format_kcc_enabled_label "$kf_enable")"
    echo "稳态峰值: $(format_kcc_enabled_label "$kfsm")$inactive_note"
    echo "甜点速度: $discount_num/$discount_den = $(format_kcc_gain "$discount_num" "$discount_den")；预计初始注入 fair-share × $(format_kcc_injection_percent "$discount_num" "$discount_den")$inactive_note"
    echo "RTT 模式: $(format_kcc_rtt_mode_label "$rtt_mode")"
    echo "====================="
}

get_modules_load_status() {
    local module_name=$1

    if [ -f "$MODULES_LOAD_CONF" ] && grep -qxF "$module_name" "$MODULES_LOAD_CONF"; then
        echo "已配置"
    else
        echo "未配置"
    fi
}

get_boot_apply_status() {
    if ! command -v systemctl >/dev/null 2>&1; then
        echo "无 systemd"
    elif systemctl is-enabled "$(basename "$BOOT_APPLY_SERVICE")" >/dev/null 2>&1; then
        echo "已启用"
    elif [ -f "$BOOT_APPLY_SERVICE" ]; then
        echo "未启用"
    else
        echo "未配置"
    fi
}

show_sysctl_override_hints() {
    local matches

    matches=$(grep -HnE '^[[:space:]]*net\.(core\.default_qdisc|ipv4\.tcp_congestion_control)[[:space:]]*=' \
        /etc/sysctl.conf /etc/sysctl.d/*.conf /run/sysctl.d/*.conf \
        /usr/local/lib/sysctl.d/*.conf /usr/lib/sysctl.d/*.conf /lib/sysctl.d/*.conf \
        2>/dev/null || true)
    [ -n "$matches" ] || return 0

    echo "sysctl 相关配置:"
    echo "$matches" | sed 's/^/  /'
}

show_persistent_scheme_status() {
    local persistent_qdisc persistent_cc

    persistent_qdisc=$(read_sysctl_conf_value net.core.default_qdisc 2>/dev/null || echo "未配置")
    persistent_cc=$(read_sysctl_conf_value net.ipv4.tcp_congestion_control 2>/dev/null || echo "未配置")

    echo "====== 持久化配置 ======"
    echo "sysctl 文件: $SYSCTL_CONF"
    echo "持久队列规则: $persistent_qdisc"
    echo "持久拥塞控制: $persistent_cc"
    echo "模块开机加载: tcp_kcc=$(get_modules_load_status tcp_kcc), tcp_bbr1=$(get_modules_load_status tcp_bbr1), 启动应用=$(get_boot_apply_status)"
    echo "====================="
}

show_tcp_congestion_socket_status() {
    local mode=${1:-detail}

    if ! command -v ss >/dev/null 2>&1; then
        echo "ss 不可用，无法检查已有连接/监听 socket 使用的拥塞控制。"
        return 0
    fi

    ss -Htanpi 2>/dev/null | awk -v mode="$mode" '
        function remember_key(key) {
            if (!seen_key[key]) {
                seen_key[key] = 1
                keys[++key_count] = key
            }
        }
        function record_socket(cc) {
            if (cc == "") {
                return
            }
            total[cc]++
            if (state == "LISTEN") {
                listen_total[cc]++
                key = cc SUBSEP proc_name SUBSEP proc_pid SUBSEP local_addr
                listen_count[key]++
                remember_key(key)
            } else {
                non_listen[cc]++
            }
        }
        function parse_process(line) {
            proc_name = "-"
            proc_pid = "-"
            if (match(line, /users:\(\("[^"]+",pid=[0-9]+/)) {
                user = substr(line, RSTART, RLENGTH)
                sub(/^users:\(\("/, "", user)
                split(user, parts, "\",pid=")
                proc_name = parts[1]
                proc_pid = parts[2]
            }
        }
        function parse_cc(line) {
            if (match(line, /cong:[^, )]+/)) {
                return substr(line, RSTART + 5, RLENGTH - 5)
            }
            if (line ~ /(^|[[:space:]])kcc([[:space:]]|$)/) {
                return "kcc"
            }
            if (line ~ /(^|[[:space:]])bbr1([[:space:]]|$)/) {
                return "bbr1"
            }
            if (line ~ /(^|[[:space:]])bbr([[:space:]]|$)/) {
                return "bbr"
            }
            return ""
        }
        /^[^[:space:]]/ {
            state = $1
            local_addr = $4
            parse_process($0)
            record_socket(parse_cc($0))
            next
        }
        {
            record_socket(parse_cc($0))
        }
        END {
            if (total["kcc"] + total["bbr"] + total["bbr1"] == 0) {
                print "  未从 ss 输出中识别到 bbr/bbr1/kcc socket。"
                exit
            }

            printf "监听摘要: kcc=%d, bbr=%d, bbr1=%d\n", listen_total["kcc"] + 0, listen_total["bbr"] + 0, listen_total["bbr1"] + 0
            printf "现有非监听连接: kcc=%d, bbr=%d, bbr1=%d\n", non_listen["kcc"] + 0, non_listen["bbr"] + 0, non_listen["bbr1"] + 0
            need_restart = (listen_total["bbr"] > 0 || listen_total["bbr1"] > 0)

            if (mode != "detail" && !need_restart) {
                exit
            }

            if (mode == "detail") {
                print "监听拥塞控制:"
            } else {
                print "需要重启的监听服务:"
            }
            listen_found = 0
            for (i = 1; i <= key_count; i++) {
                split(keys[i], parts, SUBSEP)
                cc = parts[1]
                if (listen_count[keys[i]] <= 0) {
                    continue
                }
                if (mode != "detail" && cc == "kcc") {
                    continue
                }
                listen_found = 1
                mark = ""
                if (cc == "bbr" || cc == "bbr1") {
                    mark = "  <- 需要重启服务"
                }
                printf "  %-5s %3d  %-16s pid=%-7s %s%s\n", cc, listen_count[keys[i]], parts[2], parts[3], parts[4], mark
            }
            if (!listen_found) {
                if (mode == "detail") {
                    print "  未识别到 bbr/bbr1/kcc 的 LISTEN socket。"
                } else {
                    print "  无"
                }
            }

            if (need_restart) {
                print "提示：仍有监听服务未使用 kcc，请重启上方标记的服务。"
            }
            if (non_listen["bbr"] > 0 || non_listen["bbr1"] > 0) {
                print "提示：非监听旧连接需断开或自然结束，不影响新监听服务切换判断。"
            }
        }
    '
}

show_kcc_runtime_overview() {
    show_current_scheme
    show_kcc_tuning_status
}

show_detailed_status() {
    show_current_scheme detail
    show_sysctl_override_hints
}

write_sysctl_conf_value() {
    local key=$1
    local value=$2
    local conf_dir tmp_file

    conf_dir=$(dirname "$SYSCTL_CONF")
    mkdir -p "$conf_dir" || return 1
    touch "$SYSCTL_CONF" || return 1
    tmp_file=$(mktemp "$conf_dir/.bbr-sysctl.XXXXXX") || return 1
    TEMP_FILES+=("$tmp_file")

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
    local kf_enable=$1
    local discount_num=$2
    local discount_den=$3
    local kf_steady=$4
    local rtt_mode=$5

    write_sysctl_conf_value net.kcc.kcc_kf_enable "$kf_enable" || return 1
    write_sysctl_conf_value net.kcc.kcc_kf_discount_num "$discount_num" || return 1
    write_sysctl_conf_value net.kcc.kcc_kf_discount_den "$discount_den" || return 1
    write_sysctl_conf_value net.kcc.kcc_kf_steady_mode "$kf_steady" || return 1
    write_sysctl_conf_value net.kcc.kcc_rtt_mode "$rtt_mode" || return 1
}

apply_kcc_tuning_runtime() {
    local kf_enable=$1
    local discount_num=$2
    local discount_den=$3
    local kf_steady=$4
    local rtt_mode=$5

    if ! ensure_congestion_control_available kcc; then
        echo "KCC 未安装或未加载，当前只完成持久化配置。"
        read -r -p "是否立即编译/安装/加载 KCC 模块并尝试运行时生效？[y/N]: " install_now
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
        "net.kcc.kcc_kf_enable=$kf_enable" \
        "net.kcc.kcc_kf_discount_num=$discount_num" \
        "net.kcc.kcc_kf_discount_den=$discount_den" \
        "net.kcc.kcc_kf_steady_mode=$kf_steady"; then
        echo "KCC 运行时参数已生效。"
    else
        echo "KCC 运行时参数写入失败；持久化配置已保留，重启或加载 KCC 后再检查。"
    fi
    if sysctl -q -w "net.kcc.kcc_rtt_mode=$rtt_mode" 2>/dev/null; then
        echo "KCC RTT 模式已运行时生效。"
    else
        echo "KCC RTT 模式暂未运行时生效；可能是旧 KCC 模块不支持该参数，更新/重载 KCC 后会按持久化配置生效。"
    fi
}

apply_kcc_tuning() {
    local kf_enable=$1
    local discount_num=$2
    local discount_den=$3
    local kf_steady=$4
    local rtt_mode=$5

    require_linux || return 1
    require_root || return 1

    if ! is_non_negative_integer "$kf_enable" || ! is_non_negative_integer "$discount_num" || \
        ! is_positive_integer "$discount_den" || ! is_non_negative_integer "$kf_steady" || \
        ! is_non_negative_integer "$rtt_mode" || [ "$rtt_mode" -gt 1 ]; then
        echo "KCC 参数格式不正确。"
        return 1
    fi

    persist_kcc_tuning "$kf_enable" "$discount_num" "$discount_den" "$kf_steady" "$rtt_mode" || {
        echo "写入 $SYSCTL_CONF 持久配置失败"
        return 1
    }
    echo "KCC 参数已持久化到 $SYSCTL_CONF"

    apply_kcc_tuning_runtime "$kf_enable" "$discount_num" "$discount_den" "$kf_steady" "$rtt_mode"
    show_kcc_tuning_status
}

kcc_tuning_menu() {
    local choice kf_enable kf_enable_label kf_enable_new kf_current kf_label kf_new
    local discount_num discount_den rtt_current rtt_write

    while true; do
        kf_enable=$(get_kcc_effective_value kcc_kf_enable "$KCC_KF_ENABLE")
        if [ "$kf_enable" = "1" ]; then
            kf_enable_label="启用 → 切换 禁用"
            kf_enable_new=0
        else
            kf_enable_label="禁用 → 切换 启用"
            kf_enable_new=1
        fi
        discount_num=$(get_kcc_effective_value kcc_kf_discount_num "$KCC_KF_DISCOUNT_NUM")
        discount_den=$(get_kcc_effective_value kcc_kf_discount_den "$KCC_KF_DISCOUNT_DEN")
        kf_current=$(get_kcc_effective_value kcc_kf_steady_mode "$KCC_KF_STEADY_MODE")
        rtt_current=$(get_kcc_runtime_preferred_value kcc_rtt_mode "$KCC_RTT_MODE")
        case "$rtt_current" in
            0|1) rtt_write=$rtt_current ;;
            *)   rtt_write=$KCC_RTT_MODE ;;
        esac
        if [ "$kf_current" = "1" ]; then
            kf_label="启用 → 切换 禁用"
            kf_new=0
        else
            kf_label="禁用 → 切换 启用"
            kf_new=1
        fi

        echo "====== 当前状态与 KCC 参数调优 ======"
        echo
        echo "说明:"
        echo "  kf_enable       KF 全局注入总开关；脚本应用 KCC 方案时默认启用。"
        echo "  kf_steady_mode  让新连接复用已学习到的带宽峰值，减少冷启动慢热；链路稳定、频繁新建连接时更适合。"
        echo "  kf_discount     仅 KF 注入启用后生效；实际初始注入约为 discount / high_gain。"
        echo "  kcc_rtt_mode    RTT 建模策略：FILTER 是 KCC 默认；BBR 模式使用传统 min_rtt 窗口，仅适合特定轻载/单流场景。"
        echo
        show_kcc_runtime_overview
        echo
        echo "1. KF 全局注入：当前 $kf_enable_label"
        echo "2. KF 稳态峰值模式：当前 $kf_label（复用历史峰值估计，让新连接更快进入甜点速度）"
        echo "3. 甜点速度：保守 35/100，预计初始注入 fair-share × $(format_kcc_injection_percent 35 100)（会同步启用 KF 注入）"
        echo "4. 甜点速度：默认 50/100，预计初始注入 fair-share × $(format_kcc_injection_percent 50 100)（会同步启用 KF 注入）"
        echo "5. 甜点速度：激进 75/100，预计初始注入 fair-share × $(format_kcc_injection_percent 75 100)（会同步启用 KF 注入）"
        echo "6. RTT 模式：FILTER=0 通用稳定（脚本默认，KCC 默认）"
        echo "7. RTT 模式：BBR=1 传统 min_rtt 窗口（轻载/单流特定场景）"
        echo "0. 返回主菜单"
        read -r -p "请输入选择 [0-7]，回车刷新: " choice

        case $choice in
            "")
                ;;
            1)
                apply_kcc_tuning "$kf_enable_new" "$discount_num" "$discount_den" "$kf_current" "$rtt_write"
                ;;
            2)
                if [ "$kf_new" = "1" ]; then
                    apply_kcc_tuning 1 "$discount_num" "$discount_den" "$kf_new" "$rtt_write"
                else
                    apply_kcc_tuning "$kf_enable" "$discount_num" "$discount_den" "$kf_new" "$rtt_write"
                fi
                ;;
            3)
                apply_kcc_tuning 1 35 100 "$kf_current" "$rtt_write"
                ;;
            4)
                apply_kcc_tuning 1 50 100 "$kf_current" "$rtt_write"
                ;;
            5)
                apply_kcc_tuning 1 75 100 "$kf_current" "$rtt_write"
                ;;
            6)
                apply_kcc_tuning "$kf_enable" "$discount_num" "$discount_den" "$kf_current" 0
                ;;
            7)
                apply_kcc_tuning "$kf_enable" "$discount_num" "$discount_den" "$kf_current" 1
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

strip_conflicting_sysctl_lines() {
    local conf=$1
    local tmp_file backup_file

    [ -f "$conf" ] || return 0
    grep -qE '^[[:space:]]*net\.(core\.default_qdisc|ipv4\.tcp_congestion_control)[[:space:]]*=' "$conf" 2>/dev/null || return 0

    backup_file="$conf.bbr-kcc-backup-$(date +%Y%m%d%H%M%S)"
    cp -p "$conf" "$backup_file" 2>/dev/null || cp "$conf" "$backup_file" || return 1
    tmp_file=$(mktemp "$(dirname "$conf")/.bbr-kcc-sysctl.XXXXXX") || return 1
    TEMP_FILES+=("$tmp_file")
    awk '
        /^[[:space:]]*net\.(core\.default_qdisc|ipv4\.tcp_congestion_control)[[:space:]]*=/ {
            print "# disabled-by-bbr-kcc: " $0
            next
        }
        { print }
    ' "$conf" > "$tmp_file" || {
        rm -f "$tmp_file"
        return 1
    }
    chmod --reference="$conf" "$tmp_file" 2>/dev/null || chmod 0644 "$tmp_file"
    chown --reference="$conf" "$tmp_file" 2>/dev/null || true
    mv "$tmp_file" "$conf" || return 1
    echo "已注释冲突 sysctl: $conf (备份: $backup_file)"
}

disable_conflicting_sysctl_file() {
    local conf=$1
    local disabled_file

    [ -f "$conf" ] || return 0
    [ "$conf" = "$SYSCTL_CONF" ] && return 0
    case "$conf" in
        *.disabled-by-bbr-kcc|*.disabled-by-bbr-kcc.*)
            return 0
            ;;
    esac
    grep -qE '^[[:space:]]*net\.(core\.default_qdisc|ipv4\.tcp_congestion_control)[[:space:]]*=' "$conf" 2>/dev/null || return 0

    disabled_file="$conf.disabled-by-bbr-kcc"
    if [ -e "$disabled_file" ]; then
        disabled_file="$conf.disabled-by-bbr-kcc.$(date +%Y%m%d%H%M%S)"
    fi
    mv "$conf" "$disabled_file" || return 1
    echo "已禁用冲突 sysctl 文件: $conf -> $disabled_file"
}

archive_conflicting_sysctl_configs() {
    local conf

    strip_conflicting_sysctl_lines /etc/sysctl.conf || {
        echo "警告：清理 /etc/sysctl.conf 中的 qdisc/拥塞控制覆盖项失败。"
    }

    for conf in /etc/sysctl.d/*.conf; do
        [ -e "$conf" ] || continue
        disable_conflicting_sysctl_file "$conf" || {
            echo "警告：禁用冲突 sysctl 文件失败: $conf"
        }
    done
}

# 生成sysctl配置并应用
generate_sysctl_conf() {
    local kf_enable kf_discount_num kf_discount_den kcc_kf_steady kcc_rtt_mode MIN_FREE_KBYTES

    kf_enable=$(get_kcc_effective_value kcc_kf_enable "$KCC_KF_ENABLE")
    kf_discount_num=$(get_kcc_effective_value kcc_kf_discount_num "$KCC_KF_DISCOUNT_NUM")
    kf_discount_den=$(get_kcc_effective_value kcc_kf_discount_den "$KCC_KF_DISCOUNT_DEN")
    kcc_kf_steady=$(get_kcc_effective_value kcc_kf_steady_mode "$KCC_KF_STEADY_MODE")
    kcc_rtt_mode=$(get_kcc_effective_value kcc_rtt_mode "$KCC_RTT_MODE")
    if [ "$congestion_control" = "kcc" ]; then
        kf_enable=1
    fi

    MIN_FREE_KBYTES=$(awk '/MemTotal/ {printf "%d", $2 * 0.005}' /proc/meminfo 2>/dev/null || echo 65536)

    cat > "$SYSCTL_CONF" << EOF
# $SYSCTL_CONF - BBR/KCC 系统变量配置文件
# 作者：周宇航
# Date: $(date +%Y-%m-%d)

# 内核相关配置
kernel.pid_max = 65535
kernel.panic = 10
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
vm.min_free_kbytes = $MIN_FREE_KBYTES

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
    cat >> "$SYSCTL_CONF" << EOF
net.kcc.kcc_kf_enable = $kf_enable
net.kcc.kcc_kf_discount_num = $kf_discount_num
net.kcc.kcc_kf_discount_den = $kf_discount_den
net.kcc.kcc_kf_steady_mode = $kcc_kf_steady
net.kcc.kcc_rtt_mode = $kcc_rtt_mode
EOF
    remove_legacy_sysctl_overrides
    archive_conflicting_sysctl_configs
    echo "配置已写入 $SYSCTL_CONF"
    ensure_boot_apply_service || {
        echo "警告：配置启动应用服务失败，重启后可能被其它配置覆盖。"
    }
    if ! sysctl -e -q -p "$SYSCTL_CONF"; then
        echo "警告：加载 $SYSCTL_CONF 失败，请检查上方错误。"
        return 1
    fi
    echo "系统已重新加载配置"
    echo
    show_current_scheme
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
        echo "====== 系统优化菜单 v$SCRIPT_VERSION ======"
        echo "1. 安装/更新 KCC 模块"
        echo "2. 安装/更新 BBR1 模块"
        echo "3. 应用优化方案"
        echo "4. KCC 参数调优（可选）"
        echo "5. 查看详细状态"
        echo "6. 恢复默认 BBR (bbr + fq)"
        echo "7. 重启系统"
        echo "0. 退出"
        read -r -p "请输入选项 [0-7]，回车刷新: " option

        case $option in
            "")
                ;;
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
                show_detailed_status
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
