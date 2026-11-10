class_name GardenLiftGate
extends Node3D
## Mỗi phòng giữ một khóa riêng; phòng bên cạnh không vô tình mở cửa đang bị khóa.
@export var open_height: float = 7.2
@export var close_time: float = 0.28
@export var open_time: float = 0.65
var _locks: Dictionary[Node,bool] = {}
var _tween: Tween
@onready var core: Node3D = $Core
@onready var collision: CollisionShape3D = $Blocker/CollisionShape3D

func _ready() -> void:
	core.position.y = open_height
	core.show()
	collision.disabled = true
	set_process(false); set_physics_process(false)

func set_locked(source: Node, locked: bool) -> void:
	if locked: _locks[source] = true
	else: _locks.erase(source)
	if _tween: _tween.kill()
	_tween = create_tween()
	core.show()
	if not _locks.is_empty():
		_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_tween.tween_property(core,"position:y",0.0,close_time)
		_tween.tween_callback(_slam)
	else:
		collision.set_deferred("disabled",true)
		_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tween.tween_property(core,"position:y",open_height,open_time)

func is_locked() -> bool:
	return not _locks.is_empty()

func _slam() -> void:
	if _locks.is_empty(): return
	collision.set_deferred("disabled",false)
	ScreenShake.add_trauma(0.08)
