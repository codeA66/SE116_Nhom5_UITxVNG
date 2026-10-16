class_name Player
extends Character
## Player: đọc input theo hướng camera, coyote time, các input buffer, nhặt vũ khí, mở khóa kỹ năng.
## Vũ khí và kỹ năng thuộc tiến trình (GameState), không lưu trong player: chuyển scene không bị mất.

const ANIM_IDLE := &"Rig_Medium_General/Idle_A"
const ANIM_RUN := &"Rig_Medium_MovementBasic/Running_A"
const ANIM_JUMP := &"Rig_Medium_MovementBasic/Jump_Start"
const ANIM_FALL := &"Rig_Medium_MovementBasic/Jump_Idle"
const ANIM_PICK_UP := &"Rig_Medium_General/PickUp"
const ANIM_HURT := &"Rig_Medium_General/Hit_A"
const ANIM_DEATH := &"Rig_Medium_General/Death_A"

@export_group("Input Feel")
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.12
@export var attack_buffer_time: float = 0.25
@export var dash_buffer_time: float = 0.15
@export var wind_blast_buffer_time: float = 0.15

@export_group("Fall Recovery")
## Thời gian bất tử sau khi được đưa về chỗ an toàn
@export var recovery_invincibility: float = 1.0
## Số frame trên đất liên tục không gió trước khi một vị trí được coi là an toàn
@export var safe_ground_frames: int = 8

@export_group("Damage Feedback")
## Chu kỳ nháy hình trong lúc bất tử sau khi bị đánh
@export var blink_interval: float = 0.08

@export_group("Combat")
## Bán kính tìm mục tiêu để tự quay về khi ra đòn
@export var soft_lock_range: float = 4.0
## Góc lệch tối đa (độ) giữa hướng input và mục tiêu để được soft-lock
@export var soft_lock_angle: float = 60.0

## Đòn đánh gần nhất trúng player, state Hurt dùng để lấy hướng đẩy lùi
var last_hit: DamageInfo
## Vũ khí đang chờ gắn vào tay trong state PickUp
var pending_weapon: WeaponData

var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _attack_buffer_timer: float = 0.0
var _dash_buffer_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _air_dashes_used: int = 0
var _wind_blast_buffer_timer: float = 0.0
var _wind_blast_cooldown_timer: float = 0.0
## Vị trí trên đất cuối cùng không bị gió đẩy, dùng khi rơi xuống vực
var _last_safe_position: Vector3
## Vị trí trên đất của các frame gần nhất (không gió), phần tử đầu là cũ nhất
var _recent_floor_positions: Array[Vector3] = []
var _blink_time_left: float = 0.0
var _blink_clock: float = 0.0

@onready var hitbox: HitboxComponent = $Model/Hitbox
@onready var wind_blast: WindBlastArea = $Model/WindBlastArea
@onready var interactor: InteractorComponent = $Interactor
@onready var health: HealthComponent = $HealthComponent
@onready var _hurtbox: HurtboxComponent = $HurtboxComponent
@onready var _camera_rig: CameraRig = $CameraRig
@onready var _camera: Camera3D = $CameraRig/Camera3D
@onready var _weapon_socket: Node3D = $WeaponSocket


func _ready() -> void:
	super()
	hitbox.hit.connect(_on_hitbox_hit)
	# Vào scene mới: gắn lại vũ khí đã có trong tiến trình
	_attach_weapon_model(GameState.get_weapon())
	_last_safe_position = global_position
	# Máu được giữ qua các lần chuyển khu (player là object mới mỗi khu)
	var kept_health := GameState.get_player_health()
	if kept_health > 0:
		health.set_current_health(kept_health)
	health.health_changed.connect(_on_health_changed)
	health.died.connect(_on_died)
	_hurtbox.hurt.connect(_on_hurt)
	# Chỉ chạy _process khi đang nháy hình
	set_process(false)


func _process(delta: float) -> void:
	_blink_time_left -= delta
	if _blink_time_left <= 0.0:
		_stop_blink()
		return
	_blink_clock += delta
	model.visible = fmod(_blink_clock, blink_interval * 2.0) >= blink_interval


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


func get_weapon() -> WeaponData:
	return GameState.get_weapon()


func has_weapon() -> bool:
	return get_weapon() != null


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
	pending_weapon = null
	GameState.set_weapon(data)
	_attach_weapon_model(data)


func unlock_ability(ability: AbilityData) -> void:
	GameState.unlock_ability(ability)


func has_ability(id: StringName) -> bool:
	return GameState.has_ability(id)


func get_ability(id: StringName) -> AbilityData:
	return GameState.get_ability(id)


## Đúng khi đã mở khóa dash, có lệnh dash trong buffer, hết cooldown và còn lượt dash trên không
func can_dash() -> bool:
	var dash := get_ability(DashData.ID) as DashData
	if dash == null or _dash_buffer_timer <= 0.0 or _dash_cooldown_timer > 0.0:
		return false
	return is_on_floor() or _air_dashes_used < dash.air_dashes


