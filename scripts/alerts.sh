#!/bin/bash
# ==========================================================
# 🔔 LAYER 5: DISCORD WEBHOOK ALERTS (V2)
# Chẩn đoán loại tấn công & Tính toán băng thông thực tế
# ==========================================================

INTERFACE=$(ip -o -4 route get 8.8.8.8 | sed -nr 's/.*dev ([^ ]+).*/\1/p')
[ -z "$INTERFACE" ] && INTERFACE="eth0"

# Lấy Webhook từ cấu hình cũ nếu có
WEBHOOK=$(grep -oP 'https://discord.com/api/webhooks/[^"]+' /usr/local/bin/antiddos_monitor.sh 2>/dev/null | head -n 1)

if [ -z "$WEBHOOK" ]; then
    echo "[!] Không tìm thấy Webhook URL. Vui lòng chạy setup_monitor.sh trước."
    exit 1
fi

# 1. TÍNH TOÁN BĂNG THÔNG (Gbps/Mbps)
RX1=$(cat /proc/net/dev | grep "$INTERFACE" | awk '{print $2}')
sleep 1
RX2=$(cat /proc/net/dev | grep "$INTERFACE" | awk '{print $2}')
BPS=$((RX2 - RX1))
MBPS=$((BPS * 8 / 1000000))
GBPS=$(echo "scale=2; $BPS * 8 / 1000000000" | bc 2>/dev/null || echo "0")

# 2. CHẨN ĐOÁN LOẠI TẤN CÔNG (Dựa trên Nftables counter)
ATTACK_TYPE="Unknown / Botnet"
DROPPED=$(nft list table netdev antiddos_v2 | grep "drop" | awk '{sum+=$NF} END {print sum}')

# Kiểm tra các rule cụ thể để đoán loại
if nft list table netdev antiddos_v2 | grep -q "tcp flags & (fin|syn) == (fin|syn)"; then
    ATTACK_TYPE="TCP SYN Flood / Malformed"
fi
if nft list table netdev antiddos_v2 | grep -q "udp dport"; then
    ATTACK_TYPE="UDP Flood / RakNet Attack"
fi

# 3. GỬI CẢNH BÁO NẾU PHÁT HIỆN BẤT THƯỜNG (PPS cao hoặc MBPS > 100)
if [ "$MBPS" -gt 100 ] || [ "$DROPPED" -gt 10000 ]; then
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
