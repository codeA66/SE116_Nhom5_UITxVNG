class_name FireBolt
extends Area3D
## Cầu lửa sọ của Quỷ Xương Lửa. Bay thẳng, nổ khi chạm tường hoặc player; trúng player thì gây đòn lửa
## và làm player bắt lửa (BurnableComponent). Không bị gió / kiếm đánh bật lại; chỉ hurtbox có reflect_projectile()
## (Khiên xỉ) dội ngược được: cầu bay về quái đã bắn và tính là đòn của người dội.
## Dùng với ObjectPool: không queue_free, xong việc phát finished để pool thu lại.
## Theo dõi va chạm bằng signal; chỉ chạy _physics_process khi đang bay hoặc đang nổ.

## Hết việc (nổ xong hoặc hết tuổi thọ): pool nghe để thu lại
signal finished(bolt: FireBolt)
## Trúng một hurtbox (hit = đòn có tính hay bị chặn bởi bất tử)
signal hit(hurtbox: HurtboxComponent, landed: bool)
## Bị khiên dội ngược; by = người dội
signal reflected(by: Node3D)

var _data: FireBoltData
var _attack: AttackData
var _source: Node3D
var _velocity: Vector3
var _damage_type: DamageInfo.Type = DamageInfo.Type.FIRE
var _remaining: float = 0.0
var _explode_left: float = 0.0
var _exploding: bool = false
var _spent: bool = true

@onready var _shape: CollisionShape3D = $CollisionShape3D
@onready var _visual: Node3D = $Visual
@onready var _trail: GPUParticles3D = $Trail
@onready var _burst: GPUParticles3D = $Burst
@onready var _impact_sound: AudioStreamPlayer3D = $ImpactSound


func _ready() -> void:
	# Đạn không bay theo quái cha
	top_level = true
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	set_physics_process(false)


## attack: sát thương lên mục tiêu; data: thông số cầu; source: quái bắn (cho DamageInfo)
func launch(attack: AttackData, data: FireBoltData, origin: Vector3, direction: Vector3, source: Node3D) -> void:
	_attack = attack
	_data = data
	_source = source
	_spent = false
	_damage_type = attack.damage_type
	_exploding = false
	_remaining = data.lifetime
	_velocity = direction.normalized() * data.speed
	# Shape là local_to_scene nên đổi bán kính không ảnh hưởng quả khác
	(_shape.shape as SphereShape3D).radius = data.hit_radius
	set_deferred(&"collision_mask", data.mask)
	global_position = origin
	if not _velocity.is_zero_approx():
		look_at(origin + _velocity, Vector3.UP if absf(_velocity.normalized().y) < 0.99 else Vector3.FORWARD)
	reset_physics_interpolation()
	_visual.visible = true
	_trail.emitting = true
	set_physics_process(true)


## Tan ngay không gây sát thương (quái bắn đã chết)
func dissipate() -> void:
	_explode()


func is_flying() -> bool:
	return not _spent


func pool_acquired() -> void:
	set_deferred(&"monitoring", true)


func pool_released() -> void:
	_exploding = false
	_spent = true
	set_physics_process(false)
	_trail.emitting = false
	_visual.visible = false
	set_deferred(&"monitoring", false)


func _physics_process(delta: float) -> void:
	if _exploding:
		_explode_left -= delta
		if _explode_left <= 0.0:
			_exploding = false
			set_physics_process(false)
			finished.emit(self)
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
	var info := DamageInfo.new(_attack.damage, _damage_type, _velocity.normalized() * _attack.knockback, source)
	info.attack = _attack
	# Khiên dội được: đổi hướng về quái đã bắn, không gây đòn, không nổ
	if hurtbox.has_method(&"reflect_projectile"):
		var by := hurtbox.call(&"reflect_projectile", info) as Node3D
		if by:
			_reflect(by)
			return
	# Dash (bất tử) chặn sát thương và không bắt lửa, nhưng quả vẫn nổ
	var landed := hurtbox.receive_hit(info)
	if landed and _data.ignite_on_hit and hurtbox.owner:
		var burnable := hurtbox.owner.get_node_or_null(NodePath(_data.burnable_node)) as BurnableComponent
		if burnable:
			burnable.ignite(source)
	hit.emit(hurtbox, landed)
	_explode()


## Bay ngược về quái đã bắn (không còn thì quay đầu), nhanh hơn; từ giờ là đạn của người dội, chỉ trúng quái
func _reflect(by: Node3D) -> void:
	var speed := _velocity.length() * _data.reflect_speed_mult
	var direction := -_velocity.normalized()
	if is_instance_valid(_source):
		var to_source := _source.global_position + Vector3.UP * (global_position.y - by.global_position.y) - global_position
		if not to_source.is_zero_approx():
			direction = to_source.normalized()
	_velocity = direction * speed
	_source = by
	_damage_type = _data.reflected_damage_type
	_remaining = _data.lifetime
	set_deferred(&"collision_mask", _data.reflected_mask)
	look_at(global_position + _velocity, Vector3.UP if absf(direction.y) < 0.99 else Vector3.FORWARD)
	reflected.emit(by)


func _on_body_entered(body: Node3D) -> void:
	# Nhân vật có hurtbox do area_entered lo (tránh trúng hai lần); còn lại là tường / sàn
	if _spent or body.get_node_or_null(^"HurtboxComponent") != null:
		return
	_explode()


func _explode() -> void:
	if _spent:
		return
	_spent = true
	_exploding = true
	_explode_left = _data.explode_time if _data else 0.0
	_velocity = Vector3.ZERO
	_visual.visible = false
	_trail.emitting = false
	set_deferred(&"monitoring", false)
	_burst.restart()
	if _impact_sound.stream:
		_impact_sound.play()
	set_physics_process(true)
