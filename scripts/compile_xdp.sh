#!/bin/bash
# ==========================================================
# ⚒️ COMPILE XDP: AUTOMATED BUILD & DEPENDENCY INSTALLER
# ==========================================================

echo -e "\033[1;36m[+] Đang chuẩn bị môi trường biên dịch XDP (Clang, LLVM, LibXDP)...\033[0m"

# 1. FIX APT VÀ CÀI ĐẶT DEPENDENCIES
apt-get update -y
apt --fix-broken install -y
apt-get install -y m4 build-essential clang llvm libelf-dev pkg-config zlib1g-dev gcc-multilib git curl bc

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
if [ -f xdpfw ] && [ -f xdpfw-add ]; then
    cp xdpfw /usr/local/bin/
    cp xdpfw-add /usr/local/bin/
    cp xdpfw-del /usr/local/bin/
    chmod +x /usr/local/bin/xdpfw*
    echo -e "\033[1;32m[✔] BIÊN DỊCH THÀNH CÔNG! xdpfw đã sẵn sàng.\033[0m"
else
    echo -e "\033[1;31m[✘] LỖI BIÊN DỊCH: Không tìm thấy file nhị phân xdpfw.\033[0m"
    exit 1
fi
