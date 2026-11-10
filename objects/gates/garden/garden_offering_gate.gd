@tool
class_name GardenOfferingGate
extends StoneGate
## Mỗi lá cửa và collider dùng chung bản lề, tách khỏi model scale không đều.
@export_range(20.0, 120.0, 1.0) var opening_degrees: float = 90.0
@export_range(0.1, 1.0, 0.05) var battle_close_time: float = 0.3
@export_range(0.0, 1.0, 0.05) var battle_close_trauma: float = 0.3
var _hinges: Array[AnimatableBody3D] = []
var _opening_tween: Tween
var _open_amount: float = 0.0
var _battle_locked: bool = false

func _ready() -> void:
	if Engine.is_editor_hint():
		super()
		return
	_make_hinge($Visual/OldGardenDoor/DoorLeaf_Left_004, true)
	_make_hinge($Visual/OldGardenDoor/DoorLeaf_Right_004, false)
	_collision.set_deferred("disabled", true)
	super()

func restore_open() -> void:
	if _opening_tween: _opening_tween.kill()
	_battle_locked = false
	if not persistent_id.is_empty(): GameState.set_flag(persistent_id)
	_finish_open(true)
	opened.emit()

func lock_for_battle() -> void:
	if _battle_locked: return
	_battle_locked = true; is_open = false
	if _opening_tween: _opening_tween.kill()
	_opening_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_opening_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_opening_tween.tween_method(_set_open_amount,_open_amount,0.0,battle_close_time)
	_opening_tween.tween_callback(_battle_closed)

func unlock_after_battle() -> void:
	if not _battle_locked: return
	_battle_locked = false; is_open = true
	if _opening_tween: _opening_tween.kill()
	_opening_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_opening_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_opening_tween.tween_method(_set_open_amount,_open_amount,1.0,open_time)
	_opening_tween.tween_callback(_complete_open)

func is_battle_locked() -> bool:
	return _battle_locked

func _battle_closed() -> void:
	_set_open_amount(0.0)
	if battle_close_trauma > 0.0: ScreenShake.add_trauma(battle_close_trauma)
	closed.emit()

func _refresh() -> void:
	if not _battle_locked: super()

func _make_hinge(leaf: MeshInstance3D, left: bool) -> void:
	var bounds: AABB = leaf.mesh.get_aabb()
	var edge: Vector3 = bounds.get_center()
	edge.x = bounds.position.x if left else bounds.end.x
	edge.y = bounds.position.y
	var pivot: Vector3 = leaf.global_transform * edge
	var hinge: AnimatableBody3D = AnimatableBody3D.new()
	hinge.name = "DoorHingeLeft" if left else "DoorHingeRight"
	hinge.collision_layer = collision_layer; hinge.collision_mask = 0
	hinge.transform = Transform3D(Basis.IDENTITY,to_local(pivot))
	hinge.sync_to_physics = true
	add_child(hinge)
	leaf.reparent(hinge, true)
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = bounds.size * leaf.scale.abs()
	var collider: CollisionShape3D = CollisionShape3D.new()
	collider.name = "DoorCollision"; collider.shape = shape
	hinge.add_child(collider)
	collider.transform = Transform3D(leaf.basis.orthonormalized(), leaf.transform * bounds.get_center())
	_hinges.append(hinge)

func _sink() -> void:
	if _sinking: return
	_sinking = true; _hide_lock()
	unlock_started.emit()
	_opening_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_opening_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_opening_tween.tween_method(_set_open_amount, 0.0, 1.0, open_time)
	_opening_tween.tween_callback(_complete_open)
	if open_trauma > 0.0: ScreenShake.add_trauma(open_trauma)

func _set_open_amount(amount: float) -> void:
	_open_amount = clampf(amount,0.0,1.0)
	var angle: float = deg_to_rad(opening_degrees) * _open_amount
	_hinges[0].rotation.y = angle
	_hinges[1].rotation.y = -angle

func _hide_lock() -> void:
	$Visual/OldGardenDoor/Interactive_Cyan_Lock.hide()
	$Visual/OldGardenDoor/LockBase.hide()

func _finish_open(_instant: bool) -> void:
	is_open = true; _sinking = true
	_collision.set_deferred("disabled", true)
	_hide_lock(); _set_open_amount(1.0)

func _complete_open() -> void:
	_finish_open(false)
	opened.emit()
