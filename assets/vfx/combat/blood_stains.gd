class_name BloodStains
extends Node3D
## Vết máu trên sàn: số vết cố định (max_stains), vết cũ nhất bị tái dùng nên không tích tụ.
## Mỗi vết là một quad phẳng sát đất với shader loang mép sắc. Dùng quad thay vì Decal: Decal chỉ có ở
## Forward+/Mobile, project dùng Compatibility (docs.godotengine.org, lớp Decal ghi rõ không hỗ trợ Compatibility).
## _process chỉ chạy khi còn vết đang bung / mờ.

@export var stain_shader: Shader = preload("res://assets/shaders/blood_stain.gdshader")
@export var max_stains: int = 24

@export_group("Timing")
## Thời gian vết bung ra (s)
@export var appear_time: float = 0.12
## Thời gian tồn tại đầy đủ trước khi bắt đầu mờ (s)
@export var hold_time: float = 4.0
@export var fade_time: float = 1.5

## Nâng vết khỏi mặt đất để khỏi z-fight (m)
const LIFT := 0.03

var _stains: Array[Stain] = []
var _next: int = 0
var _active_count: int = 0


## Một vết: mesh + material riêng (uniform khác nhau mỗi vết)
class Stain extends RefCounted:
	var mesh: MeshInstance3D
	var material: ShaderMaterial
	var age: float = 0.0
	var delay: float = 0.0
	var active: bool = false


func _ready() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	for i in max_stains:
		var stain := Stain.new()
		stain.material = ShaderMaterial.new()
		stain.material.shader = stain_shader
		stain.mesh = MeshInstance3D.new()
		stain.mesh.mesh = plane
		stain.mesh.material_override = stain.material
		stain.mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		stain.mesh.visible = false
		add_child(stain.mesh)
		_stains.append(stain)
	set_process(false)


func _process(delta: float) -> void:
	for stain in _stains:
		if not stain.active:
			continue
		stain.age += delta
		var life := stain.age - stain.delay
		if life < 0.0:
			continue
		stain.mesh.visible = true
		stain.material.set_shader_parameter(&"progress", clampf(life / appear_time, 0.0, 1.0))
		var fade := clampf((life - hold_time) / maxf(fade_time, 0.0001), 0.0, 1.0)
		stain.material.set_shader_parameter(&"fade", fade)
		if fade >= 1.0:
			_deactivate(stain)
	if _active_count <= 0:
		set_process(false)


## world_position: điểm trên sàn; size: đường kính (m); delay: chờ giọt rơi tới nơi (s)
func add_stain(world_position: Vector3, size: float, color: Color, delay: float = 0.0, satellites: float = 3.0) -> void:
	if _stains.is_empty():
		return
	var stain := _stains[_next]
	_next = (_next + 1) % _stains.size()
	if not stain.active:
		_active_count += 1
	stain.active = true
	stain.age = 0.0
	stain.delay = maxf(delay, 0.0)
	stain.mesh.global_position = Vector3(world_position.x, world_position.y + LIFT, world_position.z)
	stain.mesh.scale = Vector3(size, 1.0, size)
	stain.mesh.visible = false
	stain.material.set_shader_parameter(&"color", color)
	stain.material.set_shader_parameter(&"seed", randf())
	stain.material.set_shader_parameter(&"progress", 0.0)
	stain.material.set_shader_parameter(&"fade", 0.0)
	stain.material.set_shader_parameter(&"satellites", satellites)
	set_process(true)


func get_active_count() -> int:
	return _active_count


func get_capacity() -> int:
	return _stains.size()


func clear() -> void:
	for stain in _stains:
		if stain.active:
			_deactivate(stain)
	set_process(false)


func _deactivate(stain: Stain) -> void:
	stain.active = false
	stain.mesh.visible = false
	_active_count -= 1
