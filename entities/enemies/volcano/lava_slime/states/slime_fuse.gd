extends EnemyState
## Châm ngòi rồi nổ (attack_state của Slime Dung Nham): đứng yên, quay về player, ngòi đầy dần trong fuse_time;
## đầy thì nổ. Player ra ngoài fuse_cancel_range (hoặc mất mục tiêu) thì thôi châm, quay lại nảy đuổi.
## Bị thổi / đánh văng thì state khác chen vào: exit() xì hơi, ngòi tụt dần chứ không mất hết.

var slime: LavaSlime


func _ready() -> void:
	super()
	slime = owner as LavaSlime
	assert(slime != null, "SlimeFuse chỉ dùng cho LavaSlime")


func enter(_previous: StringName) -> void:
	slime.velocity.x = 0.0
	slime.velocity.z = 0.0
	slime.begin_fuse()


func exit() -> void:
	slime.end_fuse()


func physics_update(delta: float) -> void:
	slime.apply_gravity(delta)
	slime.move_toward_direction(Vector3.ZERO, delta)
	if not slime.has_target() or slime.distance_to_target() > slime.slime_data.fuse_cancel_range:
		state_machine.transition_to(slime.chase_state if slime.has_target() else IDLE)
		return
	slime.face_direction(slime.direction_to_target(), delta)
	if slime.advance_fuse(delta):
		slime.explode()
