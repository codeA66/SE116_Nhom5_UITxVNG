# Hội thoại Map Gió: sự tích và cinematic

## Kịch bản

Hai NPC cùng kể sự tích **Ngọn đèn bên kia cửa**. Người Giữ Bến nhớ chuyến thuyền trở về không có khách, chỉ còn chiếc đèn với quai ấm. Kẻ Giữ Cửa nhớ đêm đóng cổng và tiếng gõ từ bên trong. Đây là nội dung mới của tính năng này.

- Người Giữ Bến kể 3 câu khi gặp lần đầu. Sau khi trả phí gọi thuyền, hộp thoại vẫn mở để bấm F đọc tiếp 3 câu về chiếc đèn nếu chưa nghe. Đoạn này cũng có thể đọc khi quay lại nói chuyện. Sau khi nghe hết, NPC dùng lời chào ngắn.
- Kẻ Giữ Cửa kể 2 câu khi gặp lần đầu. Sau lời nhận phí, bấm F để đọc tiếp 4 câu về tiếng gõ trong cùng hộp thoại. Nếu thoát bằng Esc giữa đoạn, cổng đã trả vẫn mở và người chơi có thể quay lại nghe nốt. Sau khi nghe hết, NPC dùng lời chào ngắn.
- Đọc hết đoạn mới ghi cờ. Esc/bị đánh giữa đoạn không đánh dấu đã nghe. Cờ theo cơ chế checkpoint hiện có: chưa chạm checkpoint thì chết có thể phải nghe lại.
- Chữ dịch vụ dùng giá/loại tiền hiện tại. Lời thoại chi tiết nằm trong `resources/world/npcs/{ferry,gate}`; phí và các câu trả tiền nằm ở scene của từng NPC.

## Hiệu ứng riêng

| NPC | Camera và giao diện | VFX |
|---|---|---|
| Người Giữ Bến | Tiến chậm 1,25 s, zoom 0,82, viền 5,5%, sắc hổ phách | 8 đốm sáng bay chậm quanh phía tay cầm đèn |
| Kẻ Giữ Cửa | Chuyển 0,8 s, zoom 0,9, viền 8,5%, sắc xanh lạnh | 12 vệt bụi gió lướt ngang sát nền |

Camera hiện tại được dùng lại. VFX mỗi NPC chỉ có một MultiMesh, mesh ít đỉnh, vật liệu unshaded, không bóng/đèn động/va chạm; không blur hay render màn hình phụ. Hình học và overlay được tạo lúc vào map, được hệ thống ShaderWarmup sẵn có thu thập. VFX ngừng `_process` và ẩn khi hết hội thoại; cinematic chỉ dùng tween lúc vào/ra. Giới hạn instance thực tế là 1–24 kể cả khi cấu hình ngoài khoảng Inspector.

HUD và CanvasLayer thuộc group `gameplay_overlay` tạm ẩn, rồi khôi phục đúng trạng thái cũ. Tiêu đề vùng và giao diện tầng 3 đã đăng ký group này. Một cuộc trò chuyện mới có thể tiếp quản camera trong lúc cuộc trước đang thoát mà không tích lũy mức zoom.

`NpcStory` gắn kịch bản qua component để room `.scn` cũ có lưu override lời chào vẫn dùng đúng truyện mới. Không chuyển đổi hay ghi lại room nhị phân.

## Use case → test case → kiểm thử

| Use case | Test case / kỳ vọng | Kiểm thử tương ứng |
|---|---|---|
| UC01 Gặp NPC lần đầu | TC01 F mở đúng lời chào, khóa di chuyển; room bến cũ không ghi đè truyện | Unit UT01/05; integration kiểm tra room và lời chào; runtime F ở cả hai vị trí |
| UC02 Khám phá sự tích | TC02 Đọc xong mới mở mảnh tiếp theo; lời dài không lặp vô hạn; chỉ sau trả phí mới nghe bí mật của người giữ cửa | Unit UT02/03/06–10; integration đọc các đoạn và kiểm tra nhánh tiếp |
| UC03 Hai không khí khác nhau | TC03 Ảnh thực tế có tông màu, tốc độ camera, viền, chuyển động VFX riêng; tên vùng/HUD không che thoại | Runtime chụp trước/trong/sau cả hai NPC; integration zoom/HUD/VFX |
| UC04 Thoát hoặc bị đánh | TC04 Esc/bị đánh trả camera, HUD, điều khiển; VFX ngủ; đoạn chưa đọc xong không bật cờ | Integration Esc, damage, cờ chưa nghe |
| UC05 Trả phí | TC05 Thiếu/đủ/vừa đủ/0/giá lớn: số tiền, hàng rào và hoạt ảnh đúng; từ chối không trừ | Unit UT11/12/14/15; regression gatekeeper UC2/3/5/9 |
| UC06 Không thu tiền hai lần | TC06 Gọi thuyền lại trả ALREADY_CALLED; nghe truyện sau mở cổng không trừ thêm | Unit UT13; integration và regression gatekeeper UC6 |
| UC07 Lưu và chết | TC07 Cờ truyện qua vòng serialize/deserialize; checkpoint giữ cờ đã chốt, bỏ cờ sau checkpoint | Unit UT04/17/18 |
| UC08 Kết thúc phiên bất thường | TC08 Đổi NPC lúc outro; xóa NPC đang nói; camera/HUD/điều khiển trở lại ban đầu | Integration rapid handoff, removal, unload scene |
| UC09 Hiệu năng | TC09 Không xử lý VFX khi rảnh; hình học hữu hạn ở thời gian lớn; đo CPU VFX và frame/draw call của map thật | Unit UT16; integration idle/sleep và số lượng 0/999; runtime VFX_CPU + PROFILE |
| UC10 Đọc tiếp sau khi gọi thuyền | TC10 Bấm F xác nhận phí và tiếp tục đọc chuyện ngọn đèn trong cùng hộp thoại. Đọc hết lưu cờ, trả điều khiển, chỉ thu một lần | Runtime dùng phím F trên `level_1` và kiểm tra thuyền xuất hiện |
| UC11 Đọc tiếp sau khi trả phí cổng | TC11 F chuyển từ lời nhận phí sang chuyện tiếng gõ. Đọc hết ghi cờ, mở cổng. Esc vẫn mở cổng đã trả và để đoạn truyện còn khả dụng | Regression gatekeeper UC5/6 và integration |

