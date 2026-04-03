#!/bin/bash
# ==========================================================
# 📊 PERIODIC DISCORD REPORT (V3 ULTIMATE)
# Optimized for 1-minute intervals
# ==========================================================

# 1. CẤU HÌNH & WEBHOOK
WEBHOOK_FILE="/etc/xdpfw/webhook.txt"
WEBHOOK_URL=$(cat "$WEBHOOK_FILE" 2>/dev/null)

# Tìm kiếm webhook thay thế nếu không thấy file chính
if [ -z "$WEBHOOK_URL" ]; then
    WEBHOOK_URL=$(grep -oP 'https://discord.com/api/webhooks/[^"]+' /usr/local/bin/antiddos_monitor.sh 2>/dev/null | head -n 1)
fi

# Nếu vẫn không có webhook, thoát
if [ -z "$WEBHOOK_URL" ]; then
    exit 0
fi

# 2. THU THẬP THÔNG SỐ MẠNG (Cần 2 lần lấy để tính tốc độ)
INTERFACE=$(ip -o -4 route get 8.8.8.8 2>/dev/null | sed -nr 's/.*dev ([^ ]+).*/\1/p')
[ -z "$INTERFACE" ] && INTERFACE=$(ip link show | awk -F': ' '$2 != "lo" {print $2; exit}')

get_net_stats() {
    local LINE=$(grep "$INTERFACE" /proc/net/dev)
    echo "$(echo $LINE | awk '{print $2}') $(echo $LINE | awk '{print $3}')"
}

read RX_BYTES1 RX_PKTS1 <<< $(get_net_stats)
sleep 1
read RX_BYTES2 RX_PKTS2 <<< $(get_net_stats)

DIFF_BYTES=$((RX_BYTES2 - RX_BYTES1))
DIFF_PKTS=$((RX_PKTS2 - RX_PKTS1))

MBPS=$(echo "scale=2; $DIFF_BYTES * 8 / 1048576" | bc)
PPS=$DIFF_PKTS

# 3. THỐNG KÊ CHẶN (XDP & NFTABLES)
XDP_DROPS=$(tail -n 100 /var/log/xdpfw.log 2>/dev/null | grep -c "Dropped")
NFT_DROPS=$(nft list table inet antiddos_geo 2>/dev/null | grep "packets" | awk '{sum+=$5} END {print sum}')
[ -z "$NFT_DROPS" ] && NFT_DROPS=0

# 4. KẾT NỐI & HỆ THỐNG
TOTAL_CONN=$(ss -tun state established | wc -l)
CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8}')
RAM_P=$(free | grep Mem | awk '{print int($3/$2 * 100)}')

# 5. KHÁM PHÁ PTERODACTYL (Nếu có script hỗ trợ)
if [ -f "scripts/discover_v3.sh" ]; then
    P_PORTS=$(bash scripts/discover_v3.sh --shell 2>/dev/null | grep "ACTIVE_PTERO_PORTS" | cut -d '"' -f 2)
fi

# 6. ĐÁNH GIÁ MỨC ĐỘ NGUY HIỂM (LOGIC)
COLOR=3066993        # Green (Safe)
DANGER_LEVEL="AN TOÀN"
ICON="🛡️"

if [ "$PPS" -gt 50000 ] || [ "$DIFF_BYTES" -gt 12500000 ]; then # > 50k PPS or > 100 Mbps
    COLOR=15158332    # Red (Danger)
    DANGER_LEVEL="NGUY HIỂM"
    ICON="💀"
elif [ "$PPS" -gt 10000 ] || [ "$DIFF_BYTES" -gt 2500000 ]; then  # > 10k PPS or > 20 Mbps
    COLOR=15105570    # Yellow (Warning)
    DANGER_LEVEL="CẢNH BÁO"
    ICON="⚠️"
fi

# 7. GỬI DISCORD
HOSTNAME=$(hostname)
IP_SERVER=$(curl -s --max-time 5 https://api.ipify.org || echo "Unknown")
TIMESTAMP=$(date '+%H:%M:%S - %d/%m/%Y')

PAYLOAD=$(cat <<EOF
{
  "username": "Anti-DDoS V3 Reporter",
  "avatar_url": "https://i.imgur.com/8N88PNC.png",
  "embeds": [
    {
      "title": "$ICON TRẠNG THÁI HỆ THỐNG: $DANGER_LEVEL",
      "description": "Báo cáo định kỳ tình trạng kết nối và bảo mật.",
      "color": $COLOR,
      "fields": [
        { "name": "🚀 Lưu lượng Mạng", "value": "Tốc độ: \`${MBPS} Mbps\`\nThanh khoản: \`${PPS} PPS\`", "inline": true },
        { "name": "📊 Kết nối & Chặn", "value": "Kết nối: \`${TOTAL_CONN}\` cns\nNFT Block: \`${NFT_DROPS}\` pkts", "inline": true },
        { "name": "💻 Sức khỏe Server", "value": "CPU: \`${CPU}%\` | RAM: \`${RAM_P}%\`", "inline": false },
        { "name": "🎮 Pterodactyl Ports", "value": "\`${P_PORTS:-None detected}\`", "inline": false },
        { "name": "🖥️ Máy chủ", "value": "\`$HOSTNAME ($IP_SERVER)\`", "inline": false }
      ],
      "footer": { "text": "Hệ thống bảo vệ bởi Anti-DDoS V3 Ultimate • $TIMESTAMP" }
    }
  ]
}
EOF
)

curl -s -H "Content-Type: application/json" -X POST -d "$PAYLOAD" "$WEBHOOK_URL" > /dev/null
