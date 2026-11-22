class_name PyralonGroundFire
extends Node3D
## Một đầu khe nứt bám mục tiêu và một vệt chém quét ngang, điều khiển trong tick vật lý.

enum Mode { OFF, FISSURE, LOCKED, ARC, ARC_WALL_FADE }

const WALL_FADE_DURATION: float = 0.13
const CHIP_INTERVAL: float = 0.085

var mode: Mode = Mode.OFF
var _field: PyralonField
var _target: Node3D
var _center: Vector3
var _last_trace: Vector3
var _heading: Vector3
var _wall_anchor: Vector3
var _age: float
var _chip_timer: float
var _arc_speed: float
var _arc_distance: float
var _seed_index: int
var _arc_gold_goal: int = 8
var _hit: Dictionary[int, bool] = {}
var _query := PhysicsShapeQueryParameters3D.new()
var _shape := BoxShape3D.new()
var _arc_fx: PyralonFireFx


func _ready() -> void:
	_field = get_parent() as PyralonField
	_query.shape = _shape
	_query.collision_mask = 2
	_query.collide_with_areas = true
	_query.collide_with_bodies = false
	set_physics_process(false)


func fissure(at: Vector3, target: Node3D) -> void:
	cancel()
	_center = _field.floor_at(at)
	_last_trace = _center
	_target = target
	_age = 0.0
	_chip_timer = 0.0
	mode = Mode.FISSURE
	set_physics_process(true)


func slash(at: Vector3, direction: Vector3, speed: float) -> void:
	cancel()
	_center = _field.floor_at(at)
	_heading = direction.normalized()
	_arc_speed = speed
	_arc_distance = 0.0
	_seed_index = 0
	var data := _field.profile
	_arc_gold_goal = _field.scaled_gold_count(data.arc_gold_count)
	_arc_fx = _field.effect(
		PyralonFireFx.Kind.ARC,
		_center + Vector3.UP * 0.75,
		_heading,
		Vector2(data.arc_width * 0.56, 2.95),
		data.arc_range / maxf(speed, 0.1)
	)
	_hit.clear()
	mode = Mode.ARC
	set_physics_process(true)


func cancel() -> void:
	_field.release_effect(_arc_fx)
	_arc_fx = null
	mode = Mode.OFF
	_target = null
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	_age += delta
	match mode:
		Mode.FISSURE:
			_step_fissure(delta)
		Mode.LOCKED:
			if _age >= _field.profile.fissure_lock_time:
				_field.explode_geyser(_center + Vector3.UP * 0.75, _center, _field.profile.geyser_radius)
				cancel()
		Mode.ARC:
			_step_arc(delta)
		Mode.ARC_WALL_FADE:
			_step_arc_wall_fade()


func _step_fissure(delta: float) -> void:
	if not is_instance_valid(_target):
		cancel()
		return
	var data := _field.profile
	# Khóa điểm trên sàn ở tick đầu khe bắt kịp, kể cả khi player đang nhảy.
	var target := _field.floor_at(_target.global_position)
	var step := data.fissure_speed * delta
	var caught := _center.distance_to(target) <= step or _age >= data.fissure_max_time
	_center = target if caught else _center.move_toward(target, step)

	_chip_timer += delta
	if _chip_timer >= CHIP_INTERVAL:
		_chip_timer = 0.0
		_field.fissure_chip(_center)

	var span := (_center - _last_trace).slide(Vector3.UP)
	if span.length() >= 0.92 or (caught and span.length() > 0.10):
		_field.effect(
			PyralonFireFx.Kind.CRACK,
			(_center + _last_trace) * 0.5,
			span.normalized(),
			Vector2(0.84, span.length() * 0.66),
			2.10
		)
		_last_trace = _center

	if caught:
		mode = Mode.LOCKED
		_age = 0.0
		# Tạo vùng đất đá nứt toác lớn dưới chân player (không vòng tròn cảnh báo đỏ) trước khi phụt lửa.
		_field.effect(
			PyralonFireFx.Kind.FISSURE_CRATER,
			_center,
			Vector3.ZERO,
			Vector2.ONE * (data.geyser_radius * 1.15),
			data.fissure_lock_time + 0.65
		)
		_field.fissure_chip(_center)


func _step_arc(delta: float) -> void:
	var profile := _field.profile
	var step := minf(_arc_speed * delta, profile.arc_range - _arc_distance)
	if step <= 0.0:
		cancel()
		return
	var next := _center + _heading * step
	var level := Vector3.UP * 0.75
	# Dò trước mép lưỡi liềm một đoạn ngắn để lửa áp sát mặt tường thay vì xuyên vào tường.
	var wall_hit := _field.wall_between(_center + level, next + _heading * 0.95 + level)
	if not wall_hit.is_empty():
		_begin_wall_press(wall_hit)
		return

	_shape.size = Vector3(profile.arc_width, 1.5, 1.20 + step)
	var rot_basis := Basis.looking_at(_heading, Vector3.UP, true)
	_query.transform = Transform3D(rot_basis, (_center + next) * 0.5 + level)
	for result: Dictionary in get_world_3d().direct_space_state.intersect_shape(_query, 8):
		var hurtbox := result.collider as HurtboxComponent
		if hurtbox == null or _hit.has(hurtbox.get_instance_id()):
			continue
		if _field.wall_between(_center + level, hurtbox.global_position + Vector3.UP * 0.62).is_empty():
			_hit[hurtbox.get_instance_id()] = true
			_field.hit_feather(hurtbox, _heading)

	_arc_distance += step
	_center = next
	if is_instance_valid(_arc_fx):
		_arc_fx.set_pose(_center + level, _heading)

	var seed_step := profile.arc_range / maxi(1, _arc_gold_goal)
	if _seed_index < _arc_gold_goal and _arc_distance >= seed_step * (_seed_index + 0.5):
		_drop_seed(basis.x)
		_seed_index += 1


func _begin_wall_press(wall_hit: Dictionary) -> void:
	var hit_pos: Vector3 = wall_hit.position
	var wall_normal := (wall_hit.normal as Vector3).slide(Vector3.UP)
	if wall_normal.length_squared() < 0.01:
		wall_normal = -_heading
	else:
		wall_normal = wall_normal.normalized()
	_field.wall_splash(hit_pos, wall_normal, _field.profile.arc_width)
	_wall_anchor = hit_pos + wall_normal * 0.14
	_age = 0.0
	mode = Mode.ARC_WALL_FADE


func _step_arc_wall_fade() -> void:
	var t := clampf(_age / WALL_FADE_DURATION, 0.0, 1.0)
	if is_instance_valid(_arc_fx):
		var current := (_center + Vector3.UP * 0.75).lerp(_wall_anchor, t)
		_arc_fx.set_pose(current, _heading)
		_arc_fx.set_arc_wall_press(t, lerpf(1.0, 0.12, t))
	if t >= 1.0:
		cancel()


func _drop_seed(side: Vector3) -> void:
	var hover := Vector3.UP * _field.profile.gold_hover_height
	var flank := -1.0 if (_seed_index % 2 == 0) else 1.0
	for attempt: int in 4:
		var lateral := flank * randf_range(3.5, 6.4) if attempt < 2 else randf_range(-5.8, 5.8)
		var point := _field.floor_at(_center + side * lateral)
		if _field.can_drop_gold(point, _field.profile.gold_spacing) and _field.wall_between(_center + hover, point + hover).is_empty():
			_field.drop_gold(_center + Vector3.UP * 1.35, point)
			return
