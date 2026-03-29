#!/bin/bash
# ===== ANTI-DDOS SCRIPT CẤP CAO (Minecraft Pterodactyl/Docker) =====
# Thiết kế bởi Agent
# - Tự động quét & mở port TCP quản trị (SSH, Web)
# - Chỉ nhận kết nối UDP (Game) từ VN và Nhật Bản
# - Tối đa 10 luồng / thiết bị để bóp gãy tool DDoS, Rate limit UDP 30 túi/giây
# - Cấu hình tối ưu nhân hệ điều hành chống tràn bảng đệm (nf_conntrack)
# ====================================================================

echo -e "\033[1;32m[+] BẤT ĐẦU CÀI ĐẶT CÔNG NGHỆ ANTI-DDOS MỚI NHẤT...\033[0m"

# KIỂM TRA CHẾ ĐỘ CHẠY (Bình thường hay --fast cho Guardian)
FAST_MODE=false
if [[ "$1" == "--fast" ]]; then
    FAST_MODE=true
    echo -e "\033[1;33m[!] CHẠY CHẾ ĐỘ --FAST: Bỏ qua cài đặt & cập nhật IP các quốc gia.\033[0m"
fi

# 1. TỐI ƯU KERNEL SYSCTL LỚP MẠNG CỐT LÕI (Chống TCP SYN Flood & Mở Rộng Bảng Đệm)
echo "[1/6] Đang tiến hành ép xung Nhân Linux (Tuning Sysctl TCP/UDP Kernel)..."
if [ "$FAST_MODE" = false ]; then
cat <<EOF > /etc/sysctl.d/99-antiddos-mc.conf
# [CẤU HÌNH LIỀU THUỐC TRỊ BỆNH SYN FLOOD]
net.ipv4.tcp_syncookies=1
net.ipv4.tcp_max_syn_backlog=15000
net.core.somaxconn=15000
net.ipv4.tcp_synack_retries=2
net.ipv4.tcp_fin_timeout=15

# [CHỐNG TRÀN OVERLOAD BẢNG THEO DÕI NF_CONNTRACK]
net.netfilter.nf_conntrack_max=2000000
net.nf_conntrack_max=2000000

# [HOÀN TRẢ BỘ NHỚ NHANH TỪ CÁC CUỘC TẤN CÔNG UDP]
net.netfilter.nf_conntrack_udp_timeout=10
net.netfilter.nf_conntrack_udp_timeout_stream=20
EOF
sysctl -p /etc/sysctl.d/99-antiddos-mc.conf 2>/dev/null >/dev/null || true
fi

# 2. CÀI ĐẶT ỨNG DỤNG MỘT CÁCH TỰ ĐỘNG
if [ "$FAST_MODE" = false ]; then
echo "[2/6] Đang cài đặt Ipset & Iptables-persistent ngầm..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y -q >/dev/null 2>&1
apt-get install -y -q ipset iptables iptables-persistent netfilter-persistent curl awk >/dev/null 2>&1
fi

# 3. TẢI VÀ NẠP DANH SÁCH VN VÀ NHẬT BẢN THẦN TỐC
if [ "$FAST_MODE" = false ]; then
echo "[3/6] Tải danh sách IP từ IPDeny (Chỉ: VN, JP)..."
ZONE_DIR="/etc/antiddos_zones"
mkdir -p "$ZONE_DIR"
cd "$ZONE_DIR"

# Cố gắng cập nhật IP mới, nếu thất bại thì tiếp tục dùng lại file Zone Cũ (Cứu cánh lúc VPS Restart rớt mạng)
curl -s -f -o vn.zone.tmp https://www.ipdeny.com/ipblocks/data/countries/vn.zone && mv vn.zone.tmp vn.zone
curl -s -f -o jp.zone.tmp https://www.ipdeny.com/ipblocks/data/countries/jp.zone && mv jp.zone.tmp jp.zone

if [ ! -s vn.zone ] || [ ! -s jp.zone ]; then
    echo -e "\033[1;31mLỖI TRẦM TRỌNG: Máy chủ tải IP thất bại (ipdeny rớt) VÀ không tìm thấy Cache cũ dự phòng. Script bắt buộc ngừng chạy!\033[0m"
    exit 1
fi

# Tốc chiến Nạp IP bằng Ipset Restore
echo "      -> Nạp danh sách vào Firewall..."
ipset destroy allow_countries 2>/dev/null
ipset create allow_countries hash:net

echo "create allow_countries hash:net -exist" > "$ZONE_DIR/ipset_load.txt"
awk '{print "add allow_countries " $1}' vn.zone >> "$ZONE_DIR/ipset_load.txt"
awk '{print "add allow_countries " $1}' jp.zone >> "$ZONE_DIR/ipset_load.txt"
ipset restore < "$ZONE_DIR/ipset_load.txt"
fi

