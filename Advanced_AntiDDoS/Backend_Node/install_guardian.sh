#!/bin/bash
# ==========================================================
# CẢNH VỆ DOCKER (DOCKER GUARDIAN SERVICE)
# Nhiệm vụ: Tự động phát hiện khi Docker Khởi Động hoặc Thay Đổi Mạng
# Lập tức vá lại các quy tắc Anti-DDoS trong chain DOCKER-USER
# Tránh trình trạng Restart Docker = Mất Rules.
# ==========================================================

echo -e "\033[1;36m[+] Đang cài đặt Kẻ Giác Ngộ (Systemd Guardian) cho Docker...\033[0m"

# Tự động dò đường dẫn tuyệt đối (Cực kỳ chính xác cho VPS)
PARENT_DIR="$(cd "$(dirname "$(readlink -f "$0")")/../../" && pwd)"
GUARDIAN_SCRIPT="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)/guardian.sh"
chmod +x "$GUARDIAN_SCRIPT"

cat << EOF > /etc/systemd/system/antiddos-guardian.service
[Unit]
Description=Cảnh Vệ Anti-DDoS Thông Minh (Theo Dõi Port 10 Giây/Lần)
After=docker.service network-online.target
Requires=docker.service

[Service]
# Chạy ở chế độ nền liên tục:
Type=simple
ExecStart=/bin/bash $GUARDIAN_SCRIPT
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Nạp service vào lõi hệ thống
systemctl daemon-reload
systemctl enable antiddos-guardian.service
systemctl start antiddos-guardian.service

echo -e "\033[1;32m[+] SIÊU THÀNH CÔNG! Kể từ giây phút này...\033[0m"
echo "Cảnh Vệ (Guardian) sẽ chạy ngầm và quét Port 10 giây một lần."
echo "Bạn không cần phải chạy lại Script mỗi khi tạo Server Minecraft mới nữa."
echo "Cảnh Vệ sẽ tự động phát hiện và áp dụng lá chắn ngay lập tức."
