extends SpiderSkill
## Phun tơ: đứng lại cong bụng (nháy báo trước, quay theo player), tới web_spit_time thì chốt hướng và nhả một
## đạn tơ (WebBolt). Không phun khi player đang dính tơ rồi (không chồng tơ). Bị đánh giữa chừng thì state khác chen vào:
## exit() hủy báo trước, đã tính hồi chiêu; đạn chưa nhả thì không nhả.

const ANIM_WEB := &"WebShot"

var _elapsed: float = 0.0
var _fired: bool = false


func can_use() -> bool:
	if spider.spider_data.web == null or not super():
		return false
	return not WebEntangle.is_entangled_node(enemy.target)


func enter(_previous: StringName) -> void:
	_elapsed = 0.0
	_fired = false
	enemy.face_instantly(enemy.direction_to_target())
	enemy.velocity.x = 0.0
	enemy.velocity.z = 0.0
	enemy.set_telegraph(true)
	var data: FireSpiderData = spider.spider_data
	var length: float = spider.get_animation_length(ANIM_WEB)
	enemy.play_action(ANIM_WEB, length / data.web_duration if length > 0.0 else 1.0)


func exit() -> void:
	enemy.set_telegraph(false)
	start_cooldown()


func physics_update(delta: float) -> void:
	_elapsed += delta
	enemy.apply_gravity(delta)
	enemy.move_toward_direction(Vector3.ZERO, delta)
	var data: FireSpiderData = spider.spider_data
	if not _fired:
		enemy.face_direction(enemy.direction_to_target(), delta)
		if _elapsed >= data.web_spit_time:
			_fired = true
			enemy.set_telegraph(false)
			var direction: Vector3 = spider.web_aim_direction()
			enemy.face_instantly(direction)
			spider.shoot_web(direction)
	if _elapsed >= data.web_duration:
		state_machine.transition_to(enemy.chase_state if enemy.has_target() else IDLE)


func _min_range() -> float:
	return spider.spider_data.web_min_range


func _max_range() -> float:
	return spider.spider_data.web_max_range


func _cooldown_time() -> float:
	return spider.spider_data.web_cooldown
