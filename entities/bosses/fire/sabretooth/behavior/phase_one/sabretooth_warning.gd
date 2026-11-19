extends EnemyState
## Giữ thân khi gầm, chốt loại đòn ở cuối nhịp để player có thể dụ đòn theo vị trí.

var _actor: FireSabretooth
var _selected: SabretoothSkill
var _committed: bool


func enter(_previous: StringName) -> void:
	_actor = enemy as FireSabretooth
	_actor.velocity.x = 0.0
	_actor.velocity.z = 0.0
	_selected = null
	_committed = false
	_actor.set_telegraph(true)
	_actor.motion.play_warning(_actor.profile.warning_duration, _actor.profile.warning_bridge)


func exit() -> void:
	_actor.set_telegraph(false)


func physics_update(delta: float) -> void:
	_actor.apply_gravity(delta)
	if _actor.should_give_up_chase():
		state_machine.transition_to(IDLE)
		return
	if not _committed and _actor.motion.remaining() <= _actor.profile.warning_commit_before_end:
		_committed = true
		if _actor.phase_one_can_prepare():
			_selected = _actor.select_phase_one_skill()
	if not _actor.motion.finished():
		return
	if _selected:
		_actor.begin_skill(_selected)
	else:
		_actor.phase_one_prepared = true
		state_machine.transition_to(_actor.chase_state)
