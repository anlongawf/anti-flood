#!/bin/bash
# ==========================================================
# 💎 LAYER 5: DISCORD PREMIUM DASHBOARD (V2.1)
# Nâng cấp trải nghiệm giám sát từ xa qua Discord
# ==========================================================

# TỰ ĐỘNG XÁC ĐỊNH ĐƯỜNG DẪN SCRIPT
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INTERFACE=$(ip -o -4 route get 8.8.8.8 | sed -nr 's/.*dev ([^ ]+).*/\1/p')
[ -z "$INTERFACE" ] && INTERFACE=$(ip link show | awk -F': ' '$2 != "lo" {print $2; exit}')

# Lấy Webhook từ cấu hình hệ thống
WEBHOOK=$(grep -oP 'https://discord.com/api/webhooks/[^"]+' /usr/local/bin/antiddos_monitor.sh 2>/dev/null | head -n 1)
[ -z "$WEBHOOK" ] && exit 1

# File lưu trữ trạng thái cũ
STATE_FILE="/tmp/antiddos_state.txt"
DAILY_STATS="/tmp/antiddos_daily.txt"

# 1. THU THẬP DỮ LIỆU
RX_BYTES=$(grep "$INTERFACE" /proc/net/dev | awk '{print $2}')
TOTAL_DROPS=$(nft list table netdev antiddos_v2 2>/dev/null | grep "packets" | awk '{sum+=$5} END {print sum}')
[ -z "$TOTAL_DROPS" ] && TOTAL_DROPS=0

# Xử lý Delta & Thời gian
NOW=$(date +%s)
TODAY=$(date '+%d%m%Y')

if [ -f "$STATE_FILE" ]; then
    read LAST_RX_BYTES LAST_TOTAL_DROPS LAST_TIMESTAMP LAST_DATE < "$STATE_FILE"
else
    LAST_RX_BYTES=$RX_BYTES; LAST_TOTAL_DROPS=$TOTAL_DROPS; LAST_TIMESTAMP=$NOW; LAST_DATE=$TODAY
fi

TIME_DIFF=$((NOW - LAST_TIMESTAMP))
[ "$TIME_DIFF" -le 0 ] && TIME_DIFF=1

# Tính toán Tốc độ
BPS=$(( (RX_BYTES - LAST_RX_BYTES) / TIME_DIFF ))
MBPS=$(echo "scale=2; $BPS * 8 / 1048576" | bc)
DROPS_IN_PERIOD=$((TOTAL_DROPS - LAST_TOTAL_DROPS))
[ "$DROPS_IN_PERIOD" -lt 0 ] && DROPS_IN_PERIOD=0

# Cập nhật Thống kê ngày
if [ "$TODAY" != "$LAST_DATE" ]; then
    DAILY_COUNT=$DROPS_IN_PERIOD
else
    [ -f "$DAILY_STATS" ] && DAILY_COUNT=$(cat "$DAILY_STATS") || DAILY_COUNT=0
    DAILY_COUNT=$((DAILY_COUNT + DROPS_IN_PERIOD))
fi
echo "$DAILY_COUNT" > "$DAILY_STATS"
echo "$RX_BYTES $TOTAL_DROPS $NOW $TODAY" > "$STATE_FILE"

# 2. PHÂN TÍCH TRẠNG THÁI & MÀU SẮC
IS_ATTACK=false
SEVERITY="Bình thường"
COLOR=3066993 # Xanh lá (Normal)
ICON="✅"

if [ "$DROPS_IN_PERIOD" -gt 5000 ]; then
    IS_ATTACK=true; SEVERITY="NGUY HIỂM"; COLOR=15158332; ICON="💀"
elif [ "$DROPS_IN_PERIOD" -gt 500 ]; then
    IS_ATTACK=true; SEVERITY="CẢNH BÁO"; COLOR=15105570; ICON="⚠️"
fi

