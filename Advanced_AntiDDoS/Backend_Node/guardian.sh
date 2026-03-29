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
    # Lấy port từ Docker và các port đang listen trên hệ thống
    CURRENT_PORTS=$( (docker ps --format '{{.Ports}}' 2>/dev/null; ss -tulnp | awk 'NR>1 {print $5}' | awk -F: '{print $NF}') | sort | uniq | xargs )

    # 3. So sánh với lần quét trước
    if [ ! -f "$LAST_PORTS_FILE" ] || [ "$CURRENT_PORTS" != "$(cat "$LAST_PORTS_FILE")" ]; then
        echo "[!] PHÁT HIỆN THAY ĐỔI PORT: Cập nhật Firewall ngay lập tức..."
        echo "$CURRENT_PORTS" > "$LAST_PORTS_FILE"
        
        # Gọi script Anti-DDoS ở chế độ FAST
        bash "$ANTIDDOS_SCRIPT" --fast
        
        echo "[✔] Đã cập nhật xong. Tiếp tục tuần tra..."
    fi

    # 4. Nghỉ ngơi 10 giây
    sleep 10
done
