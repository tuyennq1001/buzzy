# AGENTS & CODING RULES (QUY TẮC VẬN HÀNH & KỸ THUẬT)

Tài liệu này là bộ quy tắc cốt lõi gồm 2 phần rõ rệt:
- **PHẦN 1: NGUYÊN TẮC KỸ THUẬT CHUNG (UNIVERSAL COMMON RULES)**: Bắt buộc tuân thủ trên mọi dự án phần mềm (Web, Mobile, Backend, CLI... bất kể ngôn ngữ). **Giữ nguyên 100% khi copy sang dự án mới hoặc đưa vào ChatGPT/AI tool.**
- **PHẦN 2: QUY TẮC ĐẶC THÙ DỰ ÁN (PROJECT-SPECIFIC RULES)**: Tùy biến theo từng dự án cụ thể. *(Hiện tại cấu hình cho dự án: Tomik — Cute Pomodoro Timer for macOS Menu Bar)*. Khi sang dự án mới, chỉ cần thay đổi nội dung phần này.

---

# ==============================================================================
# PHẦN 1: QUY TẮC KỸ THUẬT CHUNG CHO MỌI DỰ ÁN (UNIVERSAL COMMON RULES)
# (Độc lập ngôn ngữ & nền tảng — Tái sử dụng nguyên vẹn cho bất kỳ dự án nào)
# ==============================================================================

## 1. Quy trình Git Branching & Quản lý PR (Git Automation Workflow)
- **Tuyệt đối không commit trực tiếp vào nhánh chính**: Không bao giờ commit lên `main` hoặc `master`.
- **Luôn tạo nhánh riêng biệt trước khi viết code**: Tự động tạo nhánh `feature/<tên-tính-năng>` hoặc `fix/<tên-lỗi>` từ nhánh chính trước khi thực hiện bất kỳ thay đổi nào.
- **Quy trình chuẩn 4 bước**:
  1. Viết code.
  2. Chạy toàn bộ bộ kiểm thử tự động (Unit / Integration Tests) — **PHẢI PASS 100%**.
  3. Chạy build/compile dự án — **PHẢI BUILD THÀNH CÔNG**.
  4. Chờ người dùng xác nhận trải nghiệm thực tế chạy đúng mong đợi ➔ **Mới tiến hành commit**.
- **Tiêu chuẩn Commit/PR**:
  - Tiêu đề tuân theo Conventional Commits (`feat(...)`, `fix(...)`), **tối đa ≤ 72 ký tự**.
  - Nội dung mô tả (Body) **ngắn gọn ≤ 5 dòng**. Nếu cần mô tả chi tiết, ghi ra file riêng và đính kèm link.
- **Chỉ Push & Merge khi được yêu cầu**:
  - Mặc định **không tự ý push** lên remote repository. Chỉ push và tạo PR (`gh pr create`) khi người dùng yêu cầu rõ ràng.
  - Chỉ merge PR (`gh pr merge`) vào nhánh chính khi người dùng trực tiếp xác nhận "OK" hoặc "Duyệt".

---

## 2. An toàn Thực thi Terminal & Script (Terminal Safety)
- **Không viết inline script dài trong `-c`**: Bất kỳ script nào (Bash, Python, Node...) nếu dài quá ~5 dòng, **bắt buộc phải ghi ra file script tạm**, cấp quyền và thực thi file đó, sau đó xóa file tạm đi.
- **Không pipe build output qua bộ lọc chặn (blocking filter)**: Tránh dùng `| grep ...` trực tiếp trên luồng build/compile vì dễ gây treo tiến trình (hang/freeze/timeout) nếu output không khớp pattern.
- **Giới hạn độ dài dòng lệnh**: Mỗi câu lệnh CLI không vượt quá ~2000 ký tự để tránh lỗi buffer overflow và timeout.

---

