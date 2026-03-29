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

---

## 🚀 Hướng Dẫn Cài Đặt (Setup)

Toàn bộ hệ thống yêu cầu thao tác dưới tài khoản Root (hoặc `sudo`).

### 1. Kích Hoạt Lõi Tường Lửa (`antiddos.sh`)
```bash
chmod +x antiddos.sh
sudo ./antiddos.sh
```
*Lưu ý: Mặc định script có chức năng "Bom đếm lùi Cứu hộ 5 Phút" để tự tháo gỡ nếu lỡ tay khóa nhầm. Nhớ đọc màn hình Terminal để Tắt Cứu Hộ và lưu lại rules.*

### 2. Kích Hoạt Cảnh Vệ Tái Sinh Docker
Pterodactyl luôn xóa firewall khi nó reload. Kịch bản dưới đây khắc phục hoàn toàn bằng Systemctl.
```bash
chmod +x Advanced_AntiDDoS/Backend_Node/install_guardian.sh
sudo ./Advanced_AntiDDoS/Backend_Node/install_guardian.sh
```

### 3. Khởi Động Trạm Trinh Sát Webhook (Tùy chọn)
Bật kết nối theo dõi trực tiếp với Discord Channel.
```bash
chmod +x setup_monitor.sh
sudo ./setup_monitor.sh
```
*(Lệnh sẽ hỏi bạn Link Webhook và kích hoạt Cronjob)*
