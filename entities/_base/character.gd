class_name Character
extends CharacterBody3D
## Lớp cơ sở cho mọi nhân vật (player, quái, boss).
## Lo vật lý, xoay model, animation và chạy FSM. Lớp con chỉ quyết định "muốn đi hướng nào".
## Scene của lớp con phải có các node: Model, AnimationPlayer, StateMachine.

const ANIM_BLEND := 0.15

@export var movement: MovementStats

var gravity: float
var jump_velocity: float
## Tắt để bỏ qua lực ngoài (gió...), ví dụ trong lúc dash
var external_forces_enabled: bool = true

@onready var model: Node3D = $Model
@onready var state_machine: StateMachine = $StateMachine
## Không bắt buộc: nhân vật không có node này thì không chịu gió
@onready var wind_receiver: WindReceiverComponent = get_node_or_null(^"WindReceiverComponent")
@onready var _anim: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	assert(movement != null, "%s chưa gán MovementStats" % name)
	# Tính từ chiều cao và thời gian lên đỉnh, chỉnh 2 số này thay vì đoán lực nhảy
	# g = 2h / t * t , v = gt
	gravity = 2.0 * movement.jump_height / (movement.time_to_apex * movement.time_to_apex)
	jump_velocity = gravity * movement.time_to_apex


func _physics_process(delta: float) -> void:
	# Thứ tự cố định: chuẩn bị (lớp con) -> state quyết định -> áp dụng vật lý
	_pre_state_update(delta)
	state_machine.physics_update(delta)
	if wind_receiver and external_forces_enabled:
		wind_receiver.move_with_wind(self, delta)
	else:
		move_and_slide()


func apply_gravity(delta: float) -> void:
	if is_on_floor():
		return
	var g := gravity
	if velocity.y < 0.0:
		g *= movement.fall_gravity_mult
	elif absf(velocity.y) < movement.apex_threshold and _is_holding_jump():
		g *= movement.apex_gravity_mult
	velocity.y = maxf(velocity.y - g * delta, -movement.max_fall_speed)


## Tăng/giảm tốc về phía direction (đã chuẩn hóa, độ dài <= 1) và xoay model theo hướng đó
## Di chuyển có quán tính chia thành 4 lớp trên không, dừng lại, quay đầu, chạy
func move_toward_direction(direction: Vector3, delta: float) -> void:
	var target := direction * movement.max_speed
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)

	var accel: float
	if not is_on_floor():
		accel = movement.air_accel
	elif direction.is_zero_approx():
		accel = movement.ground_decel
	elif horizontal.dot(target) < 0.0:
		accel = movement.turn_accel
	else:
		accel = movement.ground_accel

	horizontal = horizontal.move_toward(target, accel * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	face_direction(direction, delta)


func face_direction(direction: Vector3, delta: float) -> void:
	if direction.is_zero_approx():
		return
	var target_angle := atan2(direction.x, direction.z)
	model.rotation.y = lerp_angle(model.rotation.y, target_angle, 1.0 - exp(-movement.rotation_speed * delta))


## Quay ngay lập tức, dùng khi ra đòn để đòn đánh đúng hướng
func face_instantly(direction: Vector3) -> void:
	if direction.is_zero_approx():
		return
	model.rotation.y = atan2(direction.x, direction.z)


## Hướng model đang nhìn (mặt phẳng ngang)
func get_facing_direction() -> Vector3:
	return Vector3(sin(model.rotation.y), 0.0, cos(model.rotation.y))


func jump() -> void:
	velocity.y = jump_velocity


func cut_jump() -> void:
	if velocity.y > 0.0:
		velocity.y *= movement.jump_cut_mult


func play_anim(anim_name: StringName) -> void:
	if _anim.current_animation != anim_name:
		_anim.play(anim_name, ANIM_BLEND)


## Chạy animation hành động từ đầu (kể cả khi đang chạy chính nó), dùng cho đòn đánh, nhặt đồ
func play_action(anim_name: StringName, speed: float = 1.0) -> void:
	_anim.play(anim_name, ANIM_BLEND, speed)
	_anim.seek(0.0, true)


## Lớp con ghi đè để cập nhật timer, cảm biến AI... trước khi state chạy
func _pre_state_update(_delta: float) -> void:
	pass


## Lớp con ghi đè nếu có "giữ nút nhảy" (player).
func _is_holding_jump() -> bool:
	return false
