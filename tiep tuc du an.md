# Tiếp tục dự án CarPlay Split

## 2026-10-02 — phát hành DuoDash gốc + adapter qua Sileo

Yêu cầu hiện tại: DEB phải xuất hiện trong nguồn Sileo
`https://chuongnguyen89dn-ui.github.io/carplaydsp/`, không yêu cầu người dùng
tải artifact để cài thủ công.

Gói mới: **DuoDash Fullscreen (Original UI)**,
`com.chuong.duodash-fullscreen-complete`, phiên bản `1.1.3+adapter1~test1`.
Workflow main build adapter từ commit `ccadfe2`, rồi đóng gói cùng DuoDash
1.1.3 trong DEB đã có tại DauDat-CarPlay. Giữ nguyên từng byte của 42 file
DuoDash (binary, UI/app picker/split, tài nguyên, Settings); chỉ bỏ hai file
`DuoDashUnifiedFullscreen` cũ và thêm hai file adapter. Không ghép Airaw.
Script kiểm tra SHA256 DEB nguồn, toàn bộ payload và các script cài/gỡ.

Gói đầy đủ chứa sẵn DuoDash nên không phụ thuộc sai phiên bản `= 1.1.3` trên
máy đang có `1.1.3+fullscreen1`. Khai báo xung đột với các bản DuoDash/Airaw,
Split độc lập và adapter rời để Sileo không cài chồng các engine/fullscreen.
Không thay chỉ mục hay xóa các gói cũ khỏi nguồn.

Đây là **bản thử nghiệm**: adapter đã build/test vòng đời đối tượng PASS;
chưa có ảnh Simulator của UI gốc hoặc kết quả runtime CarPlay thật.
Lỗi đỏ từng báo thuộc bản Split tự viết, chưa được xác nhận ở DuoDash gốc.
Không coi lỗi đó là điều kiện chặn việc dùng lại engine DuoDash nguyên bản.
Sau deploy phải đọc lại Packages/Packages.gz và tải DEB từ Pages để đối chiếu
SHA256, tên, phiên bản, phụ thuộc và payload trước khi báo đã lên Sileo.

## 2026-09-29 — phát hành alpha theo yêu cầu chủ repo

Đưa gói độc lập `com.chuong.carplaysplit` phiên bản `0.2.0~alpha1` vào nguồn Sileo hiện có. DEB gồm app điều khiển và tweak; không chứa binary DuoDash/Airaw. Đã biên dịch arm64/iOS 16 rootless, kiểm tra chữ ký Mach-O, phụ thuộc hệ thống và cấu trúc DEB. Chưa xác minh hoạt động trên thiết bị CarPlay thật.

Trong Sileo tìm **CarPlay Split**. Sau cài đặt và respring, mở app CarPlay Split trên iPhone khi đang kết nối CarPlay để bật. Menu ba chấm chọn app/thoát; kéo tay nắm đổi tỷ lệ; nút mũi tên đổi bên. Bản alpha không được quảng cáo là đã hoàn thiện hoặc hoạt động đúng video.

Mã nguồn bản dựng: commit a31be26 trong nhánh triển khai cục bộ. Lần xuất bản này chỉ thêm DEB và ghi chú phát hành vào main; không công khai thêm các tài liệu phân tích riêng của nhánh nghiên cứu.


## 2026-09-29 — sửa lỗi khởi động alpha1

Crash report của người dùng: EXC_BAD_INSTRUCTION/SIGILL tại `-[CPSPhoneController viewDidLoad] + 0`, offset 0xD58, iPhone 8 Plus/iOS 16.7.16. Binary alpha1 có vùng load commands kết thúc ở 0xD68 nhưng `__text` bắt đầu 0xD58: LC_CODE_SIGNATURE 16 byte đã ghi đè đầu mã. Cả executable và dylib đều có cùng lỗi.