## 3. Trung thực Dữ liệu & Phê duyệt Trước khi Code (Mandatory Approval)
- **Trung thực dữ liệu tuyệt đối (No Fake / Dummy Data)**: Tuyệt đối không tự ý bịa dữ liệu giả định, tên công ty giả, hoặc nhồi kết quả heuristic giả lập. Mọi dữ liệu hiển thị bắt buộc phải là dữ liệu thật 100% từ API chính thống hoặc nguồn đã kiểm chứng (trừ trường hợp kịch bản mock test được chỉ định rõ).
- **Bắt buộc chờ phê duyệt phương án trước khi sửa code**:
  1. AI phải giải thích nguyên nhân gốc rễ và trình bày phương án kỹ thuật rõ ràng.
  2. **CHỈ TIẾN HÀNH VIẾT CODE KHI NGƯỜI DÙNG XÁC NHẬN "OK" / DUYỆT TRỰC TIẾP** bằng lời nhắn trong chat.
  3. Tuyệt đối không tự động nhảy sang bước viết code / thực thi thay đổi khi người dùng chưa đồng ý.

---

## 4. Tiêu chuẩn Kỹ thuật Hiệu năng (Universal Performance Engineering)
*(Áp dụng cho mọi hệ thống: Frontend UI, Backend API, Mobile, Desktop, CLI)*
- **Cô lập State & Sự kiện tần số cao (State & Event Isolation)**:
  - Các sự kiện hoặc state biến động liên tục (hover chuột, con trỏ, vị trí scroll, sensors, keystrokes input...) **bắt buộc phải cô lập trong component/module con**. Tuyệt đối không đặt ở component cha vì sẽ kích hoạt re-render hoặc re-calculate toàn bộ cây view/component.
- **Cấm tính toán nặng trong Render Loop & Request Hot-Path**:
  - Không chạy sắp xếp (`sort`), lọc mảng lớn (`filter`), parse JSON nặng, hoặc các thuật toán tính toán phức tạp trực tiếp bên trong vòng lặp render giao diện hoặc hàm xử lý request chính.
  - Mọi phép tính nặng phải tính trước (pre-compute) và lưu cache bộ nhớ (in-memory cache / memoization). View/handler chỉ đóng vai trò đọc dữ liệu đã chuẩn bị.
- **Tối ưu cấp phát bộ nhớ & Giảm tải Garbage Collection (Allocation Optimization)**:
  - Tránh khởi tạo các đối tượng tốn kém tài nguyên (date formatters, regex parsers, database connections, crypto engines) lặp đi lặp lại trong vòng lặp kín hoặc từng item của danh sách. Bắt buộc tái sử dụng instance static/singleton hoặc object pool.
- **Ảo hóa & Phân trang dữ liệu lớn (Virtualization & Pagination)**:
  - Trên giao diện: Danh sách lớn bắt buộc phải dùng cơ chế ảo hóa (virtual list/lazy loading), chỉ render các phần tử thực sự nằm trong khung nhìn.
  - Dưới backend/DB: Luôn phân trang (pagination), stream hoặc chunking dữ liệu, tuyệt đối không tải hàng loạt triệu bản ghi vào RAM cùng lúc.
- **Gom cụm & Tiết chế luồng dữ liệu thời gian thực (Buffering & Throttling)**:
  - Dữ liệu từ luồng thời gian thực (WebSocket, Message Queue, Event Stream) không được bắn trực tiếp từng event đơn lẻ lên UI/Main Loop. Bắt buộc có cơ chế buffer gom batch và debounce/throttle (ví dụ: 0.5s – 1.0s) để giảm tải tần suất cập nhật.
- **Bất đồng bộ & Không chặn luồng chính (Non-blocking I/O)**:
  - Mọi thao tác I/O (đọc/ghi file, gọi network, truy vấn DB) tuyệt đối không chạy đồng bộ trên Main Thread / Event Loop chính.
  - Thao tác ghi đĩa/persistence lặp đi lặp lại phải được debounce và đẩy xuống background worker/thread.

---

