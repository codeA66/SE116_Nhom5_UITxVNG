class_name FireRain
extends Node3D
## Một lần Mưa Hỏa Tiễn: cầu lửa lần lượt chạm đất dọc đường thẳng, mỗi quả châm lửa quái và vật dễ cháy trong đoạn
## đường của nó (đòn va chạm chỉ gây sát thương khi attack.damage > 0; mặc định 0: sát thương chỉ đến từ cháy);
## quả cuối xong thì cả đường thành dải đất cháy: thứ dễ cháy đứng trong (kể cả đi vào sau) bị đốt
## lại đều đặn tới hết burn_lifetime. Không đốt / đánh chính người gọi.
## Hình ảnh do FireRainVfx nghe signal, node này không biết gì về VFX. Dùng qua ObjectPool.
## Hiệu năng: mỗi quả dò va chạm đúng một lần (shape query dùng lại); dải cháy theo dõi vật vào / ra bằng signal;
## chỉ chạy _physics_process trong lúc còn hoạt động.

## Xong hẳn (cả hình tàn): pool nghe để thu về
signal finished
## Bắt đầu: điểm chạm của từng quả (đã bám sàn) và quả nào có sàn để rơi
signal launched(data: FireRainData, points: PackedVector3Array, landed: PackedByteArray)
## Quả thứ index chạm đất (landed = false: chỗ đó không có sàn, quả bị bỏ)
signal impacted(index: int, point: Vector3, landed: bool)
signal burn_started
signal burn_ended

enum Phase { IDLE, RAIN, BURN, LINGER }

const FIRE_RAIN_SLOW_STAT: StringName = &"fire_rain_enemy_slow"

## Lớp hurtbox bị cầu lửa đánh trúng (mặc định: enemy)
@export_flags_3d_physics var hurtbox_mask: int = 4
## Lớp vùng dễ cháy (layer "burnable")
@export_flags_3d_physics var burnable_mask: int = 512
## Rung đủ mức khi camera trong bán kính này quanh điểm chạm, ngoài shake_max_radius thì không rung (m)
@export_range(0.0, 100.0, 0.5) var shake_full_radius: float = 10.0
@export_range(0.0, 200.0, 0.5) var shake_max_radius: float = 24.0

var _data: FireRainData
var _user: Node
var _phase: Phase = Phase.IDLE
var _clock: float = 0.0
var _next_impact: int = 0
var _direction: Vector3 = Vector3.FORWARD
var _points: PackedVector3Array = PackedVector3Array()
var _landed: PackedByteArray = PackedByteArray()
var _hit: Array[HurtboxComponent] = []
var _inside: Array[BurnableComponent] = []
var _slowed_by_area: Dictionary[BurnableComponent, Enemy] = {}
var _slow_from_stats: StatModifiers
var _rain_slow_factor: float = 1.0
var _refresh_left: float = 0.0
var _query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
var _segment: BoxShape3D = BoxShape3D.new()
var _ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()

@onready var _strip: Area3D = $Strip
@onready var _strip_shape: CollisionShape3D = $Strip/Shape


func _ready() -> void:
	set_as_top_level(true)
	set_physics_process(false)
	_query.shape = _segment
	_query.collide_with_areas = true
	_query.collide_with_bodies = false
	_strip_shape.shape = _strip_shape.shape.duplicate()
	_strip.collision_layer = 0
	_strip.collision_mask = burnable_mask
	_strip.monitorable = false
	_strip.monitoring = false
	_strip.area_entered.connect(_on_area_entered)
	_strip.area_exited.connect(_on_area_exited)


## Đang hoạt động (chưa xong hình tàn)
func is_alive() -> bool:
	return _phase != Phase.IDLE


