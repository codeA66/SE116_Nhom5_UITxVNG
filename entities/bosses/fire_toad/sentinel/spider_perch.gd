class_name SpiderPerch
extends EnemyState
## Nhện canh góc (Ếch Hoả Vương gọi khi rút ra ngoài sân): đứng yên trên bệ, quay theo player và dùng kỹ năng
## (phun tơ) mỗi khi hồi xong. Không đuổi, không rời bệ. Dùng làm chase_state của biến thể nhện canh: các state
## có sẵn (Idle thấy player, phun tơ xong) tự quay về đây, không phải sửa state của Nhện Lửa.

var spider: FireSpider


func _ready() -> void:
	super()
	spider = owner as FireSpider


func enter(_previous: StringName) -> void:
	enemy.velocity.x = 0.0
	enemy.velocity.z = 0.0
	enemy.play_anim(ANIM_IDLE)


func physics_update(delta: float) -> void:
	enemy.apply_gravity(delta)
	enemy.move_toward_direction(Vector3.ZERO, delta)
	enemy.reacquire_target()
	if not enemy.has_target():
		return
	enemy.face_direction(enemy.direction_to_target(), delta)
	var skill := spider.pick_skill() if spider else null
	if skill:
		state_machine.transition_to(skill.name)
