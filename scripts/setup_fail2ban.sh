#!/bin/bash
# ==========================================================
# 🚨 FAIL2BAN V3: XDP INTEGRATION (GUARDIAN LAYER)
# ==========================================================

echo -e "\033[1;36m[+] Đang cài đặt và kết nối Fail2Ban với XDP-Firewall...\033[0m"

# 1. CÀI ĐẶT FAIL2BAN
apt-get update -y >/dev/null
apt-get install -y fail2ban >/dev/null

# 2. TẠO ACTION: XDP-BAN (Dùng xdpfw-add để tống giam vào BPF Map)
cat << 'EOF' > /etc/fail2ban/action.d/xdpfw-action.conf
[Definition]
# Khi Ban: Thêm vào Blocklist (Mode 2), thời gian hết hạn theo cấu hình Jail
actionban = /usr/local/bin/xdpfw-add --mode 2 --ip <ip> --expires <bantime>

# Khi Unban: Xóa khỏi Blocklist
actionunban = /usr/local/bin/xdpfw-del --mode 2 --ip <ip>
[Init]
EOF

# 3. TẠO FILTER: XDPFW-FILTER (Bóc tách IP từ log XDP)
cat << 'EOF' > /etc/fail2ban/filter.d/xdpfw-filter.conf
[Definition]
# Scan log XDP (Dropped TCP/UDP packet 'IP:PORT')
failregex = Dropped \w+ packet '<HOST>:\d+' =>
ignoreregex =
EOF

# 4. TẠO JAIL: XDPFW-GUARDIAN
# Lấy danh sách Whitelist từ Discovery để nạp vào ignoreip
eval $(bash "$SCRIPT_DIR/discover_v3.sh" --shell)
# Chuyển đổi dấu phẩy trong whitelist thành dấu cách cho Fail2Ban
F2B_IGNORE=$(echo $WHITELIST_IPS | tr ',' ' ')

cat << EOF > /etc/fail2ban/jail.d/xdpfw.local
[xdpfw-guardian]
enabled = true
backend = auto
logpath = /var/log/xdpfw.log
filter = xdpfw-filter
action = xdpfw-action
maxretry = 1
findtime = 600
bantime = 3600
# Danh sách IP bỏ qua (Localhost + Mạng nội bộ + IP SSH hiện tại)
ignoreip = 127.0.0.1/8 ::1 $F2B_IGNORE
EOF

# 5. KHỞI ĐỘNG LẠI FAIL2BAN
systemctl restart fail2ban
echo -e "\033[1;32m[✔] KẾT NỐI FAIL2BAN THÀNH CÔNG! IP xấu sẽ bị cấm 1 giờ.\033[0m"
