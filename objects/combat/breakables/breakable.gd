class_name Breakable
extends StaticBody3D
## Các mảnh dựng sẵn dùng chung cho cả vỡ, nằm trên sàn và ráp lại.

signal broken
signal respawned

const FLIGHT_FRACTION: float = 0.78

@export var data: BreakableData
@export var flash_material: Material
## Các kiểu có model nguyên riêng vẫn có thể dùng chung hệ thống.
@export var use_debris_as_visual: bool = false
@export var debris_parts_root: NodePath = ^"Debris"
@export var damage_parts: Array[NodePath] = []

var is_broken: bool = false

var _hit_tween: Tween
var _piece_tween: Tween
var _chunks: Array[Node3D] = []
var _homes: Array[Transform3D] = []
var _bounds: Array[AABB] = []
var _damage_parts: Array[Node3D] = []
var _damage_homes: Array[Transform3D] = []
var _damage_axes: Array[Vector3] = []
var _meshes: Array[GeometryInstance3D] = []
var _display: Node3D
var _display_home: Transform3D
var _occupancy_query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
var _timer_elapsed: bool = false
var _rebuilding: bool = false
var _rebuild_done: bool = false

@onready var _shape: CollisionShape3D = $CollisionShape3D
@onready var _visual: Node3D = $Visual
@onready var _debris: Node3D = $Debris
@onready var _health: HealthComponent = $HealthComponent
@onready var _hurtbox: HurtboxComponent = $HurtboxComponent
@onready var _receiver: WindReceiverComponent = $WindReceiver
@onready var _blocker: Area3D = $RespawnBlocker
@onready var _blocker_shape: CollisionShape3D = $RespawnBlocker/CollisionShape3D
@onready var _respawn_timer: Timer = $RespawnTimer
@onready var _hit_dust: GPUParticles3D = $HitDust
@onready var _hit_chips: CPUParticles3D = $HitChips
@onready var _break_dust: GPUParticles3D = $BreakDust
@onready var _rebuild_dust: GPUParticles3D = $RebuildDust
@onready var _hit_sound: AudioStreamPlayer3D = $HitSound
@onready var _break_sound: AudioStreamPlayer3D = $BreakSound
@onready var _rebuild_sound: AudioStreamPlayer3D = $RebuildSound


func _ready() -> void:
	set_physics_process(false)
	_hurtbox.remove_from_group(HurtboxComponent.GROUP)
	_receiver.set_physics_process(false)
	_health.max_health = data.max_hits if data else 1
	_health.heal_full()
	_display = _debris if use_debris_as_visual else _visual
	_display_home = _display.transform
	_debris.visible = use_debris_as_visual
	_hit_chips.amount = data.hit_chip_count if data else 1
	for child: Node in get_node(debris_parts_root).get_children():
		var chunk: Node3D = child as Node3D
		if not chunk:
			continue
		_chunks.append(chunk)
		_homes.append(chunk.transform)
		_bounds.append(_cache_bounds(chunk))
	for mesh: Node in _display.find_children("*", "GeometryInstance3D", true, false):
		_meshes.append(mesh as GeometryInstance3D)
	for path: NodePath in damage_parts:
		var part: Node3D = get_node_or_null(path) as Node3D
		if part:
			_damage_parts.append(part)
			_damage_homes.append(part.transform)
			var chunk_index: int = _chunks.find(part)
			_damage_axes.append(_bounds[chunk_index].get_shortest_axis() if chunk_index >= 0 else Vector3.BACK)
	_occupancy_query.shape = _blocker_shape.shape
	_occupancy_query.collision_mask = _blocker.collision_mask
	_blocker.body_entered.connect(_on_blocker_entered)
	_blocker.body_exited.connect(_on_blocker_exited)
	_respawn_timer.timeout.connect(_on_respawn_timer)
	_hurtbox.hurt.connect(_on_hurt)
	_health.died.connect(_on_died)


func _physics_process(_delta: float) -> void:
	set_physics_process(false)
	# Hỏi vật lý ngay lúc sắp đóng vì tín hiệu vùng có thể chậm một nhịp.
	_occupancy_query.transform = _blocker_shape.global_transform
	if not get_world_3d().direct_space_state.intersect_shape(_occupancy_query, 1).is_empty():
		return
	if _rebuild_done:
		_finish_rebuild()
	elif _rebuilding and _piece_tween.is_valid():
		_piece_tween.play()
	elif _timer_elapsed:
		_start_rebuild()