## Gọi khi vào state Dash: tiêu input, tính cooldown, trừ lượt trên không, bật i-frames
func start_dash() -> DashData:
	var dash := get_ability(DashData.ID) as DashData
	_dash_buffer_timer = 0.0
	_dash_cooldown_timer = dash.duration + dash.cooldown
	if not is_on_floor():
		_air_dashes_used += 1
	_hurtbox.set_invincible(dash.duration)
	return dash


## Đúng khi đã mở khóa kỹ năng gió, có lệnh trong buffer và hết cooldown
func can_wind_blast() -> bool:
	return has_ability(WindBlastData.ID) and _wind_blast_buffer_timer > 0.0 and _wind_blast_cooldown_timer <= 0.0


## Gọi khi vào state WindBlast: tiêu input, tính cooldown
func start_wind_blast() -> WindBlastData:
	var data := get_ability(WindBlastData.ID) as WindBlastData
	_wind_blast_buffer_timer = 0.0
	_wind_blast_cooldown_timer = data.duration + data.cooldown
	return data


## Dịch chuyển kèm đặt lại chỗ an toàn và camera (cổng, hồi sinh)
func teleport(target_position: Vector3, facing: Vector3 = Vector3.ZERO) -> void:
	super(target_position, facing)
	# Chỗ mới là chỗ an toàn ban đầu; bỏ lịch sử vị trí ở chỗ cũ
	_last_safe_position = target_position
	_recent_floor_positions.clear()
	_camera_rig.snap()
	# Player vừa được tạo thì FSM chưa có state hiện tại, khi đó đã ở Idle sẵn
	if state_machine.current_state:
		state_machine.transition_to(PlayerState.IDLE)


## Gọi từ KillZone: đưa về chỗ đứng an toàn gần nhất
func on_kill_zone_entered() -> void:
	return_to_safe_ground()


## Gọi từ KillZone bật Lethal (nước sâu...): chết thật, hồi sinh ở checkpoint qua state Dead
func on_lethal_zone_entered() -> void:
	if not health.is_dead():
		health.take_damage(health.current_health)


## Về chỗ đứng an toàn gần nhất (rơi vực, trúng bẫy). stunned = choáng tại chỗ như bị đánh
func return_to_safe_ground(stunned: bool = false) -> void:
	teleport(_last_safe_position, get_facing_direction())
	_hurtbox.set_invincible(recovery_invincibility)
	if stunned:
		# Không đẩy lùi ở chỗ mới, chỉ choáng
		last_hit = null
		state_machine.transition_to(PlayerState.HURT)


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
		_air_dashes_used = 0
		# Area3D nhận biết vùng gió trễ vài frame: chỉ công nhận vị trí của safe_ground_frames frame trước,
		# khi suốt khoảng đó không có gió. Chỗ an toàn vì vậy luôn lùi khỏi mép vùng gió và mép vực
		if wind_receiver != null and not wind_receiver.get_wind().is_zero_approx():
			_recent_floor_positions.clear()
		else:
			_recent_floor_positions.append(global_position)
			if _recent_floor_positions.size() > safe_ground_frames:
				_last_safe_position = _recent_floor_positions.pop_front()
	else:
		_coyote_timer -= delta

	_jump_buffer_timer = _update_buffer(&"jump", _jump_buffer_timer, jump_buffer_time, delta)
	_attack_buffer_timer = _update_buffer(&"attack", _attack_buffer_timer, attack_buffer_time, delta)
	_dash_buffer_timer = _update_buffer(&"dash", _dash_buffer_timer, dash_buffer_time, delta)
	_dash_cooldown_timer = maxf(_dash_cooldown_timer - delta, 0.0)
	_wind_blast_buffer_timer = _update_buffer(&"skill", _wind_blast_buffer_timer, wind_blast_buffer_time, delta)
	_wind_blast_cooldown_timer = maxf(_wind_blast_cooldown_timer - delta, 0.0)


func _attach_weapon_model(data: WeaponData) -> void:
	for child in _weapon_socket.get_children():
		child.queue_free()
	if data and data.model_scene:
		_weapon_socket.add_child(data.model_scene.instantiate())


func _is_holding_jump() -> bool:
	return Input.is_action_pressed("jump")


func _update_buffer(action: StringName, timer: float, buffer_time: float, delta: float) -> float:
	if Input.is_action_just_pressed(action):
		return buffer_time
	return timer - delta


func _on_hurt(info: DamageInfo, _damage_taken: int) -> void:
	# Đòn kết liễu đã chuyển sang Dead qua signal died
	if health.is_dead():
		return
	last_hit = info
	_start_blink(_hurtbox.invincibility_time)
	state_machine.transition_to(PlayerState.HURT)


func _on_died() -> void:
	_stop_blink()
	state_machine.transition_to(PlayerState.DEAD)


func _on_health_changed(current: int, _max_value: int) -> void:
	GameState.set_player_health(current)


func _start_blink(duration: float) -> void:
	_blink_time_left = duration
	_blink_clock = 0.0
	set_process(true)


func _stop_blink() -> void:
	_blink_time_left = 0.0
	model.visible = true
	set_process(false)


func _on_hitbox_hit(_hurtbox: HurtboxComponent) -> void:
	HitStop.stop(hitbox.attack.hitstop)
