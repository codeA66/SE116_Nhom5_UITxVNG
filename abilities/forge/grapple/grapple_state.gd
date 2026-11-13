extends ForgePlayerState
## Móc kéo: bấm thì tìm vòng móc phía trước (một lần). Có vòng: tới cast_time thì bay thẳng tới vòng, không trọng lực,
## không bị gió đẩy; tới nơi / bị tường chặn / quá giờ thì buông và hất nhẹ lên. Không có vòng: kéo quái nhỏ gần nhất
## phía trước về phía mình; không có gì thì móc hụt. Dây móc là một mesh trụ tạo một lần, kéo giãn theo khoảng cách.

## Đường đi của lần móc: bay tới vòng / kéo quái / hụt
enum Mode { RING, ENEMY, WHIFF }

var _data: GrappleData
var _mode: Mode = Mode.WHIFF
var _ring: GrappleRing
var _enemy: Enemy
var _direction: Vector3 = Vector3.ZERO
var _elapsed: float = 0.0
var _pulling: bool = false
var _pull_time_limit: float = 0.0
var _stall: int = 0
var _rope: MeshInstance3D
var _rope_mesh: CylinderMesh


func enter(_previous: StringName) -> void:
	_data = player.start_skill(GrappleData.ID) as GrappleData
	_direction = get_cast_direction()
	_elapsed = 0.0
	_pulling = false
	_stall = 0
	player.face_instantly(_direction)
	player.play_action(_data.animation, _data.anim_speed)
	var eye := _hand()
	var exclude: Array[RID] = [player.get_rid()]
	_ring = GrappleRing.find_best(player.get_tree(), player.get_world_3d().direct_space_state, eye, _direction,
			_data.ring_range, _data.get_cos_half_arc(), _data.wall_mask, exclude)
	_enemy = null
	if _ring:
		_mode = Mode.RING
	else:
		_enemy = _find_enemy(eye, exclude)
		_mode = Mode.ENEMY if _enemy else Mode.WHIFF


func exit() -> void:
	player.external_forces_enabled = true
	if _rope:
		_rope.visible = false


func physics_update(delta: float) -> void:
	_elapsed += delta
	match _mode:
		Mode.RING:
			_update_ring(delta)
		_:
			_update_short(delta)


## Có vòng: đứng ngắm tới cast_time rồi bay; dây nối tay - vòng suốt lúc bay
func _update_ring(delta: float) -> void:
	if not is_instance_valid(_ring):
		_release()
		return
	_show_rope(_ring.global_position)
	if not _pulling:
		player.apply_gravity(delta)
		player.move_toward_direction(Vector3.ZERO, delta)
		if _elapsed < _data.cast_time:
			return
		_pulling = true
		player.external_forces_enabled = false
		_pull_time_limit = _elapsed + player.global_position.distance_to(_ring.get_pull_target()) / _data.pull_speed + _data.extra_time
	var to_target := _ring.get_pull_target() - player.global_position
	if to_target.length() <= _data.arrive_distance or _elapsed >= _pull_time_limit:
		_release()
		return
	# Vận tốc thực (sau move_and_slide frame trước) quá chậm nhiều frame liền = đâm tường
	if player.get_real_velocity().length() < _data.pull_speed * _data.stall_ratio and _elapsed > _data.cast_time + delta * 2.0:
		_stall += 1
		if _stall >= _data.stall_frames:
			_release()
			return
	else:
		_stall = 0
	player.velocity = to_target.normalized() * _data.pull_speed
	player.face_instantly(Vector3(to_target.x, 0.0, to_target.z))


## Kéo quái / móc hụt: đứng ra chiêu, tới cast_time thì kéo quái (nếu có), hết whiff_duration thì xong
func _update_short(delta: float) -> void:
	player.apply_gravity(delta)
	player.move_toward_direction(Vector3.ZERO, delta)
	if _elapsed < _data.cast_time:
		_show_rope(_hand() + _direction * minf(_elapsed / maxf(_data.cast_time, 0.01), 1.0) * _reach())
	elif not _pulling:
		_pulling = true
		if _mode == Mode.ENEMY and is_instance_valid(_enemy):
			_pull_enemy(_enemy)
	elif _rope:
		_rope.visible = false
	if _elapsed >= maxf(_data.whiff_duration, _data.cast_time):
		finish()


