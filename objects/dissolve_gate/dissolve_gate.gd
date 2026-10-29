@tool
class_name DissolveGate
extends StaticBody3D
## Phong ấn nghe nguồn activated/is_active; tan hết mới bỏ va chạm.
## reveal_flag giúp cửa ở khu cũ diễn hiệu ứng đúng một lần khi player trở về.

signal unlock_started
signal opened

@export var source: Node
@export var size: Vector3 = Vector3(4.0, 4.2, 0.55):
	set(value):
		size = value.max(Vector3(0.2, 0.2, 0.1))
		_apply_size()
## Cao hơn hình cửa để double jump không vượt phong ấn.
@export_range(1.0, 20.0, 0.1) var collision_height: float = 8.0:
	set(value):
		collision_height = maxf(value, 1.0)
		_apply_size()
@export_range(0.1, 5.0, 0.05) var dissolve_time: float = 1.6
@export var reveal_flag: StringName
@export var focus_camera_on_open: bool = false
@export_range(0.0, 5.0, 0.1) var camera_hold: float = 2.0
@export_range(0.0, 1.0, 0.01) var open_trauma: float = 0.12

var is_open: bool = false
var _opening: bool = false
var _material: ShaderMaterial

@onready var _barrier: MeshInstance3D = $Barrier
@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var _motes: GPUParticles3D = $Motes


func _ready() -> void:
	_apply_size()
	set_process(false)
	set_physics_process(false)
	if Engine.is_editor_hint():
		return
	# Mỗi cửa có tiến độ tan riêng, không sửa material chung của scene.
	_material = _barrier.material_override.duplicate() as ShaderMaterial
	_barrier.material_override = _material
	_material.set_shader_parameter(&"gate_size", size)
	if source == null or not source.has_signal(&"activated") or not source.has_method(&"is_active"):
		push_error("%s: cần nguồn activated/is_active cho phong ấn" % get_path())
		return
	if bool(source.call(&"is_active")):
		if reveal_flag.is_empty() or GameState.has_flag(reveal_flag):
			_finish_open(false)
		else:
			open()
	else:
		source.connect(&"activated", open, CONNECT_ONE_SHOT)


func open() -> void:
	if is_open or _opening:
		return
	_opening = true
	# Child _ready chạy trước ZoneRoot: chờ màn tải rút hết để người chơi thấy cửa tan.
	var ancestor: Node = get_parent()
	while ancestor != null and not ancestor is ZoneRoot:
		ancestor = ancestor.get_parent()
	var zone := ancestor as ZoneRoot
	if zone != null and not zone.is_combat_ready():
		await zone.combat_ready
	if not is_inside_tree():
		return
	unlock_started.emit()
	if focus_camera_on_open:
		var rig := get_tree().get_first_node_in_group(CameraRig.GROUP) as CameraRig
		if rig:
			rig.peek_at(global_position + Vector3.UP * size.y * 0.4, camera_hold)
	ScreenShake.add_trauma(open_trauma)
	_motes.restart()
	_motes.emitting = true
	var tween := create_tween()
	tween.tween_method(_set_dissolve, 0.0, 1.0, dissolve_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(_finish_open.bind(true))


func _apply_size() -> void:
	var barrier := get_node_or_null(^"Barrier") as MeshInstance3D
	var collision := get_node_or_null(^"CollisionShape3D") as CollisionShape3D
	var motes := get_node_or_null(^"Motes") as GPUParticles3D
	if barrier:
		(barrier.mesh as BoxMesh).size = size
		barrier.position.y = size.y * 0.5
		var material := barrier.material_override as ShaderMaterial
		if material:
			material.set_shader_parameter(&"gate_size", size)
	if collision:
		var height := maxf(size.y, collision_height)
		(collision.shape as BoxShape3D).size = Vector3(size.x, height, size.z)
		collision.position.y = height * 0.5
	if motes:
		motes.position.y = size.y * 0.5
		(motes.process_material as ParticleProcessMaterial).emission_box_extents = size * Vector3(0.48, 0.45, 0.6)
		motes.visibility_aabb = AABB(Vector3(-size.x, -size.y, -3.0), Vector3(size.x * 2.0, size.y * 2.0 + 4.0, 6.0))
	if _material:
		_material.set_shader_parameter(&"gate_size", size)


func _set_dissolve(value: float) -> void:
	_material.set_shader_parameter(&"dissolve", value)


func _finish_open(remember: bool) -> void:
	is_open = true
	_opening = false
	_barrier.hide()
	_collision.set_deferred(&"disabled", true)
	if remember and not reveal_flag.is_empty():
		GameState.set_flag(reveal_flag)
	opened.emit()
