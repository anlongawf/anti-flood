#!/bin/bash
# ==========================================================
# ⚒️ COMPILE XDP: AUTOMATED BUILD & DEPENDENCY INSTALLER
# ==========================================================

echo -e "\033[1;36m[+] Đang chuẩn bị môi trường biên dịch XDP (Clang, LLVM, LibXDP)...\033[0m"

# 1. FIX APT VÀ CÀI ĐẶT DEPENDENCIES
apt-get update -y
apt --fix-broken install -y
apt-get install -y m4 build-essential clang llvm libelf-dev pkg-config zlib1g-dev gcc-multilib git curl bc ipset nftables

# 2. CLONE MÃ NGUỒN (GAMEMANN XDP-FIREWALL)
BUILD_DIR="/tmp/xdp_build"
rm -rf "$BUILD_DIR" && mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

echo "[+] Đang tải mã nguồn từ GitHub..."
git clone --recursive https://github.com/gamemann/XDP-Firewall.git .

# 3. KÍCH HOẠT IP RATE LIMIT (LEVEL: HARDCORE)
echo "[+] Kích hoạt tính năng IP Rate Limit nâng cao (config.h)..."
# Tìm và bỏ comment dòng #define ENABLE_IP_LIMITS
sed -i 's|// #define ENABLE_IP_LIMITS|#define ENABLE_IP_LIMITS|g' src/common/config.h

# 4. CHẠY SCRIPT CÀI ĐẶT
echo "[+] Bắt đầu biên dịch (Quá trình này mất khoảng 1-2 phút)..."
chmod +x install.sh
./install.sh --libxdp

# 5. DI CHUYỂN NHỊ PHÂN VÀO HỆ THỐNG
# XDP-Firewall installer might put them in /usr/bin. We want them in /usr/local/bin for consistency.
XDP_PATH="build/loader/xdpfw"
XDP_ADD_PATH="build/rule_add/xdpfw-add"
XDP_DEL_PATH="build/rule_del/xdpfw-del"

if [ -f "$XDP_PATH" ]; then
    cp "$XDP_PATH" /usr/local/bin/xdpfw
    cp "$XDP_ADD_PATH" /usr/local/bin/xdpfw-add
    cp "$XDP_DEL_PATH" /usr/local/bin/xdpfw-del
    chmod +x /usr/local/bin/xdpfw*
    echo -e "\033[1;32m[✔] BIÊN DỊCH THÀNH CÔNG! xdpfw đã sẵn sàng tại /usr/local/bin/.\033[0m"
elif [ -f "/usr/bin/xdpfw" ] || [ -f "/usr/local/bin/xdpfw" ]; then
    # Nếu bộ cài gốc đã tống vào /usr/bin rồi thì copy sang /usr/local/bin cho đồng bộ script
    [ -f "/usr/bin/xdpfw" ] && cp /usr/bin/xdpfw* /usr/local/bin/ 2>/dev/null
    chmod +x /usr/local/bin/xdpfw*
    echo -e "\033[1;32m[✔] XDPFW ĐÃ ĐƯỢC CÀI ĐẶT VÀO HỆ THỐNG.\033[0m"
else
    echo -e "\033[1;31m[✘] LỖI BIÊN DỊCH: Không tìm thấy file nhị phân xdpfw.\033[0m"
    exit 1
fi