# 3. CHẨN ĐOÁN CHI TIẾT
NFT_LIST=$(nft list table netdev antiddos_v2 2>/dev/null)
LAYERS=""
[ -n "$(echo "$NFT_LIST" | grep "drop_geoip")" ] && LAYERS+="- 🌏 Geo-Shield (VN/JP Only)\n"
[ -n "$(echo "$NFT_LIST" | grep "drop_raknet")" ] && LAYERS+="- 🤖 DPI RakNet Filter\n"
[ -n "$(echo "$NFT_LIST" | grep "drop_udp_ratelimit")" ] && LAYERS+="- 🌊 UDP Rate Limit\n"

ATTACK_TYPE="Hệ thống Ổn định"
if [ "$IS_ATTACK" = true ]; then
    ATTACK_TYPE="Phát hiện lưu lượng bất thường"
    if echo "$NFT_LIST" | grep "drop_invalid_tcp_flags" | grep -v "packets 0" >/dev/null; then ATTACK_TYPE="TCP SYN/Malformed Flood";
    elif echo "$NFT_LIST" | grep "drop_raknet_dpi" | grep -v "packets 0" >/dev/null; then ATTACK_TYPE="Minecraft Join-Bot Attack";
    elif echo "$NFT_LIST" | grep "drop_geoip_untrusted" | grep -v "packets 0" >/dev/null; then ATTACK_TYPE="Foreign IP Volumetric (Blocked)";
    fi
fi

# 4. TÀI NGUYÊN & TOP IP
CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8}')
RAM_P=$(free | grep Mem | awk '{print int($3/$2 * 100)}')
[ "$CPU" -gt 80 ] && CPU_ICON="🔴" || CPU_ICON="🟢"
[ "$RAM_P" -gt 80 ] && RAM_ICON="🔴" || RAM_ICON="🟢"

TOP_IPS=$(ss -tun state established 2>/dev/null | awk 'NR>1 {split($5,a,":"); print a[1]}' | grep -P '^\d' | sort | uniq -c | sort -nr | head -n 3 | awk '{print $2 " (" $1 ")"}' | tr '\n' ' | ' | sed 's/ | $//')

# 5. GỬI WEBHOOK
TIMESTAMP=$(date '+%H:%M:%S - %d/%m/%Y')
PAYLOAD=$(cat <<JSON
{
  "username": "Anti-DDoS V2 Guardian",
  "avatar_url": "https://i.imgur.com/8N88PNC.png",
  "embeds": [{
    "title": "$ICON [TRẠNG THÁI HỆ THỐNG]: $SEVERITY",
    "description": "🛡️ **Màng chắn Ingress đang hoạt động bền bỉ.**",
    "color": $COLOR,
    "fields": [
      { "name": "🚀 Lưu lượng Mạng", "value": "Tốc độ: \`${MBPS} Mbps\`\nChặn mới: \`${DROPS_IN_PERIOD} pkt/m\`", "inline": true },
      { "name": "📊 Thống kê Ngày", "value": "Tổng chặn: \`${DAILY_COUNT}\` pkts\nKết nối: \`$(ss -tan | wc -l)\` cns", "inline": true },
      { "name": "📡 Phân tích Tấn công", "value": "**$ATTACK_TYPE**", "inline": false },
      { "name": "🧱 Các lớp phòng vệ đang bật", "value": "$LAYERS", "inline": false },
      { "name": "💻 Sức khỏe Server", "value": "$CPU_ICON CPU: \`${CPU}%\` | $RAM_ICON RAM: \`${RAM_P}%\`", "inline": true },
      { "name": "🔍 Top 3 IP đáng chú ý", "value": "\`${TOP_IPS:-Không có}\`", "inline": false }
    ],
    "footer": { "text": "Hệ thống bảo vệ bởi Agentic AI • $TIMESTAMP" }
  }]
}
JSON
)

curl -s -H "Content-Type: application/json" -X POST -d "$PAYLOAD" "$WEBHOOK" >/dev/null 2>&1