## 5. Tư duy Triển khai Ngang (Horizontal Deployment Mindset)
Khi giải quyết bất kỳ lỗi hoặc phát triển tính năng nào, bắt buộc tự động rà soát đồng bộ theo 4 trục:
- **Trục Tính năng & Thành phần tương đồng (Feature Parity)**: Nếu sửa/thêm logic ở Module A, phải tự động quét toàn bộ codebase tìm các Module B, C có vai trò hoặc logic tương tự (ví dụ: danh sách chính ↔ danh sách phụ; chế độ xem bảng ↔ chi tiết modal; giỏ hàng ↔ thanh toán) để áp dụng đồng bộ.
- **Trục Đa Nền tảng / Đa Môi trường (Environment & Platform Parity)**: Đảm bảo tính năng hoạt động nhất quán trên mọi nền tảng được hỗ trợ (Desktop ↔ Mobile, Web Responsive, macOS ↔ iOS, Dark Mode ↔ Light Mode).
- **Trục Đầy đủ Trạng thái Dữ liệu (State Parity)**: Mọi thành phần hiển thị/xử lý dữ liệu phải đáp ứng trọn vẹn 4 trạng thái:
  1. `Loading`: Có skeleton/placeholder dự trù, không làm vỡ hoặc giật layout.
  2. `Empty`: Giao diện thông báo trạng thái trống thân thiện, có chỉ dẫn hành động.
  3. `Error`: Bắt lỗi lịch sự, có nút thử lại (Retry), không để crash ứng dụng.
  4. `Loaded`: Hiển thị dữ liệu chính xác.
- **Trục Ổn định Giao diện & Hợp đồng Dữ liệu (Contract & Layout Stability)**:
  - Trên UI: Giữ vững kích thước khung hình, triệt tiêu hiện tượng giật nhảy layout (Zero Layout Shift).
  - Trên Logic: Xử lý triệt để các trường hợp biên (`null/undefined`, chia cho 0 sinh ra `NaN/Inf`, lỗi tràn mảng `Index out of bounds`). Khi thiếu số liệu, hiển thị ký hiệu thay thế lịch sự (`-` hoặc `--`), tuyệt đối không làm crash hay hiển thị giá trị bất thường.

---

## 6. An toàn Concurrency & Kiểm thử Hồi quy (Concurrency & Test Guard)
- **Luồng UI vs Luồng Background**: Mọi cập nhật trạng thái hiển thị người dùng bắt buộc diễn ra trên Main/UI Thread. Mọi tính toán thuật toán nặng hoặc I/O bắt buộc đẩy sang Background Thread/Worker.
- **Kiểm thử hồi quy (Regression Testing Guard)**: Khi sửa đổi các hàm tính toán cốt lõi hoặc thuật toán quan trọng, bắt buộc phải chạy hoặc viết bổ sung Unit Test tương ứng để đảm bảo lỗi không bao giờ tái phát.

---

# ==============================================================================
# PHẦN 2: QUY TẮC ĐẶC THÙ DỰ ÁN (PROJECT-SPECIFIC RULES: TOMIK POMODORO)
# Tech Stack: macOS 13+ (Ventura, Sonoma, Sequoia), Swift 5.9+, SwiftUI, AppKit, SPM (LaunchAtLogin, KeyboardShortcuts, SwiftState), Xcode (Tomik.xcodeproj)
# ==============================================================================

## 1. Quy Tắc Tạo 2 Version Biệt Lập (Dev vs Production Environment)
Dự án được cấu hình và vận hành song song 2 phiên bản độc lập để đảm bảo an toàn tuyệt đối khi phát triển:

- **Phiên bản Phát triển (Development / Debug)**:
  - **Tên ứng dụng (Display Name)**: `Tomik Dev`
  - **Bundle Identifier**: `com.tomik.app.dev`
  - **Scheme / Configuration**: `Tomik` / `Debug`
  - **Đường dẫn đóng gói**: `build/Build/Products/Debug/Tomik Dev.app`
  - **Mục đích**: Dùng cho phát triển cục bộ, gỡ lỗi, kiểm thử tính năng mới. `UserDefaults`, LaunchAtLogin và thiết lập của bản Dev hoàn toàn tách biệt với bản Production, không làm mất hoặc ghi đè dữ liệu người dùng thực tế.

