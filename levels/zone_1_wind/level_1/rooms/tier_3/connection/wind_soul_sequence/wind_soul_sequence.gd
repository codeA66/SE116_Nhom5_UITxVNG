extends Node3D
## Ba cờ dùng chung với các trận cũ để save trước bản này vẫn có thể mở cổng.

signal shot_started(shot: StringName)
signal portal_opened

const WOLF_FLAG: StringName = &"level_1.secret_wolf_defeated"
const BEAR_FLAG: StringName = &"level_1.enc_bear_miniboss"
const KING_FLAG: StringName = &"level_1.monkey_king_defeated"
const PORTAL_FLAG: StringName = &"level_1.t3.wind_final_portal_open"

class Spirit:
	var ghost: Node3D
	var orb: MeshInstance3D
	var trail: MeshInstance3D
	var motes: CPUParticles3D
	var ghost_material: ShaderMaterial
	var trail_material: ShaderMaterial

@export_group("Điểm quay")
@export var king_encounter: GardenKingEncounter
@export var monkey_origin: Marker3D
@export var wolf_origin: Marker3D
@export var bear_origin: Marker3D
@export var wolf_room: Node3D
@export var bear_room: Node3D
@export var wolf_cover: Node3D
@export var monkey_camera_offset: Vector3 = Vector3(11, 21, 16)
@export var wolf_camera_offset: Vector3 = Vector3(8, 16, 12)
@export var bear_camera_offset: Vector3 = Vector3(10, 18, 14)
@export var monkey_framing_offset: Vector3 = Vector3(0, 0.55, -2.75)
@export var wolf_framing_offset: Vector3 = Vector3(0.5, 0.8, 1.5)
@export var bear_framing_offset: Vector3 = Vector3(1.5, 0.4, 2.3)
@export var portal_camera_offset: Vector3 = Vector3(5, 9.5, 8)
@export var group_camera_offset: Vector3 = Vector3(6, 10.5, 11)
@export_range(1.0, 2.0, 0.05) var orbit_camera_start_scale: float = 1.32

@export_group("Nhịp")
@export_range(0.05, 3.0, 0.05) var phase_time_scale: float = 1.0
@export_range(0.1, 5.0, 0.05) var ghost_appear_time: float = 0.62
@export_range(0.0, 5.0, 0.05) var ghost_hold_time: float = 0.5
@export_range(0.1, 5.0, 0.05) var ghost_morph_time: float = 0.48
@export_range(0.2, 6.0, 0.05) var monkey_rise: float = 1.1
@export_range(0.2, 6.0, 0.05) var remote_rise: float = 1.05
@export_range(0.2, 6.0, 0.05) var soul_arrival: float = 0.62
@export_range(0.2, 8.0, 0.05) var orbit_time: float = 2.55
@export_range(0.2, 6.0, 0.05) var portal_reveal: float = 1.55
@export_range(1.0, 5.0, 0.1) var orbit_height: float = 1.55

@export_group("Linh hồn")
@export var ghost_shader: Shader
@export var trail_shader: Shader
@export_range(0.1, 4.0, 0.05) var ghost_lift: float = 0.65
@export_range(0.1, 4.0, 0.05) var ghost_to_orb_height: float = 1.7
@export_range(0.08, 2.0, 0.02) var ribbon_width: float = 0.68
@export_range(0.05, 0.5, 0.01) var flight_trail_span: float = 0.34
@export_range(0.1, 2.6, 0.05) var orbit_trail_angle: float = 1.75

var _player: Player
var _visitor: Player
var _old_camera: Camera3D
var _controls_were_enabled: bool
var _tree_was_paused: bool
var _running: bool
var _opened: bool
var _hidden_overlays: Array[CanvasLayer] = []
var _room_visibility: Dictionary[Node3D, bool] = {}
var _spirits: Array[Spirit] = []

