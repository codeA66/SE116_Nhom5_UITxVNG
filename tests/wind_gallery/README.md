# Scene test model Gió mới

Mở `wind_model_gallery.tscn` trong Godot rồi nhấn **F6** để chạy riêng scene này.

- Chọn model và biến thể ở bảng bên trái. Bấm **Tải lại danh sách model** để nhận GLB mới đã xuất trong `assets/generated/wind_ruins/`.
- Giữ chuột phải và kéo để xoay; lăn chuột để zoom. Chọn camera game để xem ở góc 50 độ, FOV 30 độ và khoảng cách của camera hiện tại.
- Chuyển **Màu vật liệu gốc** hoặc **Clay kiểm tra hình khối**. Lưới sàn có bước 1 m; model giữ tỷ lệ gốc, không co giãn cho vừa màn hình.
- Bật **Đi thử bằng cáo**, dùng WASD và Space. Collider của model được sinh tạm trong scene test. Bấm **Đặt lại cáo và camera** để về điểm xuất phát.

Scene này chỉ tham chiếu nhân vật và model có sẵn. Các override màu, collider và vị trí đặt thử chỉ tồn tại trong scene test; không được ghi vào model nguồn. Chạy scene này không đổi scene khởi động của project.

Kiểm tra tự động: chạy Godot với `--headless --path <project> res://tests/wind_gallery/smoke_test.tscn`. Nên trỏ APPDATA và LOCALAPPDATA vào `.godot/gallery_runtime` khi chạy kiểm tra để dùng dữ liệu thử riêng. Bỏ `--headless` và thêm `-- --capture` để xuất ảnh kiểm tra vào `user://wind_gallery_verification/` (thư mục dữ liệu người dùng của Godot, ngoài project).
