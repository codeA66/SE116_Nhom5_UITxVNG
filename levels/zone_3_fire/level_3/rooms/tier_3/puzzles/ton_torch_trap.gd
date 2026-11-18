class_name TonTorchTrap
extends StaticBody3D
## Sàn chỉ rung khi player thắp đuốc. Mặt sàn và va chạm rơi cùng một nhịp.

@export var torch: TonFlameStation
@export_range(0.1, 10.0, 0.05) var warning_time: float = 2.7
@export_range(0.1, 1.5, 0.05) var drop_time: float = 0.45
@export_range(1.0, 20.0, 0.1) var drop_distance: float = 6.5
@export_range(0.0, 0.3, 0.01) var shake_distance: float = 0.08

var _torch_home: Vector3
var _elapsed: float = 0.0
var _spent: bool = false
var _drop: Tween

@onready var _visual: Node3D = $Visual
@onready var _floor: CollisionShape3D = $FloorCollision
@onready var _end: CollisionShape3D = $EndCollision


func _ready() -> void:
	if torch:
		_torch_home = torch.position
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= warning_time:
		_collapse()
		return
	var strength := lerpf(0.2, 1.0, _elapsed / warning_time) * shake_distance
	_visual.position.x = sin(_elapsed * 72.0) * strength
	_visual.position.z = sin(_elapsed * 51.0) * strength


func arm() -> void:
	if _spent:
		return
	_spent = true
	_elapsed = 0.0
	set_physics_process(true)


func reset() -> void:
	set_physics_process(false)
	if _drop:
		_drop.kill()
		_drop = null
	_spent = false
	_visual.position = Vector3.ZERO
	_visual.show()
	_visual.reset_physics_interpolation()
	_floor.set_deferred(&"disabled", false)
	_end.set_deferred(&"disabled", false)
	if torch:
		torch.position = _torch_home
		torch.show()
		torch.reset_physics_interpolation()


func _collapse() -> void:
	set_physics_process(false)
	_floor.set_deferred(&"disabled", true)
	_end.set_deferred(&"disabled", true)
	_drop = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).set_parallel()
	_drop.tween_property(_visual, ^"position:y", -drop_distance, drop_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if torch:
		_drop.tween_property(torch, ^"position:y", _torch_home.y - drop_distance, drop_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_drop.chain().tween_callback(_hide_fallen)


func _hide_fallen() -> void:
	_visual.hide()
	if torch:
		torch.hide()
