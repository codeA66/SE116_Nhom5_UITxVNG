class_name CrumblingFloorData
extends Resource
## Thông số ô sàn sụp. Chỉnh trong file .tres, không cần sửa code.

## Đứng lên bao lâu thì ô rơi (s): người chơi phải đi tiếp / dash qua trong khoảng này
@export_range(0.05, 5.0, 0.05) var crack_time: float = 0.6
## Ô rơi xong bao lâu thì hiện lại (s)
@export_range(0.1, 30.0, 0.1) var respawn_time: float = 3.0
## Độ rung của ô lúc nứt (m)
@export_range(0.0, 0.2, 0.005) var shake_amount: float = 0.04
## Tốc độ rơi (m/s²) và quãng rơi tối đa trước khi ẩn hẳn (m)
@export var fall_gravity: float = 18.0
@export var fall_distance: float = 6.0
