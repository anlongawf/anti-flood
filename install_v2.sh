#!/bin/bash
# ==========================================================
# 🚀 TRÌNH CÀI ĐẶT TỔNG LỰC ANTI-DDOS V2 SIÊU CƯỜNG
# Một lệnh duy nhất - Kích hoạt mọi tầng phòng thủ
# ==========================================================

echo -e "\033[1;35m[+] ĐANG CHUẨN BỊ CHIẾN ĐỘI PHÒNG THỦ V2...\033[0m"

# 1. Phân quyền
chmod +x scripts/*.sh status.sh setup_monitor.sh Advanced_AntiDDoS/Backend_Node/guardian.sh 2>/dev/null

# 2. Thiết lập Webhook Discord
echo -e "\n\033[1;36m[1/3] Cấu hình Webhook Discord...\033[0m"
bash setup_monitor.sh

# 3. Chạy Setup chính (Nftables + Kernel + Geo)
echo -e "\n\033[1;36m[2/3] Triển khai Giáp V2 chuyên sâu...\033[0m"
sudo bash scripts/setup.sh

# 4. Kích hoạt Guardian (Chạy ngầm)
echo -e "\n\033[1;36m[3/3] Triển khai Cảnh vệ Guardian (Self-Healing)...\033[0m"
# Tìm và tắt Guardian cũ nếu có
pkill -f guardian.sh
nohup bash Advanced_AntiDDoS/Backend_Node/guardian.sh > /dev/null 2>&1 &

echo -e "\n\033[1;32m[✔] TẤT CẢ ĐÃ SẴN SÀNG! HỆ THỐNG ĐANG BẢO VỆ BẠN.\033[0m"
echo -e "Hãy dùng \033[1;33mbash status.sh --watch\033[0m để xem chiến sự ddos (PPS/Gbps)."
echo -e "\n============================================="
echo -e "\033[1;31mQUAN TRỌNG: Đừng quên dán lệnh KILL failsafe\033[0m"
echo -e "\033[1;31mnếu SSH của bạn vẫn hoạt động bình thường!\033[0m"
echo -e "=============================================\n"
