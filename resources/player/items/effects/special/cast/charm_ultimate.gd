class_name CharmUltimate
extends Node

signal charge_changed(current: int, maximum: int, equipped: bool)

const ACTION: StringName = &"charm_ultimate"
const CONFIRM: StringName = &"charm_ultimate_confirm"
const STATE_NAME: StringName = &"SkystrikeCast"

var data: SkystrikeData
var _player: Player
var _state: State
var _equipped: bool = false
var _charge: int = 0
var _pending: bool = false
var _cursor: Vector2 = Vector2.ZERO
var _visual: SkystrikeVfx

@onready var _pool: ObjectPool = $VfxPool


func _ready() -> void:
	set_physics_process(false)
	set_process_input(false)
	_state = _player.state_machine.get_node(^"SkystrikeCast") as State
	_state.call(&"configure", _player, self)
	_player.health.died.connect(_on_death)


func _exit_tree() -> void:
	if is_instance_valid(_player) and _player.bow_enemy_hit.is_connected(_on_enemy_hit):
		_player.bow_enemy_hit.disconnect(_on_enemy_hit)


func _input(event: InputEvent) -> void:
	if is_casting():
		if event is InputEventMouseMotion:
			_cursor = (event as InputEventMouseMotion).position
		elif event.is_action_pressed(CONFIRM):
			if event is InputEventMouseButton:
				_cursor = (event as InputEventMouseButton).position
			_state.call(&"request_fire")
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
			_state.call(&"request_cancel")
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(ACTION) and _can_start():
		_pending = true
		set_physics_process(true)
		get_viewport().set_input_as_handled()


func _physics_process(_delta: float) -> void:
	set_physics_process(false)
	if not _pending:
		return
	_pending = false
	if not _can_start():
		return
	# Thử toàn thân trước khi bật bất tử để trần thấp không làm phí một lượt nạp.
	if _player.test_move(_player.global_transform, Vector3.UP * data.lift_height):
		return
	_cursor = get_viewport().get_mouse_position()
	_player.state_machine.transition_to(STATE_NAME)


func configure(player: Player, config: SkystrikeData) -> void:
	_player = player
	data = config


func set_equipped(enabled: bool) -> void:
	if _equipped == enabled:
		return
	_equipped = enabled
	if enabled:
		_player.bow_enemy_hit.connect(_on_enemy_hit)
	else:
		_player.bow_enemy_hit.disconnect(_on_enemy_hit)
		_pending = false
		set_physics_process(false)
		_charge = 0
		if is_casting():
			_state.call(&"request_cancel", true)
		else:
			_discard_if_unequipped.call_deferred()
	set_process_input(enabled or is_casting())
	_publish_charge()


func is_equipped() -> bool:
	return _equipped


func get_charge() -> int:
	return _charge


func get_capacity() -> int:
	return maxi(data.hits_to_fill, 1)


func is_casting() -> bool:
	return is_instance_valid(_state) and _player.state_machine.current_state == _state


func get_cursor() -> Vector2:
	return _cursor


func spend_charge() -> void:
	_charge = 0
	_publish_charge()


func begin_visual() -> SkystrikeVfx:
	if is_instance_valid(_visual):
		_pool.release(_visual)
	_visual = _pool.acquire() as SkystrikeVfx
	if not _visual.finished.is_connected(_release_visual):
		_visual.finished.connect(_release_visual)
	_visual.begin_cast(_player.global_position, _player.model.global_basis)
	_publish_charge()
	return _visual


func finish_cast(landed: bool) -> void:
	set_process_input(_equipped)
	if is_instance_valid(_visual):
		if landed and _equipped:
			_visual.land()
		else:
			_pool.release(_visual)
			_visual = null
	if not _equipped:
		_discard_if_unequipped.call_deferred()


func _can_start() -> bool:
	return _equipped and not get_tree().paused and _charge >= get_capacity() and _player.can_start_ground_cast()


func _publish_charge() -> void:
	charge_changed.emit(_charge, get_capacity(), _equipped)


func _on_enemy_hit() -> void:
	if not _equipped or is_casting() or _charge >= get_capacity():
		return
	_charge += 1
	_publish_charge()


func _on_death() -> void:
	_pending = false
	spend_charge()


func _release_visual() -> void:
	if is_instance_valid(_visual):
		_pool.release(_visual)
		_visual = null


func _discard_if_unequipped() -> void:
	if not is_inside_tree() or _equipped or is_casting():
		return
	# Đổi nhiều lần trong một frame có thể lên lịch dọn hơn một lần.
	_state.call(&"clear_context")
	get_parent().remove_child(self)
	queue_free()
