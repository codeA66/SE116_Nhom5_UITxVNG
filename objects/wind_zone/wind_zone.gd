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
## Kích thước vùng (cục bộ); chiều Z là chiều gió thổi
@export var size: Vector3 = Vector3(4.0, 3.0, 8.0):
	set(value):
		size = value
		if is_node_ready():
			_apply_size()
			configuration_changed.emit()
## Lực giảm dần về 0 ở cuối vùng: dùng cho cột gió để nhân vật lơ lửng gần đỉnh
@export var fade_toward_end: bool = false

var active: bool = true
var warning: bool = false
## Thời gian từ lúc vùng bắt đầu chạy pulse; đầu gió chưa kịp tới chỗ nào thì chỗ đó chưa có lực
var flow_age: float = 0.0

var _cycle_time: float = 0.0

@onready var _shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	monitoring = false
	monitorable = true
	set_notify_transform(true)
	_apply_size()
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
		return ["Chưa gán WindData: kéo một file trong resources/wind/ vào ô Data."]
	return []


func is_vertical() -> bool:
	return absf(global_basis.z.normalized().y) >= VERTICAL_THRESHOLD


func get_wind_at(world_position: Vector3) -> Vector3:
	if data == null:
		return Vector3.ZERO
	var progress := (size.z * 0.5 - to_local(world_position).z) / maxf(size.z, 0.001)
	if get_flow_coverage(progress) <= 0.0:
		return Vector3.ZERO
	var strength := data.strength
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


func _set_active(value: bool) -> void:
	if active == value:
		return
	active = value
	active_changed.emit(active)


func _apply_size() -> void:
	(_shape.shape as BoxShape3D).size = size


func _on_data_changed() -> void:
	if not is_node_ready():
		return
	# Editor không chạy pulse: xem trước như gió đang bật
	set_physics_process(not Engine.is_editor_hint() and data != null and data.pulse_enabled)
	if data == null:
		_set_active(false)
	elif not data.pulse_enabled:
		_set_active(true)
	configuration_changed.emit()
