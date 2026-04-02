#!/bin/bash
# ==========================================================
# 🛡️ SMART WATCHER V3: PERFORMANCE-DRIVEN PORT MONITOR
# ==========================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LAST_HASH_FILE="/tmp/antiddos_last_hash.txt"

# 1. QUÉT PORT HIỆN TẠI VÀ TỔNG HỢP HASH
get_current_state_hash() {
    # Chạy discovery để lấy port Pterodactyl hiện tại
    local ACTIVE_PORTS=$(bash "$SCRIPT_DIR/discover_v3.sh" --shell | grep "ACTIVE_PTERO_PORTS" | cut -d '"' -f 2)
    # Lấy thêm pool allocation từ config (nếu có lưu)
    local POOL_CONFIG="/etc/xdpfw/pterodactyl_pool.txt"
    local POOL=""
    [ -f "$POOL_CONFIG" ] && POOL=$(cat "$POOL_CONFIG")
    
    # Kết hợp và băm (Hashing)
    echo "$ACTIVE_PORTS|$POOL" | sha256sum | awk '{print $1}'
}

# 2. XỬ LÝ KHI PHÁT HIỆN THAY ĐỔI
reload_firewall() {
    local ACTIVE_PORTS=$1
    echo "[!] PHÁT HIỆN THAY ĐỔI TRONG ALLOCATION PTERODACTYL!"
    echo "[+] Đang tái thiết lập màng chắn XDP & Nftables..."
    
    # Chạy lại setup configuration (sẽ tạo lại xdpfw.conf)
    bash "$SCRIPT_DIR/config_xdp.sh" --reload
    
    # Reload XDP Service
    systemctl restart xdpfw 2>/dev/null
    
    # Gửi thông báo Discord
    bash "$SCRIPT_DIR/alerts_v3.sh" "PROTECTION UPDATED" "Đã phát hiện thay đổi trong hệ thống Pterodactyl. Cấu hình XDP đã được cập nhật tự động.\n\n**Ports Đang Bảo Vệ:** \`${ACTIVE_PORTS:-None}\`" 3066993
    
    echo "[✔] Đã cập nhật thành công!"
}

# 3. VÒNG LẶP GIÁM SÁT (15 GIÂY / LẦN)
echo "[+] Watcher V3 đang bắt đầu tuần tra (15 giây)..."
while true; do
    # Lấy port active trực tiếp để truyền vào hàm reload
    eval $(bash "$SCRIPT_DIR/discover_v3.sh" --shell)
    CURR_HASH=$(echo "$ACTIVE_PTERO_PORTS|$(cat /etc/xdpfw/pterodactyl_pool.txt 2>/dev/null)" | sha256sum | awk '{print $1}')
    
    if [ ! -f "$LAST_HASH_FILE" ] || [ "$CURR_HASH" != "$(cat "$LAST_HASH_FILE")" ]; then
        reload_firewall "$ACTIVE_PTERO_PORTS"
        echo "$CURR_HASH" > "$LAST_HASH_FILE"
    fi
    
    sleep 15
done
