extends WildSkillAttack
## Bay xuyên quái, vẫn chặn bởi địa hình; khôi phục va chạm trước khi gây AoE lúc đáp.
var _leap: LeapSkillData
var _origin: Vector3
var _destination: Vector3
var _travel: Vector3
var _launched: bool = false
var _passing_enemies: bool = false
var _landing_queued: bool = false
var _enemy_layer: bool = true
var _enemy_mask: bool = true
var _landing_query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
var _ground_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
@onready var _body_shape: CollisionShape3D = owner.get_node("CollisionShape3D") as CollisionShape3D

func enter(previous: StringName) -> void:
	super(previous)
	_leap = _skill as LeapSkillData
	assert(_leap != null and _skill.active_start > _skill.windup_end)
	_origin = _actor.global_position
	_destination = _predicted_landing()
	_travel = Vector3.ZERO
	_launched = false
	_landing_queued = false
	_enemy_layer = _actor.get_collision_layer_value(3)
	_enemy_mask = _actor.get_collision_mask_value(3)
	_landing_query.shape = _body_shape.shape
	_landing_query.collision_mask = 4
	_landing_query.collide_with_areas = false
	_landing_query.exclude = [_actor.get_rid()]
	_ground_query.collision_mask = 257

func exit() -> void:
	_landing_queued = false
	_restore_enemy_collision()
	super()

func landing_position() -> Vector3:
	return _destination

func _update_aim(_previous: float, delta: float) -> void:
	if not _launched:
		_destination = _predicted_landing()
		var direction: Vector3 = _destination - _actor.global_position
		direction.y = 0.0
		_actor.face_direction(direction.normalized(), delta)
		_facing = _actor.get_facing_direction()
		if _elapsed >= _skill.windup_end:
			_launched = true
			_passing_enemies = true
			# Tắt cả hai phía: đồng đội đang chạy cũng không đẩy/chặn người đang bay.
			_actor.set_collision_mask_value(3, false)
			_actor.set_collision_layer_value(3, false)
			_origin = _actor.global_position
			_travel = _destination - _origin
			_travel.y = 0.0
			if not _travel.is_zero_approx():
				_facing = _travel.normalized()
				_actor.face_instantly(_facing)

func _update_melee(previous: float) -> void:
	if _elapsed >= _skill.active_start and not _hit_started and not _landing_queued:
		_landing_queued = true
		_land_and_hit.call_deferred()
	elif _hit_started:
		super(previous)

func _land_and_hit() -> void:
	if not _landing_queued: return
	_landing_queued = false
	# Character.move_and_slide đã tới đích; VFX và hitbox cùng lấy tâm đáp sau khi gỡ chồng người.
	_restore_enemy_collision()
	super._update_melee(0.0)

func _restore_enemy_collision() -> void:
	if not _passing_enemies: return
	if not _actor.is_dead(): _clear_landing_overlap()
	_passing_enemies = false
	_actor.set_collision_layer_value(3, _enemy_layer)
	_actor.set_collision_mask_value(3, _enemy_mask)

func _clear_landing_overlap() -> void:
	var space: PhysicsDirectSpaceState3D = _actor.get_world_3d().direct_space_state
	_landing_query.transform = _body_shape.global_transform
	if space.intersect_shape(_landing_query, 1).is_empty(): return
	var shape_transform: Transform3D = _body_shape.global_transform
	for ring: int in range(1, 13):
		for point: int in 16:
			var angle: float = float(point) * TAU / 16.0 + float(ring % 2) * .19
			var offset: Vector3 = Vector3(cos(angle), 0.0, sin(angle)) * (float(ring) * .2)
			if _actor.test_move(_actor.global_transform, offset): continue
			_landing_query.transform = Transform3D(shape_transform.basis, shape_transform.origin + offset)
			if not space.intersect_shape(_landing_query, 1).is_empty(): continue
			var at: Vector3 = _actor.global_position + offset
			_ground_query.from = at + Vector3.UP * .2
			_ground_query.to = at + Vector3.DOWN * .3
			if space.intersect_ray(_ground_query).is_empty(): continue
			_actor.global_position = at
			return

func _apply_motion(previous: float, delta: float) -> void:
	var interval: float = maxf(_skill.active_start - _skill.windup_end, 0.001)
	var before: float = clampf((previous - _skill.windup_end) / interval, 0.0, 1.0)
	var after: float = clampf((_elapsed - _skill.windup_end) / interval, 0.0, 1.0)
	# Ease-out: bay nhanh rồi giảm tốc đúng lúc hai tay đập xuống.
	var step: float = (1.0 - pow(1.0 - after, 2.0)) - (1.0 - pow(1.0 - before, 2.0))
	_actor.velocity.x = _travel.x * step / maxf(delta, 0.0001)
	_actor.velocity.z = _travel.z * step / maxf(delta, 0.0001)

func _predicted_landing() -> Vector3:
	if not _actor.has_target(): return _actor.global_position
	var point: Vector3 = _actor.target.global_position
	var body: CharacterBody3D = _actor.target as CharacterBody3D
	if body != null:
		point += Vector3(body.velocity.x, 0.0, body.velocity.z) * _leap.prediction_seconds
	var offset: Vector3 = point - _actor.global_position
	offset.y = 0.0
	var distance: float = minf(maxf(offset.length() - _leap.landing_stop_distance, 0.0), maxf(_leap.maximum_leap_distance, 0.0))
	return _actor.global_position + offset.normalized() * distance
