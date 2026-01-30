#!/bin/bash
# mihomo 健康检查 watchdog
# 用法: crontab -e → */2 * * * * /data/mihomo/mihomo-watchdog.sh
# 每2分钟检查一次，mihomo 挂了就清除 iptables 规则恢复直连

LOG="/data/mihomo/watchdog.log"
TPROXY_PORT=7893

check_mihomo() {
    # 检查进程是否存活
    if ! systemctl is-active --quiet mihomo; then
        return 1
    fi
    # 检查代理端口是否可用
    if ! ss -tlnp | grep -q ":${TPROXY_PORT}" ; then
        return 1
    fi
    return 0
}

flush_tproxy() {
    echo "$(date): mihomo DOWN - 清除 TProxy 规则，恢复直连" >> $LOG
    iptables -t mangle -D PREROUTING -j MIHOMO_PREROUTING 2>/dev/null
    iptables -t mangle -F MIHOMO_PREROUTING 2>/dev/null
    iptables -t mangle -X MIHOMO_PREROUTING 2>/dev/null
    ip rule del fwmark 1 table 100 2>/dev/null
    # 恢复 DNS 到公共 DNS（防止解析挂掉）
    echo "nameserver 223.5.5.5" > /etc/resolv.conf
    echo "nameserver 119.29.29.29" >> /etc/resolv.conf
}

restore_tproxy() {
    echo "$(date): mihomo UP - 重新应用 TProxy 规则" >> $LOG
    bash /data/on_boot.d/20-mihomo.sh
}

if check_mihomo; then
    # mihomo 正常，确保 TProxy 规则存在
    if ! iptables -t mangle -L MIHOMO_PREROUTING &>/dev/null; then
        restore_tproxy
    fi
else
    # mihomo 挂了
    flush_tproxy
    # 尝试重启
    echo "$(date): 尝试重启 mihomo..." >> $LOG
    systemctl restart mihomo
    sleep 3
    if check_mihomo; then
        echo "$(date): mihomo 重启成功" >> $LOG
        restore_tproxy
    else
        echo "$(date): mihomo 重启失败，保持直连模式" >> $LOG
    fi
fi
