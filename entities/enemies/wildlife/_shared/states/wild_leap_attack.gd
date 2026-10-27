extends WildSkillAttack
## Đến điểm đáp đúng active_start của động tác cào; CharacterBody vẫn chặn bởi tường/quái.
var _leap: LeapSkillData
var _origin: Vector3
var _destination: Vector3
var _travel: Vector3
var _launched: bool = false

func enter(previous: StringName) -> void:
	super(previous)
	_leap = _skill as LeapSkillData
	assert(_leap != null and _skill.active_start > _skill.windup_end)
	_origin = _actor.global_position
	_destination = _predicted_landing()
	_travel = Vector3.ZERO
	_launched = false

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
			_origin = _actor.global_position
			_travel = _destination - _origin
			_travel.y = 0.0
			if not _travel.is_zero_approx():
				_facing = _travel.normalized()
				_actor.face_instantly(_facing)

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
