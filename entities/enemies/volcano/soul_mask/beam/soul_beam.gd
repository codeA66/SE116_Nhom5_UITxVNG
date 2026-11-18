class_name SoulBeam
extends Node3D
## Tia của Đầu Lửa: vạch cảnh báo lúc tụ lực, tia sáng + vùng sát thương lúc bắn.
## Đặt top_level để không xoay theo model. Độ dài cắt ở vật cản đầu tiên (một tia ray mỗi lần đặt hướng).
## Hiệu năng: vùng sát thương chỉ bật monitoring trong lúc bắn; material / shape tạo một lần.

signal fired(from: Vector3, to: Vector3)
signal ended

var _data: SoulBeamData
var _query: PhysicsRayQueryParameters3D
var _from: Vector3
var _dir: Vector3 = Vector3.FORWARD
var _length: float = 0.0
var _firing: bool = false
var _grow_tween: Tween
var _flash_on: bool = false

@onready var _warn: MeshInstance3D = $Warn
@onready var _core: MeshInstance3D = $Core
@onready var _damage_area: DamageArea = $DamageArea
@onready var _damage_shape: CollisionShape3D = $DamageArea/CollisionShape3D


func _ready() -> void:
	top_level = true
	_query = PhysicsRayQueryParameters3D.new()
	_warn.visible = false
	_core.visible = false
	_damage_area.set_deferred(&"monitoring", false)


## Gán thông số, đòn đánh và thân bỏ qua khi bắn tia ray (chính con quái)
func setup(data: SoulBeamData, attack: AttackData, exclude: Array[RID]) -> void:
	_data = data
	_query.collision_mask = data.blocking_mask
	_query.exclude = exclude
	_damage_area.damage = attack.damage
	_damage_area.damage_type = attack.damage_type
	_damage_area.knockback = attack.knockback
	# Mỗi lần bắn chỉ trúng một lần
	_damage_area.hit_interval = data.fire_time + 1.0
	(_warn.material_override as StandardMaterial3D).albedo_color = data.warn_color
	(_core.material_override as StandardMaterial3D).albedo_color = data.beam_color


## Đặt gốc và hướng; trả về điểm cuối sau khi cắt ở vật cản
func aim(from: Vector3, direction: Vector3) -> Vector3:
	_from = from
	_dir = direction.normalized() if not direction.is_zero_approx() else Vector3.FORWARD
	_query.from = from
	_query.to = from + _dir * _data.max_length
	var hit := get_world_3d().direct_space_state.intersect_ray(_query)
	_length = from.distance_to(hit["position"] as Vector3) if not hit.is_empty() else _data.max_length
	_length = maxf(_length, 0.05)
	return end_point()


func end_point() -> Vector3:
	return _from + _dir * _length


func show_warning(from: Vector3, direction: Vector3) -> void:
	aim(from, direction)
	var w := _data.width * 0.5 * (_data.lock_flash_scale if _flash_on else 1.0)
	_warn.global_transform = _segment(w, 0.05)
	_warn.visible = true


func hide_warning() -> void:
	_warn.visible = false
	set_warning_flash(false)


## Chớp trắng vạch cảnh báo (lúc khoá hướng): đổi màu + phình rộng; false = về màu cảnh báo thường
func set_warning_flash(on: bool) -> void:
	if _data == null:
		return
	(_warn.material_override as StandardMaterial3D).albedo_color = _data.lock_color if on else _data.warn_color
	_flash_on = on


func fire(from: Vector3, direction: Vector3) -> void:
	aim(from, direction)
	hide_warning()
	_firing = true
	_core.visible = true
	_core.global_transform = _segment(0.05, 0.05)
	if _grow_tween:
		_grow_tween.kill()
	_grow_tween = create_tween()
	_grow_tween.tween_method(_set_core_width, 0.05, _data.width, maxf(_data.grow_time, 0.001))
	var box := _damage_shape.shape as BoxShape3D
	box.size = Vector3(_data.width, _data.width, _length)
	_damage_area.global_transform = Transform3D(_look_basis(), _from + _dir * _length * 0.5)
	_damage_area.set_deferred(&"monitoring", true)
	fired.emit(_from, end_point())


func stop() -> void:
	hide_warning()
	if _grow_tween:
		_grow_tween.kill()
	_core.visible = false
	_damage_area.set_deferred(&"monitoring", false)
	if _firing:
		_firing = false
		ended.emit()


func is_firing() -> bool:
	return _firing


func get_length() -> float:
	return _length


func _set_core_width(w: float) -> void:
	_core.global_transform = _segment(w, w)


## Hộp đơn vị kéo dài từ _from theo _dir: rộng w, cao h, dài _length
func _segment(w: float, h: float) -> Transform3D:
	var b := _look_basis()
	b = Basis(b.x * w, b.y * h, b.z * _length)
	return Transform3D(b, _from + _dir * _length * 0.5)


func _look_basis() -> Basis:
	var up := Vector3.UP if absf(_dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	return Basis.looking_at(_dir, up)
