# Wind spellbook

Sách tự dựng trong Blender theo concept đã duyệt, không dùng asset ngoài.
5 mesh, khoảng 1.780 tam giác; bìa trắng ngà/xanh nhạt, gáy xanh xám, biểu tượng xoáy lớn.
Y-up, mặt trước +Z, tâm model tại gốc. Chiều cao sách khoảng 1,05 m.

Scene vật phẩm: `res://objects/core/pickups/ability/ability_pickup.tscn`.
Hình ảnh riêng: `res://objects/core/pickups/ability/wind_spellbook_visual.tscn`.
Các WindBook trong test_game và test_movement tự nhận model mới.
Giữ nguyên AbilityData, persistent_id, vùng tương tác và logic mở khóa/lưu tiến trình.

- Pickup.spin_speed điều khiển tốc độ xoay (rad/giây), mặc định 0,45.
- Visual đặt cao 1,05 m; Presentation nghiêng nhẹ để thấy bìa từ camera game.
- Shader tạo chuyển động lơ lửng và hai dải gió xoay quanh sách; không có script cập nhật VFX mỗi frame.
- Màu sách dùng sắc độ theo mặt vát, giữ biểu tượng rõ dưới ánh sáng mạnh của map.
- 8 CPUParticles3D nhỏ mặc định, giới hạn Inspector tối đa 16.
- Mesh và shader dùng chung; material cùng màu được tái sử dụng trong mỗi sách.
- Toàn bộ VFX nằm trong cây con của vật phẩm nên biến mất cùng sách khi nhặt.

Chỉnh brightness, float_amplitude, float_speed, wind_color, wind_opacity, orbit_speed,
mote_count/radius/speed trên node Visual. Nạp lại scene sau khi chỉnh để áp dụng preview.
Tắt preview_motion nếu không cần chuyển động shader/hạt trong editor.

Test: `res://tests/wind/spellbook/test_wind_spellbook.tscn` kiểm tra input tương tác, kỹ năng E, ghi/đọc save và không sinh lại sách đã nhặt.
Test bắt buộc APPDATA/LOCALAPPDATA nằm trong `.godot/spellbook_runtime/` để bảo vệ save cá nhân.
