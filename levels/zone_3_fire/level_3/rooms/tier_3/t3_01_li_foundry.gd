class_name LiFoundry
extends Node3D
## Cửa, khiên và ngọc báo tiến độ riêng để phục hồi qua checkpoint.

signal activated
signal seal_released(seal_id: StringName)

@export var puzzle_data: LiPuzzleData
@export var stages: Array[BeamPuzzleStage] = []
@export var tutorial_receiver: BeamReceiver
@export var seal_gem: SealGem
@export var gem_picked_flag: StringName
@export var legacy_exit_flag: StringName
@export_group("Tiếp tục câu đố")
@export var phase_two_spawn: Marker3D
@export_group("Chạy riêng phòng")
@export var standalone_player: Player
@export var standalone_spawn: Marker3D
@export var standalone_camera_view: CameraViewData
@export var standalone_lighting: PackedScene

var _current_stage: int = 0
var _changing: bool = false
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
	tutorial_receiver.completed.connect(_on_tutorial_changed)
	tutorial_receiver.configure(puzzle_data, puzzle_data.tutorial_flag)
	tutorial_receiver.set_enabled(true)
	tutorial_receiver.activated.connect(stages[0].beam.request_trace)
	tutorial_receiver.deactivated.connect(stages[0].beam.request_trace)
	_restoring = true
	for index: int in range(stages.size()):
		stages[index].completed.connect(_on_stage_completed)
		stages[index].presence_finished.connect(_on_presence_finished)
		var flag: StringName = puzzle_data.completed_flag if index == stages.size() - 1 else StringName(puzzle_data.stage_flags[index])
		var legacy_flag: StringName = legacy_exit_flag if index == stages.size() - 1 else &""
		var auxiliary: BeamReceiver = tutorial_receiver if index == 0 else null
		stages[index].configure(puzzle_data, flag, legacy_flag, auxiliary)
	# Bản walkthrough lưu mốc đặt ngọc mới theo hậu tố của cờ Ly cũ.
	var placed_flag: StringName = &"" if legacy_exit_flag.is_empty() else StringName(String(legacy_exit_flag) + "_placed")
	seal_gem.configure(stages[0].receiver, gem_picked_flag, placed_flag, legacy_exit_flag)
	seal_gem.set_carrier(_resume_player)
	GameState.progress_changed.connect(_refresh_tutorial_gate)
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
	while _current_stage < stages.size() - 1 and (stages[_current_stage].is_complete() or is_active()):
		_current_stage += 1
	_refresh_tutorial_gate()
	for index: int in range(stages.size()):
		stages[index].set_prerequisite_met(index > 0 or tutorial_receiver.is_completed())
		stages[index].set_present(index == _current_stage and not is_active(), false)
	_restoring = false
	_resume_inside_workshop(_resume_player)


func _on_tutorial_changed() -> void:
	if not stages.is_empty():
		stages[0].set_prerequisite_met(tutorial_receiver.is_completed())


func _on_stage_completed(stage: BeamPuzzleStage) -> void:
	var index: int = stages.find(stage)
	if _restoring or index != _current_stage:
		return
	if index == stages.size() - 1:
		stage.set_present(false, true)
		activated.emit()
		seal_released.emit(puzzle_data.seal_id)
		return
	_changing = true
	stage.set_present(false, true)


func _on_presence_finished(stage: BeamPuzzleStage, present: bool) -> void:
	if _restoring or not _changing:
		return
	if not present and stage == stages[_current_stage]:
		_current_stage += 1
		stages[_current_stage].set_present(true, true)
	elif present and stage == stages[_current_stage]:
		_changing = false


func _refresh_tutorial_gate() -> void:
	var sealed: bool = GameState.has_flag(gem_picked_flag) or GameState.has_flag(legacy_exit_flag)
	tutorial_receiver.set_blocked(sealed)
	$TutorialGate/Visual/BrickWall.visible = sealed
	$TutorialGate/Visual/SealPlate.visible = not sealed


func _on_player_spawned(player: Player) -> void:
	_resume_player = player
	_resume_inside_workshop(player)
	seal_gem.set_carrier(player)


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
