extends EnemyState
## Lần lượt nghỉ, ngồi hoặc nằm; đứng dậy đúng dáng trước khi bắt đầu săn.

var _actor: FireSabretooth
var _time: float
var _pose: StringName
var _sequence_time: float
var _waking: bool
var _cycle: int
var _rest_wait: float


func enter(_previous: StringName) -> void:
	_actor = enemy as FireSabretooth
	_time = 0.0
	_pose = &"Growling"
	_waking = false
	_rest_wait = randf_range(_actor.profile.rest_interval.x, _actor.profile.rest_interval.y)
	_sequence_time = _actor.motion.play(_pose, _actor.profile.bridge_duration, true)


func physics_update(delta: float) -> void:
	_actor.apply_gravity(delta)
	_actor.walk(Vector3.ZERO, 0.0, delta)
	_time += delta
	_actor.reacquire_target()
	if _waking:
		if _actor.motion.finished():
			state_machine.transition_to(_actor.chase_state)
		return
	if _actor.has_target() and not _actor.should_give_up_chase():
		if _actor.is_phase_one() and _pose not in [&"Sit", &"Layout"]:
			state_machine.transition_to(_actor.chase_state)
			return
		_waking = true
		var stand: StringName = &"GetUpMad" if _pose == &"Layout" else &"Startwalk"
		var clips: Array[StringName] = []
		if _pose in [&"Sit", &"Layout"]:
			clips.append(stand)
		if not _actor.is_phase_one():
			clips.append(&"Growling")
		_sequence_time = _actor.motion.play_sequence(clips, _actor.profile.bridge_duration)
		return
	if _time < _sequence_time + _rest_wait:
		return
	_time = 0.0
	_rest_wait = randf_range(_actor.profile.rest_interval.x, _actor.profile.rest_interval.y)
	_cycle = (_cycle + 1) % 3
	if _pose == &"Sit":
		_pose = &"Growling"
		_sequence_time = _actor.motion.play_sequence([&"Startwalk", &"TiredYawn"], _actor.profile.bridge_duration)
	elif _pose == &"Layout":
		_pose = &"Growling"
		_sequence_time = _actor.motion.play_sequence([&"GetUpMad", &"Eating"], _actor.profile.bridge_duration)
	else:
		_pose = &"Sit" if _cycle == 1 else &"Layout"
		var resting: Array[StringName] = [_pose]
		if _pose == &"Sit":
			resting.append(&"Sitting2")
		_sequence_time = _actor.motion.play_sequence(resting, _actor.profile.bridge_duration)