Alpha2 bổ sung `-Wl,-headerpad,0x1000`, dựng bằng Xcode trên macOS, nâng CFBundleVersion lên 2. Trình kiểm tra gói từ chối mọi section dữ liệu/mã chồng lên load commands và đã tái hiện lỗi với alpha1. Không thay đổi tính năng chia đôi trong bản sửa này. Không đưa crash report chứa định danh thiết bị lên repo.

Sau cập nhật Sileo lên 0.2.0~alpha2 và respring, app điều khiển phải hiện giao diện ngay cả khi chưa nối CarPlay. Chia đôi trên CarPlay vẫn cần xác minh trên thiết bị thật.

Xác minh: GitHub Actions run 36506567707 build/deploy thành công; đã tải lại alpha2 từ nguồn Sileo và kiểm tra cấu trúc binary cùng SHA256 khớp chỉ mục APT. Chưa xác nhận mở app trên thiết bị người dùng sau cập nhật.


## 2026-10-02 — test2: không thấy DuoDash trong Settings

Người dùng xác nhận không có mục DuoDash sau khi đóng/mở Settings. Chưa có log
Preferences trên thiết bị nên chưa kết luận nguyên nhân runtime. Kiểm tra test1
cho thấy bundle có đủ nhưng loader entry chỉ dùng dạng inline, không trỏ tới
DuoDashPrefs.bundle. Test2 khai báo bundle, bundlePath rootless và isController
rõ ràng; dùng đúng DuoDashRootListController có sẵn. Giữ danh sách items gốc
và đưa toàn bộ danh sách đó vào Root.plist của bundle để giữ cả Choose Apps
to Bridge, ngôn ngữ và các mục gốc khác. Icon trỏ tới file thực sự có trong gói.

Không đổi binary DuoDash, picker hoặc split engine. 40 file nguyên bản còn lại
giữ từng byte; chỉ sửa hai plist Settings bên cạnh thay helper fullscreen từ
test1. Phiên bản Sileo: 1.1.3+adapter1~test2. Sau deploy kiểm tra chỉ mục, hash
và loader/bundle/Root trong DEB tải từ nguồn; hiển thị Settings vẫn cần người
dùng xác nhận trên iPhone. Nếu vẫn không có, cần kiểm tra PreferenceLoader có
được inject vào Preferences và phiên bản thực sự đã cài; không quy lỗi do người
dùng hoặc tiếp tục khẳng định chỉ cần mở lại Settings.


## 2026-10-03 — quay về DEB nguồn nguyên trạng để đối chứng

Người dùng báo Settings trống sau test2. Chưa xác định nguyên nhân runtime;
không coi build PASS hoặc việc giữ binary là bằng chứng giữ nguyên hành vi.

Đưa nguyên DEB tại DauDat-CarPlay commit 5f683ad lên cùng nguồn Sileo.
Tên hiển thị trong chỉ mục: **DuoDash (Source DEB)**; mã gói thật:
`com.sensetechlab.duodash`; phiên bản thật: `1.1.3+fullscreen1`.
DEB SHA256: `ea0d3bb8c8b9da2b45c3f158f390a7966419e84899f820d06f45cd51401fa465`.
Không đóng gói lại, không sửa control, script, plist, binary hoặc helper đi kèm.
Nhãn Name chỉ thêm trong chỉ mục APT để tránh người dùng chọn nhầm.
Đây là nguyên bản file nguồn đã có trong repo, KHÔNG tuyên bố bản vendor 1.1.3
chưa chỉnh sửa: file này vốn đã có helper fullscreen và suffix +fullscreen1.

Trên máy: gỡ DuoDash Fullscreen (Original UI), rồi cài DuoDash (Source DEB),
respring và kiểm tra Settings trước khi thử split. Không cài chồng các bản
DuoDash/Airaw/adapter khác. Không tự cài/gỡ trên máy người dùng từ CI.
Chỉ tiếp tục ghép adapter khi có kết quả đối chứng. Các gói thử cũ giữ trên
nguồn phục vụ truy vết, nhưng không hướng dẫn cài test2 để làm đối chứng.
