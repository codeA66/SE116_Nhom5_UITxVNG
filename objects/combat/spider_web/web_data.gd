class_name WebData
extends Resource
## Thông số tơ nhện (đạn tơ + tấm tơ dính player). Loại tơ khác (tơ bền, tơ chậm hơn) = thêm file .tres, không sửa code.

@export_group("Entangle")
## Tốc độ chạy còn lại khi dính tơ so với bình thường (0.3 = giảm 70%)
@export_range(0.05, 1.0, 0.01) var speed_scale: float = 0.3
## Dính tơ thì không dash được (các kỹ năng khác vẫn dùng)
@export var lock_dash: bool = true

@export_group("Break")
## Số nhát chém để xé tơ (mỗi nhát trừ 1 máu của tơ). Lửa phá ngay, không đếm
@export_range(1, 20) var hits_to_break: int = 4
## Thời gian tơ co lại rồi biến mất khi bị phá (s)
@export_range(0.05, 2.0, 0.05) var vanish_time: float = 0.35

@export_group("Patch")
## Bán kính tấm tơ (m): player bước vào là dính
@export_range(0.3, 4.0, 0.05) var radius: float = 1.0
## Số tấm tơ tối đa cùng lúc trong màn; thêm tấm mới thì tấm cũ nhất chưa dính ai bị gỡ
@export_range(1, 20) var max_patches: int = 6

@export_group("Bolt")
## Tốc độ đạn tơ (m/s). Mỗi frame đi (speed / 60) m phải nhỏ hơn đường kính hitbox kẻo xuyên vật mỏng
@export var bolt_speed: float = 9.0
## Bay tối đa rồi rớt thành tấm tơ trên sàn (s)
@export var bolt_lifetime: float = 1.6
## Bán kính hitbox đạn (m)
@export var bolt_radius: float = 0.3
