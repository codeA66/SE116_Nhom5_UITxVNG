class_name TonArrowLauncher
extends Node3D
## Máy có thể bị phá. Đường tên quét từ vị trí cũ để tấm chắn mỏng vẫn chặn được.

class Shot:
	var mesh: MeshInstance3D
	var direction: Vector3
	var seconds_left: float

const FLIGHT_MASK: int = 1 | 2 | 256

@export_range(0.1, 8.0, 0.05) var shot_interval: float = 2.4
@export_range(0.05, 3.0, 0.05) var windup_time: float = 0.65
@export_range(0.5, 40.0, 0.5) var firing_range: float = 17.5
@export_range(0.1, 60.0, 0.5) var arrow_speed: float = 15.0
@export_range(0.05, 8.0, 0.05) var arrow_lifetime: float = 1.6
@export_range(1, 10, 1) var arrow_damage: int = 1
@export var arrow_mesh: Mesh

var _target: Player
var _shots: Array[Shot] = []
var _ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
var _delay: float = 0.0
var _aim: Vector3 = Vector3.ZERO
var _charging: bool = false

@onready var _health: HealthComponent = $Health
@onready var _hurtbox: HurtboxComponent = $HurtboxComponent
@onready var _machine: Node3D = $Machine
@onready var _warning: OmniLight3D = $Machine/Warning
@onready var _muzzle: Marker3D = $Machine/Muzzle


func _ready() -> void:
	_ray.collision_mask = FLIGHT_MASK
	_ray.collide_with_areas = true
	_ray.hit_from_inside = true
	_health.died.connect(_on_destroyed)
	var count := ceili(maxf(arrow_lifetime, 0.05) / maxf(shot_interval, 0.1)) + 1
	for index: int in range(count):
		var shot := Shot.new()
		shot.mesh = MeshInstance3D.new()
		shot.mesh.mesh = arrow_mesh
		shot.mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(shot.mesh)
		shot.mesh.hide()
		_shots.append(shot)
	reset(null)


func _physics_process(delta: float) -> void:
	var space := get_world_3d().direct_space_state
	var has_arrows: bool = false
	for shot: Shot in _shots:
		if shot.seconds_left > 0.0:
			_advance_shot(shot, space, delta)
			has_arrows = has_arrows or shot.seconds_left > 0.0
	if _health.is_dead() or not is_instance_valid(_target):
		set_physics_process(has_arrows)
		return
	_delay = maxf(0.0, _delay - delta)
	if _delay > 0.0:
		return
	if _charging:
		_fire()
	elif global_position.distance_squared_to(_target.global_position) <= firing_range * firing_range:
		_begin_windup()


func reset(target: Player) -> void:
	_target = target
	_health.set_current_health(_health.max_health)
	_machine.show()
	_hurtbox.set_deferred(&"collision_layer", 4)
	_delay = 0.0
	_stop_windup()
	for shot: Shot in _shots:
		_retire(shot)
	set_physics_process(target != null)


func stop() -> void:
	_target = null
	_stop_windup()
	for shot: Shot in _shots:
		_retire(shot)
	set_physics_process(false)


func _begin_windup() -> void:
	var offset := _target.global_position - global_position
	offset.y = 0.0
	if offset.is_zero_approx():
		return
	_aim = offset.normalized()
	_machine.look_at(_machine.global_position + _aim, Vector3.UP, true)
	_charging = true
	_warning.show()
	_delay = maxf(windup_time, 0.05)


func _fire() -> void:
	_stop_windup()
	_delay = maxf(shot_interval - windup_time, 0.1)
	for shot: Shot in _shots:
		if shot.seconds_left > 0.0:
			continue
		shot.direction = _aim
		shot.seconds_left = maxf(arrow_lifetime, 0.05)
		shot.mesh.global_position = _muzzle.global_position
		shot.mesh.look_at(shot.mesh.global_position + _aim, Vector3.UP, true)
		shot.mesh.reset_physics_interpolation()
		shot.mesh.show()
		return


func _advance_shot(shot: Shot, space: PhysicsDirectSpaceState3D, delta: float) -> void:
	_ray.from = shot.mesh.global_position
	_ray.to = _ray.from + shot.direction * maxf(arrow_speed, 0.1) * minf(delta, shot.seconds_left)
	var hit := space.intersect_ray(_ray)
	if not hit.is_empty():
		var collider := hit["collider"] as Node
		if collider:
			_handle_impact(collider)
		_retire(shot)
		return
	shot.mesh.global_position = _ray.to
	shot.seconds_left -= delta
	if shot.seconds_left <= 0.0:
		_retire(shot)


func _handle_impact(collider: Node) -> void:
	var screen := collider.get_parent() as TonWindScreen
	if screen and screen.intercept_arrow():
		return
	if not is_instance_valid(_target):
		return
	var hurtbox := collider as HurtboxComponent
	if collider == _target:
		hurtbox = _target.get_node_or_null(^"HurtboxComponent") as HurtboxComponent
	if hurtbox == null or hurtbox.health != _target.health:
		return
	var hit := DamageInfo.new(arrow_damage, DamageInfo.Type.PHYSICAL, Vector3.ZERO, self)
	hit.staggers = false
	hurtbox.receive_hit(hit)


func _retire(shot: Shot) -> void:
	shot.seconds_left = 0.0
	shot.mesh.hide()


func _stop_windup() -> void:
	_charging = false
	_warning.hide()


func _on_destroyed() -> void:
	_machine.hide()
	_hurtbox.set_deferred(&"collision_layer", 0)
	_stop_windup()
