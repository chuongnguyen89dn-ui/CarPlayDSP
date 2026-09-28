# Tiếp tục dự án CarPlay Split

## 2026-09-29 — phát hành alpha theo yêu cầu chủ repo

Đưa gói độc lập `com.chuong.carplaysplit` phiên bản `0.2.0~alpha1` vào nguồn Sileo hiện có. DEB gồm app điều khiển và tweak; không chứa binary DuoDash/Airaw. Đã biên dịch arm64/iOS 16 rootless, kiểm tra chữ ký Mach-O, phụ thuộc hệ thống và cấu trúc DEB. Chưa xác minh hoạt động trên thiết bị CarPlay thật.

Trong Sileo tìm **CarPlay Split**. Sau cài đặt và respring, mở app CarPlay Split trên iPhone khi đang kết nối CarPlay để bật. Menu ba chấm chọn app/thoát; kéo tay nắm đổi tỷ lệ; nút mũi tên đổi bên. Bản alpha không được quảng cáo là đã hoàn thiện hoặc hoạt động đúng video.

Mã nguồn bản dựng: commit a31be26 trong nhánh triển khai cục bộ. Lần xuất bản này chỉ thêm DEB và ghi chú phát hành vào main; không công khai thêm các tài liệu phân tích riêng của nhánh nghiên cứu.
