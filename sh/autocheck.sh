#!/bin/bash

# 列出所有网卡，排除lo网卡
echo "可用的网络接口（排除'lo'）："
interfaces=$(ip link show | grep -v lo | grep -oP '(?<=: ).*?(?=:)' | awk '{print $1}')
i=1
for iface in $interfaces; do
  echo "$i) $iface"
  i=$((i+1))
done

# 默认网卡设定为 ens5
default_interface="ens5"
default_choice=1
i=1
for iface in $interfaces; do
  if [ "$iface" == "$default_interface" ]; then
    default_choice=$i
  fi
  i=$((i+1))
done

# 让用户选择网卡
read -p "请输入要监控的网络接口编号（默认 $default_choice）：" interface_choice
interface_choice=${interface_choice:-$default_choice}

# 获取用户选择的网卡名
interface_name=$(echo "$interfaces" | sed -n "${interface_choice}p")
if [ -z "$interface_name" ]; then
  echo "错误：无效的选择。"
  exit 1
fi

# 提示输入每月起始日期，设默认值为1
read -p "请输入每月监控的起始日期（1-31，默认 1）：" month_start_day
month_start_day=${month_start_day:-1}

# 检查起始日期是否在合理范围内
if ! [[ "$month_start_day" =~ ^[1-9]$|^[12][0-9]$|^3[01]$ ]]; then
  echo "错误：无效的每月起始日期。"
  exit 1
fi

# 提示输入流量上限，默认为1TB
read -p "请输入流量上限（单位TB，默认 1）：" traffic_limit
traffic_limit=${traffic_limit:-1}

# 检查流量上限是否是正数
if ! [[ "$traffic_limit" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  echo "错误：无效的流量上限。"
  exit 1
fi

# 转换流量上限为GB
traffic_limit_gb=$(echo "$traffic_limit * 1024" | bc)

# 更新vnstat配置
sudo sed -i.bak "/^Interface/d" /etc/vnstat.conf
sudo sed -i "/^MonthRotate/d" /etc/vnstat.conf
echo "Interface \"$interface_name\"" | sudo tee -a /etc/vnstat.conf
echo "MonthRotate $month_start_day" | sudo tee -a /etc/vnstat.conf
sudo systemctl restart vnstat

# 自动关机脚本
cat << 'EOF' > check.sh
#!/bin/bash
interface_name="$1"
traffic_limit_gb="$2"

# 更新网卡记录
vnstat -i "$interface_name"
# 获取每月用量 $11:进站+出站
ax=$(vnstat --oneline | awk -F ";" '{print $11}')
log_file="/tmp/cron_shutdown_debug.log"

echo "$(date): 检查 $interface_name 的流量，当前用量：$ax" >> "$log_file"

# 如果每月用量单位是GB则进入
if [[ "$ax" == *GB* ]]; then
  # 每月实际流量数除以流量阈值，大于或等于1，则执行关机命令
  usage=$(echo "$ax" | sed 's/ GB//g')
  if (( $(echo "$usage >= $traffic_limit_gb" | bc -l) )); then
    echo "$(date): 流量上限超出，执行关机。" >> "$log_file"
    sudo /usr/sbin/shutdown -h now
  else
    echo "$(date): 流量在限制范围内。" >> "$log_file"
  fi
else
  echo "$(date): 流量单位不是GB，跳过检查。" >> "$log_file"
fi
EOF

# 授予执行权限
chmod +x check.sh

# 设置定时任务，每5分钟执行一次检查
(crontab -l 2>/dev/null; echo "*/5 * * * * /bin/bash $(pwd)/check.sh $interface_name $traffic_limit_gb > /tmp/cron_shutdown_debug.log 2>&1") | crontab -

echo "设置完成！"
