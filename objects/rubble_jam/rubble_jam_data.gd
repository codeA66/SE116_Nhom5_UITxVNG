class_name RubbleJamData
extends Resource
## Nhịp và lực của cú phá đống đá vụn chèn cánh quạt. Chỉnh trong .tres, không cần sửa code.

@export_group("Charge")
## Gió gom xoáy quanh đống đá trước khi bung (s); đá rung mạnh dần trong lúc này
@export_range(0.0, 2.0, 0.05) var charge_time: float = 0.4
@export_range(0.0, 0.2, 0.005) var charge_shake: float = 0.05

@export_group("Debris")
## Tốc độ văng của mảnh đá (m/s), ngẫu nhiên trong khoảng
@export var speed_min: float = 4.0
@export var speed_max: float = 8.0
## Văng chếch lên bấy nhiêu (m/s cộng thêm theo phương đứng)
@export var upward: float = 4.5
@export var gravity: float = 16.0
## Tốc độ xoay của mảnh (độ/giây), ngẫu nhiên tới mức này
@export var spin_degrees: float = 720.0
## Mảnh bay bao lâu rồi biến mất (s); quãng cuối thu nhỏ dần
@export_range(0.2, 5.0, 0.05) var lifetime: float = 1.3
@export_range(0.0, 1.0, 0.05) var shrink_fraction: float = 0.35

@export_group("Feedback")
@export_range(0.0, 1.0) var trauma: float = 0.35
