class_name BossData
extends Resource
## Thông số cấu hình của Boss 1 (Dị Thú Tha Hoá). Không hard-code số ma thuật.

@export_group("General")
@export var display_name: String = "Dị Thú Tha Hoá"
@export var max_health: int = 20

@export_group("Movement")
@export var walk_speed_phase1: float = 3.2
@export var walk_speed_phase2: float = 4.2
@export var walk_speed_phase3: float = 5.6
@export var rotation_speed: float = 8.0

@export_group("I-Frames")
## I-Frame sau mỗi lần trúng đòn ở Phase 1 & 2 (s)
@export var iframe_duration_normal: float = 0.6

@export_group("Melee Attack")
@export var melee_range: float = 3.2
@export var melee_damage: int = 1
@export var melee_knockback: float = 8.0
@export var melee_cooldown_phase1: float = 1.4
@export var melee_cooldown_phase2: float = 0.9
@export var melee_cooldown_phase3: float = 0.5

@export_group("Jump Slam")
@export var jump_slam_min_range: float = 5.0
@export var jump_slam_max_range: float = 14.0
@export var jump_slam_damage: int = 1
@export var jump_slam_cooldown_phase1: float = 5.0
@export var jump_slam_cooldown_phase2: float = 3.5
@export var jump_slam_cooldown_phase3: float = 2.2

@export_group("Fireball")
@export var fireball_speed: float = 9.0
@export var fireball_reflected_speed: float = 18.0
@export var fireball_damage: int = 1
@export var fireball_cooldown_phase1: float = 3.5
@export var fireball_cooldown_phase2: float = 3.5
@export var fireball_cooldown_phase3: float = 10.0

@export_group("Buff & Multipliers")
@export var damage_multiplier_phase3: int = 2
@export var anim_speed_phase1: float = 1.0
@export var anim_speed_phase2: float = 1.2
@export var anim_speed_phase3: float = 1.4

@export_group("Stun")
@export var stun_duration_phase1: float = 2.5
@export var stun_duration_phase2: float = 3.0
