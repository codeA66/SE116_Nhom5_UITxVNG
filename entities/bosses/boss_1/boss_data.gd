class_name BossData
extends Resource
## Thông số cấu hình của Boss 1 (Ngưu Vương Huyết Diệm). Không hard-code số ma thuật.

@export_group("General")
@export var display_name: String = "Ngưu Vương Huyết Diệm"
@export var max_health: int = 20

@export_group("Health Gates")
@export_range(0.01, 1.0) var phase2_health_ratio: float = 0.5
@export_range(0.01, 1.0) var phase3_health_ratio: float = 0.2
@export_range(0.01, 1.0) var phase3_recovery_ratio: float = 0.4

@export_group("Movement")
@export var walk_speed_phase1: float = 3.2
@export var walk_speed_phase2: float = 4.2
@export var walk_speed_phase3: float = 5.6

@export_group("I-Frames")
## I-Frame sau mỗi lần trúng đòn ở Phase 1 & 2 (s)
@export var iframe_duration_normal: float = 0.6

@export_group("Jump Slam")
@export var jump_slam_min_range: float = 5.0
@export var jump_slam_max_range: float = 14.0
@export var jump_slam_cooldown_phase1: float = 5.0
@export var jump_slam_cooldown_phase2: float = 3.5
@export var jump_slam_cooldown_phase3: float = 2.2

@export_group("Fireball")
@export var fireball_cooldown_phase1: float = 3.5
@export var fireball_cooldown_phase2: float = 3.5
@export var fireball_cooldown_phase3: float = 10.0

@export_group("Magma Stomp Attack")
@export var magma_stomp_cooldown_phase1: float = 8.0
@export var magma_stomp_cooldown_phase2: float = 6.0
@export var magma_stomp_cooldown_phase3: float = 4.0
@export var magma_stomp_min_range: float = 2.0
@export var magma_stomp_max_range: float = 9.0

@export_group("Buff & Multipliers")
@export var damage_multiplier_phase3: int = 2
@export var anim_speed_phase1: float = 1.0
@export var anim_speed_phase2: float = 1.2
@export var anim_speed_phase3: float = 1.4


## Giữ tên trường cũ để các Resource/Inspector hiện tại không cần đổi cấu trúc.
func get_phase_value(property: StringName, phase: int) -> float:
	return float(get(StringName("%s_phase%d" % [property, clampi(phase, 1, 3)])))
