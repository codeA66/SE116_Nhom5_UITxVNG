# Kiểm thử Phòng 5.1, 5.2 và 5.3

Luồng: Phòng 5 (học sách Gió) → dịch chuyển tới lối 5.1 → qua cửa song sắt vào 5.2 (đánh Bọ, bắt buộc, cửa đóng sau lưng) →
thắng thì mở dốc lên Phòng 6, lối đi tiếp duy nhất (cầu thang cũ Phòng 9 → 6 chặn bằng lan can thật). Phòng bí mật 5.3 nằm sau tường giả ở góc đông-nam đấu trường (gió rò qua khe nứt, chém có gợi ý, Thổi Gió phá vỡ sau khi thắng), cuối một cầu đá dài nên ngoài khung camera khi đứng ở 5.2: 3 đợt, thưởng bùa.

| Use case | Test case trong Level 1 | Unit test của phòng |
| --- | --- | --- |
| Nhận sách Gió và vào thử thách | TC00–06. Cầu thang lên 5.1 bị chặn khi chưa học Gió. Nhấn F, dịch chuyển tới 5.1, đi bộ qua 5.1 vào 5.2 mà không đổi checkpoint, cửa vào khóa sau lưng. Cầu thang cũ bị khóa, tường giả chắn lối sang 5.3. | UT01–03. Chỉ Foxy đã học Gió kích hoạt đợt một. UT08. Đang đánh thì tường giả chưa phá được. |
| Phản đạn để mở cửa | TC07–13. Hạ một Bọ ở đợt đầu, nghỉ khoảng hai giây, rồi hạ hai Bọ bắn lệch nhịp. Kiểm tra hướng mõm Bọ lúc nhả đạn và chém hình nộm khi cạn năng lượng. Lối lên Phòng 6 chỉ mở sau con cuối, lúc đó tường giả mới phá được. | UT04–06. Chuyển đợt, mở cửa sau đợt cuối và dọn Bọ đang chờ khi rời phòng. UT10. Chỉ nhả va chạm khi cánh trượt xong; tường giả lúc này mới phá được. UT11–12. Kiểm tra hướng quay với góc đặt Bọ 0° và 180°. |
| Phòng bí mật 5.3 | TC28–30. Chém tường giả có gợi ý mà không vỡ; Thổi Gió phá vỡ, lưu cờ, mảnh đá rơi xong thì ẩn; đứng cạnh tường giả trong 5.2 thì 5.3 nằm ngoài khung camera, đi hết cầu mới thấy phòng. TC20–26. Ba đợt, quái không có bảng rơi Soul Jade. Đi thật qua hành lang vào 5.3 thì cửa khóa. Mỗi đợt xuất hiện và hạ đủ quái, bùa chỉ hiện sau đợt 3, nhặt được bùa. | |
| Đi tiếp và nạp lại | TC14–19, TC27. Đi qua dốc tới Phòng 6 mà không đổi checkpoint, kiểm tra hai vị trí xuất hiện còn tương thích với save cũ, nạp lại hồ sơ đã thắng: tường giả vẫn vỡ, 5.3 trống quái, bùa không hiện lại. | UT07. Phòng đã thắng mở cửa ngay, tường giả phá được, bỏ qua cả hai đợt. |

```powershell
godot --headless --path . tests/levels/wind_map/wind_trial/test_wind_trial_unit.tscn
godot --headless --path . tests/levels/wind_map/wind_trial/test_wind_trial.tscn
godot --headless --path . tests/enemies/burrow_beetle/burrow_beetle_demo.tscn -- --verify-beetle
```

Scene kiểm thử ngắt ghi save tự động trước khi thay tiến trình. Khi chạy trên máy có save cá nhân, đặt `APPDATA` và `LOCALAPPDATA` vào một thư mục test riêng trước khi mở Godot để cách ly cả bước nạp save của autoload.
