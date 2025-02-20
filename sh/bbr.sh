#!/bin/bash

# 应用 sysctl 配置
apply_sysctl() {
    local congestion_control=$1
    local qdisc=$2

    # 清屏、清除现有配置
    clear
    echo "正在清除现有配置..."
    clear_sysctl_conf
    echo "清除完成，正在写入新的配置..."
    # 写入新的配置
    write_sysctl_conf $congestion_control $qdisc
    echo "写入完成，正在应用系统配置..."
    # 应用系统配置
    sysctl --system
    echo "系统配置应用完成，正在设置 ulimit 配置..."
    # 调用 ulimit 配置函数
    set_ulimit
    echo "ulimit 配置设置完成，正在设置 pam_limits 配置..."

    echo "优化配置已应用。建议重启以生效。是否现在重启? 默认不重启"
    prompt_reboot
}

# 清屏、清除现有配置
clear_sysctl_conf() {
    clear
    rm -f /etc/sysctl.d/*.conf
    rm -f /usr/lib/sysctl.d/*.conf
    cat /dev/null > /etc/sysctl.conf
}

# 清理 sysctl 配置，不提示重启
clear_sysctl() {
    clear_sysctl_conf
    sysctl --system
    echo "系统优化已清理。建议重启以生效。是否现在重启? 默认不重启"
    prompt_reboot
}

# 设置 ulimit 配置
set_ulimit() {
    cat > /etc/security/limits.conf << EOF
* soft nofile $((1024 * 1024))
* hard nofile $((1024 * 1024))
* soft nproc unlimited
* hard nproc unlimited
* soft core unlimited
* hard core unlimited
EOF
    sed -i '/ulimit -SHn/d' /etc/profile
    echo "ulimit -SHn $((1024 * 1024))" >> /etc/profile
    if ! grep -q "pam_limits.so" /etc/pam.d/common-session; then
        echo "session required pam_limits.so" >> /etc/pam.d/common-session
    fi
}

# 显示系统信息
check_status() {
    kernel_version=$(uname -r | awk -F "-" '{print $1}')
    kernel_version_full=$(uname -r)
    os_version=$(cat /etc/os-release | grep "PRETTY_NAME" | cut -d '=' -f2 | tr -d '"')
    
    # 使用 sysctl 命令查询 TCP 拥塞控制算法
    net_congestion_control_sysctl=$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')
    # 使用 /proc 文件系统查询 TCP 拥塞控制算法
    net_congestion_control_proc=$(cat /proc/sys/net/ipv4/tcp_congestion_control)
    
    # 使用 sysctl 命令查询默认队列规则
    net_qdisc_sysctl=$(sysctl net.core.default_qdisc | awk '{print $3}')
    # 使用 /proc 文件系统查询默认队列规则
    net_qdisc_proc=$(cat /proc/sys/net/core/default_qdisc)
    
    echo "当前系统信息:"
    echo "操作系统版本: $os_version"
    echo "内核版本: $kernel_version_full"
    echo "TCP 拥塞控制算法 (sysctl): $net_congestion_control_sysctl"
    echo "TCP 拥塞控制算法 (proc): $net_congestion_control_proc"
    echo "默认队列规则 (sysctl): $net_qdisc_sysctl"
    echo "默认队列规则 (proc): $net_qdisc_proc"
}

# 获取可用的拥塞控制算法，如果不存在bbr，则添加到最后一项
get_available_congestion_controls() {
    local available_controls=$(sysctl net.ipv4.tcp_available_congestion_control | awk -F "=" '{print $2}' | tr ' ' '\n')
    if ! echo "$available_controls" | grep -q "bbr"; then
        available_controls="$available_controls bbr"
    fi
    echo "$available_controls"
}

# 提示重启，默认不重启
prompt_reboot() {
    read -p "输入选项: (Y/n) " answer
    if [[ "$answer" =~ ^[Yy][Ee][Ss]$ ]]; then
        reboot
    fi
}

# 菜单选项
menu() {
    clear
    echo "============================"
    check_status
    echo "============================"
    echo "  系统优化菜单  "
    echo "============================"
    echo "1. 启用优化"
    echo "2. 清理优化"
    echo "3. 退出"
    echo "============================"
    read -p "请选择一个选项: " choice
    case $choice in
        1)
            optimize_system
            ;;
        2)
            clear_sysctl
            ;;
        3)
            exit 0
            ;;
        *)
            echo "无效选项，请重新选择。"
            menu
            ;;
    esac
}

# 优化系统
optimize_system() {
    check_status

    local available_congestion_controls=$(get_available_congestion_controls)
    local queue_disciplines=("fq" "fq_pie" "cake")

    echo "可用的拥塞控制算法:"
    PS3="请选择拥塞控制算法: "
    select congestion_control in $available_congestion_controls; do
        if [ -n "$congestion_control" ]; then
            break
        else
            echo "无效选项，请重新选择。"
        fi
    done

    echo "可用的队列规则:"
    PS3="请选择队列规则: "
    select qdisc in "${queue_disciplines[@]}"; do
        if [ -n "$qdisc" ]; then
            break
        else
            echo "无效选项，请重新选择。"
        fi
    done

    echo "您选择了: 拥塞控制算法 $congestion_control 和队列规则 $qdisc"
    apply_sysctl $congestion_control $qdisc
}

# 写 sysctl 配置文件
write_sysctl_conf() {
    local congestion_control=$1
    local qdisc=$2
    cat > /etc/sysctl.conf << EOF
# /etc/sysctl.conf - 系统变量配置文件
# 作者：周宇航
# 系统优化配置文件
# 2025.1.31

# 文件系统配置
fs.file-max=1024000
fs.inotify.max_user_instances=65536

# 虚拟内存优化
vm.swappiness=1
vm.dirty_ratio=15
vm.dirty_background_ratio=5
vm.overcommit_memory=1
vm.min_free_kbytes=65536
vm.vfs_cache_pressure=50

# 网络优化配置
net.core.rps_sock_flow_entries=32768
net.ipv4.tcp_no_metrics_save=1
net.ipv4.tcp_ecn=0
net.ipv4.tcp_frto=0
net.ipv4.tcp_mtu_probing=0
net.ipv4.tcp_rfc1337=0
net.ipv4.tcp_sack=1
net.ipv4.tcp_fack=1
net.ipv4.tcp_window_scaling=1
net.ipv4.tcp_adv_win_scale=1
net.ipv4.tcp_moderate_rcvbuf=1
net.core.rmem_max=33554432
net.core.wmem_max=33554432
net.core.netdev_max_backlog=32768
net.core.somaxconn=32768
net.ipv4.tcp_rmem=4096 87380 33554432
net.ipv4.tcp_wmem=4096 16384 33554432
net.ipv4.udp_rmem_min=8192
net.ipv4.udp_wmem_min=8192
net.ipv4.tcp_max_syn_backlog=262144
net.ipv4.tcp_tw_reuse=1
net.ipv4.ip_local_port_range=1024 65535
net.ipv4.tcp_pacing_ca_ratio=110
net.ipv4.ip_forward=1
net.ipv4.conf.all.route_localnet=1
net.ipv4.conf.all.forwarding=1
net.ipv4.conf.default.forwarding=1
net.ipv6.conf.all.forwarding=1
net.ipv6.conf.default.forwarding=1
net.ipv6.conf.lo.forwarding=1
net.ipv6.conf.all.disable_ipv6=0
net.ipv6.conf.default.disable_ipv6=0
net.ipv6.conf.lo.disable_ipv6=0
net.ipv6.conf.all.accept_ra=2
net.ipv6.conf.default.accept_ra=2

# TCP优化
net.ipv4.tcp_syncookies=1
net.ipv4.tcp_retries1=3
net.ipv4.tcp_retries2=8
net.ipv4.tcp_syn_retries=2
net.ipv4.tcp_synack_retries=2
net.ipv4.tcp_fin_timeout=15
net.ipv4.tcp_max_tw_buckets=32768
net.ipv4.tcp_notsent_lowat=131072
net.ipv4.tcp_keepalive_time=600
net.ipv4.tcp_keepalive_probes=5
net.ipv4.tcp_keepalive_intvl=15
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_autocorking=0
net.ipv4.tcp_slow_start_after_idle=0

# 路由和ARP优化
net.ipv4.route.gc_timeout=100
net.ipv4.neigh.default.gc_stale_time=60
net.ipv4.neigh.default.gc_thresh1=1024
net.ipv4.neigh.default.gc_thresh2=4096
net.ipv4.neigh.default.gc_thresh3=8192
net.ipv6.neigh.default.gc_thresh1=1024
net.ipv6.neigh.default.gc_thresh2=4096
net.ipv6.neigh.default.gc_thresh3=8192

# 连接跟踪
net.netfilter.nf_conntrack_max=262144
net.nf_conntrack_max=262144
net.netfilter.nf_conntrack_tcp_timeout_established=36000

# CPU 优化
kernel.sched_autogroup_enabled=0
kernel.numa_balancing=0

# BBR 配置
net.core.default_qdisc=$qdisc  
net.ipv4.tcp_congestion_control=$congestion_control  

EOF

    # 将配置复制到 /etc/sysctl.d/99-sysctl.conf
    cp /etc/sysctl.conf /etc/sysctl.d/99-sysctl.conf
}

# 启动菜单
menu
