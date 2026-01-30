#!/bin/bash
# ============================================================
#  UDM-SE mihomo 透明代理一键安装脚本
#  项目: https://github.com/silicondawn/udmse-mihomo
#
#  用法: bash <(curl -sL https://raw.githubusercontent.com/silicondawn/udmse-mihomo/main/install.sh)
#
#  ⚠️ 未经完整测试，使用风险自负
# ============================================================

set -e

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

MIHOMO_DIR="/data/mihomo"
ONBOOT_DIR="/data/on_boot.d"
REPO_RAW="https://raw.githubusercontent.com/silicondawn/udmse-mihomo/main"
MIHOMO_VERSION="v1.19.10"

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
step()  { echo -e "\n${CYAN}==== $1 ====${NC}"; }

# ============================================================
# 前置检查
# ============================================================
step "环境检查"

# root 权限
[ "$(id -u)" -ne 0 ] && error "请用 root 运行此脚本"

# 架构
ARCH=$(uname -m)
case "$ARCH" in
    aarch64|arm64) MIHOMO_ARCH="arm64" ;;
    x86_64|amd64)  MIHOMO_ARCH="amd64" ;;
    *) error "不支持的架构: $ARCH" ;;
esac
info "架构: $ARCH → mihomo-linux-${MIHOMO_ARCH}"

# 系统
if [ -f /etc/os-release ]; then
    . /etc/os-release
    info "系统: $PRETTY_NAME"
else
    warn "无法检测系统版本"
fi

# 必要工具
for cmd in curl systemctl iptables ip; do
    if ! command -v $cmd &>/dev/null; then
        error "缺少必要工具: $cmd"
    fi
done
info "必要工具: ✅ curl, systemctl, iptables, ip"

# on_boot.d
if [ ! -d "$ONBOOT_DIR" ]; then
    warn "$ONBOOT_DIR 不存在，将创建"
    mkdir -p "$ONBOOT_DIR"
fi
info "on_boot.d: ✅"

# ============================================================
# 检查是否已安装
# ============================================================
if [ -f "${MIHOMO_DIR}/mihomo" ]; then
    CURRENT_VER=$(${MIHOMO_DIR}/mihomo -v 2>&1 | head -1 || echo "unknown")
    warn "检测到已安装的 mihomo: $CURRENT_VER"
    echo -en "${YELLOW}是否覆盖安装？(y/N): ${NC}"
    read -r REPLY
    [ "$REPLY" != "y" ] && [ "$REPLY" != "Y" ] && { info "已取消"; exit 0; }
    # 停止现有服务
    systemctl stop mihomo 2>/dev/null || true
fi

# ============================================================
# 创建目录
# ============================================================
step "创建目录"
mkdir -p "${MIHOMO_DIR}/providers"
info "目录: ${MIHOMO_DIR}"

# ============================================================
# 下载 mihomo
# ============================================================
step "下载 mihomo ${MIHOMO_VERSION}"
MIHOMO_URL="https://github.com/MetaCubeX/mihomo/releases/download/${MIHOMO_VERSION}/mihomo-linux-${MIHOMO_ARCH}-${MIHOMO_VERSION}.gz"
info "下载: $MIHOMO_URL"
curl -Lo "${MIHOMO_DIR}/mihomo.gz" "$MIHOMO_URL" || error "下载 mihomo 失败"
gunzip -f "${MIHOMO_DIR}/mihomo.gz"
chmod +x "${MIHOMO_DIR}/mihomo"
info "mihomo: $(${MIHOMO_DIR}/mihomo -v 2>&1 | head -1)"

# ============================================================
# 下载规则数据
# ============================================================
step "下载规则数据"
cd "${MIHOMO_DIR}"
curl -Lo geoip.dat   https://github.com/MetaCubeX/meta-rules-dat/releases/latest/download/geoip.dat   || warn "geoip.dat 下载失败"
curl -Lo geosite.dat https://github.com/MetaCubeX/meta-rules-dat/releases/latest/download/geosite.dat || warn "geosite.dat 下载失败"
curl -Lo country.mmdb https://github.com/MetaCubeX/meta-rules-dat/releases/latest/download/country.mmdb || warn "country.mmdb 下载失败"
info "规则数据: ✅"

# ============================================================
# 下载 Yacd-Meta 面板
# ============================================================
step "下载 Yacd-Meta 面板"
mkdir -p "${MIHOMO_DIR}/ui"
curl -Lo /tmp/yacd-meta.tar.gz https://github.com/DustinWin/proxy-tools/releases/download/Dashboard/Yacd-meta.tar.gz || warn "面板下载失败"
if [ -f /tmp/yacd-meta.tar.gz ]; then
    tar xzf /tmp/yacd-meta.tar.gz -C "${MIHOMO_DIR}/ui/"
    rm -f /tmp/yacd-meta.tar.gz
    info "面板: ✅"
else
    warn "面板下载失败，跳过（不影响核心功能）"
fi

# ============================================================
# 下载配置文件
# ============================================================
step "下载配置文件"

# 主配置（仅在不存在时下载，避免覆盖用户配置）
if [ ! -f "${MIHOMO_DIR}/config.yaml" ]; then
    curl -Lo "${MIHOMO_DIR}/config.yaml" "${REPO_RAW}/config.yaml" || error "配置文件下载失败"
    info "config.yaml: ✅ (新下载)"
else
    info "config.yaml: 已存在，跳过（保留用户配置）"
fi

