class_name WingCollapseController
extends Node3D
## Điều phối phá hủy một hướng khu vực ở Tier 3 (phòng + cầu nối + checkpoint):
## lia camera cắt cảnh, rung màn hình mạnh, cho từng cụm mảnh rung và rơi lệch nhịp xuống dung nham,
## đồng thời dựng tường chắn ở mép Hub để player không rơi.

signal collapse_started
signal collapse_finished

const DEFAULT_DATA: WingCollapseData = preload("res://resources/world/puzzles/wing_collapse_default.tres")

@export var data: WingCollapseData
@export var placed_flag: StringName
@export var targets: Array[Node3D] = []
@export var hub_barrier: Node3D
@export var camera_focus: Node3D
@export var cutscene: CameraCutscene
@export var cutscene_data: CameraCutsceneData

var _collapsed: bool = false
var _collapsing: bool = false
var _elapsed: float = 0.0
var _shake_timer: float = 0.0
var _post_hold_timer: float = 0.0
var _all_fallen: bool = false

var _chunk_nodes: Array[Node3D] = []
var _chunk_origins: PackedVector3Array = PackedVector3Array()
var _chunk_rotations: PackedVector3Array = PackedVector3Array()
var _chunk_delays: PackedFloat32Array = PackedFloat32Array()
var _chunk_velocities: PackedFloat32Array = PackedFloat32Array()
var _chunk_tilt_axes: PackedVector3Array = PackedVector3Array()
var _chunk_tilt_speeds: PackedFloat32Array = PackedFloat32Array()
var _chunk_done: PackedByteArray = PackedByteArray()


func _ready() -> void:
	set_process(false)
	if data == null:
		data = DEFAULT_DATA
	if not _collapsed and not _collapsing:
		_set_barrier_active(false)


func _process(delta: float) -> void:
	var cfg: WingCollapseData = data if data != null else DEFAULT_DATA
	_elapsed += delta
	_shake_timer += delta
	if not _all_fallen and _shake_timer >= cfg.pulse_interval:
		_shake_timer = 0.0
		ScreenShake.add_trauma(cfg.pulse_trauma)

	var remaining: int = 0
	var count: int = _chunk_nodes.size()
	var max_tilt_rad: float = deg_to_rad(cfg.max_tilt_degrees)
	for i: int in range(count):
		if _chunk_done[i] != 0:
			continue
		var chunk: Node3D = _chunk_nodes[i]
		if not is_instance_valid(chunk):
			_chunk_done[i] = 1
			continue
		var start_time: float = cfg.rumble_duration + _chunk_delays[i]
		if _elapsed < start_time:
			remaining += 1
			var phase: float = _elapsed * cfg.rumble_frequency + float(i) * 1.73
			var jitter := Vector3(
				sin(phase) * cfg.rumble_amplitude,
				cos(phase * 1.37) * cfg.rumble_amplitude * 0.45,
				sin(phase * 0.89 + 0.7) * cfg.rumble_amplitude
			)
			chunk.global_position = _chunk_origins[i] + jitter
		else:
			var vel: float = _chunk_velocities[i] + cfg.fall_gravity * delta
			_chunk_velocities[i] = vel
			var pos: Vector3 = chunk.global_position
			# Trả X/Z về tâm rung ban đầu trước khi rơi thẳng xuống theo Y để tránh lệch tích lũy
			pos.x = _chunk_origins[i].x
			pos.z = _chunk_origins[i].z
			pos.y -= vel * delta
			chunk.global_position = pos

			var fall_elapsed: float = _elapsed - start_time
			var tilt_amount: float = clampf(fall_elapsed * _chunk_tilt_speeds[i], 0.0, max_tilt_rad)
			chunk.global_rotation = _chunk_rotations[i] + _chunk_tilt_axes[i] * tilt_amount

			if pos.y <= cfg.sink_y:
				chunk.visible = false
				_chunk_done[i] = 1
			else:
				remaining += 1

	var timed_out: bool = _elapsed >= cfg.rumble_duration + cfg.max_collapse_duration
	if remaining == 0 or timed_out:
		if not _all_fallen:
			_all_fallen = true
			for i: int in range(count):
				if is_instance_valid(_chunk_nodes[i]):
					_chunk_nodes[i].visible = false
				_chunk_done[i] = 1
		_post_hold_timer += delta
		if _post_hold_timer >= cfg.post_fall_hold:
			_finish_destruction()


## Trả về true nếu khu vực này đã sập xong.
func is_collapsed() -> bool:
	return _collapsed


## Áp dụng ngay trạng thái đã sập (dùng khi tải lại save, không chiếu cutscene).
func apply_collapsed_immediate() -> void:
	_collapsing = false
	_collapsed = true
	set_process(false)
	_clear_chunks()
	_disable_targets()
	_set_barrier_active(true)


## Kích hoạt trình tự cắt cảnh + rung camera + sập khu vực xuống dung nham.
func trigger_collapse(actor: Player = null) -> void:
	if _collapsed or _collapsing:
		return
	if data == null:
		data = DEFAULT_DATA
	_collapsing = true
	collapse_started.emit()
	_set_barrier_active(true)
	_disable_target_interactions()

	if cutscene != null and camera_focus != null and actor != null and get_viewport().get_camera_3d() != null:
		cutscene.focus_target = camera_focus
		if cutscene_data != null:
			cutscene.data = cutscene_data
		cutscene.hold_indefinitely = true
		if not cutscene.shot_reached.is_connected(_begin_destruction):
			cutscene.shot_reached.connect(_begin_destruction, CONNECT_ONE_SHOT)
		if not cutscene.finished.is_connected(_on_cutscene_finished):
			cutscene.finished.connect(_on_cutscene_finished, CONNECT_ONE_SHOT)
		cutscene.play_for(actor)
		if cutscene.is_processing():
			return
		# Dự phòng nếu cutscene không thể phát (ví dụ camera bận) thì vẫn sập ngay, tránh treo
		if cutscene.shot_reached.is_connected(_begin_destruction):
			cutscene.shot_reached.disconnect(_begin_destruction)
		if cutscene.finished.is_connected(_on_cutscene_finished):
			cutscene.finished.disconnect(_on_cutscene_finished)
	_begin_destruction()


