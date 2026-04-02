#!/bin/bash
# ==========================================================
# 🔍 DISCOVER V3: INTELLIGENT PORT & INTERFACE SCANNER
# ==========================================================

# 1. TỰ ĐỘNG NHẬN DIỆN INTERFACE
get_interface() {
    local INTERFACE=$(ip -o -4 route get 8.8.8.8 2>/dev/null | sed -nr 's/.*dev ([^ ]+).*/\1/p')
    if [ -z "$INTERFACE" ]; then
        INTERFACE=$(ip link show | awk -F': ' '$2 != "lo" {print $2; exit}')
    fi
    echo "$INTERFACE"
}

# 2. QUÉT TOÀN BỘ CỔNG ĐANG MỞ TRÊN HỆ THỐNG (ADMIN PORTS)
# Dùng cho: SSH, SFTP, Wings, Database, Web Panel...
get_admin_ports() {
    # Lấy tất cả ports đang LISTEN (TCP/UDP), lọc bỏ các port cao (ephemeral) > 32768
    local PORTS=$(ss -tulnp | awk 'NR>1 {print $5}' | awk -F: '{print $NF}' | sort -n | uniq | awk '$1 < 32768' | xargs | tr ' ' ',')
    echo "$PORTS"
}

# 3. QUÉT CỔNG PTERODACTYL (DYNAMIC ALLOCATIONS)
# Chỉ quét các container có label io.pterodactyl.server
get_pterodactyl_ports() {
    local CONTAINERS=$(docker ps --filter "label=io.pterodactyl.server" -q 2>/dev/null)
    if [ -z "$CONTAINERS" ]; then
        echo ""
        return
    fi

    local PORTS=""
    for cid in $CONTAINERS; do
        # Trích xuất toàn bộ HostPort từ network settings
        local C_PORTS=$(docker inspect --format='{{range $p, $conf := .NetworkSettings.Ports}}{{range $conf}}{{.HostPort}} {{end}}{{end}}' "$cid" 2>/dev/null)
        PORTS="$PORTS $C_PORTS"
    done
    
    # Làm sạch: Loại bỏ trùng lặp và sắp xếp
    echo "$PORTS" | xargs -n1 | sort -n | uniq | xargs | tr ' ' ','
}

# 4. DANH SÁCH IP NGƯỜI DÙNG & MẠNG NỘI BỘ (WHITELIST)
get_whitelist_ips() {
    # Mạng nội bộ cơ bản
    local WHITELIST="127.0.0.1/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,::1"
    
    # Tự động lấy IP của người đang SSH hiện tại (Tránh tự khóa mình)
    local SSH_IP=$(echo $SSH_CONNECTION | awk '{print $1}')
    if [ -n "$SSH_IP" ]; then
        WHITELIST="$WHITELIST,$SSH_IP"
    fi
    
    echo "$WHITELIST"
}

# 5. XUẤT KẾT QUẢ (Dạng biến để script khác nạp)
INTERFACE=$(get_interface)
ADMIN_PORTS=$(get_admin_ports)
ACTIVE_PTERO_PORTS=$(get_pterodactyl_ports)
WHITELIST_IPS=$(get_whitelist_ips)

if [[ "$1" == "--shell" ]]; then
    echo "INTERFACE=\"$INTERFACE\""
    echo "ADMIN_PORTS=\"$ADMIN_PORTS\""
    echo "ACTIVE_PTERO_PORTS=\"$ACTIVE_PTERO_PORTS\""
    echo "WHITELIST_IPS=\"$WHITELIST_IPS\""
else
    echo "------------------------------------------------"
    echo "INTERFACE: $INTERFACE"
    echo "ADMIN PORTS (Auto): $ADMIN_PORTS"
    echo "PTERO PORTS (Active): ${ACTIVE_PTERO_PORTS:-None}"
    echo "WHITELIST IPS: $WHITELIST_IPS"
    echo "------------------------------------------------"
fi
