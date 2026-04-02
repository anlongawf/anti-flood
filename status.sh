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
PREV_XDP_DROPS=0
PREV_NFT_DROPS=0
FIRST_RUN=true

get_stats() {
    # Network Traffic
    LINE=$(grep "$INTERFACE" /proc/net/dev)
    RX_BYTES=$(echo $LINE | awk '{print $2}')
    RX_PKTS=$(echo $LINE | awk '{print $3}')
    
    # XDP Firewall Drops (From Log/Stats if xdpfw is running)
    # Note: xdpfw usually logs total drops to its log or we can use xdpfw-list
    XDP_DROPS=$(tail -n 100 /var/log/xdpfw.log 2>/dev/null | grep -c "Dropped")
    [ -z "$XDP_DROPS" ] && XDP_DROPS=0
    
    # Nftables Drops
    NFT_DROPS=$(nft list table netdev antiddos_v2 2>/dev/null | grep "packets" | awk '{sum+=$5} END {print sum}')
    [ -z "$NFT_DROPS" ] && NFT_DROPS=0
}

show_dashboard() {
    get_stats
    
    if [ "$FIRST_RUN" = true ]; then
        PREV_RX_BYTES=$RX_BYTES
        PREV_RX_PKTS=$RX_PKTS
        PREV_XDP_DROPS=$XDP_DROPS
        PREV_NFT_DROPS=$NFT_DROPS
        FIRST_RUN=false
        return
    fi

    # Calculations
    DIFF_BYTES=$((RX_BYTES - PREV_RX_BYTES))
    DIFF_PKTS=$((RX_PKTS - PREV_RX_PKTS))
    DIFF_XDP=$((XDP_DROPS - PREV_XDP_DROPS))
    [ "$DIFF_XDP" -lt 0 ] && DIFF_XDP=0
    
    MBPS=$(echo "scale=2; $DIFF_BYTES * 8 / 1048576" | bc)
    PPS=$DIFF_PKTS

    # Update previous values
    PREV_RX_BYTES=$RX_BYTES
    PREV_RX_PKTS=$RX_PKTS
    PREV_XDP_DROPS=$XDP_DROPS

    # Discovery Ports (Live)
    P_PORTS=$(bash scripts/discover_v3.sh --shell 2>/dev/null | grep "ACTIVE_PTERO_PORTS" | cut -d '"' -f 2)

    # Clear screen and draw
    clear
    echo -e "${CYAN}┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}  ${BOLD}${WHITE}📡 ANTI-DDOS V3 ULTIMATE - PRO REAL-TIME MONITOR${NC}       ${CYAN}│${NC}"
    echo -e "${CYAN}├──────────────────────────┬───────────────────────────────┤${NC}"
    echo -e "${CYAN}│${NC} ${WHITE}Interface:${NC} ${YELLOW}${INTERFACE}${NC}   ${CYAN}│${NC} ${WHITE}Status:${NC} ${GREEN}PROTECTED (XDP)${NC}      ${CYAN}│${NC}"
    echo -e "${CYAN}└──────────────────────────┴───────────────────────────────┘${NC}"

    echo -e "\n  ${BOLD}${BLUE}🚀 NETWORK TRAFFIC${NC}"
    echo -e "  Bandwidth:      ${RED}${MBPS} Mbps${NC} ${GRAY}($(echo "scale=2; $MBPS / 1000" | bc) Gbps)${NC}"
    echo -e "  Throughput:     ${YELLOW}${PPS} PPS${NC}"

    echo -e "\n  ${BOLD}${PURPLE}🧱 MULTI-LAYER DEFENSE${NC}"
    if [ "$DIFF_XDP" -gt 0 ]; then
        echo -e "  Attack Alert:   ${RED}🔥 XDP BLOCKING ACTIVE${NC}"
    else
        echo -e "  Attack Alert:   ${GREEN}✅ ALL CLEAR${NC}"
    fi
    echo -e "  XDP Drops/s:    ${RED}${DIFF_XDP} pkt/s${NC} ${GRAY}(Driver Level)${NC}"
    echo -e "  NFT Total:      ${YELLOW}${NFT_DROPS} packets${NC} ${GRAY}(Kernel Level)${NC}"

    echo -e "\n  ${BOLD}${GREEN}💻 PTERODACTYL DISCOVERY${NC}"
    echo -e "  Active Ports:   ${WHITE}${P_PORTS:-None detected}${NC}"
    
    echo -e "\n  ${BOLD}${YELLOW}🔍 TOP 3 GLOBAL CONNECTIONS${NC}"
    ss -tun state established 2>/dev/null | awk 'NR>1 {split($5,a,":"); print a[1]}' | grep -E '^[0-9]' | sort | uniq -c | sort -nr | head -n 3 | awk '{printf "  - %-15s (%s cns)\n", $2, $1}'

    echo -e "\n${GRAY}----------------------------------------------------------${NC}"
    echo -e "${GRAY}Refresh: 1s | Watcher: ACTIVE | Press Ctrl+C to exit${NC}"
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

