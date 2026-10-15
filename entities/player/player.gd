class_name Player
extends Character
## Player: đọc input theo hướng camera, coyote time, jump buffer, attack buffer, nhặt và cầm vũ khí.

const ANIM_IDLE := &"Rig_Medium_General/Idle_A"
const ANIM_RUN := &"Rig_Medium_MovementBasic/Running_A"
const ANIM_JUMP := &"Rig_Medium_MovementBasic/Jump_Start"
const ANIM_FALL := &"Rig_Medium_MovementBasic/Jump_Idle"
const ANIM_PICK_UP := &"Rig_Medium_General/PickUp"

@export_group("Input Feel")
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.12
@export var attack_buffer_time: float = 0.25

@export_group("Combat")
## Bán kính tìm mục tiêu để tự quay về khi ra đòn
@export var soft_lock_range: float = 4.0
## Góc lệch tối đa (độ) giữa hướng input và mục tiêu để được soft-lock
@export var soft_lock_angle: float = 60.0

var weapon: WeaponData
## Vũ khí đang chờ gắn vào tay trong state PickUp
var pending_weapon: WeaponData

var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _attack_buffer_timer: float = 0.0

@onready var hitbox: HitboxComponent = $Model/Hitbox
@onready var interactor: InteractorComponent = $Interactor
@onready var _camera: Camera3D = $CameraRig/Camera3D
@onready var _weapon_socket: Node3D = $WeaponSocket


func _ready() -> void:
	super()
	hitbox.hit.connect(_on_hitbox_hit)


func get_move_direction() -> Vector3:
	# get_vector đã chuẩn hóa: đi chéo không nhanh hơn, có deadzone cho tay cầm
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var cam_basis := _camera.global_basis
	var forward := Vector3(-cam_basis.z.x, 0.0, -cam_basis.z.z).normalized()
	var right := Vector3(cam_basis.x.x, 0.0, cam_basis.x.z).normalized()
	return right * input.x - forward * input.y


## Đúng khi có jump buffer và còn coyote time
func can_jump() -> bool:
	return _jump_buffer_timer > 0.0 and _coyote_timer > 0.0


func jump() -> void:
	super()
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0


func has_weapon() -> bool:
	return weapon != null


## Đúng khi đang cầm vũ khí và có lệnh đánh trong buffer
func can_attack() -> bool:
	return has_weapon() and _attack_buffer_timer > 0.0


func consume_attack_input() -> void:
	_attack_buffer_timer = 0.0


## Gọi từ vật phẩm khi được tương tác: chuyển sang state nhặt, vũ khí gắn vào tay trong lúc nhặt
func pick_up_weapon(data: WeaponData) -> void:
	pending_weapon = data
	state_machine.transition_to(PlayerState.PICK_UP)


func equip_weapon(data: WeaponData) -> void:
	weapon = data
	pending_weapon = null
	for child in _weapon_socket.get_children():
		child.queue_free()
	if data and data.model_scene:
		_weapon_socket.add_child(data.model_scene.instantiate())


## Hướng ra đòn: ưu tiên mục tiêu gần nhất nằm trong tầm và lệch không quá soft_lock_angle so với preferred
func find_attack_direction(preferred: Vector3) -> Vector3:
	var best_direction := preferred
	var best_distance := INF
	for node in get_tree().get_nodes_in_group(HurtboxComponent.GROUP):
		var hurtbox := node as HurtboxComponent
		# Chỉ nhắm vào phe mà hitbox của mình đánh được
		if hurtbox.collision_layer & hitbox.collision_mask == 0 or not hurtbox.is_alive():
			continue
		var offset := hurtbox.global_position - global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance > soft_lock_range or distance < 0.01:
			continue
		var direction := offset / distance
		if rad_to_deg(preferred.angle_to(direction)) > soft_lock_angle:
			continue
		if distance < best_distance:
			best_distance = distance
			best_direction = direction
	return best_direction


func _pre_state_update(delta: float) -> void:
	if is_on_floor():
		_coyote_timer = coyote_time
	else:
		_coyote_timer -= delta

	_jump_buffer_timer = _update_buffer(&"jump", _jump_buffer_timer, jump_buffer_time, delta)
	_attack_buffer_timer = _update_buffer(&"attack", _attack_buffer_timer, attack_buffer_time, delta)


func _is_holding_jump() -> bool:
	return Input.is_action_pressed("jump")


func _update_buffer(action: StringName, timer: float, buffer_time: float, delta: float) -> float:
	if Input.is_action_just_pressed(action):
		return buffer_time
	return timer - delta


func _on_hitbox_hit(_hurtbox: HurtboxComponent) -> void:
	HitStop.stop(hitbox.attack.hitstop)
