extends EnemyState
var _actor: WildEnemy

func enter(_previous: StringName) -> void:
	_actor = enemy as WildEnemy; _actor.velocity = Vector3.ZERO; _actor.play_anim(&"Idle")

func physics_update(delta: float) -> void:
	_actor.velocity = Vector3.ZERO; _actor.reacquire_target()
	if not _actor.has_target(): return
	_actor.face_direction(_actor.direction_to_target(),delta)
	var skill: EnemySkillData = _actor.choose_skill()
	if skill: _actor.begin_skill(skill)
