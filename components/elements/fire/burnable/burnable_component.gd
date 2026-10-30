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

@export var data: BurnData
## Nhận sát thương mỗi tick; để trống cho vật không có máu
@export var hurtbox: HurtboxComponent
## Dùng chung shape với vùng này (thường là CollisionShape3D của hurtbox) để quái to nhỏ đều khớp, khỏi chỉnh tay.
## Để trống thì tự thêm CollisionShape3D con.
@export var match_shape_of: CollisionShape3D

var _remaining: float = 0.0
var _tick_timer: float = 0.0
var _source: Node


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
	set_physics_process(false)


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


func is_burning() -> bool:
	return _remaining > 0.0


## Bắt lửa hoặc làm mới thời gian cháy. Đang cháy thì giữ đồng hồ tick:
## phun liên tục vẫn tick đều, không bị reset mãi không tới tick
func ignite(source: Node = null) -> void:
	if data == null or data.immune or data.duration <= 0.0 or not _is_alive():
		return
	_source = source
	var was_burning := is_burning()
	_remaining = data.duration
	if was_burning:
		return
	_tick_timer = data.tick_interval
	set_physics_process(true)
	ignited.emit()


func extinguish() -> void:
	if not is_burning() and not is_physics_processing():
		return
	_remaining = 0.0
	set_physics_process(false)
	extinguished.emit()


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


func _is_alive() -> bool:
	return hurtbox == null or hurtbox.is_alive()
