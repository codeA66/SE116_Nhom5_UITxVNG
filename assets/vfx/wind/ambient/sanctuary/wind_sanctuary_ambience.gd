extends Node3D
## Đồng bộ nhịp lụa và chuông bằng một đồng hồ chung, để cơn gió đi qua cả điện thờ.

const CYCLE: StringName = &"storm_cycle"
const CLOTH_CULL_MARGIN: float = 1.4

@export_group("Điện thờ")
@export var shrine: Node3D
@export var storm_vault: MeshInstance3D
@export var silk_material: ShaderMaterial
@export var storm_material: ShaderMaterial

@export_group("Cơn gió")
@export_range(2.0, 60.0, 0.1) var cycle_seconds: float = 6.0
@export_range(0.0, 15.0, 0.1) var bell_sway_degrees: float = 6.5

var _bells: Array[Node3D] = []
var _silk: ShaderMaterial
var _gust_phase: float = 0.0:
	set(value):
		_gust_phase = value
		_apply_gust(value)

@onready var _motion: AnimationPlayer = $Motion


func _ready() -> void:
	if shrine == null or storm_vault == null or silk_material == null or storm_material == null:
		push_warning("Thiếu node hoặc material cho gió điện thờ.")
		return

	_silk = silk_material.duplicate() as ShaderMaterial
	for child: Node in shrine.get_children():
		if child is MeshInstance3D and child.name.begins_with("TornSilk_"):
			var cloth: MeshInstance3D = child as MeshInstance3D
			cloth.material_override = _silk
			# Đuôi lụa có thể vươn ra ngoài hộp bao gốc ở rìa camera.
			cloth.extra_cull_margin = CLOTH_CULL_MARGIN
		elif child is Node3D and child.name.begins_with("BellPivot_"):
			_bells.append(child as Node3D)
	storm_vault.material_override = storm_material

	# Clip dài một đơn vị để chỉnh chu kỳ mà không phải dời keyframe.
	_motion.speed_scale = 1.0 / maxf(cycle_seconds, 2.0)
	_motion.play(CYCLE)
	_apply_gust(0.0)


func _apply_gust(phase: float) -> void:
	if _silk == null:
		return
	_silk.set_shader_parameter(&"cycle_phase", phase)
	for index: int in range(_bells.size()):
		var delay: float = float(index) * 0.035
		var bell_phase: float = fposmod(phase - delay, 1.0)
		var envelope: float = smoothstep(0.09, 0.31, bell_phase) * (1.0 - smoothstep(0.43, 0.76, bell_phase))
		# Hai nhịp mỗi vòng 6 giây để chuông giữ tốc độ đung đưa cũ.
		var swing: float = sin(TAU * (bell_phase * 2.0 + delay))
		_bells[index].rotation_degrees.z = bell_sway_degrees * (0.12 + 0.88 * envelope) * swing
