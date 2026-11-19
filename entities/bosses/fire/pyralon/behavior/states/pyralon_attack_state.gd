class_name PyralonAttackState
extends EnemyState

var bird: Pyralon
var skill: FireBossStrike
var animator: AnimationPlayer
var elapsed: float


func enter(_previous: StringName) -> void:
	bird = enemy as Pyralon
	animator = bird.animation_player()
	skill = bird.pending_skill as FireBossStrike
	elapsed = 0.0
	bird.velocity = Vector3.ZERO
	animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	bird.play_action(skill.animation, 1.0, 0.10)
	bird.skill_started.emit(skill)


func exit() -> void:
	bird.hitbox.cancel()
	bird.set_air_pose(false)
	animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS


func tick_pose(delta: float) -> void:
	elapsed += delta
	animator.advance(delta)
	bird.pose.update_bones()


func stay_in_place(delta: float, airborne: bool = false) -> void:
	bird.velocity.x = 0.0
	bird.velocity.z = 0.0
	if airborne:
		bird.velocity.y = 0.0
	else:
		bird.apply_gravity(delta)
	bird.set_air_pose(airborne)
