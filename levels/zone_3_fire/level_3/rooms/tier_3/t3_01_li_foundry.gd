class_name LiFoundry
extends Node3D
## Các lượt nối bằng signal; cửa đầu chỉ đóng khi player đã ở trong xưởng.

signal activated
signal seal_released(seal_id: StringName)

@export var puzzle_data: LiPuzzleData
@export var stages: Array[BeamPuzzleStage] = []
@export var tutorial_lock: HeatLock
@export var workshop_area: Area3D
@export var tutorial_gate_feedback: GateFeedback
@export var shortcut_gate_feedback: GateFeedback
@export_group("Tiếp tục câu đố")
@export var phase_two_spawn: Marker3D
@export_group("Chạy riêng phòng")
@export var standalone_player: Player
@export var standalone_spawn: Marker3D
@export var standalone_camera_view: CameraViewData
@export var standalone_lighting: PackedScene

var _inside_players: Array[Player] = []
var _current_stage: int = 0
var _changing: bool = false
var _waiting_for_entry: bool = false
var _restoring: bool = false
var _resume_player: Player

@onready var _workshop_shape: CollisionShape3D = $WorkshopArea/CollisionShape3D


func _ready() -> void:
	var zone: ZoneRoot = get_parent() as ZoneRoot
	if zone:
		zone.player_spawned.connect(_on_player_spawned)
		_resume_player = zone.get_node_or_null(^"Player") as Player
	_prepare_standalone_player()
	if puzzle_data == null or stages.is_empty() or stages.size() != puzzle_data.stage_flags.size() + 1:
		push_error("%s thiếu cấu hình các lượt câu đố Ly" % get_path())
		return
	workshop_area.body_entered.connect(_on_body_entered)
	workshop_area.body_exited.connect(_on_body_exited)
	tutorial_lock.activated.connect(_on_tutorial_changed)
	tutorial_lock.deactivated.connect(_on_tutorial_changed)
	tutorial_lock.configure(puzzle_data, puzzle_data.tutorial_flag)
	_restoring = true
	for index: int in range(stages.size()):
		stages[index].completed.connect(_on_stage_completed)
		stages[index].presence_finished.connect(_on_presence_finished)
		var flag: StringName = puzzle_data.completed_flag if index == stages.size() - 1 else StringName(puzzle_data.stage_flags[index])
		stages[index].configure(puzzle_data, flag)
	tutorial_gate_feedback.configure(puzzle_data, tutorial_gate_feedback.get_parent() as StoneGate, tutorial_lock, false)
	shortcut_gate_feedback.configure(puzzle_data, shortcut_gate_feedback.get_parent() as StoneGate, stages.back().receiver, true)
	GameState.progress_replaced.connect(_restore)
	_restore()


func is_active() -> bool:
	return not stages.is_empty() and stages.back().is_complete()


func current_stage_index() -> int:
	return _current_stage


func _restore() -> void:
	_restoring = true
	_changing = false
	_current_stage = 0
	if is_active():
		_current_stage = stages.size() - 1
	else:
		while _current_stage < stages.size() - 1 and stages[_current_stage].is_complete():
			_current_stage += 1
	_waiting_for_entry = false
	for index: int in range(stages.size()):
		stages[index].set_prerequisite_met(index > 0 or tutorial_lock.is_active())
		stages[index].set_present(index == _current_stage and not is_active(), false)
	_refresh_entrance()
	_restoring = false
	_resume_inside_workshop(_resume_player)


func _on_tutorial_changed() -> void:
	if not stages.is_empty():
		stages[0].set_prerequisite_met(tutorial_lock.is_active())
		_refresh_entrance()


func _on_stage_completed(stage: BeamPuzzleStage) -> void:
	var index: int = stages.find(stage)
	if _restoring or index != _current_stage:
		return
	if index == stages.size() - 1:
		_waiting_for_entry = false
		stage.set_present(false, true)
		_refresh_entrance()
		activated.emit()
		seal_released.emit(puzzle_data.seal_id)
		return
	if index == 0 and _inside_players.is_empty():
		_waiting_for_entry = true
		_refresh_entrance()
	else:
		_begin_transition()


func _begin_transition() -> void:
	_waiting_for_entry = false
	_changing = true
	_refresh_entrance()
	stages[_current_stage].set_present(false, true)


func _on_presence_finished(stage: BeamPuzzleStage, present: bool) -> void:
	if _restoring or not _changing:
		return
	if not present and stage == stages[_current_stage]:
		_current_stage += 1
		stages[_current_stage].set_present(true, true)
	elif present and stage == stages[_current_stage]:
		_changing = false
		_refresh_entrance()


func _on_body_entered(body: Node3D) -> void:
	var player: Player = body as Player
	if player == null or player in _inside_players:
		return
	_inside_players.append(player)
	if _waiting_for_entry:
		if stages[_current_stage].is_complete() and not is_active():
			_begin_transition()
		else:
			_waiting_for_entry = false
			_refresh_entrance()


func _on_body_exited(body: Node3D) -> void:
	_inside_players.erase(body as Player)


func _refresh_entrance() -> void:
	if stages.is_empty():
		return
	var first_pass: bool = _current_stage == 0 and tutorial_lock.is_active() and not stages[0].is_complete()
	stages[0].set_route_open(_current_stage == 0 and not is_active() and (_waiting_for_entry or (first_pass and not _changing)))


func _on_player_spawned(player: Player) -> void:
	_resume_player = player
	_resume_inside_workshop(player)


func _resume_inside_workshop(player: Player) -> void:
	if not is_instance_valid(player) or player.is_queued_for_deletion() or phase_two_spawn == null:
		return
	if _current_stage == 0 or is_active():
		return
	# Dùng vị trí thực khi nạp; signal vùng có thể còn giữ kết quả của lượt vật lý trước.
	var bounds: BoxShape3D = _workshop_shape.shape as BoxShape3D
	var local_position: Vector3 = _workshop_shape.to_local(player.global_position).abs()
	var half_size: Vector3 = bounds.size * 0.5
	if local_position.x <= half_size.x and local_position.y <= half_size.y and local_position.z <= half_size.z:
		return
	player.teleport(phase_two_spawn.global_position, -phase_two_spawn.global_basis.z)


func _prepare_standalone_player() -> void:
	if standalone_player == null:
		return
	if get_parent() is ZoneRoot:
		standalone_player.queue_free()
		return
	_resume_player = standalone_player
	if standalone_spawn:
		standalone_player.teleport(standalone_spawn.global_position, -standalone_spawn.global_basis.z)
	for rig: Node in get_tree().get_nodes_in_group(CameraRig.GROUP):
		if standalone_player.is_ancestor_of(rig):
			(rig as CameraRig).apply_view(standalone_camera_view)
	if standalone_lighting:
		add_child(standalone_lighting.instantiate())
