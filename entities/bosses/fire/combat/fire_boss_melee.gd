extends WildSkillAttack
## Tịnh tiến CharacterBody trong cửa sổ lao của đòn, dùng va chạm thật với sàn và tường.

func _update_melee(_previous: float) -> void:
	(_skill as FireBossStrike).update_hitbox(_actor.hitbox, _elapsed, _speed_scale)


func _apply_motion(previous: float, delta: float) -> void:
	var advance := maxf(0.0, minf(_elapsed, _skill.windup_end + _skill.lunge_time) - maxf(previous, _skill.windup_end))
	var speed := _skill.lunge_speed * advance / maxf(delta, 0.0001)
	_actor.velocity.x = _facing.x * speed
	_actor.velocity.z = _facing.z * speed
