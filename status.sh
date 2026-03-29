#!/bin/bash
# ==========================================================
# 📊 ANTI-DDOS SYSTEM GLOBAL STATUS CHECKER
# Thiết kế: All-in-One Dashboard trong Terminal
# ==========================================================

# Màu sắc rực rỡ
RED='\033[1;31m'
GREEN='\033[1;32m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. Thu thập Thông số Phần cứng
CPU_LOAD=$(top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8"%"}')
RAM_USED=$(free -m | awk '/Mem:/ {printf "%d/%d MB", $3, $2}')
UPTIME=$(uptime -p)

# 2. Kiểm tra Firewall (Iptables)
[[ -n "$(iptables -L DOCKER-USER -n 2>/dev/null | grep 'DROP')" ]] && FW_STATUS="${GREEN}ĐANG CHẠY (ACTIVE)${NC}" || FW_STATUS="${RED}ĐANG TẮT (INACTIVE)${NC}"
[[ -n "$(iptables -L INPUT -n 2>/dev/null | grep 'allow_countries')" ]] && HOST_PROTECT="${GREEN}BẬT${NC}" || HOST_PROTECT="${RED}TẮT${NC}"

# 3. Đếm gói tin bị DROP (Chỉ lấy trong DOCKER-USER)
DROP_PKTS=$(iptables -xnvL DOCKER-USER 2>/dev/null | awk '/DROP/ {sum+=$1} END {print sum}')
[[ -z "$DROP_PKTS" ]] && DROP_PKTS=0

# 4. Kiểm tra IPset (Quốc gia VN/JP)
IP_COUNT=$(ipset list allow_countries 2>/dev/null | grep 'Number of entries:' | awk '{print $NF}')
[[ -z "$IP_COUNT" ]] && IP_COUNT="${RED}0 (Chưa nạp!)${NC}" || IP_COUNT="${CYAN}$IP_COUNT dải IP (VN/JP)${NC}"

# 5. Dịch vụ Hệ thống (Guardian)
[[ "$(systemctl is-active antiddos-guardian.service 2>/dev/null)" == "active" ]] && GUARD_STATUS="${GREEN}ĐANG BẢO VỆ${NC}" || GUARD_STATUS="${RED}CHƯA CÀI/TẮT${NC}"

# 6. Monitor (Cronjob Discord)
[[ -n "$(crontab -l 2>/dev/null | grep 'antiddos_monitor.sh')" ]] && MON_STATUS="${GREEN}ĐANG ĐẨY BÁO CÁO${NC}" || MON_STATUS="${YELLOW}KHÔNG HOẠT ĐỘNG${NC}"

# 7. Dò tìm Minecraft & Kết nối
MC_PORTS=$(ss -tulnp | awk 'NR>1 && $1~/tcp/ {print $5}' | awk -F: '{print $NF}' | grep -E '^255[0-9]{2}$|^19132$' | sort -V | uniq)
CONN_COUNTS=$(ss -tun state established | wc -l)

clear
echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}   🛡️  HỆ THỐNG ANTI-DDOS MINECRAFT - TRẠNG THÁI TỔNG THỂ       ${NC}"
echo -e "${CYAN}================================================================${NC}"

echo -e "\n${YELLOW}[1] THÔNG SỐ MÁY CHỦ:${NC}"
echo -e "   -> Uptime: $UPTIME"
echo -e "   -> Tải CPU: $CPU_LOAD"
echo -e "   -> Bộ nhớ RAM: $RAM_USED"

echo -e "\n${YELLOW}[2] TRẠNG THÁI TƯỜNG LỬA:${NC}"
echo -e "   -> Tường lửa Docker (DOCKER-USER): $FW_STATUS"
echo -e "   -> Bảo vệ Host (INPUT Chain): $HOST_PROTECT"
echo -e "   -> Dữ liệu IP quốc gia: $IP_COUNT"
echo -e "   -> ${RED}Gói tin rác đã tiêu diệt (DROP): $DROP_PKTS gói${NC}"

echo -e "\n${YELLOW}[3] KẾT NỐI MINECRAFT (ESTABLISHED):${NC}"
if [ -n "$MC_PORTS" ]; then
    for port in $MC_PORTS; do
        CONNS=$(ss -tan state established "( dport = :$port )" | wc -l)
        # Giảm 1 vì Header của ss
        ((CONNS--))
        echo -e "   -> Minecraft Port ${GREEN}$port${NC}: ${CYAN}$CONNS${NC} người chơi đang kết nối"
    done
else
    echo -e "   -> ${RED}Không tìm thấy server Minecraft nào đang chạy!${NC}"
fi
echo -e "   -> Tổng các loại kết nối (Web/SSH/Game): $CONN_COUNTS"

echo -e "\n${YELLOW}[4] CÁC DỊCH VỤ AN NINH:${NC}"
echo -e "   -> Docker Guardian: $GUARD_STATUS"
echo -e "   -> Discord Monitor: $MON_STATUS"

echo -e "\n${CYAN}================================================================${NC}"
echo -e "      💡 Gợi ý: Dùng lệnh 'sudo ./antiddos.sh' để nạp lại Giáp"
echo -e "${CYAN}================================================================${NC}"
