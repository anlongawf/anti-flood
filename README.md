# 🛡️ Pterodactyl Anti-Flood Ultimate (V3 - XDP & Fail2Ban)

Một giải pháp bảo vệ máy chủ Pterodactyl tối thượng, kết hợp sức mạnh của **XDP (Express Data Path)** ở tầng Driver và **Fail2Ban** ở tầng Guardian. Thiết kế đặc biệt để chặn đứng hàng triệu gói tin DDoS mà không làm treo CPU.

## 🚀 Tính Năng Vượt Trội (V3)
- **XDP (Driver Level)**: Bỏ qua tầng Network Stack của Linux để lọc traffic ngay tại Card mạng. Chống Volumetric UDP Flood (Bedrock) và TCP SYN Flood cực mạnh.
- **Fail2Ban Guardian**: Tự động phát hiện kẻ tấn công từ log XDP và ra lệnh cho Driver chặn IP đó ngay lập tức (Real-time BPF Map injection).
- **Intelligent Port Discovery**: Tự động quét và nhận diện:
    - Tất cả các Port quản trị (SSH, SFTP, Wings, Database, Web Panel).
    - Toàn bộ Port Allocation của khách hàng đang chạy trên Pterodactyl.
- **Smart Watcher**: Giám sát thay đổi 15 giây/lần, chỉ cập nhật Firewall khi có sự thay đổi thực sự (Giảm 99% tải CPU).
- **Auto-Fallback**: Tự động chuyển đổi sang chế độ tương thích nếu Driver mạng không hỗ trợ XDP Native.

---

## 📦 Cài Đặt Tất Cả Trong Một (Clean Install)

Chỉ một lệnh duy nhất để gỡ bỏ bản cũ và cài đặt bản V3 Ultimate:

```bash
git clone https://github.com/anlongawf/anti-flood.git
cd anti-flood
chmod +x install.sh && sudo ./install.sh
```

---

## 📊 Dashboard Trinh Sát
Theo dõi chiến sự DDoS trực tiếp với thống kê từ tầng Driver:
```bash
sudo ./status.sh --watch
```

## 🗑️ Gỡ Cài Đặt (Uninstall)
```bash
sudo ./uninstall.sh
```
Lệnh này sẽ dọn dẹp sạch sẽ XDP, Fail2Ban, Nftables và khôi phục Driver mạng về trạng thái ban đầu.

---

## 🛡️ Kiến Trúc Hệ Thống (V3)
1. **Lớp 1: XDP Ingress Filter**: Loại bỏ 90% traffic độc ngay tại Driver.
2. **Lớp 2: Fail2Ban Guardian**: "Tống giam" các IP spam vào Blocklist của XDP.
3. **Lớp 3: RakNet DPI**: Lọc sâu gói tin Minecraft Bedrock để chặn Bot Join.
4. **Lớp 4: Nftables Raw Bypass**: Bỏ qua tracking cho các port game để chống tràn bảng Conntrack.

---
*Phát triển bởi Agentic AI cho hệ sinh thái Pterodactyl Việt Nam.*