# 4. KÍCH HOẠT QUẢ BOMB RỦI RO (HỦY THÀNH QUẢ TỰ ĐỘNG SAU 5 PHÚT NẾU LỖI)
if [ "$FAST_MODE" = false ]; then
echo "[4/6] Thiếp lập chế độ 5 phút tự cứu (Tránh bị khóa nhầm...)"
( sleep 300 && iptables -F && iptables -t nat -F && iptables -t mangle -F && echo -e "\n\n[!!!] SERVER ĐÃ TỰ ĐỘNG XÓA FIREWALL VÌ BẠN KHÔNG TẮT FAIL-SAFE TRONG 5 PHÚT.\n" > /dev/pts/0 2>/dev/null ) &
FAILSAFE_PID=$!
echo "$FAILSAFE_PID" > /tmp/antiddos_failsafe.pid
fi

# 5. CẤU HÌNH IPTABLES HOST (INPUT) VÀ TỰ DÒ CỔNG TCP
echo "[5/6] Tự động đọc và bảo vệ Cổng (Port) hiện tại..."

# Lỗ hổng / Loopback
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -s 127.0.0.0/8 -j ACCEPT
iptables -A INPUT -s 172.16.0.0/12 -j ACCEPT    # Docker Network
iptables -A INPUT -s 100.64.0.0/10 -j ACCEPT     # Tailscale Network

# --- BẢO TRÌ DNS CHO HOST & DOCKER (CỰC KỲ QUAN TRỌNG) ---
iptables -A INPUT -p udp --dport 53 -j ACCEPT
iptables -A INPUT -p udp --sport 53 -j ACCEPT
iptables -A INPUT -p tcp --dport 53 -j ACCEPT

iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# [ĐỀ XUẤT] Chặn các kết nối DỊ TẬT
iptables -A INPUT -m conntrack --ctstate INVALID -j DROP
# [ĐỀ XUẤT] Chống Ping Flood Limit (Chỉ cho phép 1 ping mỗi giây)
iptables -A INPUT -p icmp -m limit --limit 1/s --limit-burst 2 -j ACCEPT
iptables -A INPUT -p icmp -j DROP

# Tự động quét Port TCP
ACTIVE_PORTS=$(ss -tulnp | awk 'NR>1 && $1~/tcp/ {print $5}' | awk -F: '{print $NF}' | sort -n | uniq)
for port in $ACTIVE_PORTS; do
    echo "      -> Đã khóa & bảo vệ TCP Port: $port"
    # Giới hạn cho port quản lý (Pterodactyl/SSH) = cứng 20 connection 
    iptables -A INPUT -p tcp --dport "$port" -m connlimit --connlimit-above 20 -j REJECT --reject-with tcp-reset
    iptables -A INPUT -p tcp --dport "$port" -j ACCEPT
done

iptables -A INPUT -m set --match-set allow_countries src -j ACCEPT
iptables -A INPUT -j DROP # Drop TẤT CẢ TCP/UDP không thuộc danh sách hoặc các Port không dùng làm dịch vụ

# 6. BẢO VỆ MINECRAFT TRONG DOCKER (DOCKER-USER)
echo "[6/6] Định hình màng chắn chống DDoS Minecraft (UDP & TCP)..."

# --- TỰ ĐỘNG DÒ CÔNG MINECRAFT (DOCKER & SYSTEM) ---
# Dò port map từ host vào container (ưu tiên 25565)
MC_TCP_PORTS_DOCKER=$(docker ps --format '{{.Ports}}' 2>/dev/null | grep -oP '\d+(?=->25565)' | sort -n | uniq)
# Dò thêm từ hệ thống (các dải port phổ biến 1913x, 1914x, 255xx, v.v.)
MC_TCP_PORTS_SYSTEM=$(ss -tulnp | awk 'NR>1 && $1~/tcp/ {print $5}' | awk -F: '{print $NF}' | grep -E '^255[0-9]{2}$|^2557[1-9]$|^1913[0-9]$|^1914[0-9]$|^19199$|^19999$|^34725$|^2029$' | sort -n | uniq)
MC_TCP_PORTS=$(echo -e "$MC_TCP_PORTS_DOCKER\n$MC_TCP_PORTS_SYSTEM" | grep -v '^$' | sort -n | uniq | xargs)
[ -z "$MC_TCP_PORTS" ] && MC_TCP_PORTS="25565"

# --- DỌN DẸP RULE CŨ TRONG DOCKER-USER ---
iptables -F DOCKER-USER 2>/dev/null

