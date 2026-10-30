class_name VaneBridgeData
extends Resource
## Thông số cầu chong chóng. Chỉnh trong file .tres, không cần sửa code.

## Mỗi cú thổi xoay cầu bấy nhiêu độ quanh trục đứng (dương = ngược chiều kim đồng hồ nhìn từ trên)
@export var step_degrees: float = 90.0
@export_range(0.1, 5.0, 0.05) var turn_time: float = 0.9
## Chong chóng quay bao nhiêu vòng trong lúc cầu xoay (chỉ là hình)
@export var vane_turns: float = 2.0
@export_range(0.0, 1.0) var turn_trauma: float = 0.15
