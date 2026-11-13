extends PlayerState
## Lốc xoáy (Thổi gió cấp 2): đứng lại, quay về hướng chuột / input, tới mốc release thì thả một cơn lốc từ pool.
## Cơn lốc tự chạy, tự hút, tự nổ (WindTornado); state chỉ lo động tác thả. Dùng được cả trên đất và trên không.

var _data: WindTornadoData
var _elapsed: float = 0.0
var _released: bool = false
var _aim: Vector3 = Vector3.FORWARD

@onready var _pool: ObjectPool = $Pool


func _ready() -> void:
	super()
	# Pool là node con nên đã tạo sẵn lốc trước dòng này: nối cả lốc có sẵn lẫn lốc tạo thêm về sau
	_pool.configure_instance = _bind_tornado
	for tornado: WindTornado in _pool.get_children():
		_bind_tornado(tornado)


func enter(_previous: StringName) -> void:
	_data = player.start_skill(WindTornadoData.ID) as WindTornadoData
	_elapsed = 0.0
	_released = false
	# Nhắm theo chuột như Thổi gió: câu đố cần thả đúng chỗ người chơi chỉ
	_aim = player.get_mouse_aim_direction()
	if _aim.is_zero_approx():
		var input_direction := player.get_move_direction()
		var preferred := player.get_facing_direction() if input_direction.is_zero_approx() else input_direction.normalized()
		_aim = player.find_attack_direction(preferred)
	player.face_instantly(_aim)
	player.play_action(_data.animation, _data.anim_speed)


func physics_update(delta: float) -> void:
	_elapsed += delta
	player.apply_gravity(delta)
	player.move_toward_direction(Vector3.ZERO, delta)

	if not _released and _elapsed >= _data.release_time:
		_released = true
		var tornado := _pool.acquire() as WindTornado
		tornado.launch(player, _data, player.global_position + _aim * _data.spawn_offset, _aim)

	# Thả xong thì được hủy phần thu tay bằng dash
	if _released and player.can_dash():
		state_machine.transition_to(DASH)
		return

	if _elapsed >= _data.duration:
		if not player.is_on_floor():
			state_machine.transition_to(FALL)
		elif player.get_move_direction().is_zero_approx():
			state_machine.transition_to(IDLE)
		else:
			state_machine.transition_to(RUN)


func _bind_tornado(tornado: WindTornado) -> void:
	tornado.finished.connect(_pool.release.bind(tornado))
