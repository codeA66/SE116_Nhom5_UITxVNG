class_name BurnableComponent
extends Area3D
## Thứ gì gắn component này thì đốt được (quái, hình nộm, sau này rào gỗ / dây leo / lò lửa).
## Nguồn lửa tìm thấy nó qua collision layer "burnable" rồi gọi ignite(). Có hurtbox thì mỗi tick mất máu
## (đòn FIRE, không khựng); không có hurtbox thì vật tự phản ứng qua signal (rào cháy tan, lò sáng...).
## Không cháy thì tắt _physics_process.

signal ignited
signal extinguished
## damage_taken = 0 khi không có hurtbox hoặc tick bị chặn
signal burn_tick(damage_taken: int)
## Đang cháy + bị gió thổi -> phụt luồng lửa theo hướng gió
signal spread_fired(direction: Vector3)

@export var data: BurnData
## Nhận sát thương mỗi tick; để trống cho vật không có máu
@export var hurtbox: HurtboxComponent
## Dùng chung shape với vùng này (thường là CollisionShape3D của hurtbox) để quái to nhỏ đều khớp, khỏi chỉnh tay.
## Để trống thì tự thêm CollisionShape3D con.
@export var match_shape_of: CollisionShape3D
## Nghe cú gió đẩy để lan lửa; để trống thì vật không lan (thùng gỗ không nhận gió...)
@export var wind_receiver: WindReceiverComponent
## Luồng lửa phụt ra khi đang cháy mà bị gió thổi; để trống thì không lan
@export var fire_spread: FireSpread

var _remaining: float = 0.0
var _tick_timer: float = 0.0
var _source: Node
var _enabled: bool = true
var _last_wind_dir: Vector3 = Vector3.ZERO
## Mốc thời gian (ms) của cú gió mạnh gần nhất
var _last_wind_ms: int = -1000000
## Mốc thời gian (ms) sớm nhất được phụt lửa lại
var _next_spread_ms: int = 0


## Chỉ cho nguồn lửa phát hiện; chép shape hurtbox; chết thì tắt lửa; nghe gió để lan; mặc định nghỉ
func _ready() -> void:
	# Chỉ cần bị nguồn lửa phát hiện, không tự quét
	monitoring = false
	monitorable = true
	if match_shape_of:
		var copy := CollisionShape3D.new()
		copy.shape = match_shape_of.shape
		# Vị trí tương đối với vùng này, để shape trùng hurtbox dù node đặt ở đâu
		copy.transform = global_transform.affine_inverse() * match_shape_of.global_transform
		add_child(copy)
	if hurtbox and hurtbox.health:
		hurtbox.health.died.connect(extinguish)
	if wind_receiver:
		wind_receiver.pushed.connect(_on_wind_pushed)
	set_physics_process(false)


## Chỉ chạy khi đang cháy: đếm thời gian cháy và nhịp tick, hết hạn thì tắt
func _physics_process(delta: float) -> void:
	_remaining -= delta
	_tick_timer -= delta
	if _tick_timer <= 0.0:
		_tick_timer += data.tick_interval
		# Tick đúng lúc hết hạn vẫn tính: 2 s / 1.5 s hay 3 s / 1.5 s đều không bị hụt tick cuối do sai số khung
		if _remaining > -delta:
			_tick()
	if _remaining <= 0.0:
		extinguish()


## Đúng khi đang cháy
func is_burning() -> bool:
	return _remaining > 0.0


## Bật / tắt khả năng bắt lửa (vật đã cháy tan, đang ẩn...). Tắt thì dập lửa đang cháy, ẩn khỏi nguồn lửa,
## và ignite() gọi thẳng cũng không có tác dụng
func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	set_deferred(&"monitorable", enabled)
	if not enabled:
		extinguish()


## Bắt lửa hoặc làm mới thời gian cháy. Đang cháy thì giữ đồng hồ tick:
## phun liên tục vẫn tick đều, không bị reset mãi không tới tick
func ignite(source: Node = null) -> void:
	if not _enabled or data == null or data.immune or data.duration <= 0.0 or not _is_alive():
		return
	_source = source
	var was_burning := is_burning()
	_remaining = data.duration
	if was_burning:
		return
	_tick_timer = data.tick_interval
	set_physics_process(true)
	ignited.emit()
	# Cú gió đẩy cả hàng gần như cùng lúc, thường trước khi lửa lan tới: vừa bắt lửa mà còn trôi thì phụt tiếp.
	# Chỉ tính cú gió mạnh vừa xảy ra: đang trôi vì hố hút thì không phụt theo hướng một cú gió cũ
	if fire_spread and fire_spread.chains_while_pushed() and wind_receiver and wind_receiver.is_being_pushed() \
			and Time.get_ticks_msec() - _last_wind_ms <= int(fire_spread.get_chain_window() * 1000.0):
		_try_spread()


## Người châm lửa ban đầu (player...), để lửa lan / lốc lửa truyền tiếp; null nếu không rõ
func get_source() -> Node:
	return _source if is_instance_valid(_source) else null


## Tắt lửa ngay (hết giờ, chết, hoặc vật thể tự dập); gọi khi không cháy thì bỏ qua
func extinguish() -> void:
	if not is_burning() and not is_physics_processing():
		return
	_remaining = 0.0
	set_physics_process(false)
	extinguished.emit()


## Một nhịp cháy: có hurtbox thì gây đòn FIRE không khựng, rồi báo burn_tick
func _tick() -> void:
	var taken := 0
	if hurtbox:
		var info := DamageInfo.new(data.tick_damage, DamageInfo.Type.FIRE, Vector3.ZERO, _source if is_instance_valid(_source) else null)
		info.staggers = false
		info.ignores_invincibility = data.ignores_invincibility
		var before := hurtbox.health.current_health if hurtbox.health else 0
		if hurtbox.receive_hit(info) and hurtbox.health:
			taken = before - hurtbox.health.current_health
	burn_tick.emit(taken)


## Đúng khi không có máu (vật) hoặc còn sống
func _is_alive() -> bool:
	return hurtbox == null or hurtbox.is_alive()


## Cú gió mạnh đẩy trúng: nhớ hướng + thời điểm (cho lan tiếp lúc bắt lửa ngay sau đó); đang cháy thì phụt lửa ngay.
## Lực đẩy yếu hơn min_impulse (lực kéo mỗi khung của hố hút) bỏ qua: hố hút có luật lốc lửa riêng
func _on_wind_pushed(impulse: Vector3) -> void:
	var flat := Vector3(impulse.x, 0.0, impulse.z)
	if flat.is_zero_approx():
		return
	if fire_spread and flat.length() < fire_spread.get_min_impulse():
		return
	_last_wind_dir = flat.normalized()
	_last_wind_ms = Time.get_ticks_msec()
	if is_burning():
		_try_spread()


## Phụt luồng lửa theo hướng gió gần nhất, tối đa một lần mỗi spread_cooldown (chống lan qua lại vô hạn)
func _try_spread() -> void:
	if fire_spread == null or _last_wind_dir.is_zero_approx():
		return
	var now := Time.get_ticks_msec()
	if now < _next_spread_ms:
		return
	_next_spread_ms = now + int(fire_spread.get_cooldown() * 1000.0)
	fire_spread.spread(global_position, _last_wind_dir, _source if is_instance_valid(_source) else null)
	spread_fired.emit(_last_wind_dir)