- **Phiên bản Sản phẩm (Production / Release)**:
  - **Tên ứng dụng (Display Name)**: `Tomik`
  - **Bundle Identifier**: `com.tomik.app`
  - **Scheme / Configuration**: `Tomik` / `Release`
  - **Đường dẫn đóng gói**: `build/Build/Products/Release/Tomik.app`
  - **Mục đích**: Bản phát hành chính thức cho người dùng. Bật tối ưu hóa biên dịch cấp cao nhất (`-O`), strip symbol, cấu hình Hardened Runtime và Entitlements chuẩn của macOS.

- **Nguyên Tắc Bắt Buộc Về Parity Của 2 Bản Dựng (Debug & Release Parity Gate)**:
  - Trước khi báo hoàn thành bất kỳ task nào, **bắt buộc phải build thành công 100% trên cả 2 cấu hình**:
    ```bash
    # 1. Build Debug (Tomik Dev)
    xcodebuild -scheme Tomik -configuration Debug -derivedDataPath ./build build
    # 2. Build Release (Tomik)
    xcodebuild -scheme Tomik -configuration Release -derivedDataPath ./build build
    ```
  - Tuyệt đối không được phép bàn giao khi chỉ một trong hai cấu hình biên dịch thành công.

- **Quy Trình Khởi Chạy Kiểm Thử Local**:
  - Luôn kill tiến trình cũ trước khi chạy bản mới để tránh xung đột Menu Bar:
    ```bash
    pkill -9 -f "Tomik" || true; sleep 1; open "build/Build/Products/Debug/Tomik Dev.app"
    ```

---

## 2. Kiến Trúc Menu Bar & Popover Lifecycle (macOS AppKit + SwiftUI)
- **Kích thước & Cơ chế Popover**:
  - Sử dụng `NSPopover` với `behavior = .transient`.
  - Độ rộng popover chuẩn cố định: `396pt`.
- **Căn giữa Menu Bar & Chống Nhấp Nháy (Re-anchoring & Dismiss Guard)**:
  - Khi bắt đầu hoặc dừng timer, độ rộng nút bấm trên thanh Menu Bar thay đổi (~28pt chỉ icon ↔ ~65pt kèm số phút `25:00`).
  - **Quy tắc an toàn**: Cơ chế tự động căn giữa (`re-anchor`) popover qua `show(relativeTo:of:preferredEdge:)` chỉ được phép kích hoạt khi popover đang mở và **KHÔNG** trong trạng thái đóng (`popover.isShown && !isClosing`).
  - Khi người dùng nhấn nút **Bắt đầu (Start)**: Popover phải gọi `closePopover` dứt khoát trước khi bắt đầu timer, tránh để sự kiện đổi độ rộng menu bar vô tình ép popover hiện lại.

---

## 3. Hệ Thống Font Chữ Unicode & Tùy Biến Cỡ Chữ
- **7 Font Unicode chuẩn hỗ trợ tiếng Việt đầy đủ**:
  - `SF Pro Rounded / System`, `Helvetica Neue`, `Avenir Next`, `Arial`, `Georgia`, `Menlo`, `Times New Roman`.
- **Quy tắc Typography**:
  - Tuyệt đối không hardcode font tĩnh như `.font(.system(...))` trong các view con.
  - Bắt buộc dùng helper tập trung `tomikFont(size:weight:fontName:baseSize:)` kết hợp `@AppStorage("tomikFontName")` và `@AppStorage("tomikFontSize")` (cỡ chữ 10 – 20 pt).
  - Mọi thay đổi font/size trong cửa sổ Cài đặt phải cập nhật tức thì (reactive) trên cả popover lẫn cửa sổ Quản Lý/Cài Đặt.

---

## 4. Quản Lý Task To-Do & Tương Tác Kéo Thả (Drag & Drop)
- **Lưu trữ Bền vững**: Dữ liệu task được quản lý qua `TomikTodoStorage` và lưu trữ JSON vào `UserDefaults`.
- **Kéo Thả Sắp Xếp (Reordering)**:
  - Dùng `DropDelegate` với `UniformTypeIdentifiers` (`UTType.text`).
  - Khi di chuyển vị trí, dùng `withAnimation` để tạo chuyển động trượt mượt mà.
  - Thứ tự mới được tự động ghi xuống `UserDefaults` ngay khi thao tác kéo thả hoàn tất.

