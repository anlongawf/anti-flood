#!/bin/bash
# ==========================================================
# 🗑️ ANTI-DDOS UNINSTALLER (ALL-IN-ONE)
# Phục hồi hệ thống về trạng thái ban đầu sạch sẽ.
# ==========================================================

# Kiểm tra quyền root
if [[ $EUID -ne 0 ]]; then
   echo -e "\033[1;31m[✘] Vui lòng chạy với quyền sudo hoặc root!\033[0m"
   exit 1
fi

echo -e "\033[1;36m[+] ĐANG BẮT ĐẦU QUÁ TRÌNH GỠ CÀI ĐẶT TOÀN DIỆN...\033[0m"

# 1. DỪNG VÀ GỠ BỎ SERVICES (GUARDIAN & XDP)
echo -e "\n[1/5] Đang xử lý các dịch vụ chạy ngầm..."
# XDP Service
if systemctl is-active --quiet xdpfw.service; then
    systemctl stop xdpfw.service
    systemctl disable xdpfw.service
    echo "      -> Đã dừng xdpfw.service"
fi
rm -f /etc/systemd/system/xdpfw.service

# Guardian/Watcher Service
if systemctl is-active --quiet antiddos-watcher.service; then
    systemctl stop antiddos-watcher.service
    systemctl disable antiddos-watcher.service
    echo "      -> Đã dừng antiddos-watcher.service"
fi
rm -f /etc/systemd/system/antiddos-watcher.service
rm -f /usr/local/bin/antiddos_watcher.sh

pkill -f "guardian.sh|watcher_v3.sh|antiddos_watcher.sh" 2>/dev/null
systemctl daemon-reload

# 2. GỠ BỎ FAIL2BAN (QUAN TRỌNG)
echo -e "[2/5] Đang gỡ bỏ cấu hình Fail2Ban XDP..."
if [ -f /etc/fail2ban/jail.d/xdpfw.local ]; then
    rm -f /etc/fail2ban/jail.d/xdpfw.local
    rm -f /etc/fail2ban/filter.d/xdpfw-filter.conf
    rm -f /etc/fail2ban/action.d/xdpfw-action.conf
    systemctl restart fail2ban 2>/dev/null
    echo "      -> Đã dọn dẹp Jail/Filter/Action của Fail2Ban."
fi

# 3. GỠ BỎ CRONJOBS (MONITOR & GEOIP & REPORT)
echo -e "[3/5] Đang dọn dẹp các lịch trình tự động (Cronjobs)..."
# Lưu crontab hiện tại, xóa các dòng liên quan và nạp lại
crontab -l 2>/dev/null | grep -v -E "antiddos_monitor.sh|update-geoip.sh|alerts.sh|watcher_v3.sh|discord_report.sh" | crontab -
echo "      -> Đã xóa các lịch trình Monitor, GeoIP và Discord Report."

# 4. DỌN DEP TỆP TIN VÀ CẤU HÌNH NHÂN (KERNEL)
echo -e "[4/5] Đang xóa các tệp cấu hình và script hệ thống..."
rm -f /usr/local/bin/antiddos_monitor.sh
rm -f /usr/local/bin/xdpfw
rm -f /usr/local/bin/xdpfw-add
rm -f /usr/local/bin/xdpfw-del
rm -rf /etc/antiddos_zones
rm -rf /etc/xdpfw
rm -f /etc/sysctl.d/99-antiddos-mc.conf
rm -f /tmp/antiddos_failsafe.pid
rm -f /tmp/antiddos_last_ports.txt
rm -f /tmp/antiddos_last_hash.txt

# Reset cấu hình nhân nếu tệp cấu hình tồn tại
if [ -f /etc/sysctl.d/99-antiddos-mc.conf ]; then
    rm -f /etc/sysctl.d/99-antiddos-mc.conf
    echo "      -> Đã gỡ bỏ tinh chỉnh Kernel (99-antiddos-mc.conf)."
fi
sysctl --system >/dev/null 2>&1

# 5. GIẢI PHÓNG FIREWALL (NFTABLES & IPTABLES)
echo -e "[5/5] Đang giải phóng các bộ lọc mạng (Firewall)..."
# Xóa bảng Nftables XDP và Bypass
nft delete table netdev antiddos_v2 2>/dev/null
nft delete table ip raw_bypass 2>/dev/null
# Flush Iptables
iptables -F INPUT 2>/dev/null
iptables -F DOCKER-USER 2>/dev/null

# Xóa ipset nếu tồn tại
if ipset list allow_countries >/dev/null 2>&1; then
    ipset destroy allow_countries
    echo "      -> Đã xóa ipset allow_countries."
fi

# Lưu lại trạng thái sạch nếu có netfilter-persistent
if command -v netfilter-persistent &> /dev/null; then
    netfilter-persistent save >/dev/null 2>&1
    echo "      -> Đã lưu lại trạng thái Firewall sạch."
fi

# Gỡ XDP khỏi interface (Nên làm để giải phóng Driver)
INTERFACE=$(ip -o -4 route get 8.8.8.8 | sed -nr 's/.*dev ([^ ]+).*/\1/p' 2>/dev/null)
if [ -n "$INTERFACE" ]; then
    ip link set dev "$INTERFACE" xdp off 2>/dev/null
    echo "      -> Đã gỡ bỏ XDP khỏi interface $INTERFACE."
fi

echo -e "\n\033[1;32m[✔] HOÀN TẤT GỠ CÀI ĐẶT TOÀN DIỆN (V1, V2, V3)!\033[0m"
echo -e "Hệ thống của bạn đã trở về trạng thái mặc định ban đầu."
echo -e "Cảm ơn bạn đã sử dụng dịch vụ!\n"
