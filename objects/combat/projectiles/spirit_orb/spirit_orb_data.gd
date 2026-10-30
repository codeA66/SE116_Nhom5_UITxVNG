class_name SpiritOrbData
extends Resource
## Thông số quả cầu hồn. Thêm kiểu cầu mới = thêm .tres (hoặc scene đạn mới), không sửa code.

@export_group("Flight")
## Tốc độ bay (m/s). Mỗi frame đi (speed / 60) m phải nhỏ hơn đường kính hitbox, nếu không có thể xuyên vật mỏng
@export var speed: float = 7.0
## Sống tối đa rồi tan (s)
@export var lifetime: float = 3.0
## Bán kính hitbox (m): nhỏ hơn hình để sượt qua thì không tính
@export var hit_radius: float = 0.22
## Thời gian nổ / tan trước khi nhả về pool (s)
@export var explode_time: float = 0.3

@export_group("Wind Reflect")
## Bán kính vùng cho cú thổi bắt được (m), rộng hơn hitbox để dễ phản
@export var wind_catch_radius: float = 0.45
## Phản lại nhanh hơn: tốc độ sau phản = speed × giá trị này
@export var reflect_speed_mult: float = 1.5
## Phản xong tự bẻ hướng về quái gần nhất lệch không quá góc này so với hướng thổi (độ)
@export_range(0.0, 180.0) var reflect_aim_angle: float = 25.0
@export var reflect_aim_range: float = 12.0
## Sát thương lên quái khi quả đã bị phản
@export var reflected_attack: AttackData

@export_group("Collision")
## Trước khi bị phản: dừng ở world + player
@export_flags_3d_physics var hostile_mask: int = 3
## Sau khi bị phản: dừng ở world + enemy
@export_flags_3d_physics var reflected_mask: int = 5
## Layer của hurtbox quái dùng cho aim assist sau khi phản
@export_flags_3d_physics var aim_assist_layer: int = 4
