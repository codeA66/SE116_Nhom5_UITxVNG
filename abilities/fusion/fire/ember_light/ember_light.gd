class_name EmberLight
extends Node3D
## Đốm lửa còn cháy lại chỗ mũi tên lửa cắm: sáng life giây rồi tắt dần trong fade_time (soi đường trong phòng tối).
## Lấy từ object pool: play() bật, hết giờ phát finished để pool thu về. Không có _process: dùng một Tween.

signal finished

var _tween: Tween

@onready var _light: OmniLight3D = $Light
@onready var _ember: MeshInstance3D = $Ember


## Bật tại point: sáng energy, tầm range trong life giây, rồi tắt dần trong fade_time giây
func play(point: Vector3, life: float, fade_time: float, energy: float, light_range: float) -> void:
	if _tween:
		_tween.kill()
	global_position = point
	_light.omni_range = light_range
	_light.light_energy = energy
	_ember.scale = Vector3.ONE
	show()
	# Chờ (life - fade_time) rồi mới tắt dần đèn + co đốm cùng lúc, xong thì báo pool
	_tween = create_tween()
	_tween.tween_interval(maxf(life - fade_time, 0.0))
	_tween.tween_property(_light, ^"light_energy", 0.0, maxf(fade_time, 0.01))
	_tween.parallel().tween_property(_ember, ^"scale", Vector3.ONE * 0.05, maxf(fade_time, 0.01))
	_tween.tween_callback(_done)


func is_lit() -> bool:
	return visible and _light.light_energy > 0.0


func _done() -> void:
	hide()
	finished.emit()


## Pool nhả slot (đổi khu...): tắt hẳn
func pool_released() -> void:
	if _tween:
		_tween.kill()
	hide()
