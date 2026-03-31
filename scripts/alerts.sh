#!/bin/bash
# ==========================================================
# 🔔 LAYER 5: DISCORD WEBHOOK ALERTS (V2)
# Chẩn đoán loại tấn công & Tính toán băng thông thực tế
# ==========================================================

# TỰ ĐỘNG XÁC ĐỊNH ĐƯỜNG DẪN SCRIPT
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INTERFACE=$(ip -o -4 route get 8.8.8.8 | sed -nr 's/.*dev ([^ ]+).*/\1/p')
[ -z "$INTERFACE" ] && INTERFACE="eth0"

# Lấy Webhook từ môi trường hoặc cấu hình hệ thống
WEBHOOK=$(grep -oP 'https://discord.com/api/webhooks/[^"]+' /usr/local/bin/antiddos_monitor.sh 2>/dev/null | head -n 1)

if [ -z "$WEBHOOK" ]; then
    # Thử tìm Webhook trong thư mục cài đặt nếu /usr/local/bin không có
    WEBHOOK=$(grep -oP 'https://discord.com/api/webhooks/[^"]+' "$SCRIPT_DIR/../setup_monitor.sh" 2>/dev/null | head -n 1)
fi

if [ -z "$WEBHOOK" ]; then
    exit 1 # Im lặng thoát nếu không có webhook
fi

# 1. TÍNH TOÁN BĂNG THÔNG (Gbps/Mbps)
RX1=$(cat /proc/net/dev | grep "$INTERFACE" | awk '{print $2}')
sleep 1
RX2=$(cat /proc/net/dev | grep "$INTERFACE" | awk '{print $2}')
BPS=$((RX2 - RX1))
MBPS=$((BPS * 8 / 1000000))
GBPS=$(echo "scale=2; $BPS * 8 / 1000000000" | bc 2>/dev/null || echo "0")

# 2. CHẨN ĐOÁN LOẠI TẤN CÔNG (Dựa trên Nftables counter)
DROPPED=$(nft list table netdev antiddos_v2 2>/dev/null | grep "drop" | awk '{sum+=$NF} END {print sum}')
# Đảm bảo các biến luôn là số nguyên để tránh lỗi so sánh
MBPS=${MBPS:-0}
DROPPED=${DROPPED:-0}
[[ ! "$MBPS" =~ ^[0-9]+$ ]] && MBPS=0
[[ ! "$DROPPED" =~ ^[0-9]+$ ]] && DROPPED=0

# Mặc định là ổn định
ATTACK_TYPE="✅ Hệ thống Ổn định / Bình thường"

# Phân tích sâu hơn các quy tắc có số lượng gói tin bị chặn (counter > 0)
if [ "$DROPPED" -gt 0 ]; then
    ATTACK_TYPE="⚔️ Botnet / Application Attack"
    
    # Kiểm tra từng rule cụ thể
    if nft list table netdev antiddos_v2 2>/dev/null | grep "tcp flags & (fin|syn) == (fin|syn)" | grep -v "packets 0" >/dev/null; then
        ATTACK_TYPE="🧨 TCP SYN/Malformed Flood"
    elif nft list table netdev antiddos_v2 2>/dev/null | grep "0x00ffff00fefefefefdfdfdfd12345678" | grep -v "packets 0" >/dev/null; then
        ATTACK_TYPE="🤖 Minecraft RakNet Join-Bot"
    elif nft list table netdev antiddos_v2 2>/dev/null | grep "ip frag-off" | grep -v "packets 0" >/dev/null; then
        ATTACK_TYPE="🧩 Fragmented IP Attack"
    elif nft list table netdev antiddos_v2 2>/dev/null | grep "udp dport" | grep -v "packets 0" >/dev/null; then
        ATTACK_TYPE="🌊 UDP Volumetric Flood"
    fi
fi

# 3. CHẾ ĐỘ GỬI TIN NHẮN (Gửi định kỳ hoặc Khi bị tấn công)
TIMESTAMP=$(date '+%d/%m/%Y %H:%M:%S')
IS_ATTACK=false
[ "$MBPS" -gt 50 ] || [ "$DROPPED" -gt 5000 ] && IS_ATTACK=true

# Màu sắc: Đỏ nếu bị ddos, Xanh nếu ổn định
COLOR=5814783
TITLE="📡 [BÁO CÁO ĐỊNH KỲ] PTERODACTYL NODE"
if [ "$IS_ATTACK" = true ]; then
    COLOR=15548997
    TITLE="🔥 [CẢNH BÁO ĐANG BỊ DDOS] V2 SIÊU CƯỜNG"
fi

PAYLOAD=$(cat <<JSON
{
  "embeds": [{
    "title": "$TITLE",
    "color": $COLOR,
    "fields": [
      { "name": "⏱️ Lõi Mạng (Ping)", "value": "\`$(ping -c 1 8.8.8.8 | awk -F '/' 'END {printf "%.0f\n", $5}')ms\`", "inline": true },
      { "name": "🚀 Băng thông (Gbps)", "value": "\`${GBPS} Gbps (${MBPS} Mbps)\`", "inline": true },
      { "name": "📡 Loại lưu lượng", "value": "\`${ATTACK_TYPE}\`", "inline": false },
      { "name": "🧱 Gói tin bị ép chết", "value": "🔥 \`${DROPPED}\` Gói tin rác", "inline": true },
      { "name": "💻 Tài Nguyên", "value": "CPU: \`$(top -bn1 | grep 'Cpu(s)' | awk '{print 100 - $8}')%\` | RAM Trống: \`$(free -m | awk '/Mem:/ {print $4}')MB\`", "inline": true },
      { "name": "🔍 TOP 3 IP KẾT NỐI", "value": "\`$(ss -tun state established | awk 'NR>1 {print $5}' | sed -E 's/.*([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+).*/\1/' | grep -v '127.0.0.1' | sort | uniq -c | sort -nr | head -n 3 | awk '{print $2 " (" $1 ")"}' | tr '\n' ' | ')\`", "inline": false }
    ],
    "footer": { "text": "Hệ thống Anti-DDoS V2 Agent • $TIMESTAMP" }
  }]
}
JSON
)

# Gửi tin nhắn (Nếu là Alert thì gửi ngay, nếu là Report thì Cronjob lo)
curl -s -H "Content-Type: application/json" -X POST -d "$PAYLOAD" "$WEBHOOK" >/dev/null 2>&1
