# UDM-SE mihomo 透明代理部署方案

## 环境
- UDM-SE, UniFi OS 5.0.12
- Debian 11 Bullseye (aarch64)
- systemd + on_boot.d
- 数据目录: /data/

## 架构
```
设备 → UDM-SE (mihomo)
        ├─ 国内 (geoip:cn + geosite:cn) → 直连
        ├─ *.hen-ladon.ts.net → Tailscale MagicDNS (100.100.100.100)
        └─ 国外 → Clash 订阅节点
```

## 部署步骤

### 1. 下载 mihomo
```bash
mkdir -p /data/mihomo
cd /data/mihomo

# 下载最新 mihomo linux-arm64
wget https://github.com/MetaCubeX/mihomo/releases/latest/download/mihomo-linux-arm64-v1.19.0.gz
gunzip mihomo-linux-arm64-v1.19.0.gz
mv mihomo-linux-arm64-v1.19.0 mihomo
chmod +x mihomo

# 下载规则数据
wget -O geoip.dat https://github.com/MetaCubeX/meta-rules-dat/releases/latest/download/geoip.dat
wget -O geosite.dat https://github.com/MetaCubeX/meta-rules-dat/releases/latest/download/geosite.dat
wget -O country.mmdb https://github.com/MetaCubeX/meta-rules-dat/releases/latest/download/country.mmdb
```

### 2. 配置文件
见 `config.yaml`

### 3. systemd 服务
见 `mihomo.service`

### 4. on_boot 脚本
见 `20-mihomo.sh`

### 5. 部署命令
```bash
# 复制配置
cp config.yaml /data/mihomo/
cp mihomo.service /etc/systemd/system/
cp 20-mihomo.sh /data/on_boot.d/
chmod +x /data/on_boot.d/20-mihomo.sh

# 启动
systemctl daemon-reload
systemctl enable --now mihomo

# 验证
systemctl status mihomo
curl -x http://127.0.0.1:7890 https://www.google.com
```

### 6. UDM-SE 网络设置
- DHCP DNS 改为 UDM-SE 自身 IP（mihomo 监听 53 端口）
- 或在 UniFi 控制面板设置 LAN DNS 为 127.0.0.1
