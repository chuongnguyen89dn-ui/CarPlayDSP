# Tiếp tục dự án CarPlay Split

## 2026-09-29 — phát hành alpha theo yêu cầu chủ repo

Đưa gói độc lập `com.chuong.carplaysplit` phiên bản `0.2.0~alpha1` vào nguồn Sileo hiện có. DEB gồm app điều khiển và tweak; không chứa binary DuoDash/Airaw. Đã biên dịch arm64/iOS 16 rootless, kiểm tra chữ ký Mach-O, phụ thuộc hệ thống và cấu trúc DEB. Chưa xác minh hoạt động trên thiết bị CarPlay thật.

Trong Sileo tìm **CarPlay Split**. Sau cài đặt và respring, mở app CarPlay Split trên iPhone khi đang kết nối CarPlay để bật. Menu ba chấm chọn app/thoát; kéo tay nắm đổi tỷ lệ; nút mũi tên đổi bên. Bản alpha không được quảng cáo là đã hoàn thiện hoặc hoạt động đúng video.

Mã nguồn bản dựng: commit a31be26 trong nhánh triển khai cục bộ. Lần xuất bản này chỉ thêm DEB và ghi chú phát hành vào main; không công khai thêm các tài liệu phân tích riêng của nhánh nghiên cứu.


## 2026-09-29 — sửa lỗi khởi động alpha1

Crash report của người dùng: EXC_BAD_INSTRUCTION/SIGILL tại `-[CPSPhoneController viewDidLoad] + 0`, offset 0xD58, iPhone 8 Plus/iOS 16.7.16. Binary alpha1 có vùng load commands kết thúc ở 0xD68 nhưng `__text` bắt đầu 0xD58: LC_CODE_SIGNATURE 16 byte đã ghi đè đầu mã. Cả executable và dylib đều có cùng lỗi.

Alpha2 bổ sung `-Wl,-headerpad,0x1000`, dựng bằng Xcode trên macOS, nâng CFBundleVersion lên 2. Trình kiểm tra gói từ chối mọi section dữ liệu/mã chồng lên load commands và đã tái hiện lỗi với alpha1. Không thay đổi tính năng chia đôi trong bản sửa này. Không đưa crash report chứa định danh thiết bị lên repo.

Sau cập nhật Sileo lên 0.2.0~alpha2 và respring, app điều khiển phải hiện giao diện ngay cả khi chưa nối CarPlay. Chia đôi trên CarPlay vẫn cần xác minh trên thiết bị thật.

Xác minh: GitHub Actions run 36506567707 build/deploy thành công; đã tải lại alpha2 từ nguồn Sileo và kiểm tra cấu trúc binary cùng SHA256 khớp chỉ mục APT. Chưa xác nhận mở app trên thiết bị người dùng sau cập nhật.
