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

# 1. DỪNG VÀ GỠ BỎ SERVICES (GUARDIAN)
echo -e "\n[1/5] Đang xử lý các dịch vụ chạy ngầm..."
if systemctl is-active --quiet antiddos-guardian.service; then
    systemctl stop antiddos-guardian.service
    systemctl disable antiddos-guardian.service
    echo "      -> Đã dừng antiddos-guardian.service"
fi
rm -f /etc/systemd/system/antiddos-guardian.service
pkill -f guardian.sh 2>/dev/null
systemctl daemon-reload

# 2. GỠ BỎ CRONJOBS (MONITOR & GEOIP)
echo -e "[2/5] Đang dọn dẹp các lịch trình tự động (Cronjobs)..."
# Lưu crontab hiện tại, xóa các dòng liên quan và nạp lại
crontab -l 2>/dev/null | grep -v -E "antiddos_monitor.sh|update-geoip.sh|alerts.sh" | crontab -
echo "      -> Đã xóa các lịch trình Monitor và GeoIP."

# 3. DỌN DEP TỆP TIN VÀ CẤU HÌNH NHÂN (KERNEL)
echo -e "[3/5] Đang xóa các tệp cấu hình và script hệ thống..."
rm -f /usr/local/bin/antiddos_monitor.sh
rm -rf /etc/antiddos_zones
rm -f /etc/sysctl.d/99-antiddos-mc.conf
rm -f /tmp/antiddos_failsafe.pid
rm -f /tmp/antiddos_last_ports.txt
rm -f /tmp/antiddos_last_ports.txt

# Reset cấu hình nhân nếu tệp cấu hình tồn tại
if [ -f /etc/sysctl.d/99-antiddos-mc.conf ]; then
    rm -f /etc/sysctl.d/99-antiddos-mc.conf
    echo "      -> Đã gỡ bỏ tinh chỉnh Kernel (99-antiddos-mc.conf)."
fi
sysctl --system >/dev/null 2>&1

# 4. GIẢI PHÓNG FIREWALL NFTABLES (V2)
echo -e "[4/5] Đang xóa bỏ các bảng Nftables (V2)..."
nft delete table netdev antiddos_v2 2>/dev/null
nft delete table ip raw_bypass 2>/dev/null
echo "      -> Đã xóa bảng Nftables Ingress và Raw Bypass."

# 5. GIẢI PHÓNG FIREWALL IPTABLES & IPSET (V1)
echo -e "[5/5] Đang dọn dẹp Iptables và Ipset (V1)..."
# Flush các chain chính liên quan
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

echo -e "\n\033[1;32m[✔] HOÀN TẤT GỠ CÀI ĐẶT!\033[0m"
echo -e "Hệ thống của bạn đã trở về trạng thái mặc định ban đầu."
echo -e "Cảm ơn bạn đã sử dụng dịch vụ!\n"
