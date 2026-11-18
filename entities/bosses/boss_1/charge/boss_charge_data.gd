class_name BossChargeData
extends Resource
## Dữ liệu chiêu húc, dùng chung giữa state, bộ chọn chiêu và chỉ thị.

@export_group("Điều kiện chọn")
@export var enabled: bool = true
@export_range(1, 3) var first_phase: int = 1
@export var allow_while_shielded: bool = false
@export_range(0.0, 1.0) var selection_chance: float = 0.45
@export var minimum_range: float = 4.0
@export var maximum_range: float = 12.0
@export var cooldown_by_phase: PackedFloat32Array = PackedFloat32Array([10.0, 8.0, 6.0])
@export_group("Chuyển động")
@export_range(0.01, 10.0, 0.01, "or_greater") var warning_duration: float = 0.9
@export_range(0.01, 100.0, 0.1, "or_greater") var speed: float = 16.0
@export_range(0.01, 100.0, 0.1, "or_greater") var distance: float = 10.0
@export_range(0.01, 10.0, 0.01, "or_greater") var recovery_duration: float = 0.65
@export var stop_at_ledge: bool = true
@export var ledge_probe_height: float = 0.5
@export var ledge_probe_depth: float = 2.0
@export var stop_on_player_hit: bool = false
@export_group("Va chạm")
@export var attack: AttackData
@export var hitbox_size: Vector3 = Vector3(2.4, 3.0, 1.8)
@export var hitbox_center: Vector3 = Vector3(0.0, 1.5, 0.5)
@export_group("Animation")
@export var animation: StringName = &"Charge"
@export var launch_time: float = 0.4
@export var rush_end_time: float = 2.2
@export var blend_in: float = 0.12

func get_cooldown(phase: int) -> float:
	if cooldown_by_phase.is_empty():
		return 0.0
	return maxf(cooldown_by_phase[clampi(phase - 1, 0, cooldown_by_phase.size() - 1)], 0.0)
