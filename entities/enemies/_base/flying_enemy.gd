class_name FlyingEnemy
extends Enemy
## Lớp cơ sở cho quái luôn bay: còn sống thì lơ lửng cách đất (HoverComponent), không rơi, không chết vì vực / gai.
## Chết rồi thì xác rơi bằng trọng lực thường. Quái bay mới kế thừa lớp này và thêm node HoverComponent.

@onready var hover: HoverComponent = $HoverComponent


## Thay trọng lực bằng hover khi còn sống; mọi state dùng chung gọi hàm này nên tự bay lơ lửng
func apply_gravity(delta: float) -> void:
	if is_dead():
		super(delta)
		return
	hover.apply(self, delta)


## Bay ngang tới direction (độ dài <= 1) bằng air_accel, KHÔNG xoay model (state tự quyết hướng nhìn)
func fly_toward(direction: Vector3, delta: float) -> void:
	var target := direction * movement.max_speed
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(target, movement.air_accel * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z


# Quái bay không rơi vực / không chết vì gai khi còn sống; chết rồi thì xác đã tắt va chạm
func on_kill_zone_entered() -> void:
	pass


func on_lethal_zone_entered(_red_flash: bool = false) -> void:
	pass
