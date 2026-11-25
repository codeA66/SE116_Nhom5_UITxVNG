class_name FireRainAimVfx
extends Node3D
## Vạch ngắm Mưa Hỏa Tiễn trên mặt sàn: state FireRain gọi show_line() mỗi khung lúc đang ngắm.
## Thả phím: sáng bừng rồi tắt (commit); hủy (dash / bị đánh): xám rồi tắt (cancel).
## Chỉ chạy _process trong lúc đang mờ dần.

## Nâng vạch khỏi mặt sàn một chút (m)
@export_range(0.0, 0.5, 0.01) var lift: float = 0.04
@export_range(0.02, 1.0, 0.01) var commit_time: float = 0.18
@export_range(0.02, 1.0, 0.01) var cancel_time: float = 0.22

var _showing: bool = false
var _fade_clock: float = -1.0
var _fade_time: float = 0.2
var _just_shown: bool = false

@onready var _line: MeshInstance3D = $Line
@onready var _material: ShaderMaterial = _line.material_override as ShaderMaterial


func _ready() -> void:
	top_level = true
	_line.hide()
	set_process(false)


## Đúng khi vạch đang hiện để ngắm (không tính lúc đang mờ dần sau khi thả / hủy)
func is_showing() -> bool:
	return _showing


## Vẽ đường từ start dài length theo direction (ngang), rộng width
func show_line(start: Vector3, direction: Vector3, length: float, width: float) -> void:
	direction.y = 0.0
	if direction.is_zero_approx():
		return
	direction = direction.normalized()
	if not _showing:
		_showing = true
		_fade_clock = -1.0
		_material.set_shader_parameter(&"opacity", 1.0)
		_material.set_shader_parameter(&"commit", 0.0)
		_material.set_shader_parameter(&"cancel", 0.0)
		_line.show()
		_just_shown = true
		set_process(false)
	var center := start + direction * length * 0.5 + Vector3.UP * lift
	# PlaneMesh 1 x 1 nằm trên mặt XZ: trục X = bề ngang, trục Z = dọc đường (-Z hướng về cuối đường)
	var back := -direction
	var side := Vector3.UP.cross(back).normalized()
	global_transform = Transform3D(Basis(side * width, Vector3.UP, back * length), center)
	# Game bật physics interpolation: vừa hiện lại thì đặt thẳng chỗ mới, không trượt từ chỗ lần ngắm trước
	if _just_shown:
		reset_physics_interpolation()
		_just_shown = false
	_material.set_shader_parameter(&"size", Vector2(width, length))


## Thả phím: vạch sáng bừng rồi tắt
func commit() -> void:
	_start_fade(&"commit", commit_time)


## Hủy: vạch xám rồi tắt
func cancel() -> void:
	_start_fade(&"cancel", cancel_time)


func _process(delta: float) -> void:
	_fade_clock += delta
	var t := clampf(_fade_clock / _fade_time, 0.0, 1.0)
	_material.set_shader_parameter(&"opacity", 1.0 - t)
	if t >= 1.0:
		_fade_clock = -1.0
		_line.hide()
		set_process(false)


func _start_fade(flag: StringName, duration: float) -> void:
	if not _showing:
		return
	_showing = false
	_material.set_shader_parameter(flag, 1.0)
	_fade_time = duration
	_fade_clock = 0.0
	set_process(true)