@onready var _camera: Camera3D = $ShotCamera
@onready var _portal: Portal = $Portal
@onready var _rift: MeshInstance3D = $Portal/Rift
@onready var _rift_material: ShaderMaterial = _rift.material_override as ShaderMaterial
@onready var _audience: Area3D = $Audience


func _ready() -> void:
	_prepare_spirit($Ghosts/Monkey, $Souls/Monkey, &"Monkey_Chieftain_Idle_Loop")
	_prepare_spirit($Ghosts/Wolf, $Souls/Wolf, &"idle")
	_prepare_spirit($Ghosts/Bear, $Souls/Bear, &"General/Idle_A")
	_audience.body_entered.connect(_on_audience_entered)
	_audience.body_exited.connect(_on_audience_exited)
	GameState.progress_changed.connect(_refresh_gate)
	GameState.progress_replaced.connect(_refresh_gate)
	if king_encounter:
		king_encounter.victory_presentation_finished.connect(_refresh_gate)
	var zone: ZoneRoot = get_parent() as ZoneRoot
	if zone:
		zone.combat_ready.connect(_refresh_gate)
	_set_portal(GameState.has_flag(PORTAL_FLAG))


func _exit_tree() -> void:
	_restore_room()
	if _running:
		_restore_gameplay()


func is_portal_open() -> bool:
	return _opened


func get_portal_position() -> Vector3:
	return _portal.global_position


func try_begin(actor: Player) -> bool:
	if _running or _opened or not is_instance_valid(actor) or not actor.controls_enabled or actor.health.is_dead():
		return false
	if not _three_defeated() or SceneManager.is_busy() or get_tree().paused:
		return false
	if king_encounter and not king_encounter.is_victory_presentation_finished():
		return false
	_running = true
	_player = actor
	_old_camera = get_viewport().get_camera_3d()
	_controls_were_enabled = actor.controls_enabled
	_tree_was_paused = get_tree().paused
	actor.set_controls_enabled(false)
	for overlay: Node in get_tree().get_nodes_in_group(&"gameplay_overlay"):
		_hide_overlay(overlay as CanvasLayer)
	_hide_overlay(actor.get_node_or_null(^"HUD") as CanvasLayer)
	get_tree().paused = true
	_play.call_deferred()
	return true


func _three_defeated() -> bool:
	return GameState.has_flag(WOLF_FLAG) and GameState.has_flag(BEAR_FLAG) and GameState.has_flag(KING_FLAG)


func _on_audience_entered(body: Node3D) -> void:
	if body is Player:
		_visitor = body as Player
		_refresh_gate.call_deferred()


func _on_audience_exited(body: Node3D) -> void:
	if body == _visitor:
		_visitor = null


func _refresh_gate() -> void:
	if _running:
		return
	_set_portal(GameState.has_flag(PORTAL_FLAG))
	if not _opened and _three_defeated():
		_start_nearby.call_deferred()


func _start_nearby() -> void:
	if is_instance_valid(_visitor):
		try_begin(_visitor)