## Buông móc: hất lên + tới trước để đáp lên bục cạnh vòng
func _release() -> void:
	player.external_forces_enabled = true
	var forward := Vector3(player.velocity.x, 0.0, player.velocity.z)
	forward = forward.normalized() if not forward.is_zero_approx() else _direction
	player.velocity = forward * _data.release_forward_speed + Vector3.UP * _data.release_up_speed
	finish()


## Kéo quái về phía player: vận tốc đẩy giảm đều theo push_decay của quái, tính vận tốc đầu để dừng cách stop_distance
func _pull_enemy(enemy: Enemy) -> void:
	var receiver := enemy.wind_receiver
	if receiver == null:
		return
	var offset := player.global_position - enemy.global_position
	offset.y = 0.0
	var travel := offset.length() - _data.enemy_stop_distance
	if travel <= 0.0:
		return
	receiver.push(offset.normalized() * sqrt(2.0 * receiver.push_decay * travel))


## Quái còn sống gần nhất trong tầm, trong cung trước mặt, không bị tường chắn
func _find_enemy(eye: Vector3, exclude: Array[RID]) -> Enemy:
	var best: Enemy
	var best_distance := _data.enemy_range
	var cos_half := _data.get_cos_half_arc()
	var query := PhysicsRayQueryParameters3D.create(eye, eye, _data.wall_mask, exclude)
	var space := player.get_world_3d().direct_space_state
	for node: Node in player.get_tree().get_nodes_in_group(HurtboxComponent.GROUP):
		var hurtbox := node as HurtboxComponent
		var enemy := hurtbox.owner as Enemy if hurtbox else null
		if enemy == null or not hurtbox.is_alive() or enemy.wind_receiver == null:
			continue
		var offset := enemy.global_position - player.global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance >= best_distance or (distance > 0.01 and offset.normalized().dot(_direction) < cos_half):
			continue
		query.to = enemy.global_position + Vector3.UP * _data.hand_height
		var skip: Array[RID] = exclude.duplicate()
		skip.append(enemy.get_rid())
		query.exclude = skip
		if not space.intersect_ray(query).is_empty():
			continue
		best = enemy
		best_distance = distance
	return best


func _hand() -> Vector3:
	return player.global_position + Vector3.UP * _data.hand_height


func _reach() -> float:
	if _mode == Mode.ENEMY and is_instance_valid(_enemy):
		return _hand().distance_to(_enemy.global_position + Vector3.UP * _data.hand_height)
	return _data.ring_range


## Dây móc từ tay tới target: trụ đơn vị trục Y, đặt giữa hai đầu, giãn theo chiều dài
func _show_rope(target: Vector3) -> void:
	if _rope == null:
		_rope_mesh = CylinderMesh.new()
		_rope_mesh.height = 1.0
		_rope_mesh.radial_segments = 6
		_rope_mesh.rings = 1
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_rope_mesh.material = material
		_rope = MeshInstance3D.new()
		_rope.name = "GrappleRope"
		_rope.mesh = _rope_mesh
		_rope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_rope.top_level = true
		player.add_child(_rope)
	(_rope_mesh.material as StandardMaterial3D).albedo_color = _data.rope_color
	_rope_mesh.top_radius = _data.rope_radius
	_rope_mesh.bottom_radius = _data.rope_radius
	var from := _hand()
	var span := target - from
	var length := span.length()
	if length < 0.01:
		_rope.visible = false
		return
	var axis_y := span / length
	var helper := Vector3.UP if absf(axis_y.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var axis_x := helper.cross(axis_y).normalized()
	var axis_z := axis_x.cross(axis_y)
	_rope.global_transform = Transform3D(Basis(axis_x, axis_y * length, axis_z), from + span * 0.5)
	_rope.visible = true
