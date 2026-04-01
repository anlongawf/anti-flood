#!/bin/bash
# ==========================================================
# 📊 ANTI-DDOS V2: PREMIUM REAL-TIME DASHBOARD
# Designed for High-Performance Monitoring
# ==========================================================

# Colors & Style
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
PURPLE='\033[1;35m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m'
BOLD='\033[1m'

# Search for interface
INTERFACE=$(ip -o -4 route get 8.8.8.8 | sed -nr 's/.*dev ([^ ]+).*/\1/p')
[ -z "$INTERFACE" ] && INTERFACE=$(ip link show | awk -F': ' '$2 != "lo" {print $2; exit}')

# Initialization for deltas
PREV_RX_BYTES=0
PREV_RX_PKTS=0
PREV_DROPS=0
FIRST_RUN=true

get_stats() {
    # Network Traffic from /proc/net/dev
    LINE=$(grep "$INTERFACE" /proc/net/dev)
    RX_BYTES=$(echo $LINE | awk '{print $2}')
    RX_PKTS=$(echo $LINE | awk '{print $3}')
    
    # Firewall Drops from Nftables (Total)
    DROPS=$(nft list table netdev antiddos_v2 2>/dev/null | grep "packets" | awk '{sum+=$5} END {print sum}')
    [ -z "$DROPS" ] && DROPS=0
}

show_dashboard() {
    get_stats
    
    if [ "$FIRST_RUN" = true ]; then
        PREV_RX_BYTES=$RX_BYTES
        PREV_RX_PKTS=$RX_PKTS
        PREV_DROPS=$DROPS
        FIRST_RUN=false
        return
    fi

    # Calculations (per second)
    DIFF_BYTES=$((RX_BYTES - PREV_RX_BYTES))
    DIFF_PKTS=$((RX_PKTS - PREV_RX_PKTS))
    DIFF_DROPS=$((DROPS - PREV_DROPS))
    
    MBPS=$(echo "scale=2; $DIFF_BYTES * 8 / 1048576" | bc)
    PPS=$DIFF_PKTS
    DROPS_PER_SEC=$DIFF_DROPS

    # Update previous values
    PREV_RX_BYTES=$RX_BYTES
    PREV_RX_PKTS=$RX_PKTS
    PREV_DROPS=$DROPS

    # Clear screen and draw
    clear
    echo -e "${CYAN}┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}  ${BOLD}${WHITE}📡 ANTI-DDOS V2 SIÊU CƯỜNG - GIÁM SÁT CHIẾN SỰ MẠNG${NC}    ${CYAN}│${NC}"
    echo -e "${CYAN}├──────────────────────────┬───────────────────────────────┤${NC}"
    echo -e "${CYAN}│${NC} ${WHITE}Card mạng:${NC} ${YELLOW}${INTERFACE}${NC}  ${CYAN}│${NC} ${WHITE}Thời gian:${NC} ${GREEN}$(date '+%H:%M:%S')${NC}       ${CYAN}│${NC}"
    echo -e "${CYAN}└──────────────────────────┴───────────────────────────────┘${NC}"

    echo -e "\n  ${BOLD}${BLUE}🚀 BĂNG THÔNG HIỆN TẠI${NC}"
    echo -e "  Traffic In:     ${RED}${MBPS} Mbps${NC} ${GRAY}($(echo "scale=2; $MBPS / 1000" | bc) Gbps)${NC}"
    echo -e "  Packets/sec:    ${YELLOW}${PPS} PPS${NC}"

    echo -e "\n  ${BOLD}${PURPLE}🧱 TÌNH HÌNH PHÒNG THỦ${NC}"
    if [ "$DROPS_PER_SEC" -gt 0 ]; then
        echo -e "  Tình trạng:     ${RED}🔥 ĐANG BỊ TẤN CÔNG${NC}"
    else
        echo -e "  Tình trạng:     ${GREEN}✅ Ổn định${NC}"
    fi
    echo -e "  Drops/sec:      ${RED}${DROPS_PER_SEC} Gói tin/giây${NC}"
    echo -e "  Tổng chặn:      ${YELLOW}${DROPS} Gói tin rác${NC}"

    echo -e "\n  ${BOLD}${GREEN}💻 TÀI NGUYÊN HỆ THỐNG${NC}"
    CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8}')
    RAM=$(free -m | awk '/Mem:/ {print $3 "/" $2 "MB"}')
    echo -e "  CPU Load:       ${BOLD}${WHITE}${CPU}%${NC}"
    echo -e "  RAM Usage:      ${BOLD}${WHITE}${RAM}${NC}"

    echo -e "\n  ${BOLD}${YELLOW}🔍 TOP 3 IP KẾT NỐI NHIỀU NHẤT${NC}"
    ss -tun state established 2>/dev/null | awk 'NR>1 {split($5,a,":"); print a[1]}' | grep -E '^[0-9]' | sort | uniq -c | sort -nr | head -n 3 | awk '{printf "  - %-15s (%s connections)\n", $2, $1}'

    echo -e "\n${GRAY}----------------------------------------------------------${NC}"
    echo -e "${GRAY}Bấm Ctrl+C để thoát Dashboard. (Refresh: 1s)${NC}"
}

# MAIN LOOP
if [[ "$1" == "--watch" ]]; then
    while true; do
        show_dashboard
        sleep 1
    done
else
    # Single shot: need two samples to get rates
    get_stats
    PREV_RX_BYTES=$RX_BYTES
    PREV_RX_PKTS=$RX_PKTS
    PREV_DROPS=$DROPS
    sleep 1
    show_dashboard
fi

