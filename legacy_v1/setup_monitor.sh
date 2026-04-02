#!/bin/bash
# =========================================================================
# SCRIPT CÀI ĐẶT BOT DISCORD GIÁM SÁT HỆ THỐNG ANTI-DDOS (CHẠY 1 LẦN)
# =========================================================================

echo -e "\n\033[1;36m[+] TRÌNH CÀI ĐẶT HỆ THỐNG CẢNH BÁO DISCORD (LIVE DASHBOARD)\033[0m"

# 1. Hỏi Ý Kiến Bật Tắt (Y/N)
read -r -p "[?] Ông có muốn Bật tính năng Báo cáo tự động lên Discord mỗi 1 phút không? (y/n): " choice
if [[ ! "$choice" =~ ^[Yy]$ ]]; then
    echo "[-] Đã hủy Thiết lập Webhook."
    exit 0
fi

# 2. Xử lý Link Webhook
read -r -p "[>] Vui lòng dán Link Webhook Discord của ông vào đây: " WEBHOOK_URL

if [[ -z "$WEBHOOK_URL" || ! "$WEBHOOK_URL" =~ ^https://discord.com/api/webhooks/ ]]; then
    echo -e "\033[1;31mLỖI: Hình như Link Webhook chưa đúng định dạng! Vui lòng chạy lại file này để nhập lại.\033[0m"
    exit 1
fi

TARGET_SCRIPT="/usr/local/bin/antiddos_monitor.sh"

# 3. Khởi tạo Thuật toán Gom IP nội bộ
echo "[+] Đang biên dịch thuật toán bóc tách Gói Tin..."
cat << 'EOF' > "$TARGET_SCRIPT"
#!/bin/bash
# ==========================================================
# CORE BÁO CÁO BOT DISCORD DO HỆ THỐNG TỰ SINH
# ==========================================================

WEBHOOK="REPLACE_ME_WEBHOOK"

# 1. Móc ping quốc tế (Google DNS)
PING_MS=$(ping -c 1 8.8.8.8 | awk -F '/' 'END {printf "%.0f\n", $5}')
if [ -z "$PING_MS" ]; then PING_MS="Timeout"; else PING_MS="${PING_MS}ms"; fi

# 2. Đọc lượng IP đang vào nhà
TCP_CONN=$(ss -tn state established | wc -l)
UDP_CONN=$(ss -un state established | awk 'NR>1' | wc -l)

# 3. Kiểm đếm xác Botnet bị giết ở cổng ngoài (Iptables DROP)
DROP_PKTS=$(iptables -xnvL DOCKER-USER | awk '/DROP/ {sum+=$1} END {print sum}')
[[ -z "$DROP_PKTS" ]] && DROP_PKTS=0

# 4. Trích xuất Sinh Tồn Máy Chủ
CPU_LOAD=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
RAM_FREE=$(free -m | awk '/Mem:/ {print $4}')

# 5. Phân tích Top 3 Sát thủ IP (Những kẻ kết nối nhiều nhất)
# Cắt lấy IP: ss -tun lọc ESTAB, trích IP loại bỏ Port, đếm số lần và xếp hạng
TOP_IPS=$(ss -tun state established | awk 'NR>1 {print $5}' | sed -E 's/.*([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+).*/\1/' | grep -v '127.0.0.1' | sort | uniq -c | sort -nr | head -n 3 | awk '{print $2 " (" $1 " cổng)"}' | tr '\n' ' | ')
[[ -z "$TOP_IPS" ]] && TOP_IPS="Server Vắng Khách"

# --- Khởi tạo Khuôn đúc Đồ họa Webhook (JSON) ---
PAYLOAD=$(cat <<JSON
{
  "embeds": [{
    "title": "📡 [BÁO CÁO THỜI GIAN THỰC] PTERODACTYL NODE",
    "color": 5814783,
    "description": "Tình hình chiến sự Mạng và Phân tích tài nguyên tự động:",
    "fields": [
      { "name": "⏱️ Lõi Mạng (Ping)", "value": "\`${PING_MS}\`", "inline": true },
      { "name": "🔌 Luồng Client Đang Vào", "value": "TCP: \`${TCP_CONN}\` | UDP: \`${UDP_CONN}\`", "inline": true },
      { "name": "💻 Tài Nguyên", "value": "CPU: \`${CPU_LOAD}%\` | RAM Trống: \`${RAM_FREE}MB\`", "inline": true },
      { "name": "🧱 Gói Tin Độc Bị Tường Lửa Ép Chết", "value": "🔥 \`${DROP_PKTS}\` Gói tin rác", "inline": false },
      { "name": "🔍 TOP 3 IP CẮM KẾT NỐI NHIỀU NHẤT", "value": "\`${TOP_IPS}\`", "inline": false }
    ],
    "footer": { "text": "Hệ thống Anti-DDoS Độc Quyền Agent • $(date '+%d/%m/%Y %H:%M:%S')" }
  }]
}
JSON
)

# Đẩy thẳng vào Máy Lọc Discord
curl -s -H "Content-Type: application/json" -X POST -d "$PAYLOAD" "$WEBHOOK" >/dev/null 2>&1
EOF

# Nạp Key Webhook vào Core
sed -i "s|REPLACE_ME_WEBHOOK|$WEBHOOK_URL|g" "$TARGET_SCRIPT"
chmod +x "$TARGET_SCRIPT"

# 4. Nạp đạn tự động vào Crontab (Lên dây cót 1 Phút)
echo "[+] Gỡ lịch cũ (nếu có để không bị đè)..."
crontab -l 2>/dev/null | grep -v "antiddos_monitor.sh" | crontab -

echo "[+] Khởi tạo cỗ máy thời gian Cronjob (Bắn 1 Phút / Lần)..."
(crontab -l 2>/dev/null; echo "* * * * * $TARGET_SCRIPT") | crontab -

echo -e "\n\033[1;32m[+] XUẤT XẮC! TẤT CẢ ĐÃ GỌN GÀNG VÀO VỊ TRÍ.\033[0m"
echo -e "Hệ thống Webhook của ông sẽ tự động nhả tin nhắn Báo Cáo liên tục \033[1;33mMỗi Phút 1 Lần\033[0m."
echo "Để tắt nó đi lúc nào ông chán, chỉ cần gõ lệnh: \033[1;31mcrontab -e\033[0m và xóa dòng cuối cùng."
