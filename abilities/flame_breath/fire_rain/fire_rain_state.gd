extends PlayerState
## Mưa Hỏa Tiễn (Phun lửa cấp 2, kiểu chiêu R của Rumble). Bấm giữ phím: chỗ chuột lúc bấm là điểm đầu đường lửa
## (kẹp trong max_cast_range quanh cáo), rê chuột để chọn hướng, cáo vẫn đi chậm được. Thả phím: trừ năng lượng,
## tính hồi chiêu, lấy một FireRain từ pool gọi mưa. Dash hoặc bị đánh trúng lúc đang ngắm thì hủy, không tốn gì
## (chỉ thả phím mới gọi start_skill). Đường lửa tự chạy (FireRain); state chỉ lo ngắm và động tác thả.
## Đặt trong nhánh kỹ năng (không ở states/action) vì thư mục đó đã đủ mục.

## Vạch ngắm trên sàn
@export var aim_visual: FireRainAimVfx

## Nguồn điểm chuột trên sàn (Vector3, INF nếu không có). Trống = chuột thật; test / demo tự động gán để điều khiển
var cursor_source: Callable

var _data: FireRainData
var _start: Vector3 = Vector3.ZERO
var _direction: Vector3 = Vector3.FORWARD
var _aiming: bool = false
var _cast_clock: float = 0.0

@onready var _pool: ObjectPool = $Pool


func _ready() -> void:
	super()
	# Pool là node con nên đã tạo sẵn trước dòng này: nối cả đối tượng có sẵn lẫn tạo thêm về sau
	_pool.configure_instance = _bind
	for fire_rain: FireRain in _pool.get_children():
		_bind(fire_rain)


## Điểm đầu đường lửa đang ngắm
func get_line_start() -> Vector3:
	return _start


## Hướng (ngang, đã chuẩn hoá) của đường lửa đang ngắm
func get_line_direction() -> Vector3:
	return _direction


func enter(_previous: StringName) -> void:
	_data = _current_form()
	_aiming = true
	_cast_clock = 0.0
	var origin := player.global_position
	var cursor := _cursor_point()
	var offset := Vector3.ZERO
	if cursor.is_finite():
		offset = cursor - origin
		offset.y = 0.0
	if offset.length() < 0.05:
		offset = player.get_facing_direction() * minf(_data.min_drag * 2.0, _data.max_cast_range)
	_start = origin + offset.limit_length(_data.max_cast_range)
	_start.y = origin.y
	_direction = _fallback_direction()
	_update_direction()


func exit() -> void:
	# Rời state lúc còn ngắm (dash, bị đánh, mất điều khiển): hủy, chưa tốn gì
	if _aiming:
		_aiming = false
		if aim_visual:
			aim_visual.cancel()


func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	if _aiming:
		_aim(delta)
	else:
		_cast(delta)


func _aim(delta: float) -> void:
	if not player.controls_enabled or player.health.is_dead():
		state_machine.transition_to(IDLE)
		return
	if player.can_dash():
		state_machine.transition_to(DASH)
		return
	var move := player.get_move_direction()
	player.move_toward_direction(move * _data.aim_move_scale, delta)
	player.play_anim(Player.ANIM_IDLE if move.is_zero_approx() else Player.ANIM_RUN)
	_update_direction()
	if aim_visual:
		aim_visual.show_line(_start, _direction, _data.line_length, _data.line_width)
	if not Input.is_action_pressed(_data.input_action):
		_release()


func _release() -> void:
	if not player.energy.can_spend(_data.energy_cost):
		player.energy.notify_insufficient(_data.energy_cost)
		state_machine.transition_to(IDLE)
		return
	_aiming = false
	# Tới lúc này mới trừ năng lượng và tính hồi chiêu (ngắm rồi hủy thì không mất gì)
	player.start_skill(FireRainData.ID)
	if aim_visual:
		aim_visual.commit()
	var toward := _start + _direction * _data.line_length * 0.5 - player.global_position
	toward.y = 0.0
	if not toward.is_zero_approx():
		player.face_instantly(toward.normalized())
	player.play_action(_data.animation, _data.anim_speed)
	# Gọi mưa ngay lúc thả: mốc rơi do first_impact_delay lo, bị đánh giữa động tác cũng không mất chiêu đã trả
	var fire_rain := _pool.acquire() as FireRain
	fire_rain.launch(player, _data, _start, _direction)


func _cast(delta: float) -> void:
	_cast_clock += delta
	player.move_toward_direction(Vector3.ZERO, delta)
	if player.can_dash():
		state_machine.transition_to(DASH)
		return
	if _cast_clock < _data.cast_duration:
		return
	if not player.is_on_floor():
		state_machine.transition_to(FALL)
	elif player.get_move_direction().is_zero_approx():
		state_machine.transition_to(IDLE)
	else:
		state_machine.transition_to(RUN)


## Hướng = từ điểm đầu tới chuột; chuột còn sát điểm đầu thì giữ hướng cũ
func _update_direction() -> void:
	var cursor := _cursor_point()
	if not cursor.is_finite():
		return
	var drag := cursor - _start
	drag.y = 0.0
	if drag.length() >= _data.min_drag:
		_direction = drag.normalized()


## Chưa rê chuột: đường chạy thẳng từ cáo qua điểm đầu (hoặc theo hướng cáo nếu điểm đầu ngay chân)
func _fallback_direction() -> Vector3:
	var away := _start - player.global_position
	away.y = 0.0
	if away.length() > 0.05:
		return away.normalized()
	var facing := player.get_facing_direction()
	facing.y = 0.0
	return facing.normalized() if not facing.is_zero_approx() else Vector3.FORWARD


func _cursor_point() -> Vector3:
	if cursor_source.is_valid():
		return cursor_source.call()
	# Chạy headless (test tự động) không có chuột thật
	if DisplayServer.get_name() == "headless":
		return Vector3.INF
	return player.project_cursor_to_height(get_viewport().get_mouse_position(), player.global_position.y)


## Dạng Mưa Hỏa Tiễn của kỹ năng đang mở (kỹ năng gốc là Phun lửa đã nâng cấp)
func _current_form() -> FireRainData:
	for ability in GameState.get_abilities():
		var skill := ability as SkillData
		if skill:
			var form := player.get_skill_form(skill) as FireRainData
			if form:
				return form
	return null


func _bind(fire_rain: FireRain) -> void:
	fire_rain.finished.connect(_pool.release.bind(fire_rain))
