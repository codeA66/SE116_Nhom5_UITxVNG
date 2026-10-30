class_name SpiritOrb
extends Area3D
## Quả cầu hồn của quái pháp sư. Bay thẳng, nổ khi chạm tường hoặc player.
## Cú thổi gió (WindBlastArea) phản được: bay ngược lại, đổi phe, gây sát thương lên quái.
## Dùng với ObjectPool: không queue_free, hết việc thì phát finished để pool thu lại.
## Theo dõi va chạm bằng signal; chỉ chạy _physics_process khi đang bay hoặc đang nổ.

## Hết việc (nổ xong hoặc hết tuổi thọ): pool nghe để thu lại
signal finished(orb: SpiritOrb)
signal reflected(orb: SpiritOrb)

@export var hostile_material: Material
@export var reflected_material: Material

var _data: SpiritOrbData
var _attack: AttackData
var _source: Node3D
var _velocity: Vector3
var _remaining: float = 0.0
var _explode_left: float = 0.0
var _exploding: bool = false
var _spent: bool = false
var _reflected: bool = false
## false sau khi bị tách khỏi pool: tự xoá khi xong
var _pooled: bool = true

@onready var _shape: CollisionShape3D = $CollisionShape3D
@onready var _core: MeshInstance3D = $Core
@onready var _wind_receiver: WindReceiverComponent = $WindReceiverComponent
@onready var _wind_shape: CollisionShape3D = $WindReceiverComponent/CollisionShape3D
@onready var _trail: GPUParticles3D = $Trail
@onready var _burst: GPUParticles3D = $Burst
@onready var _reflect_sound: AudioStreamPlayer3D = $ReflectSound
@onready var _impact_sound: AudioStreamPlayer3D = $ImpactSound


func _ready() -> void:
	# Đạn không bay theo quái cha
	top_level = true
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	_wind_receiver.pushed.connect(_on_wind_pushed)
	set_physics_process(false)


func is_reflected() -> bool:
	return _reflected


## attack: sát thương lên player trước khi bị phản; data: thông số cầu; source: quái bắn (cho DamageInfo)
func launch(attack: AttackData, data: SpiritOrbData, origin: Vector3, direction: Vector3, source: Node3D) -> void:
	_attack = attack
	_data = data
	_source = source
	_reflected = false
	_spent = false
	_exploding = false
	_remaining = data.lifetime
	_velocity = direction.normalized() * data.speed
	# Shape là local_to_scene nên đổi bán kính không ảnh hưởng quả khác
	(_shape.shape as SphereShape3D).radius = data.hit_radius
	(_wind_shape.shape as SphereShape3D).radius = data.wind_catch_radius
	global_position = origin
	reset_physics_interpolation()
	_apply_phase(false)
	_core.visible = true
	_trail.emitting = true
	set_physics_process(true)


## Tan ngay không gây sát thương (quái bắn đã chết)
func dissipate() -> void:
	_explode()


func pool_acquired() -> void:
	set_deferred(&"monitoring", true)
	_wind_receiver.set_deferred(&"monitorable", true)


func pool_released() -> void:
	_exploding = false
	_spent = true
	set_physics_process(false)
	_trail.emitting = false
	set_deferred(&"monitoring", false)
	_wind_receiver.set_deferred(&"monitorable", false)


func pool_detached() -> void:
	_pooled = false


func _physics_process(delta: float) -> void:
	if _exploding:
		_explode_left -= delta
		if _explode_left <= 0.0:
			_finish()
		return
	global_position += _velocity * delta
	_remaining -= delta
	if _remaining <= 0.0:
		_explode()


func _on_area_entered(area: Area3D) -> void:
	var hurtbox := area as HurtboxComponent
	if _spent or hurtbox == null:
		return
	var source: Node = _source if is_instance_valid(_source) else null
	var info: DamageInfo
	if _reflected:
		var reflected_attack := _data.reflected_attack
		info = DamageInfo.new(reflected_attack.damage, reflected_attack.damage_type, _velocity.normalized() * reflected_attack.knockback, null)
	else:
		info = DamageInfo.new(_attack.damage, _attack.damage_type, _velocity.normalized() * _attack.knockback, source)
	# Dash (bất tử) chặn sát thương nhưng quả vẫn nổ
	hurtbox.receive_hit(info)
	_explode()


func _on_body_entered(body: Node3D) -> void:
	# Nhân vật có hurtbox do area_entered lo (tránh trúng hai lần); còn lại là tường / sàn
	if _spent or body.get_node_or_null(^"HurtboxComponent") != null:
		return
	_explode()


func _on_wind_pushed(impulse: Vector3) -> void:
	if _spent or _reflected:
		return
	var flat := Vector3(impulse.x, 0.0, impulse.z)
	if flat.is_zero_approx():
		return
	_reflected = true
	_source = null
	var direction := _find_reflect_direction(flat.normalized())
	_velocity = direction * _data.speed * _data.reflect_speed_mult
	# Cho thêm tuổi thọ đủ để bay tới mục tiêu
	_remaining = _data.lifetime
	_apply_phase(true)
	if _reflect_sound.stream:
		_reflect_sound.play()
	reflected.emit(self)


## Aim assist một lần lúc phản: bẻ về hurtbox quái gần nhất lệch không quá reflect_aim_angle
func _find_reflect_direction(blow_direction: Vector3) -> Vector3:
	var best_direction := blow_direction
	var best_distance := _data.reflect_aim_range
	var max_angle := deg_to_rad(_data.reflect_aim_angle)
	for node in get_tree().get_nodes_in_group(HurtboxComponent.GROUP):
		var hurtbox := node as HurtboxComponent
		if hurtbox == null or not hurtbox.is_alive() or (hurtbox.collision_layer & _data.aim_assist_layer) == 0:
			continue
		var offset := _hurtbox_center(hurtbox) - global_position
		var distance := offset.length()
		if distance >= best_distance or distance < 0.01:
			continue
		var flat_offset := Vector3(offset.x, 0.0, offset.z)
		if flat_offset.is_zero_approx() or blow_direction.angle_to(flat_offset.normalized()) > max_angle:
			continue
		best_distance = distance
		best_direction = offset / distance
	return best_direction


func _hurtbox_center(hurtbox: HurtboxComponent) -> Vector3:
	for child in hurtbox.get_children():
		if child is CollisionShape3D:
			return (child as CollisionShape3D).global_position
	return hurtbox.global_position


func _apply_phase(is_reflected_now: bool) -> void:
	# Đổi mask trong callback va chạm phải hoãn lại
	set_deferred(&"collision_mask", _data.reflected_mask if is_reflected_now else _data.hostile_mask)
	var material := reflected_material if is_reflected_now else hostile_material
	_core.material_override = material
	_trail.material_override = material
	_burst.material_override = material


func _explode() -> void:
	if _spent:
		return
	_spent = true
	_exploding = true
	_explode_left = _data.explode_time
	_velocity = Vector3.ZERO
	_core.visible = false
	_trail.emitting = false
	set_deferred(&"monitoring", false)
	_wind_receiver.set_deferred(&"monitorable", false)
	_burst.restart()
	if _impact_sound.stream:
		_impact_sound.play()
	set_physics_process(true)


func _finish() -> void:
	_exploding = false
	set_physics_process(false)
	finished.emit(self)
	if not _pooled:
		queue_free()