func _play() -> void:
	var center: Vector3 = _player.global_position + Vector3.UP * orbit_height
	var monkey: Vector3 = monkey_origin.global_position if monkey_origin else center + Vector3.FORWARD * 2.5
	if king_encounter and king_encounter.get_victory_soul_origin().is_finite():
		monkey = king_encounter.get_victory_soul_origin()
	_show_monkey_room()
	_place_camera(monkey + monkey_framing_offset, monkey_camera_offset)
	_camera.make_current()
	shot_started.emit(&"monkey")
	var departure: Vector3 = await _reveal_spirit(_spirits[0], monkey)
	await _travel(_spirits[0], departure, _orbit_point(center, 0.0, 0, 1.9), monkey_rise, 1.15)
	await _remote(&"wolf", wolf_origin, wolf_room, wolf_cover, center, 1, wolf_framing_offset, wolf_camera_offset)
	await _remote(&"bear", bear_origin, bear_room, null, center, 2, bear_framing_offset, bear_camera_offset)

	_place_camera(center, group_camera_offset * orbit_camera_start_scale)
	shot_started.emit(&"orbit")
	var orbit: Tween = _shot_tween()
	orbit.tween_method(_turn_souls.bind(center), 0.0, 1.0, orbit_time * phase_time_scale)
	await orbit.finished

	_rift.show()
	_rift_material.set_shader_parameter(&"opening", 0.0)
	var join: Tween = _shot_tween().set_parallel()
	var rift_center: Vector3 = _rift.global_position
	_place_camera(rift_center.lerp(center, 0.18), portal_camera_offset)
	shot_started.emit(&"portal")
	var cross_time: float = portal_reveal * phase_time_scale
	var converge_time: float = cross_time * 0.49
	for spirit: Spirit in _spirits:
		join.tween_method(_arc.bind(spirit, spirit.orb.global_position, rift_center, 0.5), 0.0, 1.0, converge_time)
	join.tween_callback(_hide_spirits).set_delay(converge_time)
	join.tween_method(_reveal_rift, 0.0, 1.0, cross_time).set_delay(cross_time * 0.30)
	await join.finished
	GameState.set_flag(PORTAL_FLAG)
	_restore_room()
	_restore_gameplay()
	_running = false
	_set_portal(true)
	portal_opened.emit()


func _remote(shot: StringName, start: Marker3D, room: Node3D, cover: Node3D, center: Vector3,
		index: int, framing_offset: Vector3, camera_offset: Vector3) -> void:
	_show_room(room, cover)
	var origin: Vector3 = start.global_position if start else center + Vector3(4.5 * index, -orbit_height, -3.5)
	var focus: Vector3 = origin + framing_offset
	_place_camera(focus, camera_offset)
	shot_started.emit(shot)
	var spirit: Spirit = _spirits[index]
	var departure: Vector3 = await _reveal_spirit(spirit, origin)
	var exit_shot: Vector3 = departure + Vector3(-5.2 if index == 1 else 4.8, 3.4, -2.7)
	# Khung rộng giữ lại kiến trúc trong lúc linh hồn bắt đầu rời phòng.
	var lift: Tween = _shot_tween()
	lift.tween_method(_remote_lift.bind(spirit, departure, exit_shot, focus, camera_offset),
		0.0, 1.0, remote_rise * phase_time_scale)
	await lift.finished
	_restore_room()

	_show_monkey_room()
	_place_camera(center, group_camera_offset)
	var inbound: Vector3 = center + Vector3(8.0 if index == 1 else -8.0, 4, -5)
	await _travel(spirit, inbound, _orbit_point(center, 0.0, index, 1.9), soul_arrival, 1.0)


func _remote_lift(value: float, spirit: Spirit, origin: Vector3, destination: Vector3,
		focus: Vector3, camera_offset: Vector3) -> void:
	_arc(value, spirit, origin, destination, 0.75)
	_place_camera(focus.lerp(spirit.orb.global_position, value * 0.28), camera_offset)


func _travel(spirit: Spirit, origin: Vector3, destination: Vector3, seconds: float, arch_height: float) -> void:
	_stop_trail(spirit)
	spirit.orb.global_position = origin
	spirit.orb.show()
	var flight: Tween = _shot_tween()
	flight.tween_method(_arc.bind(spirit, origin, destination, arch_height), 0.0, 1.0, seconds * phase_time_scale)
	await flight.finished
	_stop_trail(spirit)


