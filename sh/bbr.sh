#!/bin/bash
# 系统优化脚本
# 作者：周宇航

# 显示系统信息
get_system_info() {
    echo "====== 系统信息 ======"
    arch=$(uname -m)
    kern=$(uname -r)
    date=$(date +%Y-%m-%d)
    echo "架构: $arch 内核版本: $kern 日期: $date"
    echo "当前队列规则: $(sysctl net.core.default_qdisc | awk '{print $3}')"
    echo "当前拥塞控制: $(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')"
    echo "====================="
}

# 选择队列算法
select_qdisc() {
    echo "请选择队列算法组合:"
    echo "1. bbr + fq (默认)"
    echo "2. bbr + fq_pie"
    echo "3. bbr + cake"
    read -p "请输入选择 [1-3] (默认1): " choice
    
    case $choice in
        1|"")
            qdisc="fq"
            congestion_control="bbr"
            ;;
        2)
            qdisc="fq_pie"
            congestion_control="bbr"
            ;;
        3)
            qdisc="cake"
            congestion_control="bbr"
            ;;
        *)
            echo "无效选择，使用默认值"
            qdisc="fq"
            congestion_control="bbr"
            ;;
    esac
}

# 生成sysctl配置并应用
generate_sysctl_conf() {
    cat > /etc/sysctl.d/99-sysctl.conf << EOF
# /etc/sysctl.conf - 系统变量配置文件
# 作者：周宇航
# Date: $(date +%Y-%m-%d)

# 文件系统相关配置
fs.file-max=1024000
fs.inotify.max_user_instances=65536

# 内核相关配置
kernel.pid_max=65535
kernel.panic=1
kernel.sysrq=1
kernel.core_pattern=core_%e
kernel.printk=3 4 1 3
kernel.numa_balancing=0
kernel.sched_autogroup_enabled=0

# 虚拟内存相关配置
vm.swappiness=10
vm.dirty_ratio=10
vm.dirty_background_ratio=5
vm.panic_on_oom=1
vm.overcommit_memory=1
vm.min_free_kbytes=153600
vm.vfs_cache_pressure=50

# 网络核心参数配置
net.core.rps_sock_flow_entries=32768
net.core.dev_weight=4096
net.core.netdev_budget=65536
net.core.netdev_budget_usecs=4096
net.core.busy_poll=50
net.core.busy_read=50
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.core.netdev_max_backlog=32768
net.core.somaxconn=4096

# IPv4 TCP 基础参数配置
net.ipv4.tcp_timestamps=1
net.ipv4.tcp_no_metrics_save=0
net.ipv4.tcp_ecn=0
net.ipv4.tcp_frto=0
net.ipv4.tcp_mtu_probing=1
net.ipv4.tcp_rfc1337=0
net.ipv4.tcp_sack=1
net.ipv4.tcp_fack=0
net.ipv4.tcp_window_scaling=1
net.ipv4.tcp_adv_win_scale=2
net.ipv4.tcp_moderate_rcvbuf=1
net.ipv4.tcp_rmem=8192 87380 66060287
net.ipv4.tcp_wmem=8192 65536 33030143
net.ipv4.udp_rmem_min=8192
net.ipv4.udp_wmem_min=8192

# IPv4 TCP 连接管理参数配置
net.ipv4.tcp_max_syn_backlog=4096
net.ipv4.tcp_tw_reuse=1
net.ipv4.ip_local_port_range=1024 65535
net.ipv4.tcp_abort_on_overflow=0
net.ipv4.tcp_max_orphans=65536
net.ipv4.tcp_synack_retries=2
net.ipv4.tcp_syn_retries=3
net.ipv4.tcp_stdurg=0
net.ipv4.conf.all.rp_filter=1
net.ipv4.conf.default.rp_filter=1
net.ipv4.conf.all.arp_announce=2
net.ipv4.conf.default.arp_announce=2
net.ipv4.conf.all.arp_ignore=1
net.ipv4.conf.default.arp_ignore=1

# 文件系统相关配置
fs.file-max=6553560
net.ipv4.tcp_pacing_ca_ratio=110
net.ipv4.ip_forward=1
net.ipv4.conf.all.route_localnet=1
net.ipv4.conf.all.forwarding=1
net.ipv4.conf.default.forwarding=1
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

# IPv4 和 IPv6 路由与邻居参数配置
net.ipv4.route.gc_timeout=100
net.ipv4.neigh.default.gc_stale_time=60
net.ipv4.neigh.default.gc_thresh1=1024
net.ipv4.neigh.default.gc_thresh2=4096
net.ipv4.neigh.default.gc_thresh3=8192
net.ipv6.neigh.default.gc_thresh1=1024
net.ipv6.neigh.default.gc_thresh2=4096
net.ipv6.neigh.default.gc_thresh3=8192

# IPv6 相关配置
net.ipv6.conf.all.forwarding=1
net.ipv6.conf.default.forwarding=1
net.ipv6.conf.lo.forwarding=1
net.ipv6.conf.all.disable_ipv6=0
net.ipv6.conf.default.disable_ipv6=0
net.ipv6.conf.lo.disable_ipv6=0
net.ipv6.conf.all.accept_ra=2
net.ipv6.conf.default.accept_ra=2

# 网络连接跟踪相关配置
net.netfilter.nf_conntrack_max=262144
net.nf_conntrack_max=262144
net.netfilter.nf_conntrack_tcp_timeout_established=36000
net.netfilter.nf_conntrack_tcp_timeout_close_wait=60
net.netfilter.nf_conntrack_tcp_timeout_fin_wait=45

# 内核调度相关配置
kernel.sched_autogroup_enabled=0
kernel.numa_balancing=0

# 最后 BBR 配置
net.core.default_qdisc=$qdisc  
net.ipv4.tcp_congestion_control=$congestion_control  
EOF
    echo "配置已写入 /etc/sysctl.d/99-sysctl.conf"
    sysctl --system
    echo "系统已重新加载配置"
}

# 清理优化
cleanup() {
    clear
    # 清理 sysctl 配置
    rm -f /usr/lib/sysctl.d/99-sysctl.conf
    echo "已清理 /etc/sysctl.d/99-sysctl.conf"
    sysctl --system
    echo "系统已重新加载配置"
}

# 菜单
menu() {
    while true; do
        echo "====== 系统优化菜单 ======"
        echo "1. 应用BBR优化(bbr + fq)"
        echo "2. 自定义优化方案"
        echo "3. 重启系统"
        echo "0. 退出"
        read -p "请输入选项 [0-3]: " option

        case $option in
            1) 
                qdisc="fq"
                congestion_control="bbr"
                generate_sysctl_conf
                ;;
            2) 
                select_qdisc
                generate_sysctl_conf
                ;;
            3) systemctl reboot ;;
            0) exit 0 ;;
            *) echo "无效选项" ;;
        esac
        echo
    done
}

# 显示系统信息
get_system_info
# 启动菜单
menu
