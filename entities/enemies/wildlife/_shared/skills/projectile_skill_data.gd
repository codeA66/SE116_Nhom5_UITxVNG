class_name ProjectileSkillData
extends EnemySkillData
## release_time tính theo đồng hồ đòn; tốc độ đạn tính theo tốc độ chạy của mục tiêu lúc bắn.
@export var projectile_scene: PackedScene
@export var held_visual_scene: PackedScene
@export var hand_bone: StringName
@export var held_scale: float = 1.0
@export var release_time: float = 0.7
@export var projectile_speed_ratio: float = 1.5
@export var flight_lifetime: float = 3.0
@export var launch_height: float = 1.0
@export var launch_forward: float = 0.65