## Gọi mưa dọc đường từ start theo direction (ngang). user không bị chiêu của chính mình đánh / đốt
func launch(user: Node, data: FireRainData, start: Vector3, direction: Vector3) -> void:
	_clear_rain_slow()
	_user = user
	_data = data
	var caster: Player = user as Player
	if caster != null:
		_rain_slow_factor = clampf(caster.stats.get_multiplier(FIRE_RAIN_SLOW_STAT), 0.1, 1.0)
		if _rain_slow_factor < 1.0:
			_slow_from_stats = caster.stats
			_slow_from_stats.changed.connect(_on_slow_stat_changed)
	direction.y = 0.0
	_direction = direction.normalized() if not direction.is_zero_approx() else Vector3.FORWARD
	_hit.clear()
	_inside.clear()
	_clock = 0.0
	_next_impact = 0
	_phase = Phase.RAIN
	_place_points(start)
	_place_strip(start)
	reset_physics_interpolation()
	launched.emit(data, _points, _landed)
	set_physics_process(true)


func pool_released() -> void:
	_clear_rain_slow()
	_phase = Phase.IDLE
	_hit.clear()
	_inside.clear()
	_user = null
	if is_node_ready():
		_strip.set_deferred(&"monitoring", false)
	# Hình ảnh (node con có pool_released) cũng dọn theo
	for child in get_children():
		if child.has_method(&"pool_released"):
			child.call(&"pool_released")
	set_physics_process(false)


func _exit_tree() -> void:
	_clear_rain_slow()


func _physics_process(delta: float) -> void:
	_clock += delta
	match _phase:
		Phase.RAIN:
			while _next_impact < _points.size() and _clock >= _data.get_impact_time(_next_impact):
				_impact(_next_impact)
				_next_impact += 1
			if _next_impact >= _points.size():
				_start_burn()
		Phase.BURN:
			_refresh_left -= delta
			if _refresh_left <= 0.0:
				_refresh_left += _data.burn_refresh
				for burnable in _inside:
					if is_instance_valid(burnable):
						burnable.ignite(_user)
			if _clock >= _burn_end():
				_end_burn()
		Phase.LINGER:
			if _clock >= _burn_end() + _data.linger:
				_phase = Phase.IDLE
				set_physics_process(false)
				if finished.get_connections().is_empty():
					queue_free()
				else:
					finished.emit()


## Điểm chạm của từng quả: giữa đoạn đường của nó, bám xuống mặt sàn bên dưới
func _place_points(start: Vector3) -> void:
	var count := maxi(_data.impact_count, 1)
	_points.resize(count)
	_landed.resize(count)
	_ray.collision_mask = _data.floor_mask
	var space := get_world_3d().direct_space_state
	for index in count:
		var point := start + _direction * _data.line_length * (float(index) + 0.5) / float(count)
		_ray.from = point + Vector3.UP * _data.floor_probe_up
		_ray.to = point - Vector3.UP * _data.floor_probe_down
		var result := space.intersect_ray(_ray)
		_landed[index] = 0 if result.is_empty() else 1
		if not result.is_empty():
			point = result.position
		_points[index] = point


## Vùng đốt phủ cả đường, đáy ở mặt sàn trung bình của các điểm chạm
func _place_strip(start: Vector3) -> void:
	var floor_y := start.y
	var landed_count := 0
	var sum := 0.0
	for index in _points.size():
		if _landed[index] == 1:
			sum += _points[index].y
			landed_count += 1
	if landed_count > 0:
		floor_y = sum / landed_count
	var center := start + _direction * _data.line_length * 0.5
	center.y = floor_y
	global_transform = Transform3D(Basis.looking_at(_direction, Vector3.UP), center)
	(_strip_shape.shape as BoxShape3D).size = Vector3(_data.line_width, _data.hit_height, _data.line_length)
	_strip_shape.position = Vector3(0.0, _data.hit_height * 0.5, 0.0)


func _impact(index: int) -> void:
	var point := _points[index]
	if _landed[index] == 0:
		impacted.emit(index, point, false)
		return
	_segment.size = Vector3(_data.line_width, _data.hit_height, _data.line_length / _points.size())
	_query.transform = Transform3D(Basis.looking_at(_direction, Vector3.UP), point + Vector3.UP * (_data.hit_height * 0.5))
	var space := get_world_3d().direct_space_state
	# Đòn va chạm 0 sát thương (mặc định): cầu lửa chỉ châm lửa, sát thương đến từ cháy
	if _data.attack != null and _data.attack.damage > 0:
		_hit_hurtboxes(space, point)
	_query.collision_mask = burnable_mask
	for result: Dictionary in space.intersect_shape(_query, 64):
		var burnable := result.collider as BurnableComponent
		if burnable and not IgniterArea.belongs_to(burnable, _user):
			burnable.ignite(_user)
	if _data.impact_shake > 0.0:
		ScreenShake.add_trauma_at(_data.impact_shake, point, shake_full_radius, shake_max_radius)
	impacted.emit(index, point, true)