func _begin_destruction() -> void:
	var cfg: WingCollapseData = data if data != null else DEFAULT_DATA
	_prepare_chunks(cfg)
	ScreenShake.add_trauma(cfg.initial_trauma)
	if _chunk_nodes.is_empty():
		_finish_destruction()
		return
	_elapsed = 0.0
	_shake_timer = 0.0
	_post_hold_timer = 0.0
	_all_fallen = false
	set_process(true)


func _finish_destruction() -> void:
	set_process(false)
	_clear_chunks()
	_disable_targets()
	_collapsed = true
	_collapsing = false
	if cutscene != null and cutscene.is_processing():
		cutscene.release_hold()
		return
	collapse_finished.emit()


func _on_cutscene_finished() -> void:
	collapse_finished.emit()


func _prepare_chunks(cfg: WingCollapseData) -> void:
	_clear_chunks()
	var collected: Array[Node3D] = []
	for target: Node3D in targets:
		if is_instance_valid(target):
			_collect_visual_chunks(target, target, collected)
	if collected.is_empty():
		return

	# Sắp xếp từ gần tâm Hub ra xa để các mảnh đổ sập nối tiếp nhau ra phía ngoài
	collected.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.global_position.length_squared() < b.global_position.length_squared()
	)

	var count: int = collected.size()
	_chunk_nodes = collected
	_chunk_origins.resize(count)
	_chunk_rotations.resize(count)
	_chunk_delays.resize(count)
	_chunk_velocities.resize(count)
	_chunk_tilt_axes.resize(count)
	_chunk_tilt_speeds.resize(count)
	_chunk_done.resize(count)

	var step: float = cfg.stagger_step
	if count > 1 and step * float(count - 1) > cfg.max_stagger_span:
		step = cfg.max_stagger_span / float(count - 1)

	for i: int in range(count):
		var chunk: Node3D = collected[i]
		_chunk_origins[i] = chunk.global_position
		_chunk_rotations[i] = chunk.global_rotation
		_chunk_delays[i] = step * float(i)
		_chunk_velocities[i] = 0.0
		_chunk_tilt_axes[i] = Vector3(
			1.0 if (i % 2 == 0) else -1.0,
			0.35 if (i % 3 == 0) else -0.35,
			0.8 if ((i / 2) % 2 == 0) else -0.8
		).normalized()
		_chunk_tilt_speeds[i] = 0.9 + float(i % 4) * 0.22
		_chunk_done[i] = 0


func _collect_visual_chunks(node: Node, root_target: Node3D, out: Array[Node3D]) -> void:
	if node is CollisionShape3D or node is Marker3D or node is CameraCutscene or node is Camera3D:
		return
	if node is Area3D:
		if not (node as Node3D).visible:
			return
		# Không thêm Area3D vào mảng rơi nhưng vẫn duyệt node con (ví dụ bình phong AnimatableBody3D trong TonWindScreen)
		for child: Node in node.get_children():
			_collect_visual_chunks(child, root_target, out)
		return
	if node is Node3D and node != root_target:
		var node3d := node as Node3D
		if not node3d.visible:
			return
		# Dừng ở từng cụm mô hình/mesh/bình phong độc lập để chúng rơi tách rời nhau mà không phá cấu trúc con
		if node is AnimatableBody3D or node is GeometryInstance3D or node is Light3D or not node3d.scene_file_path.is_empty():
			out.append(node3d)
			return
	for child: Node in node.get_children():
		_collect_visual_chunks(child, root_target, out)


func _disable_target_interactions() -> void:
	for target: Node3D in targets:
		if not is_instance_valid(target):
			continue
		target.set_physics_process(false)
		for col: Node in target.find_children("*", "CollisionShape3D", true, false):
			(col as CollisionShape3D).set_deferred(&"disabled", true)
		for area: Node in target.find_children("*", "Area3D", true, false):
			var area3d := area as Area3D
			area3d.set_physics_process(false)
			area3d.set_deferred(&"monitoring", false)
			area3d.set_deferred(&"monitorable", false)


func _disable_targets() -> void:
	_disable_target_interactions()
	for target: Node3D in targets:
		if not is_instance_valid(target):
			continue
		target.visible = false
		target.process_mode = Node.PROCESS_MODE_DISABLED


func _set_barrier_active(active: bool) -> void:
	if not is_instance_valid(hub_barrier):
		return
	hub_barrier.visible = active
	hub_barrier.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	for col: Node in hub_barrier.find_children("*", "CollisionShape3D", true, false):
		(col as CollisionShape3D).set_deferred(&"disabled", not active)


func _clear_chunks() -> void:
	_chunk_nodes.clear()
	_chunk_origins.clear()
	_chunk_rotations.clear()
	_chunk_delays.clear()
	_chunk_velocities.clear()
	_chunk_tilt_axes.clear()
	_chunk_tilt_speeds.clear()
	_chunk_done.clear()