func _prepare_spirit(ghost: Node3D, orb: MeshInstance3D, pose_name: StringName) -> void:
	var spirit: Spirit = Spirit.new()
	spirit.ghost = ghost
	spirit.orb = orb
	spirit.trail = orb.get_node(^"Trail") as MeshInstance3D
	spirit.motes = orb.get_node(^"Motes") as CPUParticles3D
	var tint: Color = (orb.material_override as ShaderMaterial).get_shader_parameter(&"tint")
	spirit.ghost_material = ShaderMaterial.new()
	spirit.ghost_material.shader = ghost_shader
	spirit.ghost_material.set_shader_parameter(&"tint", tint)
	for child: Node in ghost.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = child as MeshInstance3D
		mesh.material_override = spirit.ghost_material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	spirit.trail_material = ShaderMaterial.new()
	spirit.trail_material.shader = trail_shader
	spirit.trail_material.set_shader_parameter(&"tint", tint)
	spirit.trail_material.set_shader_parameter(&"width", ribbon_width)
	spirit.trail.material_override = spirit.trail_material
	var animation: AnimationPlayer = ghost.get_node_or_null(^"AnimationPlayer") as AnimationPlayer
	if not animation:
		animation = ghost.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animation and animation.has_animation(pose_name):
		# Lấy dáng đứng gốc của boss mà không giữ bộ phát animation chạy khi hồn ẩn.
		animation.play(pose_name)
		animation.advance(0.0)
		animation.pause()
	_spirits.append(spirit)


func _reveal_spirit(spirit: Spirit, origin: Vector3) -> Vector3:
	var ghost: Node3D = spirit.ghost
	var material: ShaderMaterial = spirit.ghost_material
	ghost.global_position = origin - Vector3.UP * 0.18
	ghost.scale = Vector3.ONE
	material.set_shader_parameter(&"appearance", 0.0)
	material.set_shader_parameter(&"dissolve", 0.0)
	ghost.show()
	var entrance: Tween = _shot_tween()
	entrance.tween_method(_raise_ghost.bind(spirit, origin), 0.0, 1.0, ghost_appear_time * phase_time_scale)
	entrance.tween_interval(ghost_hold_time * phase_time_scale)
	await entrance.finished
	var departure: Vector3 = origin + Vector3.UP * ghost_to_orb_height
	var morph_start: Vector3 = ghost.global_position
	spirit.orb.global_position = departure
	spirit.orb.scale = Vector3.ONE * 0.08
	spirit.orb.show()
	var morph: Tween = _shot_tween()
	morph.tween_method(_morph_ghost.bind(spirit, morph_start, departure), 0.0, 1.0, ghost_morph_time * phase_time_scale)
	await morph.finished
	ghost.hide()
	return departure


func _raise_ghost(value: float, spirit: Spirit, origin: Vector3) -> void:
	var eased: float = smoothstep(0.0, 1.0, value)
	spirit.ghost.global_position = origin + Vector3.UP * lerpf(-0.18, ghost_lift, eased)
	spirit.ghost_material.set_shader_parameter(&"appearance", smoothstep(0.08, 0.84, value))


func _morph_ghost(value: float, spirit: Spirit, origin: Vector3, departure: Vector3) -> void:
	var fold: float = smoothstep(0.10, 0.94, value)
	spirit.ghost.global_position = origin.lerp(departure, fold)
	spirit.ghost.scale = Vector3.ONE * lerpf(1.0, 0.09, fold)
	spirit.ghost_material.set_shader_parameter(&"dissolve", value)
	spirit.orb.scale = Vector3.ONE * lerpf(0.08, 1.0, smoothstep(0.25, 0.94, value))


func _shot_tween() -> Tween:
	# Giữ nhịp từng cảnh khi gameplay đang dừng hoặc hitstop chưa trả lại tốc độ.
	return create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_ignore_time_scale()


func _arc(value: float, spirit: Spirit, origin: Vector3, destination: Vector3, arch_height: float) -> void:
	var span: float = minf(value, flight_trail_span * minf(1.0, 11.0 / maxf(1.0, origin.distance_to(destination))))
	_pose_spirit(spirit, _arc_sample(value, origin, destination, arch_height),
		_arc_sample(value - span * 0.33, origin, destination, arch_height),
		_arc_sample(value - span * 0.67, origin, destination, arch_height),
		_arc_sample(value - span, origin, destination, arch_height))


func _arc_sample(value: float, origin: Vector3, destination: Vector3, arch_height: float) -> Vector3:
	var eased: float = value * value * (3.0 - 2.0 * value)
	return origin.lerp(destination, eased) + Vector3.UP * (sin(PI * value) * arch_height)


