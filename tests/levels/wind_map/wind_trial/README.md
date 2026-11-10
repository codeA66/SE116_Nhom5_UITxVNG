# Kiểm thử Phòng 5.1 và 5.2

| Use case | Test case trong Level 1 | Unit test của phòng |
| --- | --- | --- |
| Nhận sách Gió và vào thử thách | TC00–06. Nhấn F, dịch chuyển tới 5.1, đi qua 5.1 mà không đổi checkpoint rồi bước vào 5.2. Lối cầu thang cũ bị khóa và save cũ vẫn có đường đi bộ vào 5.1. | UT01–03. Chỉ Foxy đã học Gió kích hoạt đợt một. UT08–09. Cửa chặn lối ngay khi hai cánh bắt đầu trượt và khép ở giữa. |
| Phản đạn để mở cửa | TC07–13. Hạ một Bọ ở đợt đầu, nghỉ khoảng hai giây, rồi hạ hai Bọ bắn lệch nhịp. Kiểm tra hướng mõm Bọ lúc nhả đạn và chém hình nộm khi cạn năng lượng. Cửa chỉ mở sau con cuối. | UT04–06. Chuyển đợt, mở cổng sau đợt cuối và dọn Bọ đang chờ khi rời phòng. UT10. Chỉ nhả va chạm khi cánh trượt xong. UT11–12. Kiểm tra hướng quay với góc đặt Bọ 0° và 180°. |
| Đi tiếp và nạp lại | TC14–19. Đi qua dốc tới Phòng 6 mà không đổi checkpoint, kiểm tra hai vị trí xuất hiện còn tương thích với save cũ và nạp lại hồ sơ đã thắng. | UT07. Phòng đã thắng mở cửa ngay và bỏ qua cả hai đợt. |

```powershell
godot --headless --path . tests/levels/wind_map/wind_trial/test_wind_trial_unit.tscn
godot --headless --path . tests/levels/wind_map/wind_trial/test_wind_trial.tscn
godot --headless --path . tests/enemies/burrow_beetle/burrow_beetle_demo.tscn -- --verify-beetle
```

Scene kiểm thử ngắt ghi save tự động trước khi thay tiến trình. Khi chạy trên máy có save cá nhân, đặt `APPDATA` và `LOCALAPPDATA` vào một thư mục test riêng trước khi mở Godot để cách ly cả bước nạp save của autoload.