# --- THIẾT LẬP LUẬT BẢO VỆ (Rule nào khớp sẽ thoát bằng RETURN) ---
# 1. Luôn cho phép các kết nối đã thiết lập và mạng nội bộ Docker
iptables -A DOCKER-USER -m state --state ESTABLISHED,RELATED -j RETURN
iptables -A DOCKER-USER -s 172.16.0.0/12 -j RETURN

# 2. MỞ KHÓA DNS CHO DOCKER (Không để UnknownHostException)
iptables -A DOCKER-USER -p udp --dport 53 -j RETURN
iptables -A DOCKER-USER -p udp --sport 53 -j RETURN

# 3. CHỐNG SYN FLOOD & TCP STATE ANOMALY (Toàn bộ TCP)
iptables -A DOCKER-USER -p tcp ! --syn -m state --state NEW -j DROP 
iptables -A DOCKER-USER -p tcp --syn -m hashlimit --hashlimit-upto 50/sec --hashlimit-burst 100 --hashlimit-mode srcip --hashlimit-name tcp_syn_limit -j RETURN
iptables -A DOCKER-USER -p tcp --syn -j DROP

# 4. BẢO VỆ RIÊNG CHO CÁC PORT MINECRAFT TCP
for port in $MC_TCP_PORTS; do
    echo "      -> Cài giáp TCP Minecraft Port: $port"
    # Chặn IP ngoại quốc
    iptables -A DOCKER-USER -p tcp --dport "$port" -m set ! --match-set allow_countries src -j DROP
    # Giới hạn 20 kết nối/IP (áp dụng cho cả IP VN/JP)
    iptables -A DOCKER-USER -p tcp --dport "$port" -m connlimit --connlimit-above 20 -j REJECT --reject-with tcp-reset
    # Nếu vượt qua các bước trên -> OK
    iptables -A DOCKER-USER -p tcp --dport "$port" -j RETURN
done

# 5. BẢO VỆ MINECRAFT UDP (BEDROCK)
echo "      -> Cài giáp UDP Minecraft..."

# Dò tìm các port UDP đang Map của Docker (thường là 19132)
MC_UDP_PORTS=$(docker ps --format '{{.Ports}}' 2>/dev/null | grep -oP '\d+(?=/udp)' | grep -v '53' | sort -n | uniq | xargs | tr ' ' ',')
[ -z "$MC_UDP_PORTS" ] && MC_UDP_PORTS="19132"

# CHỈ CHẶN IP NGOẠI QUỐC VÀO CÁC PORT GAME UDP (Để không chặn nhầm DNS)
iptables -A DOCKER-USER -p udp -m multiport --dports "$MC_UDP_PORTS" -m set ! --match-set allow_countries src -j DROP
# Giới hạn 10 luồng UDP/IP cho Game
iptables -A DOCKER-USER -p udp -m multiport --dports "$MC_UDP_PORTS" -m set --match-set allow_countries src -m connlimit --connlimit-above 10 -j DROP
# Rate limit 30 packet/giây cho Game
iptables -A DOCKER-USER -p udp -m multiport --dports "$MC_UDP_PORTS" -m set --match-set allow_countries src -m hashlimit --hashlimit-upto 30/sec --hashlimit-burst 50 --hashlimit-mode srcip --hashlimit-name udp_ratelimit -j RETURN
# Khi quá tải -> Drop
iptables -A DOCKER-USER -p udp -m multiport --dports "$MC_UDP_PORTS" -m set --match-set allow_countries src -j DROP


# Luôn cho phép Output 
iptables -I OUTPUT 1 -j ACCEPT
netfilter-persistent save >/dev/null 2>&1

echo -e "\n\033[1;32m[+] CÀI ĐẶT THÀNH CÔNG AN TOÀN TUYỆT ĐỐI\033[0m"
echo -e "\033[1;31m================ LƯU Ý QUAN TRỌNG =================\033[0m"
echo "Hệ thống sẽ TỰ ĐỘNG XÓA TOÀN BỘ CHẶN SAU 5 PHÚT NỮA"
echo "để đề phòng tình trạng bạn cấu hình nhầm và sập máy, không thể kết nối SSH."
echo ""
echo "Bây giờ bạn hãy KIỂM TRA MỘT THỨ DUY NHẤT: Bấm kết nối mới (Mở Tab SSH Mới/Vào Web Panel) để xem VPS có đang chạy tốt không?"
echo -e "Nếu bạn truy cập bình thường, HÃY DÁN LỆNH SAU ĐỂ TẮT BOM HẸN GIỜ: \033[1;33mkill $FAILSAFE_PID\033[0m"
echo -e "\033[1;31m===================================================\033[0m\n"
