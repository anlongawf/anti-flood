#!/bin/bash
# ==========================================================
# 🚀 TRÌNH CÀI ĐẶT TỔNG LỰC ANTI-DDOS V2 SIÊU CƯỜNG
# Một lệnh duy nhất - Kích hoạt mọi tầng phòng thủ
# ==========================================================

echo -e "\033[1;35m[+] ĐANG CHUẨN BỊ CHIẾN ĐỘI PHÒNG THỦ V2...\033[0m"

# --- GIAI ĐOẠN 0: DỌN DẸP HỆ THỐNG CŨ (CLEAN UP V1) ---
echo -e "\033[1;36m[0/4] Đang dọn dẹp hệ thống phòng thủ cũ (V1)...\033[0m"
# 1. Flush Iptables cũ để không xung đột với Nftables V2
sudo iptables -F INPUT 2>/dev/null
sudo iptables -F DOCKER-USER 2>/dev/null
# 2. Xóa các cronjob cũ
crontab -l 2>/dev/null | grep -v "antiddos_monitor.sh" | crontab -
# 3. Lưu trữ các file cũ vào thư mục Backup
mkdir -p legacy_v1
mv antiddos.sh install.sh setup_monitor.sh legacy_v1/ 2>/dev/null

# 1. Phân quyền
chmod +x scripts/*.sh status.sh Advanced_AntiDDoS/Backend_Node/guardian.sh 2>/dev/null

# 2. Thiết lập Webhook Discord
echo -e "\n\033[1;36m[1/5] Cấu hình Webhook Discord...\033[0m"
# Hỏi Webhook nếu chưa có hoặc muốn cập nhật
if [ ! -f /usr/local/bin/antiddos_monitor.sh ]; then
    read -r -p "[?] Nhập Link Webhook Discord của bạn: " WEBHOOK_URL
else
    echo "      -> Đã tìm thấy cấu hình Webhook cũ."
    read -r -p "[?] Bạn có muốn cập nhật Webhook mới không? (y/N): " update_choice
    if [[ "$update_choice" =~ ^[Yy]$ ]]; then
        read -r -p "[>] Nhập Link Webhook Discord MỚI: " WEBHOOK_URL
    fi
fi

if [[ "$WEBHOOK_URL" =~ ^https://discord.com/api/webhooks/ ]]; then
    echo "#!/bin/bash" > /usr/local/bin/antiddos_monitor.sh
    echo "WEBHOOK=\"$WEBHOOK_URL\"" >> /usr/local/bin/antiddos_monitor.sh
    chmod +x /usr/local/bin/antiddos_monitor.sh
fi

# 2.1. TEST WEBHOOK NGAY LẬP TỨC
if [ -f /usr/local/bin/antiddos_monitor.sh ]; then
    echo -e "      -> Đang gửi tin nhắn TEST tới Discord..."
    bash scripts/alerts.sh # Chạy thử script alert để test kết nối
fi

# 3. Chạy Setup chính (Nftables + Kernel + Geo)
echo -e "\n\033[1;36m[2/5] Triển khai Giáp V2 chuyên sâu...\033[0m"
sudo bash scripts/setup.sh

# 4. Kích hoạt Guardian (Chạy ngầm)
echo -e "\n\033[1;36m[3/5] Triển khai Cảnh vệ Guardian (Self-Healing)...\033[0m"
# Tìm và tắt Guardian cũ nếu có
pkill -f guardian.sh
nohup bash Advanced_AntiDDoS/Backend_Node/guardian.sh > /dev/null 2>&1 &

# 5. Cài đặt Unified Monitor & Alerts
echo -e "\n\033[1;36m[4/5] Thiết lập Lịch Báo cáo V2 & Cảnh báo (Crontab)...\033[0m"
# Lấy đường dẫn hiện tại của thư mục
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Xóa sạch các lịch cũ (V1 và V2 cũ) để không bị trùng lặp
(crontab -l 2>/dev/null | grep -v "antiddos_monitor.sh" | grep -v "alerts.sh" | crontab -)
# Thiết lập lịch mới: Báo cáo tình hình mỗi 1 phút một lần
(crontab -l 2>/dev/null; echo "* * * * * bash $BASE_DIR/scripts/alerts.sh") | crontab -

echo -e "\n\033[1;36m[5/5] Hoàn tất cài đặt!\033[0m"

echo -e "\n\033[1;32m[✔] TẤT CẢ ĐÃ SẴN SÀNG! HỆ THỐNG ĐANG BẢO VỆ BẠN.\033[0m"
echo -e "Hãy dùng \033[1;33mbash status.sh --watch\033[0m để xem chiến sự ddos (PPS/Gbps)."
echo -e "\n============================================="
echo -e "\033[1;31mQUAN TRỌNG: Đừng quên dán lệnh KILL failsafe\033[0m"
echo -e "\033[1;31mnếu SSH của bạn vẫn hoạt động bình thường!\033[0m"
echo -e "=============================================\n"
