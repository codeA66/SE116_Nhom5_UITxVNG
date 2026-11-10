class_name EnemyProjectile
extends Node3D
## Quét thể tích toàn quãng bay mỗi tick. Chuối hụt chuyển sang rơi, vỏ và VFX trong cùng pool.
signal finished(projectile: EnemyProjectile)
signal released_peel(projectile: EnemyProjectile)
signal struck_player(projectile: EnemyProjectile)

enum Phase { INACTIVE, FLIGHT, FALL, PEEL, BURST }
@export var leaves_peel: bool = false
@export var peel_lifetime: float = 15.0
@export var tumble_speed: float = 14.0
@export var fall_gravity: float = 18.0
@export var persistent_peel: bool = false
var phase: Phase = Phase.INACTIVE
var speed: float = 0.0
var age: float = 0.0
var source_instance_id: int = 0
var _flight_lifetime: float = 3.0
var _velocity: Vector3
var _attack: AttackData
var _source: WeakRef
var _reflected: bool = false
var _return_target: WeakRef
var _wind: BananaWindReceiver
var _default_peel_lifetime: float
@onready var visual: Node3D = $Visual
@onready var peel_visual: Node3D = $PeelVisual
@onready var _cast: ShapeCast3D = $Sweep
@onready var _peel_area: Area3D = $PeelArea
@onready var _burst: Node3D = $ContactBurst

func _ready() -> void:
	_default_peel_lifetime = peel_lifetime
	set_as_top_level(true)
	if leaves_peel:
		_wind = BananaWindReceiver.new()
		_wind.name = "BananaWindReceiver"; _wind.collision_layer = 128; _wind.collision_mask = 0; _wind.monitoring = false
		var collision: CollisionShape3D = CollisionShape3D.new()
		var sphere: SphereShape3D = SphereShape3D.new(); sphere.radius = 0.42; collision.shape = sphere
		_wind.add_child(collision); add_child(_wind)
	_peel_area.body_entered.connect(_stepped)
	pool_released()

func launch(skill: ProjectileSkillData, at: Vector3, direction: Vector3, source: WildEnemy, target: Node3D) -> void:
	peel_lifetime = _default_peel_lifetime
	persistent_peel = false
	_attack = skill
	_source = weakref(source)
	source_instance_id = source.get_instance_id()
	_reflected = false; _return_target = null
	if _wind: _wind.enabled = true; _wind.set_deferred(&"monitorable", true)
	_flight_lifetime = maxf(skill.flight_lifetime, 0.05)
	var runner_speed: float = 6.0
	if target is Character: runner_speed = (target as Character).movement.max_speed
	speed = runner_speed * maxf(skill.projectile_speed_ratio, 0.1)
	_velocity = direction.normalized() * speed
	global_transform = Transform3D(Basis.IDENTITY, at)
	visual.rotation = Vector3.ZERO
	if not leaves_peel: visual.look_at(global_position + direction, Vector3.UP, true)
	_cast.clear_exceptions()
	_cast.add_exception(source)
	_cast.collision_mask = 259
	phase = Phase.FLIGHT
	age = 0.0
	visible = true
	visual.visible = true
	peel_visual.visible = false
	_burst.visible = false
	_burst.position = Vector3.UP * 0.04
	_peel_area.set_deferred(&"monitoring", false)
	reset_physics_interpolation()
	set_physics_process(true)

func pool_released() -> void:
	phase = Phase.INACTIVE
	visible = false
	set_physics_process(false)
	_peel_area.set_deferred(&"monitoring", false)
	_burst.set_process(false)
	if _wind: _wind.enabled = false; _wind.set_deferred(&"monitorable", false)
	_reflected = false; _return_target = null

func reflect(_impulse: Vector3) -> void:
	if phase != Phase.FLIGHT or not leaves_peel or _reflected: return
	_reflected = true; age = 0.0
	var thrower: Node3D = _source.get_ref() as Node3D if _source else null
	_cast.collision_mask = 261
	if is_instance_valid(thrower): _cast.remove_exception(thrower)
	if thrower is RoofBananaGrunt and not (thrower as RoofBananaGrunt).is_dead():
		_return_target = weakref(thrower)
		_velocity = (thrower.global_position+Vector3.UP-global_position).normalized()*speed
		_flight_lifetime = maxf(_flight_lifetime,global_position.distance_to(thrower.global_position+Vector3.UP)/maxf(speed,0.1)+0.5)
	else:
		_velocity = -_velocity
	_wind.enabled = false; _wind.set_deferred(&"monitorable", false)
	_burst.play(Color("8beaff"))

