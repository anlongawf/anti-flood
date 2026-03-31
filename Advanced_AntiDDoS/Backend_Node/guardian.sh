#!/bin/bash
# ==========================================================
# 🛡️ SIÊU CẢNH VỆ ANTI-DDOS (Intelligent Watcher)
# Nhiệm vụ: Theo dõi sự thay đổi Port 10 giây một lần.
# Chỉ cập nhật Firewall khi phát hiện có sự thay đổi.
# ==========================================================

# 1. Xác định đường dẫn
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANTIDDOS_SCRIPT="$SCRIPT_DIR/../../antiddos.sh"
LAST_PORTS_FILE="/tmp/antiddos_last_ports.txt"

echo "[+] Cảnh vệ đang bắt đầu tuần tra (Chu kỳ 10 giây)..."

while true; do
    # 2. Thu thập danh sách Port hiện tại (TCP & UDP)
    CURRENT_PORTS=$( (docker ps --format '{{.Ports}}' 2>/dev/null; ss -tulnp | awk 'NR>1 {print $5}' | awk -F: '{print $NF}') | sort | uniq | xargs )

    # --- TỰ PHỤC HỒI (SELF-HEALING) ---
    # Kiểm tra xem bảng Nftables V2 có bị mất không
    if ! nft list table netdev antiddos_v2 >/dev/null 2>&1; then
        echo "[!] CẢNH BÁO: Bảng Firewall V2 bị mất! Đang phục hồi ngay lập tức..."
        bash /Users/anphan/Documents/block_ip/scripts/setup.sh
    fi

    # 3. So sánh Port với lần quét trước
    if [ ! -f "$LAST_PORTS_FILE" ] || [ "$CURRENT_PORTS" != "$(cat "$LAST_PORTS_FILE")" ]; then
        echo "[!] PHÁT HIỆN THAY ĐỔI PORT: Cài đặt Giáp V2 ngay lập tức..."
        echo "$CURRENT_PORTS" > "$LAST_PORTS_FILE"
        
        # Gọi script setup V2 (Chỉ cấu hình Nftables, không cài lại Dependencies)
        bash /Users/anphan/Documents/block_ip/scripts/setup.sh
        
        echo "[✔] Đã khóa port mới. Tiếp tục tuần tra..."
    fi

    # 4. Gửi cảnh báo Discord nếu có DDoS
    bash /Users/anphan/Documents/block_ip/scripts/alerts.sh

    # 5. Nghỉ ngơi 10 giây
    sleep 10
done
