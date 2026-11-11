extends EnemyState
## Đuổi theo mục tiêu bằng clip Walk. Mỗi khung kiểm tra kỹ năng (SpiderSkill) theo thứ tự ưu tiên rồi mới tới cắn;
## kỹ năng nào dùng được (đủ tầm, hết hồi chiêu) thì chuyển sang state đó. Mục tiêu ra quá xa thì bỏ đuổi.

var spider: FireSpider


func _ready() -> void:
	super()
	spider = owner as FireSpider
	assert(spider != null, "SpiderChase chỉ dùng cho FireSpider")


func enter(_previous: StringName) -> void:
	enemy.play_anim(ANIM_WALK)


func physics_update(delta: float) -> void:
	enemy.apply_gravity(delta)
	if enemy.should_give_up_chase():
		enemy.forget_target()
		state_machine.transition_to(PATROL)
		return
	var skill: SpiderSkill = spider.pick_skill()
	if skill != null:
		state_machine.transition_to(skill.name)
		return
	if enemy.can_attack():
		state_machine.transition_to(enemy.attack_state)
		return
	# Trong tầm cắn nhưng còn hồi chiêu: đứng lại quay mặt về mục tiêu (khoảng hở cho player)
	if enemy.distance_to_target() <= enemy.data.attack_range:
		enemy.move_toward_direction(Vector3.ZERO, delta)
		enemy.face_direction(enemy.direction_to_target(), delta)
		return
	enemy.move_toward_direction(enemy.direction_to_target(), delta)
