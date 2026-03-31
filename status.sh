#!/bin/bash
# ==========================================================
# 📊 ANTI-DDOS V2: REAL-TIME MONITORING DASHBOARD
# Hệ thống Giám sát Chiến sự Mạng
# ==========================================================

INTERFACE=$(ip -o -4 route get 8.8.8.8 | sed -nr 's/.*dev ([^ ]+).*/\1/p')
[ -z "$INTERFACE" ] && INTERFACE="eth0"

# Hàm hiển thị Dashboard
show_dashboard() {
    clear
    echo -e "\033[1;36m📡 [GIÁM SÁT CHIẾN SỰ MẠNG] ANTI-DDOS V2 SIÊU CƯỜNG\033[0m"
    echo -e "Card mạng: \033[1;33m$INTERFACE\033[0m | Thời gian: \033[1;32m$(date '+%H:%M:%S')\033[0m"
    echo "--------------------------------------------------------"

    # 1. Tính toán PPS và BPS (1 giây mẫu)
    TX1=$(cat /proc/net/dev | grep "$INTERFACE" | awk '{print $10}')
    RX1=$(cat /proc/net/dev | grep "$INTERFACE" | awk '{print $2}')
    PK1=$(cat /proc/net/dev | grep "$INTERFACE" | awk '{print $3}')
    sleep 1
    TX2=$(cat /proc/net/dev | grep "$INTERFACE" | awk '{print $10}')
    RX2=$(cat /proc/net/dev | grep "$INTERFACE" | awk '{print $2}')
    PK2=$(cat /proc/net/dev | grep "$INTERFACE" | awk '{print $3}')

    # PPS (Packets Per Second)
    PPS=$((PK2 - PK1))
    MBPS=$(((RX2 - RX1) * 8 / 1000000))
    GBPS=$(echo "scale=2; $((RX2 - RX1)) * 8 / 1000000000" | bc 2>/dev/null || echo "0")
    
    # 2. Thống kê Firewall (Nftables)
    # Lấy số lượng packet bị Drop từ bảng antiddos_v2
    DROP_PKTS=$(nft list table netdev antiddos_v2 2>/dev/null | grep "drop" | awk '{sum+=$NF} END {print sum}')
    [[ -z "$DROP_PKTS" ]] && DROP_PKTS=0

    # 3. Tài nguyên hệ thống
    CPU_LOAD=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    RAM_FREE=$(free -m | awk '/Mem:/ {print $4}')

    # Hiển thị
    echo -e "🚀 Băng thông đang vào: \033[1;31m$GBPS Gbps ($MBPS Mbps)\033[0m"
    echo -e "📦 Tốc độ gói tin:      \033[1;33m$PPS Packets/sec\033[0m"
    echo -e "🧱 Gói tin bị ép chết:  \033[1;31m🔥 $DROP_PKTS Gói tin rác\033[0m"
    echo "--------------------------------------------------------"
    echo -e "💻 CPU: \033[1;32m$CPU_LOAD%\033[0m | RAM Trống: \033[1;32m${RAM_FREE}MB\033[0m"
    
    # 4. TOP 3 IP Sát thủ
    echo "🔍 TOP 3 IP KẾT NỐI NHIỀU NHẤT:"
    ss -tun state established | awk 'NR>1 {print $5}' | sed -E 's/.*([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+).*/\1/' | grep -v '127.0.0.1' | sort | uniq -c | sort -nr | head -n 3 | awk '{printf "   - \033[1;37m%s\033[0m (%s cổng)\n", $2, $1}'
    
    echo "--------------------------------------------------------"
    echo -e "\033[1;30mBấm Ctrl+C để thoát Dashboard.\033[0m"
}

# Hỗ trợ tham số --watch
if [[ "$1" == "--watch" ]]; then
    while true; do
        show_dashboard
    done
else
    show_dashboard
fi
