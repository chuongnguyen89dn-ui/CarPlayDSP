# Tiếp tục dự án CarPlay Split

Dự án độc lập khởi đầu trong cuộc trao đổi ngày 27/09/2026.
Cập nhật yêu cầu ngày 29/09/2026 (giờ Việt Nam).
Repo: chuongnguyen89dn-ui/carplaydsp, thư mục independent-split.
Nguồn Sileo: https://chuongnguyen89dn-ui.github.io/carplaydsp/

## Đã phát hành trước lần này

- 0.3.0~alpha2, commit 082d35d26ce9e545a974d66e8331c468ec91d8ed:
  8 bố cục, menu kính gọn, kéo sát mép phóng một khung, cài đặt và đóng app.
- 0.3.0~alpha3, commit c24568340774789883df0e27a4fdb89b2f4bfa46:
  cấu hình ẩn biểu tượng iPhone; thêm icon Settings 1x/2x/3x.
- Build, phát hành và SHA256 DEB trên nguồn đã được kiểm tra. Chưa có kết quả
  xác minh đầy đủ hành vi trên thiết bị cho các bản này.

## Thay đổi alpha4

Bỏ mục chọn app trong cài đặt iPhone vì nó chỉ lọc danh sách trong Split, không
đưa icon app lên màn hình chính CarPlay. Xóa luôn việc sử dụng bộ lọc allowedApps
ở runtime; thiết lập cũ không còn hạn chế app, kể cả danh sách cũ rỗng.
Giữ công tắc tổng với tên đúng là Bật CarPlay Split. Chọn app ngay trong khung
CarPlay. Việc bỏ bộ lọc không đồng nghĩa đã có tính năng mở riêng bên dưới.

## Cần bổ sung: mở app riêng trên CarPlay — CHƯA TRIỂN KHAI

Yêu cầu: app không hỗ trợ CarPlay có thể có biểu tượng riêng trên màn hình chính
CarPlay và mở một app toàn màn hình, không cần đi qua giao diện chọn bố cục Split.

- App hỗ trợ CarPlay tiếp tục dùng đường mở native hiện có.
- App mở riêng dùng chung cơ chế host đã có nhưng tách trạng thái khỏi phiên Split.
- Bổ sung đăng ký icon, định tuyến lệnh mở đúng bundle, trở về Home và chuyển
  qua lại giữa chế độ riêng/Split; tránh mở hai host cho cùng một app.
- Danh sách chọn icon trong Settings chỉ được đưa trở lại khi thực sự điều khiển
  icon CarPlay. Không đặt tên CarBridge cho bộ lọc app trong Split.
- Không cần thao tác trên iPhone trước khi mở app trên CarPlay.

Người dùng hiện yêu cầu ghi lại mục này, chưa yêu cầu triển khai trong alpha4.

## Mục tiêu hiệu năng — CHƯA ĐO / CHƯA ÁP DỤNG

Mục tiêu là giảm phần tải do Split thêm vào, giữ thao tác mượt và nội dung app
sống trong lúc kéo. Không hứa mọi app sẽ không lag/nóng trong mọi điều kiện.
Phải xét CPU, GPU, RAM, thời gian khung hình và trạng thái nhiệt, không chỉ CPU.

Các điểm đã xác nhận trong mã alpha3/alpha4:

1. CPSSceneHost chạy pollScene mỗi 0,25 giây trong toàn bộ vòng đời host. Ba host
   tạo 12 lượt kiểm tra/giây ngay cả khi cảnh ổn định. Đây không phải số FPS và
   chưa có bằng chứng nó là nguyên nhân tải lớn nhất.
2. viewDidLayoutSubviews gọi resizeTo cho mọi khung nhìn thấy; resizeTo chưa bỏ
   qua toàn bộ thao tác khi kích thước không đổi. Menu thay đổi cũng có thể gọi
   lại setContentReferenceSize và transform dù không đổi tỷ lệ.
