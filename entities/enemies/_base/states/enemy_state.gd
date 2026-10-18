class_name EnemyState
extends State
## State dành cho quái: có sẵn tham chiếu enemy và tên các state dùng chung.
## Quái có hành vi riêng thêm state mới (kế thừa lớp này), không sửa state dùng chung.

const IDLE := &"Idle"
const PATROL := &"Patrol"
const CHASE := &"Chase"
const ATTACK := &"Attack"
const HURT := &"Hurt"
const BLOWN := &"Blown"
const DEAD := &"Dead"

## Tên animation mặc định; model nào có clip trùng tên thì tự chạy, không có thì bỏ qua
const ANIM_IDLE := &"Idle"
const ANIM_WALK := &"Walk"
const ANIM_RUN := &"Run"
const ANIM_HURT := &"Hurt"
const ANIM_DEATH := &"Death"

var enemy: Enemy


func _ready() -> void:
	# owner là node gốc của scene (quái), có sẵn trước khi _ready chạy
	enemy = owner as Enemy
	assert(enemy != null, "EnemyState phải nằm trong scene kế thừa Enemy")


## Dùng chung: có mục tiêu thì chuyển sang đuổi
func _check_target() -> bool:
	if enemy.has_target() and not enemy.should_give_up_chase():
		state_machine.transition_to(enemy.chase_state)
		return true
	return false
