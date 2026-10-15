class_name AttackData
extends Resource
## Dữ liệu một đòn đánh. Mọi mốc thời gian tính bằng giây thực, từ lúc bắt đầu đòn.

@export_group("Animation")
@export var animation: StringName
@export var anim_speed: float = 1.0

@export_group("Damage")
@export var damage: int = 1
@export var damage_type: DamageInfo.Type = DamageInfo.Type.PHYSICAL
@export var knockback: float = 5.0
@export var hitstop: float = 0.05

@export_group("Timing")
## Hitbox bật trong khoảng [active_start, active_end)
@export var active_start: float = 0.15
@export var active_end: float = 0.3
## Từ mốc này có thể nối sang đòn tiếp theo trong combo
@export var combo_window_start: float = 0.3
## Từ mốc này có thể hủy đòn bằng dash (dùng khi có Dash)
@export var cancel_start: float = 0.3
## Tổng thời gian đòn, hết thì trở về Idle/Run
@export var duration: float = 0.5

@export_group("Movement")
## Lao nhẹ về trước khi ra đòn
@export var lunge_speed: float = 4.0
@export var lunge_time: float = 0.12