func _on_hurt(info: DamageInfo, damage_taken: int) -> void:
	if is_broken or damage_taken <= 0 or not data:
		return
	_apply_damage_pose()
	_play_hit(info)


func _on_died() -> void:
	if is_broken:
		return
	is_broken = true
	_set_solid(false)
	_play_break()
	broken.emit()
	if data and data.respawn_time > 0.0:
		# Giữ vùng theo dõi từ lúc vỡ để timer rất ngắn vẫn thấy Foxy đang đứng trên thùng.
		_blocker.set_deferred(&"monitoring", true)
		_respawn_timer.start(data.respawn_time)


func _on_respawn_timer() -> void:
	_timer_elapsed = true
	set_physics_process(true)


func _on_blocker_entered(_body: Node3D) -> void:
	if _rebuilding and _piece_tween.is_valid():
		_piece_tween.pause()


func _on_blocker_exited(_body: Node3D) -> void:
	if _timer_elapsed:
		set_physics_process(true)


func _set_solid(solid: bool) -> void:
	_shape.set_deferred(&"disabled", not solid)
	_hurtbox.set_deferred(&"monitorable", solid)
	_receiver.set_deferred(&"monitorable", solid)
	_receiver.enabled = solid


func _apply_damage_pose() -> void:
	var damage: float = 1.0 - float(_health.current_health) / float(_health.max_health)
	var part_count: int = _damage_parts.size()
	for index: int in part_count:
		var part: Node3D = _damage_parts[index]
		var home: Transform3D = _damage_homes[index]
		var wear: float = clampf(damage * float(part_count + 1) - float(index), 0.0, 1.0)
		part.position = home.origin + home.basis * _damage_axes[index] * data.damage_part_offset * wear
		part.basis = home.basis * Basis(Vector3.RIGHT, deg_to_rad(data.damage_part_tilt) * wear)


func _play_hit(info: DamageInfo) -> void:
	if _hit_sound.stream:
		_hit_sound.play()
	var direction: Vector3 = global_basis.inverse() * info.direction
	direction = Vector3(direction.x, 0.0, direction.z).normalized()
	if direction.is_zero_approx():
		direction = Vector3.FORWARD
	var box: BoxShape3D = _shape.shape as BoxShape3D
	var impact: Vector3 = _shape.position
	if box:
		var half: Vector3 = box.size * 0.5
		var face_distance: float = 1.0 / maxf(absf(direction.x) / half.x, absf(direction.z) / half.z)
		impact -= direction * face_distance
	_hit_dust.position = impact
	_hit_dust.restart()
	_hit_chips.position = impact
	_hit_chips.direction = -direction + Vector3.UP
	_hit_chips.restart()
	ScreenShake.add_trauma(data.hit_trauma)

	_reset_hit()
	_set_flash(true)
	_hit_tween = create_tween().set_parallel()
	var pulse: Vector3 = Vector3(1.0 + data.hit_squash * 0.5, 1.0 - data.hit_squash, 1.0 + data.hit_squash * 0.5)
	var anticipation: float = data.shake_time * 0.25
	var recover: float = data.shake_time - anticipation
	_hit_tween.tween_property(_display, ^"position", _display_home.origin + direction * data.shake_offset, anticipation)
	_hit_tween.tween_property(_display, ^"scale", _display_home.basis.get_scale() * pulse, anticipation)
	_hit_tween.tween_property(_display, ^"position", _display_home.origin, recover).set_delay(anticipation).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_hit_tween.tween_property(_display, ^"scale", _display_home.basis.get_scale(), recover).set_delay(anticipation).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_hit_tween.tween_callback(_set_flash.bind(false)).set_delay(data.flash_time)


func _play_break() -> void:
	_reset_hit()
	_visual.hide()
	_break_dust.restart()
	if _break_sound.stream:
		_break_sound.play()
	if not data:
		_debris.hide()
		return
	ScreenShake.add_trauma(data.break_trauma)
	_debris.show()
	_piece_tween = create_tween().set_parallel()
	for index: int in _chunks.size():
		var chunk: Node3D = _chunks[index]
		var start: Transform3D = chunk.transform
		var land: Transform3D = _landing_pose(index)
		var flight: float = data.debris_time * FLIGHT_FRACTION
		_piece_tween.tween_method(_move_chunk.bind(chunk, start, land, data.debris_lift), 0.0, 1.0, flight)
		_piece_tween.tween_method(_move_chunk.bind(chunk, land, land, data.debris_bounce), 0.0, 1.0, data.debris_time - flight).set_delay(flight)


