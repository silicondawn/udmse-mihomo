#!/bin/bash
# UDM-SE mihomo 一键部署脚本
# 在 UDM-SE 上执行: bash deploy.sh
set -e

MIHOMO_DIR="/data/mihomo"
VERSION="v1.19.10"  # 按需更新版本号

echo "=== 1. 创建目录 ==="
mkdir -p ${MIHOMO_DIR}/providers

echo "=== 2. 下载 mihomo ==="
cd ${MIHOMO_DIR}
if [ ! -f mihomo ]; then
    curl -Lo mihomo.gz "https://github.com/MetaCubeX/mihomo/releases/download/${VERSION}/mihomo-linux-arm64-${VERSION}.gz"
    gunzip mihomo.gz
    chmod +x mihomo
    echo "mihomo 下载完成"
else
    echo "mihomo 已存在，跳过下载"
fi

echo "=== 3. 下载规则数据 ==="
curl -Lo geoip.dat https://github.com/MetaCubeX/meta-rules-dat/releases/latest/download/geoip.dat
curl -Lo geosite.dat https://github.com/MetaCubeX/meta-rules-dat/releases/latest/download/geosite.dat
curl -Lo country.mmdb https://github.com/MetaCubeX/meta-rules-dat/releases/latest/download/country.mmdb
echo "规则数据下载完成"

echo "=== 4. 下载 Yacd-Meta 面板 ==="
mkdir -p ${MIHOMO_DIR}/ui
curl -Lo /tmp/yacd-meta.tar.gz https://github.com/DustinWin/proxy-tools/releases/download/Dashboard/Yacd-meta.tar.gz
tar xzf /tmp/yacd-meta.tar.gz -C ${MIHOMO_DIR}/ui/
rm -f /tmp/yacd-meta.tar.gz
echo "面板下载完成"

echo "=== 5. 检查配置文件 ==="
if [ ! -f config.yaml ]; then
    echo "❌ 请先将 config.yaml 放到 ${MIHOMO_DIR}/"
    exit 1
fi

if grep -q "YOUR_CLASH_SUBSCRIPTION_URL_HERE" config.yaml; then
    echo "⚠️  请先编辑 config.yaml，替换订阅 URL"
    exit 1
fi

echo "=== 6. 安装 systemd 服务 ==="
cp mihomo.service /etc/systemd/system/ 2>/dev/null || cp ${MIHOMO_DIR}/mihomo.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable mihomo

echo "=== 7. 安装 on_boot 脚本 ==="
cp /data/on_boot.d/20-mihomo.sh /data/on_boot.d/ 2>/dev/null || true
chmod +x /data/on_boot.d/20-mihomo.sh

echo "=== 8. 启动 mihomo ==="
systemctl start mihomo
sleep 2

if systemctl is-active --quiet mihomo; then
    echo "✅ mihomo 启动成功！"
    echo ""
    echo "=== 9. 应用 TProxy 规则 ==="
    bash /data/on_boot.d/20-mihomo.sh
    echo ""
    echo "✅ 部署完成！"
    echo ""
    echo "📋 后续步骤:"
    echo "  1. 管理面板: http://$(hostname -I | awk '{print $1}'):9090"
    echo "  2. 在 UniFi 控制面板将 LAN DHCP DNS 改为 UDM-SE 的 IP"
    echo "  3. 测试: curl -x http://127.0.0.1:7890 https://www.google.com"
    echo ""
    echo "=== 10. 安装 watchdog ==="
    cp ${MIHOMO_DIR}/mihomo-watchdog.sh ${MIHOMO_DIR}/mihomo-watchdog.sh 2>/dev/null
    chmod +x ${MIHOMO_DIR}/mihomo-watchdog.sh
    cp ${MIHOMO_DIR}/mihomo-watchdog.service /etc/systemd/system/
    cp ${MIHOMO_DIR}/mihomo-watchdog.timer /etc/systemd/system/
    systemctl daemon-reload
    systemctl enable --now mihomo-watchdog.timer
    echo "✅ watchdog 已启动（每2分钟检查）"
    echo "   mihomo 挂了会自动清除 TProxy 规则恢复直连，并尝试重启"
else
    echo "❌ mihomo 启动失败，检查日志:"
    echo "  journalctl -u mihomo -n 50"
fi
