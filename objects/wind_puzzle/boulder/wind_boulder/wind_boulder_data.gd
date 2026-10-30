class_name WindBoulderData
extends Resource
## Thông số đá trượt gió. Chỉnh trong file .tres, không cần sửa code.

## Bán kính viên đá (m): va chạm, hình và phép dò đường đều dùng số này
@export_range(0.3, 3.0, 0.05) var radius: float = 0.9
@export var slide_speed: float = 9.0
## Quãng trượt tối đa mỗi cú thổi (m), tránh trượt vô tận khi không có gì chặn
@export var max_slide_distance: float = 40.0
## Chừa khoảng hở trước vật chặn (m). Không để quá nhỏ: đá dừng sát vật rồi trượt ngang dọc theo vật sẽ bị coi là đang chạm, không đi được
@export var stop_margin: float = 0.2
## Lớp va chạm làm đá dừng lại (world + player blocker + player)
@export_flags_3d_physics var blocking_mask: int = 1 | 2 | 256
