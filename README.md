# 🛡️ Pterodactyl Anti-Flood System (L3/L4 Mitigation)

Một giải pháp chặn DDoS toàn diện (iptables + ipset + GeoIP + Kernel Tuning) được thiết kế đặc biệt cho máy chủ Pterodactyl Hosting (Minecraft). Ngăn chặn mạnh mẽ các đợt bão UDP Flood và TCP SYN Flood.

## 📌 Tính Năng Cốt Lõi
- **Tự động dò tìm**: Tự động nhận diện các container Minecraft đang chạy (TCP 25565) để áp dụng cấu hình.
- **Lọc Địa lý (Geo-filter)**: Chỉ cho phép các dải IP từ Việt Nam và Nhật Bản kết nối vào cổng Game.
- **Chống TCP SYN Flood**: Bảo vệ hệ thống khỏi các cuộc tấn công làm cạn kiệt tài nguyên TCP.
- **Giới hạn kết nối (Connlimit)**: Ngăn chặn Bot Join bằng cách giới hạn mỗi IP chỉ được mở tối đa 20 kết nối TCP đồng thời.
- **Bảo vệ UDP (Bedrock)**: Giữ nguyên lớp bảo vệ UDP siêu mạnh cho các server điện thoại.
- **Guardian Service**: Tự động khôi phục Firewall ngay cả khi Docker hoặc Pterodactyl khởi động lại.
- **Ép Xung Nhân Linux:** Cấu trúc tự cập nhật nhân Linux mở rộng bộ đệm `nf_conntrack` lến 2 Triệu connection và thiết lập giáp TCP SYN Cookies.
- **Docker Guardian:** Tích hợp cảnh vệ `systemd` tự động nạp lại Firewall mỗi khi Docker Restart, chống việc Pterodactyl đập bể rules.
- **Live Discord Dashboard:** Cỗ máy định kỳ quét trạng thái RAM/CPU/Connections và Báo cáo trực tiếp lên Discord mỗi phút một lần.
- **Global Status Check:** Lệnh `status.sh` tích hợp sẵn để kiểm tra nhanh mọi thông số hệ thống và sức khỏe Firewall chỉ trong 1 giây.

---

## 🚀 Cài Đặt Tất Cả Trong Một (All-in-One)

Dán lệnh duy nhất này để cài đặt Firewall + Guardian + Monitor (tùy chọn) cùng lúc:

```bash
git clone https://github.com/anlongawf/anti-flood.git
cd anti-flood
chmod +x install.sh && sudo ./install.sh
```

---

## 📊 Kiểm Tra Trạng Thái
Sau khi cài đặt, dùng lệnh dưới đây để xem Dashboard chiến sự:
```bash
sudo ./status.sh
```
Lõi này sẽ tự động:
- Tinh chỉnh Kernel Nhân Linux.
- Tải danh sách IP VN/JP vào RAM (ipset).
- Dò tìm Container Minecraft và áp dụng cấu hình TCP/UDP.

> [!WARNING]
> Mặc định script có chức năng **"Bom đếm lùi Cứu hộ 5 Phút"**. Nếu sau khi chạy, bạn vẫn kết nối SSH bình thường, hãy nhớ bấm lệnh `kill [PID]` hiện trên màn hình để giữ lại Firewall.

### 2. Kích Hoạt Cảnh Vệ Tái Sinh Docker
Pterodactyl hoặc Docker Restart thường làm rớt các quy tắc Firewall. Script này tích hợp vào `systemd` để tự động vá lại màng chắn ngay khi Docker khởi động.
```bash
sudo ./Advanced_AntiDDoS/Backend_Node/install_guardian.sh
```

### 3. Khởi Động Trạm Trinh Sát Webhook (Monitor)
Gửi báo cáo tình hình chiến sự (CPU, RAM, Connections, Attack Stats) trực tiếp lên Discord mỗi 1 phút.
```bash
chmod +x setup_monitor.sh && sudo ./setup_monitor.sh
```
*(Yêu cầu chuẩn bị trước một Link Webhook Discord).*

---

## 🛡️ Tính Năng Nổi Bật
- **Lọc Địa Lý Tốc Độ Cao:** Dùng `ipset` để xử lý hàng nghìn dải IP mà không làm lag CPU.
- **Giáp Kép Minecraft:** Bảo vệ cả Java (25565 - TCP) và Bedrock (19132 - UDP).
- **Chống Bot Join:** Giới hạn 20 kết nối TCP đồng thời để ngăn chặn các cuộc tấn công proxy-bot.
- **Ưu tiên Mạng Nội Bộ:** Không bao giờ chặn giao tiếp giữa các Container (DNS, Wings API).
