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
var phase: Phase = Phase.INACTIVE
var speed: float = 0.0
var age: float = 0.0
var _flight_lifetime: float = 3.0
var _velocity: Vector3
var _attack: AttackData
var _source: WeakRef
@onready var visual: Node3D = $Visual
@onready var peel_visual: Node3D = $PeelVisual
@onready var _cast: ShapeCast3D = $Sweep
@onready var _peel_area: Area3D = $PeelArea
@onready var _burst: Node3D = $ContactBurst

func _ready() -> void:
	set_as_top_level(true)
	_peel_area.body_entered.connect(_stepped)
	pool_released()

func launch(skill: ProjectileSkillData, at: Vector3, direction: Vector3, source: WildEnemy, target: Node3D) -> void:
	_attack = skill
	_source = weakref(source)
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

func _physics_process(delta: float) -> void:
	age += delta
	if phase == Phase.FLIGHT or phase == Phase.FALL:
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
				var source: Node = _source.get_ref() as Node
				var info: DamageInfo = DamageInfo.new(_attack.damage, _attack.damage_type, _velocity.normalized() * _attack.knockback, source)
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
		if age >= peel_lifetime: _finish()
	elif phase == Phase.BURST:
		if age >= 0.4: _finish()

func _begin_fall() -> void:
	# Không quét lại tường ngay từ điểm chạm; để quả rơi sát bên tường xuống sàn thật.
	if _cast.is_colliding(): global_position += _cast.get_collision_normal(0) * 0.04
	phase = Phase.FALL
	age = 0.0
	_velocity = Vector3.DOWN * 0.8
	_cast.collision_mask = 257

func _become_peel(at: Vector3) -> void:
	global_position = at + Vector3.UP * 0.015
	phase = Phase.PEEL
	age = 0.0
	visual.visible = false
	peel_visual.visible = true
	peel_visual.rotation.y = randf() * TAU
	_peel_area.set_deferred(&"monitoring", true)
	released_peel.emit(self)

func _stepped(body: Node3D) -> void:
	if phase != Phase.PEEL or not body is Character: return
	var actor: Character = body as Character
	if actor.banana_slip == null or not actor.banana_slip.begin(): return
	# Một vỏ chỉ được giẫm một lần, kể cả nhiều body vào trong cùng physics tick.
	_burst.global_position = actor.global_position + Vector3.UP * 0.04
	_begin_burst(Color(1.0, 0.81, 0.22))

func _begin_burst(color: Color) -> void:
	phase = Phase.BURST
	age = 0.0
	visual.visible = false
	peel_visual.visible = false
	_peel_area.set_deferred(&"monitoring", false)
	_burst.play(color)

func _finish() -> void:
	pool_released()
	finished.emit(self)