---

## 5. Âm Thanh & Trải Nghiệm Thư Giãn (Audio & Break Activities)
- **Âm lượng Chuẩn 0 – 100%**:
  - Tách bạch 3 kênh âm lượng: Chuông báo hoàn thành (`dingVolume`), Lên dây cót (`windupVolume`), Tích tắc (`tickingVolume`).
  - Khi người dùng thử âm thanh trong Settings, phải ngắt âm thanh mẫu đang phát trước đó trước khi phát âm thanh mới (`stopThemeSound()` trước khi `playThemeSound()`).
- **Gợi Ý Vận Động Khi Nghỉ (Break Tips)**:
  - Tự động hiển thị gợi ý ngẫu nhiên từ `TomikBreakActivities` mỗi khi bước vào giờ giải lao.

---

## 6. Hệ Thống Tự Động Cập Nhật (Sparkle 2) & Quy Trình Phát Hành (Release Automation)
- **Cơ Chế Cập Nhật Tự Động Bản Chính Thức (Production Auto-Update)**:
  - Bản chính thức (`com.tomik.app`, `Tomik.app` cài tại `/Applications/Tomik.app`) luôn bật tự động kiểm tra định kỳ (`SUEnableAutomaticChecks = true`, chu kỳ 6 giờ qua `SUScheduledCheckInterval = 21600`).
  - **Mặc định tải ngầm trong nền (`SUAutomaticallyUpdate = true`)**: Bản update sẽ được âm thầm tải về trong nền từ GitHub Releases mà không làm gián đoạn người dùng, và tự động áp dụng khi khởi động lại app.
  - Trong cửa sổ Cài đặt, cung cấp toggle cho phép người dùng tùy chọn bật/tắt tải ngầm.
- **Nguyên Tắc Phân Tách Môi Trường Khi Phát Triển & Sử Dụng**:
  - Khi code / gỡ lỗi hàng ngày: **Chỉ khởi chạy bản Dev (`Tomik Dev.app`)**.
  - Bản Dev có tiêu đề `Tomik Dev` và badge DEV màu cam pastel; Sparkle bị vô hiệu hóa (`#if DEBUG`) để không bao giờ bị auto-update ghi đè code đang làm việc cục bộ.
  - Bản chính thức (`Tomik.app`) nằm độc lập trong thư mục `/Applications`, tự nhận cập nhật qua Sparkle feed. Tuyệt đối không mở bản Release trực tiếp từ thư mục `build/` khi đang dev.
- **Quy Trình Phát Hành Bản Mới Chuẩn Hóa (`release.sh`)**:
  - Lệnh thực thi: `./release.sh <version> <build_number>` (ví dụ: `./release.sh 1.0.1 2`).
  - Quy trình tự động thực hiện trọn gói 9 bước:
    1. Preflight kiểm tra công cụ (`xcodebuild`, `gh`, `git`, `sign_update`, tag).
    2. Cập nhật `CFBundleShortVersionString` & `CFBundleVersion` trên `Info.plist` và `project.pbxproj`.
    3. Biên dịch bản Release (`xcodebuild`), nhúng `Sparkle.framework`, cấu hình `rpath`.
    4. Chạy Smoke test (3 giây) đảm bảo app khởi chạy ổn định.
    5. Dọn dẹp sạch các file zip helper nội bộ từ dependencies (`LaunchAtLoginHelper.zip`, `copy-helper-swiftpm.sh`) trước khi ký để tránh lỗi Apple Notarization.
    6. Ký số Developer ID (`Developer ID Application: RELIPA COMPANY LIMITED (B2U85XPU55)`) với Hardened Runtime và Entitlements.
    7. Gửi Apple Notary Service qua profile `GOX_NOTARY` (tự fallback `notarytool`), staple ticket vào `.app`, đóng gói lại file `Tomik.zip`.
    8. Ký số EdDSA bằng Sparkle `sign_update` (lấy private key từ Keychain `ed25519`) và cập nhật `appcast.xml`.
    9. Push commit lên `main`, tạo Git Tag `v<version>`, và phát hành GitHub Release kèm `Tomik.zip`.
