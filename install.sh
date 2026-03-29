#!/bin/bash
# ==========================================================
# 🚀 ANTI-DDOS MINECRAFT ALL-IN-ONE INSTALLER
# ==========================================================

# Kiểm tra quyền Root
if [ "$EUID" -ne 0 ]; then 
  echo "Vui lòng chạy dưới quyền root (sudo ./install.sh)"
  exit 1
fi

echo -e "\033[1;36m[+] BẮT ĐẦU QUÁ TRÌNH CÀI ĐẶT TOÀN DIỆN...\033[0m"

# 1. Kích hoạt core Anti-DDoS
echo -e "\n[1/3] Đang nạp hệ tường lửa lõi..."
chmod +x antiddos.sh
./antiddos.sh

# 2. Cài đặt Guardian (Cảnh vệ)
echo -e "\n[2/3] Đang cài đặt Guardian tự phục hồi..."
chmod +x Advanced_AntiDDoS/Backend_Node/install_guardian.sh
./Advanced_AntiDDoS/Backend_Node/install_guardian.sh

# 3. Kích hoạt Monitor (Nếu muốn)
read -p "[3/3] Ông có muốn cài đặt Báo cáo Discord không? (y/n): " mon_choice
if [[ "$mon_choice" =~ ^[Yy]$ ]]; then
    chmod +x setup_monitor.sh
    ./setup_monitor.sh
fi

echo -e "\n\033[1;32m[+] HOÀN TẤT CÀI ĐẶT TẤT CẢ PHÀN MỀM!\033[0m"
echo -e "Hãy kiểm tra trạng thái bằng lệnh: \033[1;33msudo ./status.sh\033[0m"
echo -e "\033[1;31mLưu ý quan trọng: Nhớ copy lệnh 'kill' từ bước [1] để tắt bom cứu hộ 5 phút!\033[0m"
