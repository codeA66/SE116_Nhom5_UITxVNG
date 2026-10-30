class_name ShockwaveData
extends Resource
## Thông số một sóng kích lan trên mặt đất. Quái / boss khác dùng lại bằng file .tres riêng.

@export_group("Damage")
@export var damage: int = 1
@export var damage_type: DamageInfo.Type = DamageInfo.Type.PHYSICAL
@export var knockback: float = 7.0
## Bỏ qua bất tử (dash). Mặc định không: dash xuyên qua sóng được
@export var ignore_invincibility: bool = false

@export_group("Shape")
## Bán kính lúc bắt đầu (m)
@export var start_radius: float = 0.6
## Mép ngoài của vành sóng dừng ở bán kính này (m): xa hơn mức này (cộng bán kính hurtbox) là an toàn
@export var max_radius: float = 6.0
## Tốc độ lan (m/s)
@export var speed: float = 7.0
## Độ dày vành sóng (m)
@export var band_width: float = 0.6
## Chân mục tiêu cao hơn mặt đất nơi đập quá mức này thì né được (nhảy, bục cao) (m)
@export var hit_height: float = 0.45
## Chân mục tiêu thấp hơn mặt đất nơi đập quá mức này thì không trúng (m)
@export var hit_height_below: float = 1.0

@export_group("Rules")
## Tường / vật thể thế giới chắn sóng (không trúng xuyên tường)
@export var blocked_by_world: bool = true
@export_flags_3d_physics var world_mask: int = 1