## Mỗi mục tiêu trong đoạn của quả này nhận đòn va chạm (mỗi mục tiêu một lần cả chiêu)
func _hit_hurtboxes(space: PhysicsDirectSpaceState3D, point: Vector3) -> void:
	_query.collision_mask = hurtbox_mask
	for result: Dictionary in space.intersect_shape(_query, 64):
		var hurtbox := result.collider as HurtboxComponent
		if hurtbox == null or hurtbox in _hit or IgniterArea.belongs_to(hurtbox, _user):
			continue
		_hit.append(hurtbox)
		var away := hurtbox.global_position - point
		away.y = 0.0
		var info := DamageInfo.new(_data.attack.damage, _data.attack.damage_type, Vector3.ZERO, _user)
		info.direction = away.normalized() if away.length_squared() > 0.0001 else _direction
		info.attack = _data.attack
		hurtbox.receive_hit(info)


func _start_burn() -> void:
	if _data.burn_lifetime <= 0.0:
		_phase = Phase.LINGER
		burn_ended.emit()
		return
	_phase = Phase.BURN
	_refresh_left = _data.burn_refresh
	# Bật vùng đốt: vật đang đứng sẵn trong dải cũng được báo area_entered ở khung vật lý sau
	_strip.set_deferred(&"monitoring", true)
	burn_started.emit()


func _end_burn() -> void:
	_phase = Phase.LINGER
	_clear_rain_slow()
	_inside.clear()
	_strip.set_deferred(&"monitoring", false)
	burn_ended.emit()


## Dải cháy hết hạn lúc này (tính từ lúc thả)
func _burn_end() -> float:
	return _data.get_impact_time(maxi(_data.impact_count, 1) - 1) + _data.burn_lifetime


func _on_area_entered(area: Area3D) -> void:
	var burnable := area as BurnableComponent
	if _phase != Phase.BURN or burnable == null or burnable in _inside or IgniterArea.belongs_to(burnable, _user):
		return
	_inside.append(burnable)
	burnable.ignite(_user)
	if _rain_slow_factor < 1.0:
		var affected_enemy: Enemy = burnable.get_parent() as Enemy
		if (affected_enemy != null and not affected_enemy.is_dead()
				and not affected_enemy is FlyingEnemy and not affected_enemy is PreviewFireBoss):
			_slowed_by_area[burnable] = affected_enemy
			affected_enemy.set_area_speed_modifier(self, _rain_slow_factor)


func _on_area_exited(area: Area3D) -> void:
	var burnable := area as BurnableComponent
	if burnable == null:
		return
	_inside.erase(burnable)
	var affected_enemy: Enemy = _slowed_by_area.get(burnable)
	_slowed_by_area.erase(burnable)
	if is_instance_valid(affected_enemy) and _slowed_by_area.find_key(affected_enemy) == null:
		affected_enemy.set_area_speed_modifier(self, 1.0)


func _on_slow_stat_changed(stat: StringName) -> void:
	if stat == FIRE_RAIN_SLOW_STAT and _slow_from_stats.get_multiplier(stat) >= 1.0:
		_clear_rain_slow()


func _clear_rain_slow() -> void:
	for affected_enemy: Enemy in _slowed_by_area.values():
		if is_instance_valid(affected_enemy):
			affected_enemy.set_area_speed_modifier(self, 1.0)
	_slowed_by_area.clear()
	if is_instance_valid(_slow_from_stats) and _slow_from_stats.changed.is_connected(_on_slow_stat_changed):
		_slow_from_stats.changed.disconnect(_on_slow_stat_changed)
	_slow_from_stats = null
	_rain_slow_factor = 1.0
