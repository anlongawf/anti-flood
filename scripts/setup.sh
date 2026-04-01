#!/bin/bash
# ==========================================================
# 🛡️ ANTI-DDOS SIÊU CƯỜNG V2 (SETUP & INSTALLER)
# Thiết kế: 4-Layer Defense / Ingress Filter / RakNet DPI
# ==========================================================

echo -e "\033[1;32m[+] BẮT ĐẦU CÀI ĐẶT HỆ THỐNG ANTI-DDOS V2 SIÊU CƯỜNG...\033[0m"

# 1. KIỂM TRA QUYỀN VÀ PHIÊN BẢN
if [[ $EUID -ne 0 ]]; then
   echo "[✘] Script này phải được chạy với quyền root (sudo)!"
   exit 1
fi

# 2. CÀI ĐẶT DEPENDENCIES
echo "[1/6] Đang cài đặt Dependencies (Nftables, Ipset, Curl)..."
apt-get update -y -q >/dev/null 2>&1
apt-get install -y -q nftables ipset curl awk >/dev/null 2>&1

# 3. TỰ ĐỘNG NHẬN DIỆN INTERFACE
INTERFACE=$(ip -o -4 route get 8.8.8.8 | sed -nr 's/.*dev ([^ ]+).*/\1/p')
if [ -z "$INTERFACE" ]; then
    INTERFACE=$(ip link show | awk -F': ' '$2 != "lo" {print $2; exit}')
fi
echo "[2/6] Card mạng đang hoạt động: $INTERFACE"

# 4. CHẠY CÁC MODULE LAYER 2 & 3
bash scripts/optimize-kernel.sh
bash scripts/update-geoip.sh

# 4.1. THIẾT LẬP CRONJOB CẬP NHẬT IP HÀNG TUẦN (CHỦ NHẬT)
echo "      -> Thiết lập Lịch cập nhật IP VN/JP hàng tuần..."
(crontab -l 2>/dev/null | grep -v "update-geoip.sh" | crontab -)
(crontab -l 2>/dev/null; echo "0 0 * * 0 bash /Users/anphan/Documents/block_ip/scripts/update-geoip.sh >/dev/null 2>&1") | crontab -

# 5. CẤU HÌNH NFTABLES (SIÊU CẤP TỐC ĐỘ)
echo "[3/6] Đang thiết lập Nftables Ingress Hook (Layer 1)..."

# Xóa cấu hình antiddos cũ (Chỉ xóa bảng riêng của script, giữ nguyên rules của Docker)
nft delete table netdev antiddos_v2 2>/dev/null
nft delete table ip raw_bypass 2>/dev/null

# Tạo bảng Ingress (Tầng Driver)
nft add table netdev antiddos_v2
nft add chain netdev antiddos_v2 ingress { type filter hook ingress device "$INTERFACE" priority -500 \; policy accept \; }

# --- FILTER LAYER 1: CHẶN RÁC NGAY LẬP TỨC ---
# 1. Chặn Invalid Packets (Malformed)
nft add rule netdev antiddos_v2 ingress tcp flags \& \(fin\|syn\|rst\|psh\|ack\|urg\) == 0 counter drop comment \"drop_invalid_tcp_flags\"
nft add rule netdev antiddos_v2 ingress tcp flags \& \(fin\|syn\) == \(fin\|syn\) counter drop comment \"drop_invalid_tcp_flags\"
nft add rule netdev antiddos_v2 ingress tcp flags \& \(syn\|rst\) == \(syn\|rst\) counter drop comment \"drop_invalid_tcp_flags\"
nft add rule netdev antiddos_v2 ingress tcp flags \& \(fin\|rst\) == \(fin\|rst\) counter drop comment \"drop_invalid_tcp_flags\"

# 2. Chặn Port Scan & Fragmented Packet
nft add rule netdev antiddos_v2 ingress ip frag-off \& 0x1fff != 0 counter drop comment \"drop_fragmented\"

