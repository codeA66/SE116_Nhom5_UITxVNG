# Kiểm thử Phòng 5.1, 5.2 và 5.3

Luồng: Phòng 5 (học sách Gió) → dịch chuyển lên ban công 5.1 → rơi qua hố xuống 5.2 (đánh Bọ, bắt buộc) →
thắng thì mở dốc lên Phòng 6 (đi tiếp). Phòng bí mật 5.3 nằm sau tường giả ở mép nam đấu trường (gió rò qua khe nứt, chém có gợi ý, Thổi Gió phá vỡ sau khi thắng): mái che tan khi bước vào, 3 đợt, thưởng bùa.

| Use case | Test case trong Level 1 | Unit test của phòng |
| --- | --- | --- |
| Nhận sách Gió và vào thử thách | TC00–06. Cầu thang lên 5.1 bị chặn khi chưa học Gió. Nhấn F, dịch chuyển lên ban công 5.1, đi vào hố, rơi xuống 5.2 mà không đổi checkpoint. Cầu thang cũ bị khóa, cửa sang 5.3 đóng. | UT01–03. Chỉ Foxy đã học Gió kích hoạt đợt một. UT08. Cửa sang 5.3 đóng sẵn từ đầu. |
| Phản đạn để mở cửa | TC07–13. Hạ một Bọ ở đợt đầu, nghỉ khoảng hai giây, rồi hạ hai Bọ bắn lệch nhịp. Kiểm tra hướng mõm Bọ lúc nhả đạn và chém hình nộm khi cạn năng lượng. Lối lên Phòng 6 và cửa sang 5.3 chỉ mở sau con cuối. | UT04–06. Chuyển đợt, mở cả hai cửa sau đợt cuối và dọn Bọ đang chờ khi rời phòng. UT10. Chỉ nhả va chạm khi cánh trượt xong. UT11–12. Kiểm tra hướng quay với góc đặt Bọ 0° và 180°. |
| Phòng bí mật 5.3 | TC28–30. Chém tường giả có gợi ý mà không vỡ; Thổi Gió phá vỡ, lưu cờ, mảnh đá rơi xong thì ẩn; đứng ngoài thì mái che kín, bước vào thì mái tan. TC20–26. Ba đợt, quái không có bảng rơi Soul Jade. Đi thật qua hành lang vào 5.3 thì cửa khóa. Mỗi đợt xuất hiện và hạ đủ quái, bùa chỉ hiện sau đợt 3, nhặt được bùa. | |
| Đi tiếp và nạp lại | TC14–19, TC27. Đi qua dốc tới Phòng 6 mà không đổi checkpoint, kiểm tra hai vị trí xuất hiện còn tương thích với save cũ, nạp lại hồ sơ đã thắng: 5.3 trống quái, bùa không hiện lại. | UT07. Phòng đã thắng mở cả hai cửa ngay và bỏ qua cả hai đợt. |

```powershell
godot --headless --path . tests/levels/wind_map/wind_trial/test_wind_trial_unit.tscn
godot --headless --path . tests/levels/wind_map/wind_trial/test_wind_trial.tscn
godot --headless --path . tests/enemies/burrow_beetle/burrow_beetle_demo.tscn -- --verify-beetle
```

Scene kiểm thử ngắt ghi save tự động trước khi thay tiến trình. Khi chạy trên máy có save cá nhân, đặt `APPDATA` và `LOCALAPPDATA` vào một thư mục test riêng trước khi mở Godot để cách ly cả bước nạp save của autoload.
