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
ATTACK_TYPE="⚔️ Botnet / Application Attack"
DROPPED=$(nft list table netdev antiddos_v2 2>/dev/null | grep "drop" | awk '{sum+=$NF} END {print sum}')
# Đảm bảo các biến luôn là số nguyên để tránh lỗi so sánh
MBPS=${MBPS:-0}
DROPPED=${DROPPED:-0}
[[ ! "$MBPS" =~ ^[0-9]+$ ]] && MBPS=0
[[ ! "$DROPPED" =~ ^[0-9]+$ ]] && DROPPED=0

# Phân tích sâu hơn các gói tin bị chặn
if nft list table netdev antiddos_v2 2>/dev/null | grep -A 5 "ingress" | grep -q "tcp flags & (fin|syn) == (fin|syn)"; then
    ATTACK_TYPE="🧨 TCP SYN/Malformed Flood"
fi
if nft list table netdev antiddos_v2 2>/dev/null | grep -A 10 "ingress" | grep -q "udp dport"; then
    ATTACK_TYPE="🌊 UDP Volumetric Flood"
fi
if nft list table netdev antiddos_v2 2>/dev/null | grep -A 10 "ingress" | grep -q "0x00ffff00fefefefefdfdfdfd12345678"; then
    ATTACK_TYPE="🤖 Minecraft RakNet Join-Bot"
fi
if nft list table netdev antiddos_v2 2>/dev/null | grep -A 5 "ingress" | grep -q "ip frag-off"; then
    ATTACK_TYPE="🧩 Fragmented IP Attack"
fi

# 3. GỬI CẢNH BÁO NẾU PHÁT HIỆN BẤT THƯỜNG (PPS > 5,000 hoặc MBPS > 50)
if [ "$MBPS" -gt 50 ] || [ "$DROPPED" -gt 5000 ]; then
    TIMESTAMP=$(date '+%d/%m/%Y %H:%M:%S')
    
    PAYLOAD=$(cat <<JSON
{
  "embeds": [{
    "title": "🔥 [CẢNH BÁO ĐANG BỊ DDOS] V2 SIÊU CƯỜNG",
    "color": 15548997,
    "fields": [
      { "name": "📡 Loại tấn công", "value": "\`${ATTACK_TYPE}\`", "inline": true },
      { "name": "🚀 Băng thông dội vào", "value": "\`${GBPS} Gbps (${MBPS} Mbps)\`", "inline": true },
      { "name": "🧱 Gói tin bị ép chết", "value": "\`${DROPPED} Packets\`", "inline": false },
      { "name": "💻 Interface", "value": "\`${INTERFACE}\`", "inline": true },
      { "name": "⏱️ Thời điểm", "value": "\`${TIMESTAMP}\`", "inline": true }
    ],
    "footer": { "text": "Hệ thống Cảnh vệ Cao cấp Agent" }
  }]
}
JSON
)
    curl -s -H "Content-Type: application/json" -X POST -d "$PAYLOAD" "$WEBHOOK" >/dev/null 2>&1
fi