3. applySize ghi NSLog và ghi file mỗi lần thay kích thước. Log chạy ở queue riêng
   nhưng vẫn có chi phí tạo chuỗi, I/O và queue trong khi kéo.
4. Scene dùng kích thước logical gấp 2 theo mỗi chiều rồi thu nhỏ. Diện tích
   logical gấp 4, KHÔNG đồng nghĩa CPU tăng 4 lần. Đổi hệ số có thể đổi bố cục,
   độ nét và vùng chạm; cần đo surface scale thực tế trước khi sửa.
5. Phóng một khung 100% chỉ ẩn các view còn lại; các host đó vẫn nằm trong tập
   scene được ép foreground. View ẩn không chứng minh app dừng render/chạy nền.
6. Poll kết nối 2 giây/lần chạy thường trực trong SpringBoard. Cần chuyển sang
   sự kiện với retry có giới hạn khi đã có bằng chứng đầy đủ các sự kiện kết nối.
7. CPSPref đồng bộ CFPreferences mỗi lần đọc, kể cả chuỗi/font. Có thể cache theo
   thông báo thay đổi; phải giữ đúng đồng bộ đa tiến trình.

Ưu tiên triển khai sau khi có mốc đo:

- Bỏ thao tác resize trùng; gom cập nhật drag theo nhịp màn hình, commit kích thước
  cuối khi nhấc tay. Không khóa FPS của video/app bên trong, không thay nội dung
  đang kéo bằng ảnh tĩnh. CADisplayLink chỉ tồn tại khi kéo và được hủy sau đó.
- Theo dõi thay đổi scene bằng sự kiện; chỉ kiểm tra nhanh lúc mở, có fallback
  chậm và tolerance nếu chưa đủ sự kiện. Không bỏ phát hiện app bị đóng/crash.
- Log sự kiện chính và tổng hợp số liệu theo đợt, không ghi từng nhịp kéo.
- Khi khung bị che: tách việc giữ tiến trình/audio/dẫn đường khỏi việc giữ cảnh
  foreground; kiểm chứng âm thanh, chỉ đường và khôi phục khung trước khi dùng.
- Giới hạn blur trong thanh công cụ nhỏ, chỉ hoạt động khi menu hiện. Giữ thiết kế
  trong suốt đã thống nhất, tránh thêm hiệu ứng nền/animation liên tục.
- Chọn kích thước render phù hợp sau khi đo; giữ độ nét và tọa độ chạm. Không
  tự ý hạ độ phân giải chỉ để đạt số CPU đẹp.
- Phản ứng thermalState/Low Power Mode bằng cách giảm công việc của Split trước.
  Không tùy tiện đóng bản đồ/nhạc hay sửa cơ chế nhiệt của hệ thống.

Đo so sánh cùng máy, cùng app và nội dung, cùng màn hình xe, tình trạng sạc và
kết nối: app native đơn; một khung Split; hai khung; ba khung; đang kéo; phóng
100%; thoát/ngắt kết nối. Ghi CPU theo tiến trình, GPU nếu có công cụ phù hợp,
RAM, frame-time/hitch p95/p99, thermalState và thời gian chạy. thermalState không
phải số độ C. So sánh trước/sau; xác minh tác vụ nền của Split kết thúc khi thoát.
Hiện chưa có quyền kết nối trực tiếp iPhone để thu các số liệu này.

Tài liệu Apple đã đối chiếu:
- https://developer.apple.com/library/archive/documentation/Performance/Conceptual/EnergyGuide-iOS/MinimizeTimerUse.html
- https://developer.apple.com/documentation/quartzcore/cadisplaylink
- https://developer.apple.com/library/archive/documentation/Performance/Conceptual/EnergyGuide-iOS/AvoidExtraneousGraphicsAndAnimations.html
- https://developer.apple.com/videos/play/wwdc2019/422/

## Để sau theo yêu cầu

Điều tra hụt đáy trong bản DuoDash tham khảo; không ghép việc này vào alpha4.
