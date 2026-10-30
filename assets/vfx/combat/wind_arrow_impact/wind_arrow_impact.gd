class_name WindArrowImpact
extends ArrowImpact
## Hiệu ứng trúng của tên gió: như ArrowImpact (chớp sáng, vòng sóng, lưỡi gió văng ra)
## thêm một quả cầu sóng gió bung to rồi tắt dần.

## Lùi cả hiệu ứng khỏi bề mặt bị trúng (m, nhân impact scale) để chớp sáng và quả cầu không bị tường cắt mất nửa
@export var surface_offset: float = 0.35

@export_group("Shell")
## Đường kính quả cầu lúc bung hết (m)
@export var shell_size: float = 2.0
## Cỡ lúc bắt đầu so với cỡ tối đa (0..1)
@export_range(0.0, 1.0) var shell_start_ratio: float = 0.25
@export var shell_grow_time: float = 0.1
@export var shell_time: float = 0.32
@export var shell_intensity: float = 1.1

@onready var _shell: MeshInstance3D = $Shell
@onready var _shell_material: ShaderMaterial = _shell.material_override as ShaderMaterial


func play(world_position: Vector3, direction: Vector3, effect_scale: float = 1.0) -> void:
	var back := -direction.normalized() if direction.length_squared() > 0.0001 else Vector3.ZERO
	super.play(world_position + back * surface_offset * maxf(effect_scale, 0.01), direction, effect_scale)
	_end_time = maxf(_end_time, shell_time)
	_shell.visible = true
	_apply(0.0)


func _apply(age: float) -> void:
	super._apply(age)
	if _shell == null:
		return
	var grow := _ease_out(clampf(age / maxf(shell_grow_time, 0.001), 0.0, 1.0))
	var fade := 1.0 - clampf((age - shell_grow_time) / maxf(shell_time - shell_grow_time, 0.001), 0.0, 1.0)
	# SphereMesh bán kính 0.5 = đường kính 1 m, nên scale = đường kính mong muốn
	_shell.scale = Vector3.ONE * shell_size * _scale * lerpf(shell_start_ratio, 1.0, grow)
	_shell_material.set_shader_parameter(&"intensity", shell_intensity * fade)
	_shell.visible = age < shell_time
