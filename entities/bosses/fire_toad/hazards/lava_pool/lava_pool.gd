class_name LavaPool
extends Node3D
## Vũng dung nham (Dậm Dung Nham của Ếch Hoả Vương): đứng trong bị đốt mất máu theo nhịp DamageArea, tồn tại vài giây
## rồi nguội tắt. Lộn (bất tử) qua thì không mất máu, giống mọi vùng sát thương khác.
## Dùng với ObjectPool: xong việc phát finished. Không có _process: chạy bằng tween.

signal finished(pool: LavaPool)

const LavaPoolVfx = preload("res://assets/vfx/enemies/fire/fire_toad/lava/lava_pool_vfx.gd")

## Thời gian loang ra và nguội tắt (s)
@export_range(0.05, 3.0, 0.05) var spread_time: float = 0.25
@export_range(0.05, 3.0, 0.05) var fade_time: float = 0.5

var _tween: Tween

@onready var _vfx: LavaPoolVfx = $Vfx
@onready var _damage: DamageArea = $DamageArea
@onready var _damage_shape: CollisionShape3D = $DamageArea/CollisionShape3D


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	_reset()


func activate(where: Vector3, radius: float, lifetime: float, enraged: bool = false) -> void:
	_reset()
	visible = true
	global_position = where
	reset_physics_interpolation()
	(_damage_shape.shape as CylinderShape3D).radius = radius
	_vfx.play(radius, lifetime, spread_time, fade_time, enraged)
	_damage.set_active(true)
	_tween = create_tween()
	_tween.tween_interval(spread_time)
	_tween.tween_interval(maxf(lifetime - spread_time - fade_time, 0.0))
	_tween.tween_callback(_damage.set_active.bind(false))
	_tween.tween_interval(fade_time)
	_tween.tween_callback(_finish)


func pool_released() -> void:
	_reset()
	visible = false


func _finish() -> void:
	_vfx.reset()
	finished.emit(self)


func _reset() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_vfx.reset()
	_damage.set_active(false)