func ignore_collision(body: CollisionObject3D) -> void:
	_cast.add_exception(body)

func cancel() -> void:
	if phase != Phase.INACTIVE: _finish()

func _physics_process(delta: float) -> void:
	age += delta
	if phase == Phase.FLIGHT or phase == Phase.FALL:
		if _return_target:
			var target: Enemy = _return_target.get_ref() as Enemy
			if is_instance_valid(target) and not target.is_dead():
				_velocity = (target.global_position+Vector3.UP-global_position).normalized()*speed
		if leaves_peel: visual.rotate_z(tumble_speed * delta)
		if phase == Phase.FALL:
			_velocity.y -= fall_gravity * delta
		var motion: Vector3 = _velocity * delta
		_cast.target_position = motion
		_cast.force_shapecast_update()
		if _cast.is_colliding():
			global_position += motion * _cast.get_closest_collision_safe_fraction()
			var collider: Node = _cast.get_collider(0) as Node
			var hurtbox: HurtboxComponent = collider as HurtboxComponent
			if hurtbox == null and collider != null:
				hurtbox = collider.get_node_or_null(^"HurtboxComponent") as HurtboxComponent
			if phase == Phase.FLIGHT and hurtbox != null:
				var source: Node = _source.get_ref() as Node if _source else null
				var info: DamageInfo = DamageInfo.new(1 if _reflected else _attack.damage, _attack.damage_type, _velocity.normalized() * _attack.knockback, null if _reflected else source)
				info.attack = _attack
				hurtbox.receive_hit(info)
				struck_player.emit(self)
				_begin_burst(Color(0.8, 0.94, 1.0) if not leaves_peel else Color(1.0, 0.82, 0.2))
			elif leaves_peel:
				if _cast.get_collision_normal(0).y > 0.55: _become_peel(_cast.get_collision_point(0))
				else: _begin_fall()
			else:
				_begin_burst(Color(0.65, 0.9, 1.0))
			return
		global_position += motion
		if phase == Phase.FLIGHT and age >= _flight_lifetime:
			if leaves_peel: _begin_fall()
			else: _begin_burst(Color(0.65, 0.9, 1.0))
		elif phase == Phase.FALL and age > 5.0: _finish()
	elif phase == Phase.PEEL:
		if not persistent_peel and age >= peel_lifetime: _finish()
	elif phase == Phase.BURST:
		if age >= 0.4: _finish()

func _begin_fall() -> void:
	if _wind: _wind.enabled = false; _wind.set_deferred(&"monitorable", false)
	# Không quét lại tường ngay từ điểm chạm; để quả rơi sát bên tường xuống sàn thật.
	if _cast.is_colliding(): global_position += _cast.get_collision_normal(0) * 0.04
	phase = Phase.FALL
	age = 0.0
	_velocity = Vector3.DOWN * 0.8
	_cast.collision_mask = 257

func _become_peel(at: Vector3) -> void:
	if _wind: _wind.enabled = false; _wind.set_deferred(&"monitorable", false)
	global_position = at + Vector3.UP * 0.015
	phase = Phase.PEEL
	age = 0.0
	visual.visible = false
	peel_visual.visible = true
	peel_visual.rotation.y = randf() * TAU
	_peel_area.set_deferred(&"monitoring", true)
	released_peel.emit(self)

func place_peel(at: Vector3) -> void:
	visible = true; persistent_peel = true; _become_peel(at); set_physics_process(true); reset_physics_interpolation()

func _stepped(body: Node3D) -> void:
	if phase != Phase.PEEL or not body is Character: return
	var actor: Character = body as Character
	var response: BananaPeelResponse = BananaPeelResponse.find_on(actor)
	if response and response.step_on_peel():
		_burst.global_position = actor.global_position+Vector3.UP*0.04
		_begin_burst(Color("54ff92")); return
	if actor.banana_slip == null or not actor.banana_slip.begin(): return
	# Một vỏ chỉ được giẫm một lần, kể cả nhiều body vào trong cùng physics tick.
	_burst.global_position = actor.global_position + Vector3.UP * 0.04
	_begin_burst(Color(1.0, 0.81, 0.22))

func _begin_burst(color: Color) -> void:
	if _wind: _wind.enabled = false; _wind.set_deferred(&"monitorable", false)
	phase = Phase.BURST
	age = 0.0
	visual.visible = false
	peel_visual.visible = false
	_peel_area.set_deferred(&"monitoring", false)
	_burst.play(color)

func _finish() -> void:
	pool_released()
	finished.emit(self)
