# Wind shrine

Đền gió tự dựng trong Blender theo concept đã duyệt, không dùng asset ngoài.

- 6 mesh, khoảng 1.122 tam giác; Y-up, đơn vị mét.
- Đường kính bệ/vòng đá khoảng 2,3 m, bệ cao 0,05 m, vòng đá thấp hơn 0,25 m.
- Tâm pha lê y=1,43 m, đỉnh khoảng 1,9 m. Pha lê dùng cùng hình học ở cả hai trạng thái.
- UV của từng mặt pha lê dành riêng cho viền sáng: không tự unwrap lại nếu vẫn dùng shader hiện tại.

Scene dùng trong game: `res://objects/checkpoint/checkpoint.tscn`.
Giữ Trigger và Spawn cũ; phần hình ảnh nằm trong `WindShrineVisual`.
Chỉ checkpoint hiện được GameState chọn mới sáng. Đọc save hoặc thay tiến trình đều cập nhật hình ảnh.
Scene không có vật cản mới để người chơi vẫn đi qua và hồi sinh ở tâm bệ.

Chỉnh độ sáng đá, màu pha lê, cường độ sáng, độ lơ lửng và thời gian chuyển trạng thái tại:
`res://resources/wind/wind_shrine_default.tres`.
Tốc độ xoay giữ ở `Checkpoint.crystal_spin_speed` (độ/giây).
Trong editor, bật `WindShrineVisual.preview_active` để xem trạng thái kích hoạt.
Sau khi sửa các trường bên trong Resource, nạp lại scene để áp dụng trong preview.

Pha lê xoay và lơ lửng bằng shader TIME; shader và mesh dùng chung.
Năm material hiệu ứng tạo một lần mỗi đền để các đền chuyển trạng thái độc lập.
Khi kích hoạt, mặt bệ và vòng đá phủ xanh ngọc, rõ hơn về phía viền; vòng khắc sáng xanh nhạt.
Tween chỉ chạy khi đổi trạng thái, không có vòng lặp script mỗi frame.
Aura dùng shader cộng màu, hoạt động với GL Compatibility và không cần bật bloom toàn map.

Test: `res://tests/test_wind_shrine.tscn`.
Bài kiểm tra thực sự lưu/đọc checkpoint: chạy với APPDATA/LOCALAPPDATA riêng như log kiểm thử để tránh đụng save cá nhân.
