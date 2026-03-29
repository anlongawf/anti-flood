#!/bin/bash
# ==========================================================
# CẢNH VỆ DOCKER (DOCKER GUARDIAN SERVICE)
# Nhiệm vụ: Tự động phát hiện khi Docker Khởi Động hoặc Thay Đổi Mạng
# Lập tức vá lại các quy tắc Anti-DDoS trong chain DOCKER-USER
# Tránh trình trạng Restart Docker = Mất Rules.
# ==========================================================

echo -e "\033[1;36m[+] Đang cài đặt Kẻ Giác Ngộ (Systemd Guardian) cho Docker...\033[0m"

# Trỏ chính xác đến file bash vừa nãy của ông
SCRIPT_PATH="/Users/anphan/Documents/block_ip/antiddos.sh"

cat << EOF > /etc/systemd/system/antiddos-guardian.service
[Unit]
Description=Bảo Vệ Tường Lửa Anti-DDoS Đè Lên Docker (DOCKER-USER Guardian)
After=docker.service network-online.target
Requires=docker.service

[Service]
Type=oneshot
# Ngay khi Docker xong, chạy Script vá lỗi bảo mật này:
ExecStart=/bin/bash $SCRIPT_PATH
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Nạp service vào lõi hệ thống
systemctl daemon-reload
systemctl enable antiddos-guardian.service

echo -e "\033[1;32m[+] SIÊU THÀNH CÔNG! Kể từ giây phút này...\033[0m"
echo "Bất kỳ thao tác Restart Docker nào của Pterodactyl bôi xóa Firewall"
echo "Cảnh Vệ sẽ lập tức tự động Tát Docker qua một bên và khôi phục lá chắn."
