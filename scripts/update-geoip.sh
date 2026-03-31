#!/bin/bash
# ==========================================================
# 🌏 LAYER 2: CHỐT CHẶN QUỐC GIA (VN & JP GEO-IP)
# Chỉ chấp nhận traffic từ "Vùng an toàn"
# ==========================================================

ZONE_DIR="/etc/antiddos_zones"
SET_NAME="allow_countries"

echo -e "\033[1;36m[+] Đang cập nhật Danh sách IP Quốc gia (VN, JP)...\033[0m"

# 1. Tạo thư mục lưu trữ
mkdir -p "$ZONE_DIR"
cd "$ZONE_DIR"

# 2. Tải danh sách CIDR (ipdeny.com)
echo "      -> Đang tải CIDR từ ipdeny.com..."
curl -s -f -o vn.zone.tmp https://www.ipdeny.com/ipblocks/data/countries/vn.zone && mv vn.zone.tmp vn.zone
curl -s -f -o jp.zone.tmp https://www.ipdeny.com/ipblocks/data/countries/jp.zone && mv jp.zone.tmp jp.zone

# 3. Kiểm tra file (Cứu cánh nếu tải lỗi)
if [ ! -s vn.zone ] || [ ! -s jp.zone ]; then
    echo -e "\033[1;31m[!] LỖI: Không tải được danh sách mới. Sử dụng Cache cũ...\033[0m"
    if [ ! -s vn.zone ] || [ ! -s jp.zone ]; then
        echo -e "\033[1;31m[✘] KHÔNG CÓ CACHE CŨ! Dừng script.\033[0m"
        exit 1
    fi
fi

# 4. Tạo và nạp IPSET (Tốc chiến bằng Restore)
echo "      -> Đang nạp danh sách vào Firewall..."
ipset create $SET_NAME hash:net -exist

# Tạo file nạp hàng loạt để nhanh hơn (IPSET Restore)
echo "flush $SET_NAME" > ipset_load.txt
awk -v set="$SET_NAME" '{print "add " set " " $1}' vn.zone >> ipset_load.txt
awk -v set="$SET_NAME" '{print "add " set " " $1}' jp.zone >> ipset_load.txt

# Nạp vào firewall ngầm
ipset restore < ipset_load.txt

echo -e "\033[1;32m[✔] Đã khóa 95% vùng tấn công quốc tế. Chỉ mở VN & JP.\033[0m"