func _orbit_point(center: Vector3, angle: float, index: int, radius: float) -> Vector3:
	var phase: float = angle + TAU * float(index) / float(_spirits.size())
	var lane: float = (float(index) - 1.0) * 0.48
	return center + Vector3(cos(phase) * radius, lane + sin(phase * 2.0) * 0.26, sin(phase) * radius)


func _turn_souls(value: float, center: Vector3) -> void:
	var angle: float = TAU * (value * 0.30 + value * value * 2.15)
	var radius: float = lerpf(1.9, 2.65, smoothstep(0.0, 0.9, value))
	var drag: float = minf(angle, lerpf(0.24, orbit_trail_angle, value))
	_place_camera(center, group_camera_offset * lerpf(orbit_camera_start_scale, 1.0, smoothstep(0.0, 1.0, value)))
	for index: int in _spirits.size():
		_pose_spirit(_spirits[index], _orbit_point(center, angle, index, radius),
			_orbit_point(center, angle - drag * 0.33, index, radius),
			_orbit_point(center, angle - drag * 0.67, index, radius),
			_orbit_point(center, angle - drag, index, radius))


func _pose_spirit(spirit: Spirit, head: Vector3, bend_near: Vector3, bend_far: Vector3, tail: Vector3) -> void:
	spirit.orb.global_position = head
	var strength: float = smoothstep(0.08, 0.68, head.distance_to(tail))
	if strength <= 0.0:
		_stop_trail(spirit)
		return
	var material: ShaderMaterial = spirit.trail_material
	material.set_shader_parameter(&"head", head)
	material.set_shader_parameter(&"bend_near", bend_near)
	material.set_shader_parameter(&"bend_far", bend_far)
	material.set_shader_parameter(&"tail", tail)
	material.set_shader_parameter(&"strength", strength)
	spirit.trail.show()
	if not spirit.motes.emitting:
		spirit.motes.emitting = true


func _stop_trail(spirit: Spirit) -> void:
	spirit.trail.hide()
	spirit.motes.emitting = false


func _hide_spirits() -> void:
	for spirit: Spirit in _spirits:
		_stop_trail(spirit)
		spirit.orb.hide()


func _place_camera(focus: Vector3, offset: Vector3) -> void:
	_camera.look_at_from_position(focus + offset, focus)


func _show_room(room: Node3D, cover: Node3D) -> void:
	var ancestor: Node3D = room
	while ancestor != null:
		if not ancestor.visible:
			_room_visibility[ancestor] = false
			ancestor.show()
		ancestor = ancestor.get_parent() as Node3D
	if cover and cover.visible:
		_room_visibility[cover] = true
		cover.hide()


func _show_monkey_room() -> void:
	# Camera quay lại trước khi các vùng ẩn tầng nhận được lượt vật lý mới.
	if king_encounter:
		_show_room(king_encounter.get_parent() as Node3D, null)


func _restore_room() -> void:
	for node: Node3D in _room_visibility:
		if is_instance_valid(node):
			node.visible = _room_visibility[node]
	_room_visibility.clear()


func _restore_gameplay() -> void:
	if is_instance_valid(_old_camera):
		_old_camera.make_current()
	for overlay: CanvasLayer in _hidden_overlays:
		if is_instance_valid(overlay):
			overlay.show()
	_hidden_overlays.clear()
	if is_instance_valid(_player):
		_player.set_controls_enabled(_controls_were_enabled)
	get_tree().paused = _tree_was_paused
	_player = null


func _hide_overlay(overlay: CanvasLayer) -> void:
	if overlay and overlay.visible:
		_hidden_overlays.append(overlay)
		overlay.hide()


func _reveal_rift(value: float) -> void:
	_rift_material.set_shader_parameter(&"opening", value)


func _set_portal(active: bool) -> void:
	_opened = active
	_portal.set_active(active)
	_rift.visible = active
	_reveal_rift(1.0 if active else 0.0)
