class_name MovementStats
extends Resource
## Thông số di chuyển. Mỗi loại nhân vật dùng một file .tres riêng, chỉnh không cần sửa code.

@export_group("Move")
@export var max_speed: float = 6.0
@export var ground_accel: float = 60.0
@export var ground_decel: float = 70.0
## Gia tốc khi đổi hướng ngược lại, cao hơn để không bị trơn
@export var turn_accel: float = 110.0
@export var air_accel: float = 25.0
@export var rotation_speed: float = 14.0

@export_group("Jump")
@export var jump_height: float = 2.0
@export var time_to_apex: float = 0.38
@export var fall_gravity_mult: float = 1.8
## Nhân vận tốc lên khi nhả nút sớm -> nhảy thấp
@export var jump_cut_mult: float = 0.45
## Vùng vận tốc quanh đỉnh nhảy được giảm trọng lực
@export var apex_threshold: float = 1.0
@export var apex_gravity_mult: float = 0.5
@export var max_fall_speed: float = 25.0
