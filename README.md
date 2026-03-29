# 🛡️ Pterodactyl Anti-Flood System (L3/L4 Mitigation)

Một giải pháp chặn DDoS toàn diện (iptables + ipset + GeoIP + Kernel Tuning) được thiết kế đặc biệt cho máy chủ Pterodactyl Hosting (Minecraft). Ngăn chặn mạnh mẽ các đợt bão UDP Flood và TCP SYN Flood.

## 📌 Tính Năng Cốt Lõi
- **Chống Ngoại Xâm (GeoIP):** Tự động tải danh sách IP theo quốc gia (VN/JP) vào hệ cơ sở dữ liệu RAM `ipset` (tốc độ ánh sáng).
- **Trị Tội Lạm Dụng (Rate & Conn Limit):** Mạng nội địa/Proxy VN cũng bị ép vào chuẩn Tối đa 10 luồng/IP và 30 packet/s khi kết nối vào Docker (Ngăn UDP Bedrock Botnet).
- **Tự Động Nhận Diện TCP:** Không bao giờ lo bị "Tự Nhốt Mình". Script tự động quét các port ssh/Pterodactyl đang chạy và cho phép thông quan.
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
