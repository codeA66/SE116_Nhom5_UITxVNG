class_name FireBoltData
extends Resource
## Thông số cầu lửa sọ của Quỷ Xương Lửa. Thêm kiểu cầu mới = thêm .tres, không sửa code.

@export_group("Flight")
## Tốc độ bay (m/s). Mỗi frame đi (speed / 60) m phải nhỏ hơn đường kính hitbox, nếu không có thể xuyên vật mỏng
@export var speed: float = 8.0
## Sống tối đa rồi tan (s)
@export var lifetime: float = 2.5
## Bán kính hitbox (m)
@export var hit_radius: float = 0.24
## Thời gian nổ trước khi nhả về pool (s)
@export var explode_time: float = 0.3

@export_group("Burn")
## Trúng player (đòn không bị chặn bởi bất tử / dash) thì làm bắt lửa
@export var ignite_on_hit: bool = true
## Tên node BurnableComponent trên mục tiêu (player, quái...)
@export var burnable_node: StringName = &"BurnableComponent"

@export_group("Collision")
## Dừng ở world + player
@export_flags_3d_physics var mask: int = 3

@export_group("Reflect")
## Bị khiên dội ngược (Khiên xỉ) thì đổi sang mask này: world + hurtbox quái (không trúng lại khiên / player)
@export_flags_3d_physics var reflected_mask: int = 5
## Tốc độ sau khi bị dội = speed x hệ số này
@export_range(0.1, 5.0, 0.05) var reflect_speed_mult: float = 1.3
## Loại sát thương của cầu sau khi bị dội. Mặc định thường (PHYSICAL): Quỷ Xương Lửa kháng lửa hẳn nên cầu dội
## mang loại FIRE sẽ không gây sát thương gì
@export var reflected_damage_type: DamageInfo.Type = DamageInfo.Type.PHYSICAL