# 3. Chốt chặn IP Quốc gia (Dùng Geo-Set từ scripts/update-geoip.sh)
echo "[4/6] Đang liên kết Geo-Shield vào tầng Ingress..."
nft add set netdev antiddos_v2 allow_countries { type ipv4_addr \; flags interval \; }
# Nạp IP từ ipset vào nft set (Đồng bộ hóa)
ipset list allow_countries | grep -E '^[0-9]' | xargs -I {} nft add element netdev antiddos_v2 allow_countries { {} }

# --- FILTER LAYER 4: RAKNET DEEP FILTER (MINECRAFT) ---
echo "[5/6] Đang kích hoạt RakNet Deep Filter (DPI)..."
# Logic: Chỉ cho phép gói tin UDP có Magic Bytes của RakNet OpenConnectionRequest
nft add rule netdev antiddos_v2 ingress udp dport { 19132, 19133 } @th,160,128 != 0x00ffff00fefefefefdfdfdfd12345678 counter drop comment \"drop_raknet_dpi\"

# --- STATELESS BYPASS (NOTRACK) ---
echo "      -> Kích hoạt Stateless Prerouting (Băng qua bảng Conntrack)..."
nft add table ip raw_bypass
nft add chain ip raw_bypass prerouting { type filter hook prerouting priority -300 \; policy accept \; }
# Bỏ qua lưu vết (NOTRACK) cho các port game để chống tràn RAM/CPU
GAME_PORTS=$(docker ps --format '{{.Ports}}' 2>/dev/null | grep -oP '\d+(?=/udp)' | xargs | tr ' ' ',')
[ -z "$GAME_PORTS" ] && GAME_PORTS="19132"
nft add rule ip raw_bypass prerouting udp dport { $GAME_PORTS } notrack

# --- DROP KHÔNG THUỘC VN/JP ---
# Cho phép loopback và mạng docker nội bộ (Mạng Tin Cậy)
nft add rule netdev antiddos_v2 ingress ip saddr { 127.0.0.0/8, 172.16.0.0/12, 10.0.0.0/8 } accept

# Cho phép port quan trọng (SSH) nhưng giới hạn rate để chống Brute Force
nft add rule netdev antiddos_v2 ingress tcp dport 22 limit rate 10/second accept

# Các port game: Chỉ VN/JP
nft add rule netdev antiddos_v2 ingress ip saddr != @allow_countries udp dport { $GAME_PORTS } counter drop comment \"drop_geoip_untrusted\"

# --- RATE LIMIT CHUYÊN SÂU ---
nft add rule netdev antiddos_v2 ingress udp dport { $GAME_PORTS } limit rate over 100/second burst 200 packets counter drop comment \"drop_udp_ratelimit\"

# 6. LƯU CẤU HÌNH VĨNH VIỄN (PERSISTENCE)
echo "[6/7] Đang lưu cấu hình vĩnh viễn (Persistence)..."
nft list ruleset > /etc/nftables.conf
systemctl enable --now nftables >/dev/null 2>&1

# 7. FAILSAFE 5 PHÚT (Bảo hiểm cho User)
echo -e "\n[7/7] Thiết lập chế độ tự giải cứu (5 phút)..."
( sleep 300 && (nft delete table netdev antiddos_v2 2>/dev/null; nft delete table ip raw_bypass 2>/dev/null) && echo -e "\n[!!!] SERVER ĐÃ TỰ ĐỘNG XÓA FIREWALL VÌ BẠN KHÔNG TẮT FAIL-SAFE.\n" > /dev/pts/0 2>/dev/null ) &
FAILSAFE_PID=$!
echo "$FAILSAFE_PID" > /tmp/antiddos_failsafe.pid

echo -e "\n\033[1;32m[+] CÀI ĐẶT THÀNH CÔNG V2 SIÊU CƯỜNG!\033[0m"
echo -e "Lệnh tắt Fail-safe: \033[1;33mkill $FAILSAFE_PID\033[0m"
