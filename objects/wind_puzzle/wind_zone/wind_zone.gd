@tool
class_name WindZone
extends Area3D
## Vùng gió: đẩy mọi WindReceiverComponent bên trong theo trục -Z cục bộ.
## Xoay node để đổi hướng: luồng ngang và cột gió nâng là cùng một component.
## Gió có pulse lan từ mặt vào (+Z) tới mặt ra (-Z) trong sweep_time: chỗ nào gió tới mới bị đẩy.
## Hình ảnh nằm ở WindZoneVfx (node con), nghe các signal dưới đây.

signal active_changed(active: bool)
signal warning_changed(warning: bool)
## Kích thước, hướng hoặc dữ liệu đổi: VFX dựng lại theo
signal configuration_changed

## Vùng có hướng gió lệch khỏi phương ngang quá mức này được coi là cột gió (lên hoặc xuống)
const VERTICAL_THRESHOLD := 0.7
## Chỉ dùng để cảnh báo trong editor: gió chặn hay không là so sức gió với tốc độ chạy của player
const PLAYER_MOVEMENT: MovementStats = preload("res://resources/player/player_movement.tres")

@export var data: WindData:
	set(value):
		if data and data.changed.is_connected(_on_data_changed):
			data.changed.disconnect(_on_data_changed)
		data = value
		if data:
			data.changed.connect(_on_data_changed)
		if is_node_ready():
			_on_data_changed()
		update_configuration_warnings()
## Kích thước vùng (cục bộ); chiều Z là chiều gió thổi.
## Đồng bộ hai chiều với hộp CollisionShape3D qua BoxShapeSyncComponent: kéo gizmo hộp cũng cập nhật ô này và VFX
@export var size: Vector3 = Vector3(4.0, 3.0, 8.0):
	set(value):
		if size == value:
			return
		size = value
		if is_node_ready():
			_box_sync.apply(size)
			configuration_changed.emit()
## Lực giảm dần về 0 ở cuối vùng: dùng cho cột gió để nhân vật lơ lửng gần đỉnh
@export var fade_toward_end: bool = false

var active: bool = true
var warning: bool = false
## Thời gian từ lúc vùng bắt đầu chạy pulse; đầu gió chưa kịp tới chỗ nào thì chỗ đó chưa có lực
var flow_age: float = 0.0

var _cycle_time: float = 0.0

@onready var _box_sync: BoxShapeSyncComponent = $BoxShapeSync


func _ready() -> void:
	monitoring = false
	monitorable = true
	set_notify_transform(true)
	_box_sync.apply(size)
	_box_sync.size_changed.connect(_on_box_size_changed)
	_on_data_changed()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and is_node_ready():
		configuration_changed.emit()


## Chỉ chạy khi có pulse (bật trong _on_data_changed); vùng gió đều không tốn xử lý mỗi frame
func _physics_process(delta: float) -> void:
	flow_age += delta
	_cycle_time = fmod(_cycle_time + delta, maxf(data.on_time + data.off_time, 0.001))
	_set_active(_cycle_time < data.on_time)
	var next_warning := not active and _cycle_time >= data.on_time + data.off_time - data.warning_time
	if warning != next_warning:
		warning = next_warning
		warning_changed.emit(warning)


func _get_configuration_warnings() -> PackedStringArray:
	if data == null:
		return ["Chưa gán WindData: kéo một file trong resources/world/wind/wind/ vào ô Data."]
	if is_vertical():
		return []
	var run_speed := PLAYER_MOVEMENT.max_speed
	if data.blocks_player and data.strength <= run_speed:
		return ["Gió đánh dấu Blocks Player nhưng sức gió (%.1f) không lớn hơn tốc độ chạy (%.1f): người chơi vẫn đi ngược được. Tăng Strength hoặc tắt Blocks Player." % [data.strength, run_speed]]
	if not data.blocks_player and data.strength >= run_speed:
		return ["Sức gió (%.1f) ≥ tốc độ chạy (%.1f) nên người chơi không đi ngược được, nhưng hình ảnh vẫn là gió nhẹ. Bật Blocks Player hoặc giảm Strength." % [data.strength, run_speed]]
	return []


func is_vertical() -> bool:
	return absf(global_basis.z.normalized().y) >= VERTICAL_THRESHOLD


func get_wind_at(world_position: Vector3) -> Vector3:
	if data == null:
		return Vector3.ZERO
	var local := to_local(world_position)
	var progress := (size.z * 0.5 - local.z) / maxf(size.z, 0.001)
	if get_flow_coverage(progress) <= 0.0:
		return Vector3.ZERO
	var strength := data.strength * _edge_factor(local)
	if fade_toward_end:
		strength *= 1.0 - clampf(progress, 0.0, 1.0)
	return -global_basis.z.normalized() * strength


## Pha trong chu kỳ bật/tắt, VFX dùng để khớp hình với lực
func get_flow_phase() -> float:
	return _cycle_time


## 1 nếu gió đang có mặt tại tiến độ progress (0 = mặt vào, 1 = mặt ra), 0 nếu không
func get_flow_coverage(progress: float) -> float:
	if data == null or progress < 0.0 or progress > 1.0:
		return 0.0
	if not data.pulse_enabled:
		return 1.0 if active else 0.0
	var delay := pow(progress, 1.0 / data.sweep_exponent) * data.sweep_time
	if flow_age < delay:
		return 0.0
	var emission_phase := fposmod(_cycle_time - delay, maxf(data.on_time + data.off_time, 0.001))
	return 1.0 if emission_phase < data.on_time else 0.0


## Còn gió đang chạy trong vùng (kể cả đuôi gió sau khi tắt)
func has_flow_in_transit() -> bool:
	if data == null:
		return false
	if not data.pulse_enabled:
		return active
	return active or _cycle_time < data.on_time + data.sweep_time


## 0 ở mép vùng, tăng dần lên 1 sau edge_softness mét, chỉ theo các trục nằm ngang.
## Trục thẳng đứng bỏ qua: người chơi đứng sát sàn (đáy vùng) vẫn chịu đủ lực, cột gió nâng đủ từ đáy
func _edge_factor(local: Vector3) -> float:
	var softness := data.edge_softness
	if softness <= 0.0:
		return 1.0
	var vertical_axis := _vertical_local_axis()
	var factor := 1.0
	for axis in 3:
		if axis == vertical_axis:
			continue
		var inside := size[axis] * 0.5 - absf(local[axis])
		factor = minf(factor, clampf(inside / softness, 0.0, 1.0))
	return factor


## Trục cục bộ (0 = x, 1 = y, 2 = z) gần phương thẳng đứng của thế giới nhất
func _vertical_local_axis() -> int:
	var best := 1
	var best_dot := 0.0
	for axis in 3:
		var d := absf(global_basis[axis].normalized().y)
		if d > best_dot:
			best_dot = d
			best = axis
	return best


func _set_active(value: bool) -> void:
	if active == value:
		return
	active = value
	active_changed.emit(active)


func _on_box_size_changed(box_size: Vector3) -> void:
	# size setter bỏ qua khi bằng nhau nên không lặp vô hạn giữa hai chiều
	size = box_size


func _on_data_changed() -> void:
	if not is_node_ready():
		return
	# Editor không chạy pulse: xem trước như gió đang bật
	set_physics_process(not Engine.is_editor_hint() and data != null and data.pulse_enabled)
	if data == null:
		_set_active(false)
	elif not data.pulse_enabled:
		_set_active(true)
	update_configuration_warnings()
	configuration_changed.emit()
