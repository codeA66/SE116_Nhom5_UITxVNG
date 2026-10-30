class_name BossDead
extends BossState
## State tử trận của Boss.

func enter(_previous: StringName) -> void:
	boss.play_anim(&"Dying")
	boss.on_death()


func physics_update(delta: float) -> void:
	boss.apply_gravity(delta)
	boss.move_toward_direction(Vector3.ZERO, delta)