Unit test kiểm tra lựa chọn dữ liệu, phí và hình học độc lập với renderer. Integration dùng Player, NPC, FSM, input F/Esc và camera thật. Runtime nạp nguyên `level_1`, gửi input F/Esc trong game có cửa sổ, chụp framebuffer thật. Không dùng kết quả headless để kết luận bố cục hình ảnh hoặc FPS.

## Chạy lại

Từ thư mục project trong PowerShell; thay `$godotExe` bằng đường dẫn Godot của máy:

```powershell
$godotExe = 'C:/duong-dan/Godot.exe'
& $godotExe --headless --path . res://tests/npcs/conversation/test_wind_story_unit.tscn
& $godotExe --headless --path . res://tests/npcs/conversation/test_wind_conversation.tscn
& $godotExe --headless --path . res://tests/npcs/test_gatekeeper.tscn
& $godotExe --path . --resolution 1280x720 res://tests/npcs/conversation/runtime/test_wind_gameplay.tscn
```

Runtime tự đóng sau khi chụp xong; ảnh nằm trong `output/wind_conversation/`. Các test ngắt kết nối tự lưu trước khi tạo tiến trình thử, không ghi đè hồ sơ người chơi. Unit/integration/runtime trả exit code khác 0 khi assertion không đạt; regression cũ cần đọc `RESULT fails=0`.

## Kết quả

Chạy ngày 09/11/2026, Godot 4.7.2, Compatibility/OpenGL, NVIDIA GeForce MX230, 1280×720.

| Bộ kiểm thử | Kết quả |
|---|---|
| Unit | 26 PASS, 0 FAIL; không có ERROR trong log |
| Integration | 24 PASS, 0 FAIL; không có ERROR trong log |
| Regression thu phí cổng | 39 PASS, 0 FAIL; không có ERROR trong log |
| Game có cửa sổ, input F/Esc, ảnh framebuffer (trước bản sửa `Area3D`) | 10 PASS, 0 FAIL |

Ảnh đã xem trực tiếp để kiểm tra chữ, viền, tông màu, vị trí NPC và việc ẩn HUD/tiêu đề vùng:

- `output/wind_conversation/FerryAttendant_during.png`
- `output/wind_conversation/Tier3Gatekeeper_during.png`
- Cùng thư mục có ảnh `_before`, `_after` và log `unit.log`, `integration.log`, `gate_regression.log`, `runtime.log`, `baseline.log`.

Chi phí CPU đo riêng cho một lần cập nhật VFX, trung bình 1.000 lần: Người Giữ Bến **8,583 µs** (~0,0086 ms), Kẻ Giữ Cửa **10,149 µs** (~0,0101 ms). Khi idle, VFX không chạy `_process`. Số đo này không bao gồm GPU.

Mẫu 20 frame trong lượt chạy cuối:

| Vị trí | Trước hội thoại: process / draw calls | Trong hội thoại: process / draw calls |
|---|---|---|
| Bến thuyền | 9,84 ms / ~599 | 8,51 ms / 378 |
| Lối tầng 3 | 19,90 ms / 269 | 13,18 ms / 203 |

Đây là mẫu ngắn của **toàn map**, không phải benchmark FPS ổn định. Zoom thay đổi phần cảnh nhìn thấy, HUD ẩn và tải map thay đổi theo thời gian; không dùng bảng này để kết luận cinematic làm tăng FPS. Các lượt khởi động lạnh trước đó có frame time cao hơn đáng kể.

### Ghi chú khi chạy toàn map

- Môi trường sandbox không tạo được shader cache trong `user://`; renderer vẫn chạy và chụp ảnh được. Chưa đánh giá việc lưu cache ở môi trường ngoài sandbox.
- Đã sửa ba lỗi `Condition "!E" is true` tại `area_3d.cpp:215` khi đóng `level_1`. `TierZone` hoãn đổi `process_mode` của phòng và cầu đến sau callback va chạm, để Godot hoàn tất việc báo người chơi rời các vùng con. Kiểm tra headless xác nhận cầu bật khi vào, tắt khi ra và bật lại khi quay vào. Gỡ map, thoát game tại lối tầng 3 và bài chạy F/Esc với cả hai NPC đều sạch lỗi. Log nằm trong `output/wind_teardown/`.
- Cảnh báo nội suy MultiMesh ở lượt thử đầu đã được sửa bằng cách tắt physics interpolation riêng cho VFX cập nhật theo render frame; lượt chạy cuối không còn cảnh báo đó.

Để kiểm tra lại việc đóng map với các component hội thoại đã gỡ khỏi scene (chạy headless):

```powershell
& $godotExe --headless --path . res://tests/npcs/conversation/runtime/test_wind_gameplay.tscn -- --baseline
```