func _start_rebuild() -> void:
	if _piece_tween and _piece_tween.is_valid():
		_piece_tween.kill()
	_rebuilding = true
	_piece_tween = create_tween().set_parallel()
	for index: int in _chunks.size():
		var chunk: Node3D = _chunks[index]
		_piece_tween.tween_method(_move_chunk.bind(chunk, chunk.transform, _homes[index], data.rebuild_lift), 0.0, 1.0, data.respawn_grow_time).set_delay(float(index) * data.rebuild_stagger)
	_piece_tween.chain().tween_callback(_play_rebuild_finish)
	_piece_tween.chain().tween_interval(data.rebuild_flash_time)
	_piece_tween.chain().tween_callback(_queue_rebuild_finish)


func _play_rebuild_finish() -> void:
	if not use_debris_as_visual:
		_debris.hide()
		_visual.show()
	_set_flash(true)
	_rebuild_dust.restart()
	if _rebuild_sound.stream:
		_rebuild_sound.play()


func _queue_rebuild_finish() -> void:
	_set_flash(false)
	_rebuild_done = true
	set_physics_process(true)


func _finish_rebuild() -> void:
	_rebuilding = false
	_rebuild_done = false
	_timer_elapsed = false
	_blocker.set_deferred(&"monitoring", false)
	for index: int in _damage_parts.size():
		_damage_parts[index].transform = _damage_homes[index]
	_health.heal_full()
	_set_solid(true)
	_finish_rebuild_signal.call_deferred()


func _finish_rebuild_signal() -> void:
	is_broken = false
	respawned.emit()


func _cache_bounds(chunk: Node3D) -> AABB:
	var bounds: AABB = AABB()
	# Dùng được cả mảnh mesh đơn lẫn cụm mesh nhập từ model.
	if chunk is MeshInstance3D:
		var mesh: MeshInstance3D = chunk as MeshInstance3D
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bounds = mesh.get_aabb()
	for child: Node in chunk.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = child as MeshInstance3D
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var offset: Transform3D = chunk.global_transform.affine_inverse() * mesh.global_transform
		var mesh_bounds: AABB = offset * mesh.get_aabb()
		bounds = mesh_bounds if not bounds.has_volume() else bounds.merge(mesh_bounds)
	return bounds


func _landing_pose(index: int) -> Transform3D:
	var home: Transform3D = _homes[index]
	var out: Vector3 = Vector3(home.origin.x, 0.0, home.origin.z).normalized()
	if out.is_zero_approx():
		out = Vector3.RIGHT.rotated(Vector3.UP, TAU * float(index) / float(_chunks.size()))
	var bounds: AABB = _bounds[index]
	var yaw: float = Vector3.FORWARD.signed_angle_to(out, Vector3.UP)
	var turn: float = deg_to_rad(data.debris_landing_turn)
	yaw += randf_range(-turn, turn)
	var basis: Basis = Basis(Vector3.UP, yaw) * Basis(Quaternion(bounds.get_shortest_axis(), Vector3.UP))
	basis = basis.scaled_local(home.basis.get_scale())
	var landed: Vector3 = home.origin + out * data.debris_reach
	# Đặt đáy AABB đã xoay lên đúng mặt sàn, kể cả pivot nằm giữa ván.
	landed.y = -(Transform3D(basis, Vector3.ZERO) * bounds).position.y
	return Transform3D(basis, landed)


func _move_chunk(progress: float, chunk: Node3D, start: Transform3D, finish: Transform3D, lift: float) -> void:
	var pose: Transform3D = start.interpolate_with(finish, progress)
	pose.origin.y += 4.0 * progress * (1.0 - progress) * lift
	chunk.transform = pose


func _reset_hit() -> void:
	if _hit_tween and _hit_tween.is_valid():
		_hit_tween.kill()
	_display.transform = _display_home
	_set_flash(false)


func _set_flash(on: bool) -> void:
	for mesh: GeometryInstance3D in _meshes:
		mesh.material_overlay = flash_material if on else null
