class_name BossCharge
extends BossState
## State húc: phát các đoạn animation theo nhịp cảnh báo, lao và hồi phục.

signal charge_started(direction: Vector3)
signal charge_finished(reason: StringName)

@export var data: BossChargeData
@export var animation_player: AnimationPlayer
@export var hitbox: SweptHitboxComponent
@export var indicator: ChargeLaneIndicator
@export var effect: Node3D
@export var debug_log: bool = false

var _step: Callable
var _direction: Vector3 = Vector3.FORWARD
var _origin: Vector3 = Vector3.ZERO
var _elapsed: float = 0.0
var _distance: float = 0.0
var _rushing: bool = false
var _finish_reason: StringName = &"distance"
var _effect_auto_sync: bool = true
var _effect_time: Callable
var _effect_stop: Callable
var _preview_collision: KinematicCollision3D = KinematicCollision3D.new()
var _launch_time: float = 0.0
var _rush_end_time: float = 0.0
var _clip_end: float = 0.0

@onready var _ground_ahead: RayCast3D = $GroundAhead

func _ready() -> void:
	super._ready()
	_effect_time = Callable(effect, "set_charge_time")
	_effect_stop = Callable(effect, "stop_charge")
	hitbox.hit.connect(_on_hit)

func enter(_previous: StringName) -> void:
	assert(data != null and data.attack != null)
	_elapsed = 0.0
	_rushing = false
	_finish_reason = &"distance"
	_step = _windup
	_effect_auto_sync = bool(effect.get("auto_sync"))
	effect.set("auto_sync", false)
	hitbox.configure_box(data.hitbox_size, data.hitbox_center)
	boss.velocity.x = 0.0
	boss.velocity.z = 0.0
	_clip_end = maxf(animation_player.get_animation(data.animation).length - 0.0001, 0.0003)
	_launch_time = clampf(data.launch_time, 0.0, _clip_end - 0.0001)
	_rush_end_time = clampf(data.rush_end_time, _launch_time + 0.0001, _clip_end)
	var warning_speed: float = maxf(_launch_time, 0.0001) / maxf(data.warning_duration, 0.01)
	boss.play_action(data.animation, warning_speed, data.blend_in)
	animation_player.set_section(0.0, _launch_time)
	_aim()
	_set_effect_time(0.0)
	if debug_log:
		print("Charge: bắt đầu cảnh báo")

func exit() -> void:
	_step = Callable()
	_rushing = false
	animation_player.reset_section()
	hitbox.deactivate()
	indicator.hide_lane()
	_effect_stop.call()
	effect.set("auto_sync", _effect_auto_sync)
	boss.velocity.x = 0.0
	boss.velocity.z = 0.0

func physics_update(delta: float) -> void:
	boss.apply_gravity(delta)
	if _step.is_valid():
		_step.call(delta)

func is_rushing() -> bool:
	return _rushing

func get_locked_direction() -> Vector3:
	return _direction

func get_planned_distance() -> float:
	return _distance

func _windup(delta: float) -> void:
	if not is_instance_valid(boss.target_player):
		state_machine.transition_to(&"Idle")
		return
	_elapsed += delta
	_aim()
	var progress: float = clampf(_elapsed / maxf(data.warning_duration, 0.01), 0.0, 1.0)
	var box_size: Vector3 = hitbox.get_box_size()
	var world_scale: Vector3 = hitbox.global_basis.get_scale()
	var world_width: float = box_size.x * world_scale.x
	var rear: float = minf(0.0, (data.hitbox_center.z - box_size.z * 0.5) * world_scale.z)
	var front: float = maxf(0.0, (data.hitbox_center.z + box_size.z * 0.5) * world_scale.z)
	indicator.show_lane(boss.global_position + _direction * rear, _direction, world_width, _distance + front - rear, progress)
	_set_effect_time(animation_player.current_animation_position)
	if progress >= 1.0:
		_origin = boss.global_position
		_elapsed = 0.0
		_rushing = true
		_step = _rush
		indicator.hide_lane()
		hitbox.activate(boss.get_attack_data(data.attack))
		_play_section(_launch_time, _rush_end_time, _distance / maxf(data.speed, 0.01))
		charge_started.emit(_direction)

func _rush(delta: float) -> void:
	var displacement: Vector3 = boss.global_position - _origin
	var traveled: float = maxf(displacement.dot(_direction), 0.0)
	var remaining: float = _distance - traveled
	_set_effect_time(animation_player.current_animation_position)
	if boss.is_on_wall():
		_begin_recovery(&"wall")
		return
	if data.stop_at_ledge and not boss.is_on_floor():
		_begin_recovery(&"ledge")
		return
	if remaining <= 0.001:
		_begin_recovery(&"distance")
		return
	var speed: float = minf(maxf(data.speed, 0.01), remaining / maxf(delta, 0.0001))
	if data.stop_at_ledge and not _has_ground_ahead(_direction * speed * delta):
		_begin_recovery(&"ledge")
		return
	boss.velocity.x = _direction.x * speed
	boss.velocity.z = _direction.z * speed

func _recovery(delta: float) -> void:
	_elapsed += delta
	var progress: float = clampf(_elapsed / maxf(data.recovery_duration, 0.01), 0.0, 1.0)
	_set_effect_time(animation_player.current_animation_position)
	if progress >= 1.0:
		charge_finished.emit(_finish_reason)
		state_machine.transition_to(&"Idle")

func _aim() -> void:
	if not is_instance_valid(boss.target_player):
		return
	var direction: Vector3 = boss.target_player.global_position - boss.global_position
	direction.y = 0.0
	if not direction.is_zero_approx():
		_direction = direction.normalized()
	boss.face_instantly(_direction)
	_distance = maxf(data.distance, 0.01)
	if boss.test_move(boss.global_transform, _direction * _distance, _preview_collision):
		_distance = minf(_distance, maxf(_preview_collision.get_travel().dot(_direction), 0.01))

func _begin_recovery(reason: StringName) -> void:
	_finish_reason = reason
	_elapsed = 0.0
	_rushing = false
	_step = _recovery
	boss.velocity.x = 0.0
	boss.velocity.z = 0.0
	hitbox.deactivate()
	_play_section(_rush_end_time, _clip_end, data.recovery_duration)
	_set_effect_time(_rush_end_time)
	if debug_log:
		print("Charge: dừng vì ", reason)

func _play_section(start: float, end: float, duration: float) -> void:
	var speed: float = maxf(end - start, 0.0001) / maxf(duration, 0.01)
	# Cho mixer chạy theo thời gian để blend và chuyển động xương thực sự tiến lên.
	animation_player.play_section(data.animation, start, end, 0.0, speed)
	animation_player.seek(start, true)

func _set_effect_time(time: float) -> void:
	_effect_time.call(time)

func _has_ground_ahead(motion: Vector3) -> bool:
	_ground_ahead.global_position = boss.global_position + motion + Vector3.UP * maxf(data.ledge_probe_height, 0.01)
	_ground_ahead.target_position = Vector3.DOWN * maxf(data.ledge_probe_depth, 0.02)
	_ground_ahead.collision_mask = boss.collision_mask
	_ground_ahead.force_raycast_update()
	return _ground_ahead.is_colliding()

func _on_hit(_hurtbox: HurtboxComponent) -> void:
	if _rushing and data.stop_on_player_hit:
		_begin_recovery(&"player")
