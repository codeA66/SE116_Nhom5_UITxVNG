class_name LiFoundry
extends Node3D
## Cửa, khiên và ngọc báo tiến độ riêng để phục hồi qua checkpoint.

signal activated
signal seal_released(seal_id: StringName)

@export var puzzle_data: LiPuzzleData
@export var stages: Array[BeamPuzzleStage] = []
@export var tutorial_receiver: BeamReceiver
@export var seal_gem: SealGem
@export var tutorial_gate_cutscene: CameraCutscene
@export var gem_picked_flag: StringName
@export var legacy_exit_flag: StringName
@export_group("Cửa niêm phong")
@export_range(0.2, 3.0, 0.05) var brick_rise_time: float = 0.85
@export_range(1.0, 8.0, 0.1) var brick_rise_depth: float = 4.2
@export_range(0.0, 1.0, 0.01) var brick_rise_trauma: float = 0.18
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
var _gate_sealed: bool = false
var _gate_cutscene_playing: bool = false
var _brick_tween: Tween
var _resume_player: Player

@onready var _workshop_shape: CollisionShape3D = $WorkshopArea/CollisionShape3D
@onready var _tutorial_gate: FireBurnGate = $TutorialGate as FireBurnGate
@onready var _brick_wall: Node3D = $TutorialGate/Visual/BrickWall
@onready var _seal_plate: Node3D = $TutorialGate/Visual/SealPlate


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
	seal_gem.collected.connect(_on_gem_collected)
	seal_gem.set_carrier(_resume_player)
	if tutorial_gate_cutscene != null:
		tutorial_gate_cutscene.shot_reached.connect(_on_gate_cutscene_shot_reached)
		tutorial_gate_cutscene.finished.connect(_on_gate_cutscene_finished)
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
	_gate_cutscene_playing = false
	if _brick_tween != null and _brick_tween.is_valid():
		_brick_tween.kill()
	if tutorial_gate_cutscene != null:
		tutorial_gate_cutscene.cancel_playback()
	var gem_picked: bool = _is_gem_picked()
	_current_stage = 0
	if is_active():
		_current_stage = stages.size() - 1
	elif gem_picked:
		while _current_stage < stages.size() - 1 and stages[_current_stage].is_complete():
			_current_stage += 1
	_refresh_tutorial_gate()
	for index: int in range(stages.size()):
		stages[index].set_prerequisite_met(index > 0 or tutorial_receiver.is_completed())
		var show_stage: bool = (index == _current_stage) and not is_active() and (index > 0 or not stages[0].is_complete())
		stages[index].set_present(show_stage, false)
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
		_changing = false
		# Chờ nhặt ngọc + xem cutscene đóng cửa 1 xong mới trồi bộ gương phase 2.
		if _is_gem_picked() and not _gate_cutscene_playing:
			_reveal_phase_two()
	elif present and stage == stages[_current_stage]:
		_changing = false


func _refresh_tutorial_gate() -> void:
	var sealed: bool = _is_gem_picked()
	if not _restoring and sealed and not _gate_sealed and tutorial_gate_cutscene != null:
		# Chờ cutscene tới khung hình mới trồi tường gạch niêm phong cửa 1.
		return
	_apply_tutorial_gate_sealed(sealed, false)


func _on_gem_collected(player: Player) -> void:
	if _gate_sealed or tutorial_gate_cutscene == null:
		_apply_tutorial_gate_sealed(true, false)
		_reveal_phase_two()
		return
	_gate_cutscene_playing = true
	tutorial_gate_cutscene.play_for(player)
	if not tutorial_gate_cutscene.is_processing():
		_gate_cutscene_playing = false
		_apply_tutorial_gate_sealed(true, false)
		_reveal_phase_two()


func _on_gate_cutscene_shot_reached() -> void:
	_apply_tutorial_gate_sealed(true, true)


func _on_gate_cutscene_finished() -> void:
	_gate_cutscene_playing = false
	if not _gate_sealed:
		_apply_tutorial_gate_sealed(true, false)
	_reveal_phase_two()


func _reveal_phase_two() -> void:
	if stages.size() < 2 or is_active() or _gate_cutscene_playing or not _is_gem_picked():
		return
	if stages[0].is_changing() or stages[0].is_present():
		return
	if _current_stage >= 1 and (stages[1].is_present() or stages[1].is_changing()):
		return
	_current_stage = 1
	_changing = true
	stages[1].set_present(true, true)


func _apply_tutorial_gate_sealed(sealed: bool, animate_brick: bool) -> void:
	if _brick_tween != null and _brick_tween.is_valid():
		_brick_tween.kill()
	_gate_sealed = sealed
	if _tutorial_gate != null:
		_tutorial_gate.set_sealed(sealed)
	tutorial_receiver.set_blocked(sealed)
	_seal_plate.visible = not sealed
	if not sealed:
		_brick_wall.visible = false
		_brick_wall.position.y = 0.0
		return
	_brick_wall.visible = true
	if animate_brick:
		_brick_wall.position.y = -brick_rise_depth
		_brick_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_brick_tween.tween_property(_brick_wall, "position:y", 0.0, brick_rise_time)
		if brick_rise_trauma > 0.0:
			ScreenShake.add_trauma(brick_rise_trauma)
	else:
		_brick_wall.position.y = 0.0


func _is_gem_picked() -> bool:
	return GameState.has_flag(gem_picked_flag) or GameState.has_flag(legacy_exit_flag)


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
