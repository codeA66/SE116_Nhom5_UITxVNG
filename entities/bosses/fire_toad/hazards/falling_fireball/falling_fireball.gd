class_name FallingFireball
extends Node3D
## Quả cầu lửa rơi từ trời (Mưa Hoả Cầu của Ếch Hoả Vương): vòng báo trên sàn hiện trước, cầu lửa rơi xuống đúng vòng
## lúc hết giờ báo, nổ gây sát thương một lần trong bán kính. Lộn (bất tử) lúc nổ thì không mất máu.
## Dùng với ObjectPool: không queue_free, xong việc phát finished để chủ trả về pool. Không có _process: chạy bằng tween.

signal finished(fireball: FallingFireball)

const FallingFireballVfx = preload("res://assets/vfx/enemies/fire/fire_toad/rain/falling_fireball_vfx.gd")

## Cầu lửa bắt đầu rơi từ độ cao này trên điểm rơi (m)
@export_range(1.0, 60.0, 0.5) var fall_height: float = 14.0
## Thời gian rơi (s), nằm trong thời gian báo: cầu lửa xuất hiện ở cuối thời gian báo
@export_range(0.05, 3.0, 0.05) var fall_time: float = 0.35
## Vùng nổ bật bao lâu để chắc bắt được người đứng trong (s)
@export_range(0.02, 1.0, 0.01) var blast_active_time: float = 0.1
## Thời gian loé nổ (s)
@export_range(0.05, 2.0, 0.05) var flash_time: float = 0.3
@export_range(0.0, 1.0, 0.01) var impact_trauma: float = 0.12

var _tween: Tween

@onready var _vfx: FallingFireballVfx = $Vfx
@onready var _damage: DamageArea = $DamageArea
@onready var _damage_shape: CollisionShape3D = $DamageArea/CollisionShape3D


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	_reset()


## Rơi xuống target sau warn_time giây, nổ bán kính radius
func launch(target: Vector3, warn_time: float, radius: float, enraged: bool = false) -> void:
	_reset()
	visible = true
	global_position = target
	reset_physics_interpolation()
	(_damage_shape.shape as SphereShape3D).radius = radius
	_vfx.warn(radius, warn_time, enraged)
	var fall := minf(fall_time, warn_time)
	_tween = create_tween()
	_tween.tween_interval(maxf(warn_time - fall, 0.0))
	_tween.tween_callback(_start_fall)
	_tween.tween_property(_vfx.falling, ^"position", Vector3.ZERO, fall).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_tween.tween_callback(_explode)
	_tween.tween_interval(blast_active_time)
	_tween.tween_callback(_damage.set_active.bind(false))
	_tween.tween_interval(maxf(flash_time - blast_active_time, 0.0))
	_tween.tween_callback(_finish)


func pool_released() -> void:
	_reset()
	visible = false


func _start_fall() -> void:
	_vfx.start_fall(fall_height)


func _explode() -> void:
	_damage.set_active(true)
	ScreenShake.add_trauma(impact_trauma)
	_vfx.burst(flash_time)


func _finish() -> void:
	_vfx.reset()
	finished.emit(self)


func _reset() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_vfx.reset()
	_damage.set_active(false)
