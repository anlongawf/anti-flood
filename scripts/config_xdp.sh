#!/bin/bash
# ==========================================================
# ⚙️ CONFIG V3: XDP CONFIGURATION GENERATOR (ULTIMATE)
# ==========================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
XDP_CONF_FILE="/etc/xdpfw/xdpfw.conf"
POOL_FILE="/etc/xdpfw/pterodactyl_pool.txt"

# 1. ĐỌC DỮ LIỆU TỪ DISCOVERY
# Nạp các biến INTERFACE, ADMIN_PORTS, ACTIVE_PTERO_PORTS, WHITELIST_IPS
eval $(bash "$SCRIPT_DIR/discover_v3.sh" --shell)

# Lấy dải Port Pool từ file hoặc mặc định
PTERO_POOL=$(cat "$POOL_FILE" 2>/dev/null || echo "30000-30100")

echo "[+] Đang khởi tạo cấu hình XDP cho Interface: $INTERFACE"

# 2. TẠO FILE CONFIG XDPFW.CONF
mkdir -p /etc/xdpfw
cat <<EOF > "$XDP_CONF_FILE"
// =============================================================
// XDP FIREWALL - V3 ULTIMATE PERFORMANCE CONFIG
// =============================================================

verbose = 1;
log_file = "/var/log/xdpfw.log";
interface = "$INTERFACE";
update_time = 15;
no_stats = false;
stats_per_second = true;
stdout_update_time = 2000;

filters = (
    // -------------------------------------------------------------
    // NHÓM 0: WHITELIST IP TIN CẬY (Không bao giờ Ban)
    // -------------------------------------------------------------
    {
        enabled = true,
        action = 1,          // Allow Whitelist IPs
        src_ip = [ $WHITELIST_IPS ]
    },

    // -------------------------------------------------------------
    // NHÓM 1: WHITELIST ADMIN PORTS (SSH, Wings, DB...)
    // -------------------------------------------------------------
    {
        enabled = true,
        action = 1,
        tcp_enabled = true,
        tcp_dport = [ $ADMIN_PORTS ]
    },
    {
        enabled = true,
        action = 1,
        udp_enabled = true,
        udp_dport = [ $ADMIN_PORTS ]
    },

    // -------------------------------------------------------------
    // NHÓM 2: PTERODACTYL ACTIVE (GAME DPI + STRICT RATE LIMIT)
    // -------------------------------------------------------------
EOF

# Thêm logic cho các Port đang active (Nếu có)
if [ -n "$ACTIVE_PTERO_PORTS" ]; then
cat <<EOF >> "$XDP_CONF_FILE"
    {
        enabled = true,
        action = 0, block_time = 120, log = true,
        udp_enabled = true, udp_dport = [ $ACTIVE_PTERO_PORTS ],
        flow_pps = 300,      // Game Minecraft/Bedrock PPS thực tế
        ip_pps = 2000,       // Chống Multi-thread Attack
        flow_bps = 500000    // 500KB/s
    },
    {
        enabled = true,
        action = 1, udp_enabled = true, udp_dport = [ $ACTIVE_PTERO_PORTS ]
    },
EOF
fi

# Thêm logic cho Pterodactyl Pool (Dự phòng)
cat <<EOF >> "$XDP_CONF_FILE"
    // -------------------------------------------------------------
    // NHÓM 3: PTERODACTYL POOL (Dự phòng cho khách mới)
    // -------------------------------------------------------------
    {
        enabled = true,
        action = 0, block_time = 60, log = false,
        udp_enabled = true, udp_dport = "$PTERO_POOL",
        flow_pps = 1000,     // Nới lỏng hơn cho pool dự phòng
        ip_pps = 5000
    },
    {
        enabled = true, action = 1, udp_enabled = true, udp_dport = "$PTERO_POOL"
    },
    {
        enabled = true, action = 1, tcp_enabled = true, tcp_dport = "$PTERO_POOL"
    },

    // Default Allow cho Admin và các gói tin không khớp (để đẩy lên nftables)
    { enabled = true, action = 1 }
);
EOF

# 3. THIẾT LẬP GEO-SHIELD LAYER (NFTABLES)
echo "[+] Đang kích hoạt Geo-Shield Level 2 (VN/JP Nftables)..."
# Tạo Table Nftables để lọc IP Quốc Gia cho Game Ports
nft delete table inet antiddos_geo 2>/dev/null
nft add table inet antiddos_geo
nft add chain inet antiddos_geo prerouting { type filter hook prerouting priority -150 \; policy accept \; }

# Tạo Set trong Nftables từ IPSET (Đồng bộ)
nft add set inet antiddos_geo allow_countries { type ipv4_addr \; flags interval \; }
ipset list allow_countries | grep -E '^[0-9]' | xargs -n1 -I {} nft add element inet antiddos_geo allow_countries { {} } 2>/dev/null

# Áp dụng luật DROP: Nếu không thuộc VN/JP mà truy cập Port Game/Pool thì DROP ngay
if [ -n "$ACTIVE_PTERO_PORTS" ]; then
    nft add rule inet antiddos_geo prerouting ip saddr != @allow_countries udp dport { $ACTIVE_PTERO_PORTS } counter drop comment \"geo_block_ptero\"
fi

# Chặn nốt dải Pool Pterodactyl
nft add rule inet antiddos_geo prerouting ip saddr != @allow_countries udp dport { $PTERO_POOL } counter drop comment \"geo_block_pool\"
nft add rule inet antiddos_geo prerouting ip saddr != @allow_countries tcp dport { $PTERO_POOL } counter drop comment \"geo_block_pool\"

# Tinh chỉnh Kernel (Bổ trợ)
sysctl -w net.ipv4.conf.all.rp_filter=1 >/dev/null

# 4. TẠO SYSTEMD SERVICE (Nếu chưa có)
if [ ! -f /etc/systemd/system/xdpfw.service ]; then
cat <<EOF > /etc/systemd/system/xdpfw.service
[Unit]
Description=XDP Firewall V3 Ultimate Service
After=network.target network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/xdpfw --config /etc/xdpfw/xdpfw.conf --offload
Restart=always
RestartSec=3
StandardOutput=append:/var/log/xdpfw.log
StandardError=append:/var/log/xdpfw.log
LimitNOFILE=65535
LimitMEMLOCK=infinity

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
fi

echo -e "\033[1;32m[✔] ĐÃ TẠO CẤU HÌNH XDP & GEO-SHIELD THÀNH CÔNG!\033[0m"
