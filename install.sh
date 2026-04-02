#!/bin/bash
# ==========================================================
# 🚀 ANTI-DDOS V3 ULTIMATE: CLEAN INSTALLER (ALL-IN-ONE)
# Tầng Driver (XDP) + Tầng Guardian (Fail2Ban) + Port Discovery
# ==========================================================

# 1. KIỂM TRA QUYỀN VÀ KHỞI TẠO
if [ "$EUID" -ne 0 ]; then 
  echo -e "\033[1;31m[✘] Vui lòng chạy dưới quyền root (sudo ./install.sh)\033[0m"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
chmod +x scripts/*.sh status.sh uninstall.sh 2>/dev/null

echo -e "\n\033[1;35m[+] BẮT ĐẦU CHIẾN DỊCH KHỞI TẠO ANTI-DDOS V3 ULTIMATE...\033[0m"

# 2. GIAI ĐOẠN 0: DỌN DẸP HỆ THỐNG CŨ (V1 & V2)
echo -e "\n\033[1;36m[0/5] Đang dọn dẹp hệ thống phòng thủ cũ (Clean Install)...\033[0m"
bash "$SCRIPT_DIR/uninstall.sh" >/dev/null 2>&1
echo "      -> Đã giải phóng hoàn toàn Iptables/Nftables/Ipset cũ."

# 3. GIAI ĐOẠN 1: NHẬP THÔNG TIN TỪ USER
echo -e "\n\033[1;36m[1/5] Thiết lập tham số dải Port (Pterodactyl Allocation Pool)...\033[0m"
read -r -p "[?] Nhập dải Port Pterodactyl của bạn (Ví dụ: 30000-35000): " PTERO_POOL
[ -z "$PTERO_POOL" ] && PTERO_POOL="30000-30100"

mkdir -p /etc/xdpfw
echo "$PTERO_POOL" > /etc/xdpfw/pterodactyl_pool.txt

# 4. GIAI ĐOẠN 2: BIÊN DỊCH VÀ CÀI ĐẶT XDP-FIREWALL
echo -e "\n\033[1;36m[2/5] Đang build giáp Driver XDP (Gamemann Core)...\033[0m"
bash "$SCRIPT_DIR/scripts/compile_xdp.sh"

# 5. GIAI ĐOẠN 3: CẤU HÌNH VÀ TỐI ƯU HỎA HỆ THỐNG
echo -e "\n\033[1;36m[3/5] Đang kích hoạt Port Discovery & Config Generator...\033[0m"
bash "$SCRIPT_DIR/scripts/config_xdp.sh"

# 6. GIAI ĐOẠN 4: KẾT NỐI FAIL2BAN GUARDIAN
echo -e "\n\033[1;36m[4/5] Đang thiết lập Fail2Ban trừng phạt IP (1 Giờ)...\033[0m"
bash "$SCRIPT_DIR/scripts/setup_fail2ban.sh"

# 7. GIAI ĐOẠN 5: KÍCH HOẠT DỊCH VỤ VÀ WATCHER
echo -e "\n\033[1;36m[5/5] Hoàn tất và kích hoạt bảo vệ liên tục...\033[0m"
systemctl enable --now xdpfw 2>/dev/null
systemctl start xdpfw 2>/dev/null

# Khởi chạy Watcher V3 trong nền (Systemd hoặc nohup)
# Tôi dùng nohup để đơn giản hóa cho User, có thể chuyển sang service sau.
pkill -f watcher_v3.sh 2>/dev/null
nohup bash "$SCRIPT_DIR/scripts/watcher_v3.sh" > /dev/null 2>&1 &

echo -e "\n\033[1;32m[✔] TẤT CẢ ĐÃ SẴN SÀNG! HỆ THỐNG V3 ULTIMATE ĐANG BẢO VỆ BẠN.\033[0m"
echo -e "Hãy dùng \033[1;33mbash status.sh --watch\033[0m để xem chiến sự ddos XDP."
echo -e "Lệnh gỡ cài đặt: \033[1;33msudo ./uninstall.sh\033[0m\n"
