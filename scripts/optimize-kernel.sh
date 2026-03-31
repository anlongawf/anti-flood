#!/bin/bash
# ==========================================================
# 🧠 LAYER 3: KERNEL HARDENING (NETWORK OPTIMIZER)
# Đưa giới hạn vật lý của máy chủ lên mức tối đa
# ==========================================================

echo -e "\033[1;36m[+] Đang tối ưu hóa Nhân Linux (Sysctl Tuning)...\033[0m"

# TỰ ĐỘNG CÂN BẰNG TẢI CPU (IRQ BALANCE)
echo "      -> Đang cài đặt & Kích hoạt Multi-Queue CPU (IRQ Balance)..."
export DEBIAN_FRONTEND=noninteractive
apt-get install -y -q irqbalance >/dev/null 2>&1
systemctl enable --now irqbalance >/dev/null 2>&1

# Sao lưu cấu hình cũ
[ ! -f /etc/sysctl.conf.bak ] && cp /etc/sysctl.conf /etc/sysctl.conf.bak

# Tạo file cấu hình tối ưu chuyên sâu
cat <<EOF > /etc/sysctl.d/99-antiddos-v2.conf
# 1. CHỐNG TCP SYN FLOOD (SYN Cookies + Backlog)
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 3
net.ipv4.tcp_max_syn_backlog = 65536
net.core.somaxconn = 65536

# 2. TỐI ƯU HÓA BỘ ĐỆM (BUFFER) CHO UDP PPS LỚN
net.core.netdev_max_backlog = 100000
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.rmem_default = 16777216
net.core.wmem_default = 16777216
net.ipv4.udp_rmem_min = 16384
net.ipv4.udp_wmem_min = 16384

# 3. CHỐNG TRÀN BẢNG THEO DÕI (CONNTRACK)
net.netfilter.nf_conntrack_max = 2000000
net.netfilter.nf_conntrack_tcp_timeout_established = 1200
net.netfilter.nf_conntrack_udp_timeout = 10
net.netfilter.nf_conntrack_udp_timeout_stream = 20

# 4. TĂNG DẢI PORT VÀ GIẢM THỜI GIAN CHỜ (TIME_WAIT)
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_tw_reuse = 1

# 5. BẢO VỆ STACK MẠNG (IP Spoofing, ICMP)
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
EOF

# Áp dụng cấu hình ngay lập tức (bỏ qua lỗi nếu hệ thống không hỗ trợ một số tham số)
sysctl -p /etc/sysctl.d/99-antiddos-v2.conf 2>/dev/null >/dev/null || true

echo -e "\033[1;32m[✔] Nhân Linux đã được ép xung hoàn tất (Backlog: 65k, UDP Buffer: 16MB)\033[0m"
