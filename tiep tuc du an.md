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


## 2026-10-01 — DuoDash 1.1.3 / fullscreen / Split runtime handoff

### Mục tiêu hiện tại
- Giữ nguyên giao diện DuoDash 1.1.3.
- Giữ nguyên Split engine, app picker, swap và divider.
- Thêm fullscreen/reflow: ẩn CarPlay bar/sidebar và cho nội dung chiếm vùng vừa giải phóng.
- Gesture là cơ chế chính; không bắt buộc icon fullscreen.
- Thoát fullscreen phải khôi phục layout.
- Không phá horizontal divider resize.

### Nguyên tắc bắt buộc
- Không copy Airaw vào DuoDash.
- Airaw chỉ là tài liệu tham khảo về cơ chế ẩn chrome/reflow.
- Không reimplement DuoDash Split.
- Không đổi UI DuoDash ngoài yêu cầu.
- Không đoán lỗi runtime.
- Sau mỗi code change/build phải kiểm tra build/deploy/log.
- Không tuyên bố thành công nếu chưa có artifact/runtime evidence.
- Simulator chỉ dùng khi cần UI/geometry/gesture; runtime CarPlay phải test trên iPhone jailbreak + CarPlay.

### Runtime evidence
Conflict.log trước đây cho thấy trong CarPlayTemplateUIHost đồng thời có Airaw.dylib, DuoDash.dylib và DuoDashAirawConflictProbe.dylib; trạng thái ghi nhận DuoDash=1, DuoDashFullscreen=0, Airaw=1. Vì vậy phải test baseline DuoDash khi Airaw không inject để tách xung đột.

DuoDash-geometry-report-v2.txt có các path runtime quan trọng:
- /var/mobile/Library/DuoDash/
- /var/tmp/com.sensetechlab.appbridge.plist
- /var/tmp/com.sensetechlab.autoinject.log
- /var/tmp/com.sensetechlab.autoinject.pid
- /var/tmp/duodash_ab_display_held
- /var/tmp/duodash_latch/
- bridge.state
- appbridge_cp.state
- navapps.plist

Script geometry-report từng có lỗi parsing “Illegal number”, nên output đó không được coi là geometry cuối.

### Code-level DuoDash 1.1.3
Đã phân tích DuoDash.dylib. Các điểm quan trọng:
- CNABUIApp
- CNABDividerView
- setBridgeFrame:
- bridgeFrame
- setIsSplit:
- relayoutAllWindows

Không được thay Split engine nếu chưa có evidence. Fullscreen phải tác động đúng tầng chrome/geometry sau khi DuoDash thiết lập Split.

### Lỗi đã từng gặp
- Mất khả năng hiện lại bar.
- Divider trung tâm không kéo được trong một bản.
- Swap còn nhưng resize Split hỏng.
- Giao diện bị đổi khỏi DuoDash gốc.
- Ẩn sidebar nhưng còn vùng đen/dải đen.
- Lỗi đỏ khi mở app trong Split trên iPhone.
- Không được mặc định lỗi đỏ là do fullscreen; phải kiểm tra Split baseline và runtime log.

### Tài liệu giao diện mục tiêu trong Library
- Hướng dẫn DuoDash chế độ toàn màn hình.png
- Bản mẫu giao diện CarPlay Split.png
- Màn hình CarPlay mở rộng, không thanh bên.png
- Demo giao diện điều khiển DuoDash.png
- Bảng Thiết Kế DuoDash Neon.png
- So sánh DuoDash trước và sau khi toàn màn hình.png

Mục tiêu trực quan: DuoDash nguyên bản, 2 pane, divider trung tâm, app picker và swap nguyên bản; fullscreen làm sidebar/bar biến mất và 2 pane lấp đầy vùng được giải phóng; không black band; divider vẫn kéo được.

### Adapter hiện tại
Repo: chuongnguyen89dn-ui/carplaydsp
Branch: duodash-fullscreen-adapter

Files:
- duodash-fullscreen/DuoDashFullscreen.xm
- duodash-fullscreen/Makefile
- duodash-fullscreen/control
- .github/workflows/duodash-fullscreen.yml

Adapter thử:
- hook CNABUIApp setBridgeFrame:/setIsSplit:
- theo dõi bridge frame;
- gọi relayoutAllWindows;
- lấy dock view;
- hook CNABDividerView touch;
- vertical swipe tại divider toggle fullscreen;
- horizontal drag vẫn để DuoDash xử lý;
- lưu frame gốc và khôi phục khi thoát.

Đây chưa phải implementation cuối vì chưa có runtime test thật. Chưa xác nhận dock class thực tế, gesture target thực tế, tầng geometry cuối hay pane nào phải mở rộng. Không tiếp tục sửa theo kiểu đoán.

### Build/deploy
Workflow phải được kiểm tra:
1. build status;
2. build log;
3. .deb artifact;
4. dpkg-deb -I;
5. dpkg-deb -c;
6. artifact;
7. cài trên iPhone;
8. runtime log.

Không nói đã xong nếu chưa có artifact/runtime evidence.

### Runtime lỗi đỏ — việc còn thiếu
Cần log đúng lúc:
1. mở DuoDash;
2. bật Split;
3. mở app gây lỗi đỏ;
4. giữ trạng thái lỗi;
5. lấy crash/system log.

Ưu tiên kiểm tra CarPlayTemplateUIHost, DuoDash.dylib, appbridge, scene/window attach, bridgeFrame, layout/inset, exception/crash/backtrace và tweak cùng inject. Nếu Airaw đang inject thì phải loại khỏi baseline.

### Quy trình test
Baseline DuoDash: Split → 2 app → kéo divider → swap → mở app bị lỗi → ghi runtime log.

Adapter: Split phải giữ nguyên baseline; horizontal divider drag không đổi; chỉ thêm fullscreen gesture.

Fullscreen: sidebar/bar ẩn; pane mở rộng; không black band; divider vẫn kéo; swap/app picker vẫn hoạt động.

Restore: gesture/corner restore; frame/layout khôi phục; không mất app; không crash.

### Trạng thái hiện tại
Đã có:
- DuoDash 1.1.3 DEB;
- phân tích Mach-O/class/selector;
- ảnh UI mục tiêu;
- runtime evidence về Airaw + DuoDash cùng inject;
- adapter branch;
- workflow build.

Chưa có:
- runtime log mới của lỗi đỏ;
- xác nhận geometry fullscreen trên CarPlay thật;
- DEB adapter đã cài/test thành công;
- ảnh runtime thật chứng minh fullscreen.

### Thứ tự tiếp tục
1. Kiểm tra build artifact.
2. Lấy runtime log lỗi đỏ Split.
3. Xác định lỗi Split nền.
4. Test baseline DuoDash không Airaw.
5. Chỉ khi Split ổn mới test fullscreen.
6. Nếu fullscreen không reflow đúng, tìm đúng tầng geometry/inset từ runtime.
7. Sửa đúng tầng.
8. Build lại.
9. Cài/test.
10. Chỉ kết thúc khi có DEB + runtime evidence.

### Mục tiêu cuối
DuoDash nguyên bản + fullscreen gesture/reflow: 2 pane, divider trung tâm, app picker, swap, sidebar/bar ẩn khi fullscreen, nội dung lấp đầy vùng màn hình, không bắt buộc icon fullscreen, gesture không phá horizontal resize.
