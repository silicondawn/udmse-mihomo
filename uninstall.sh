#!/bin/bash
# ============================================================
#  UDM-SE mihomo 卸载脚本
#  用法: bash <(curl -sL https://raw.githubusercontent.com/silicondawn/udmse-mihomo/main/uninstall.sh)
# ============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

MIHOMO_DIR="/data/mihomo"

echo -e "${RED}⚠️  即将卸载 mihomo 透明代理${NC}"
echo -e "这将停止服务、清除 iptables 规则、删除所有文件"
echo -en "${YELLOW}确认卸载？(y/N): ${NC}"
read -r REPLY
[ "$REPLY" != "y" ] && [ "$REPLY" != "Y" ] && { echo "已取消"; exit 0; }

echo ""

# 停止服务
echo -e "${GREEN}[1/5]${NC} 停止服务..."
systemctl stop mihomo-watchdog.timer 2>/dev/null || true
systemctl stop mihomo 2>/dev/null || true
systemctl disable mihomo-watchdog.timer 2>/dev/null || true
systemctl disable mihomo 2>/dev/null || true

# 清除 systemd
echo -e "${GREEN}[2/5]${NC} 清除 systemd 服务..."
rm -f /etc/systemd/system/mihomo.service
rm -f /etc/systemd/system/mihomo-watchdog.service
rm -f /etc/systemd/system/mihomo-watchdog.timer
systemctl daemon-reload

# 清除 iptables
echo -e "${GREEN}[3/5]${NC} 清除 iptables 规则..."
iptables -t mangle -D PREROUTING -j MIHOMO_PREROUTING 2>/dev/null || true
iptables -t mangle -F MIHOMO_PREROUTING 2>/dev/null || true
iptables -t mangle -X MIHOMO_PREROUTING 2>/dev/null || true
ip rule del fwmark 1 table 100 2>/dev/null || true
ip route del local 0.0.0.0/0 dev lo table 100 2>/dev/null || true

# 删除 on_boot
echo -e "${GREEN}[4/5]${NC} 删除 on_boot 脚本..."
rm -f /data/on_boot.d/20-mihomo.sh

# 删除文件
echo -e "${GREEN}[5/5]${NC} 删除 mihomo 文件..."
echo -en "${YELLOW}是否保留配置文件 config.yaml？(Y/n): ${NC}"
read -r KEEP
if [ "$KEEP" = "n" ] || [ "$KEEP" = "N" ]; then
    rm -rf "${MIHOMO_DIR}"
    echo "已删除全部文件"
else
    # 只保留 config.yaml
    TMPCONF=$(mktemp)
    cp "${MIHOMO_DIR}/config.yaml" "$TMPCONF" 2>/dev/null || true
    rm -rf "${MIHOMO_DIR}"
    mkdir -p "${MIHOMO_DIR}"
    mv "$TMPCONF" "${MIHOMO_DIR}/config.yaml" 2>/dev/null || true
    echo "已保留 ${MIHOMO_DIR}/config.yaml"
fi

echo ""
echo -e "${GREEN}✅ mihomo 已完全卸载${NC}"
echo -e "${YELLOW}提示: 请在 UniFi 控制面板将 DNS 设置改回默认${NC}"
