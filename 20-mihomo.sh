#!/bin/bash
# UDM-SE on_boot.d - mihomo 透明代理
# 放置位置: /data/on_boot.d/20-mihomo.sh

MIHOMO_DIR="/data/mihomo"
MIHOMO_BIN="${MIHOMO_DIR}/mihomo"

# 确保 service 文件存在（防固件更新覆盖）
if [ ! -f /etc/systemd/system/mihomo.service ]; then
    cp ${MIHOMO_DIR}/mihomo.service /etc/systemd/system/
    systemctl daemon-reload
fi

# 启动 mihomo
systemctl enable --now mihomo

# 等待 mihomo 启动
sleep 3

# ========== TProxy iptables 规则 ==========

# 清理旧规则
iptables -t mangle -D PREROUTING -j MIHOMO_PREROUTING 2>/dev/null
iptables -t mangle -F MIHOMO_PREROUTING 2>/dev/null
iptables -t mangle -X MIHOMO_PREROUTING 2>/dev/null

# 创建链
iptables -t mangle -N MIHOMO_PREROUTING

# 跳过本地/内网地址
iptables -t mangle -A MIHOMO_PREROUTING -d 0.0.0.0/8 -j RETURN
iptables -t mangle -A MIHOMO_PREROUTING -d 10.0.0.0/8 -j RETURN
iptables -t mangle -A MIHOMO_PREROUTING -d 100.64.0.0/10 -j RETURN  # Tailscale
iptables -t mangle -A MIHOMO_PREROUTING -d 127.0.0.0/8 -j RETURN
iptables -t mangle -A MIHOMO_PREROUTING -d 169.254.0.0/16 -j RETURN
iptables -t mangle -A MIHOMO_PREROUTING -d 172.16.0.0/12 -j RETURN
iptables -t mangle -A MIHOMO_PREROUTING -d 192.168.0.0/16 -j RETURN
iptables -t mangle -A MIHOMO_PREROUTING -d 224.0.0.0/4 -j RETURN
iptables -t mangle -A MIHOMO_PREROUTING -d 240.0.0.0/4 -j RETURN

# TCP + UDP 流量标记并重定向到 TProxy
iptables -t mangle -A MIHOMO_PREROUTING -p tcp -j TPROXY --on-port 7893 --tproxy-mark 1
iptables -t mangle -A MIHOMO_PREROUTING -p udp -j TPROXY --on-port 7893 --tproxy-mark 1

# 挂载到 PREROUTING
iptables -t mangle -A PREROUTING -j MIHOMO_PREROUTING

# 策略路由
ip rule del fwmark 1 table 100 2>/dev/null
ip rule add fwmark 1 table 100
ip route replace local 0.0.0.0/0 dev lo table 100

echo "[on_boot] mihomo started with TProxy rules"
