class_name BossFireball
extends Area3D
## Quả cầu lửa của Boss 1. Bay thẳng về phía người chơi.
## Người chơi dùng Kỹ năng Gió E (WindBlastArea) phản được: bay ngược lại về phía Boss,
## phá vỡ 1 tầng khiên bất tử của Boss.

signal finished(fireball: BossFireball)
signal hit_boss(boss: Character)

@export var speed: float = 9.0
@export var reflected_speed: float = 18.0
@export var lifetime: float = 6.0
@export var damage: int = 1
@export var knockback: float = 6.0

var _velocity: Vector3 = Vector3.ZERO
var _remaining_life: float = 0.0
var _reflected: bool = false
var _spent: bool = false
var _boss_ref: Node3D = null
## false sau khi tách khỏi pool: tự xoá khi xong
var _pooled: bool = true

@onready var _wind_receiver: WindReceiverComponent = $WindReceiverComponent
@onready var _visual: Node3D = $Visual
@onready var _light: OmniLight3D = $OmniLight3D


func _ready() -> void:
	top_level = true
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	if _wind_receiver:
		_wind_receiver.pushed.connect(_on_wind_pushed)
	set_physics_process(false)


## Được gọi bởi ObjectPool khi fireball được lấy ra để dùng
func pool_acquired() -> void:
	set_deferred(&"monitoring", true)
	if _wind_receiver:
		_wind_receiver.set_deferred(&"monitorable", true)


## Được gọi bởi ObjectPool khi fireball được trả về pool (reset trạng thái)
func pool_released() -> void:
	_spent = true
	_reflected = false
	set_physics_process(false)
	set_deferred(&"monitoring", false)
	if _wind_receiver:
		_wind_receiver.set_deferred(&"monitorable", false)


## Được gọi bởi ObjectPool khi tách hoàn toàn khỏi pool (hiếm dùng)
func pool_detached() -> void:
	_pooled = false


func launch(origin: Vector3, direction: Vector3, boss: Node3D) -> void:
	_boss_ref = boss
	_reflected = false
	_spent = false
	_remaining_life = lifetime
	_velocity = direction.normalized() * speed
	global_position = origin
	reset_physics_interpolation()
	
	# Layer 5 (enemy_hitbox = 16), Mask: Player (layer 2 = 2) + World (layer 1 = 1)
	collision_layer = 16
	collision_mask = 3
	
	_set_visual_state(false)
	visible = true
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if _spent:
		return
	global_position += _velocity * delta
	_remaining_life -= delta
	if _remaining_life <= 0.0:
		_explode()


func _on_area_entered(area: Area3D) -> void:
	if _spent:
		return
	var hurtbox := area as HurtboxComponent
	if hurtbox == null:
		return
	
	# Nếu đã phản đòn: chỉ tác động lên Boss/Enemy
	if _reflected:
		if is_instance_valid(_boss_ref) and (_boss_ref.is_ancestor_of(hurtbox) or hurtbox.get_parent() == _boss_ref):
			if _boss_ref.has_method(&"on_fireball_hit"):
				_boss_ref.call(&"on_fireball_hit", self)
			hit_boss.emit(_boss_ref)
			_explode()
			return
		elif (hurtbox.collision_layer & 4) != 0: # Layer 3 (enemy = 4)
			var info := DamageInfo.new(damage, DamageInfo.Type.PHYSICAL, _velocity.normalized() * knockback, null)
			hurtbox.receive_hit(info)
			_explode()
			return
	else:
		# Chưa phản đòn: đánh trúng Player (layer 2 = 2)
		if (hurtbox.collision_layer & 2) != 0:
			var info := DamageInfo.new(damage, DamageInfo.Type.PHYSICAL, _velocity.normalized() * knockback, _boss_ref)
			hurtbox.receive_hit(info)
			_explode()


func _on_body_entered(body: Node3D) -> void:
	if _spent:
		return
	# Nếu đụng Boss khi đã phản đòn
	if _reflected and body == _boss_ref:
		if _boss_ref.has_method(&"on_fireball_hit"):
			_boss_ref.call(&"on_fireball_hit", self)
		hit_boss.emit(_boss_ref)
		_explode()
		return
	# Bỏ qua nếu chạm hurtbox (đã xử lý ở area_entered)
	if body.get_node_or_null(^"HurtboxComponent") != null:
		return
	# Đụng tường / sàn
	_explode()


func _on_wind_pushed(impulse: Vector3) -> void:
	if _spent or _reflected:
		return
	_reflected = true
	
	# Tính hướng bay về Boss
	var target_dir: Vector3
	if is_instance_valid(_boss_ref):
		var to_boss: Vector3 = (_boss_ref.global_position + Vector3(0, 1.2, 0)) - global_position
		target_dir = to_boss.normalized()
	else:
		var flat: Vector3 = Vector3(impulse.x, 0.0, impulse.z)
		target_dir = flat.normalized() if not flat.is_zero_approx() else -_velocity.normalized()
	
	_velocity = target_dir * reflected_speed
	_remaining_life = lifetime
	
	# Đổi mask để quét Enemy (layer 3 = 4) và World (layer 1 = 1)
	collision_mask = 5
	_set_visual_state(true)


func _set_visual_state(is_reflected_now: bool) -> void:
	if _light:
		if is_reflected_now:
			_light.light_color = Color(0.3, 0.85, 1.0) # Xanh gió phản đòn
			_light.light_energy = 4.0
		else:
			_light.light_color = Color(1.0, 0.45, 0.1) # Đỏ cam nguyên bản
			_light.light_energy = 3.0


func _explode() -> void:
	if _spent:
		return
	_spent = true
	set_physics_process(false)
	
	var fx: Node = get_node_or_null(^"/root/CombatFx")
	if fx and fx.has_method(&"spawn_hit"):
		fx.spawn_hit(global_position, Vector3.UP)
	
	visible = false
	# Phát signal để pool thu lại; nếu không có pool thì tự xoá
	finished.emit(self)
	if not _pooled:
		queue_free()
