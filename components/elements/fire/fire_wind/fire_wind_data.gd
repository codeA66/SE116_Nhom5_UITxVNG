class_name FireWindData
extends Resource
## Thông số lửa theo vết gió. Chỉnh trong .tres, không sửa code.

## Vết lửa còn bật thêm bao lâu sau khi cú gió tắt (s); 0 = tắt cùng gió
@export_range(0.0, 2.0, 0.01) var extra_time: float = 0.1