# systemd service
curl -Lo "${MIHOMO_DIR}/mihomo.service" "${REPO_RAW}/mihomo.service" || error "service 文件下载失败"
info "mihomo.service: ✅"

# on_boot 脚本
curl -Lo "${MIHOMO_DIR}/20-mihomo.sh" "${REPO_RAW}/20-mihomo.sh" || error "on_boot 脚本下载失败"
chmod +x "${MIHOMO_DIR}/20-mihomo.sh"
info "20-mihomo.sh: ✅"

# watchdog
curl -Lo "${MIHOMO_DIR}/mihomo-watchdog.sh" "${REPO_RAW}/mihomo-watchdog.sh" || error "watchdog 下载失败"
chmod +x "${MIHOMO_DIR}/mihomo-watchdog.sh"
curl -Lo "${MIHOMO_DIR}/mihomo-watchdog.service" "${REPO_RAW}/mihomo-watchdog.service" || error "watchdog service 下载失败"
curl -Lo "${MIHOMO_DIR}/mihomo-watchdog.timer" "${REPO_RAW}/mihomo-watchdog.timer" || error "watchdog timer 下载失败"
info "watchdog: ✅"

# ============================================================
# 配置订阅 URL
# ============================================================
step "配置订阅"
if grep -q "YOUR_CLASH_SUBSCRIPTION_URL_HERE" "${MIHOMO_DIR}/config.yaml"; then
    echo ""
    echo -e "${YELLOW}请输入你的 Clash 订阅 URL（直接回车跳过，稍后手动编辑）:${NC}"
    read -r SUB_URL
    if [ -n "$SUB_URL" ]; then
        sed -i "s|YOUR_CLASH_SUBSCRIPTION_URL_HERE|${SUB_URL}|g" "${MIHOMO_DIR}/config.yaml"
        info "订阅 URL 已写入"
    else
        warn "跳过订阅配置，请稍后编辑: ${MIHOMO_DIR}/config.yaml"
    fi
fi

# ============================================================
# 安装 systemd 服务
# ============================================================
step "安装服务"
cp "${MIHOMO_DIR}/mihomo.service" /etc/systemd/system/
cp "${MIHOMO_DIR}/mihomo-watchdog.service" /etc/systemd/system/
cp "${MIHOMO_DIR}/mihomo-watchdog.timer" /etc/systemd/system/
systemctl daemon-reload
systemctl enable mihomo
systemctl enable mihomo-watchdog.timer
info "systemd 服务: ✅"

# ============================================================
# 安装 on_boot 脚本
# ============================================================
step "安装 on_boot 脚本"
cp "${MIHOMO_DIR}/20-mihomo.sh" "${ONBOOT_DIR}/20-mihomo.sh"
chmod +x "${ONBOOT_DIR}/20-mihomo.sh"
info "on_boot: ✅"

# ============================================================
# 启动
# ============================================================
step "启动 mihomo"

# 检查订阅是否已配置
if grep -q "YOUR_CLASH_SUBSCRIPTION_URL_HERE" "${MIHOMO_DIR}/config.yaml"; then
    warn "订阅 URL 未配置，mihomo 暂不启动"
    echo ""
    echo -e "${YELLOW}请手动配置后启动:${NC}"
    echo "  1. 编辑配置: nano ${MIHOMO_DIR}/config.yaml"
    echo "  2. 替换 YOUR_CLASH_SUBSCRIPTION_URL_HERE 为你的订阅 URL"
    echo "  3. 启动: systemctl start mihomo"
    echo "  4. 应用 TProxy: bash ${ONBOOT_DIR}/20-mihomo.sh"
else
    systemctl start mihomo
    sleep 3
    if systemctl is-active --quiet mihomo; then
        info "mihomo 启动成功！"
        # 应用 TProxy
        bash "${ONBOOT_DIR}/20-mihomo.sh"
        # 启动 watchdog
        systemctl start mihomo-watchdog.timer
    else
        error "mihomo 启动失败，请检查: journalctl -u mihomo -n 50"
    fi
fi

# ============================================================
# 完成
# ============================================================
step "安装完成 🎉"
echo ""
LAN_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "<UDM-SE-IP>")
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  mihomo 透明代理已安装${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  📁 配置目录:  ${CYAN}${MIHOMO_DIR}${NC}"
echo -e "  📝 配置文件:  ${CYAN}${MIHOMO_DIR}/config.yaml${NC}"
echo -e "  🌐 管理面板:  ${CYAN}http://${LAN_IP}:9090/ui${NC}"
echo -e "  📊 API:       ${CYAN}http://${LAN_IP}:9090${NC}"
echo -e "  🔧 HTTP 代理: ${CYAN}${LAN_IP}:7890${NC}"
echo ""
echo -e "  ${YELLOW}后续步骤:${NC}"
echo -e "  1. 在 UniFi 控制面板将 LAN DHCP 的 DNS 改为 ${LAN_IP}"
echo -e "  2. 访问管理面板查看节点状态"
echo -e "  3. 测试: curl -x http://127.0.0.1:7890 https://www.google.com"
echo ""
echo -e "  ${YELLOW}常用命令:${NC}"
echo -e "  查看状态:  systemctl status mihomo"
echo -e "  查看日志:  journalctl -u mihomo -f"
echo -e "  重启服务:  systemctl restart mihomo"
echo -e "  停止服务:  systemctl stop mihomo"
echo -e "  编辑配置:  nano ${MIHOMO_DIR}/config.yaml"
echo ""
echo -e "  ${RED}卸载:${NC} bash <(curl -sL ${REPO_RAW}/uninstall.sh)"
echo ""
