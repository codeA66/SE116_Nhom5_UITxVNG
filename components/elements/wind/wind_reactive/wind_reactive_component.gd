class_name WindReactiveComponent
extends Node3D
## Nối bộ nhận cú thổi và vùng gió với hình ảnh của vật trang trí.

signal reacted(direction: Vector3, strength: float)
signal wind_changed(direction: Vector3, strength: float)

@export var data: WindReactData
@export var receiver_path: NodePath = ^"../WindReceiver"

var _zones: Array[WindZone] = []
var _last_wind: Vector3 = Vector3.ZERO

@onready var _receiver: WindReceiverComponent = get_node(receiver_path) as WindReceiverComponent


func _ready() -> void:
	WindReactiveClock.ensure_clock(get_tree())
	set_process(false)
	_receiver.pushed.connect(_on_pushed)
	_receiver.area_entered.connect(_on_area_entered)
	_receiver.area_exited.connect(_on_area_exited)
	_receiver.monitoring = true
	_receiver.monitorable = true


func _process(_delta: float) -> void:
	# Chỉ vùng gió nhịp mới cần lấy mẫu khi đầu gió đi qua.
	_refresh_wind()


func apply_gust(direction: Vector3, strength: float) -> void:
	if direction.is_zero_approx() or strength <= 0.0:
		return
	reacted.emit(direction.normalized(), strength)


func get_wind_strength() -> float:
	return _last_wind.length()


func _on_pushed(impulse: Vector3) -> void:
	apply_gust(impulse, impulse.length())


func _on_area_entered(area: Area3D) -> void:
	var zone := area as WindZone
	if zone == null or zone in _zones:
		return
	_zones.append(zone)
	zone.active_changed.connect(_on_zone_changed)
	zone.configuration_changed.connect(_on_zone_configuration_changed)
	_refresh_processing()
	_refresh_wind()


func _on_area_exited(area: Area3D) -> void:
	var zone := area as WindZone
	if zone == null or zone not in _zones:
		return
	_zones.erase(zone)
	zone.active_changed.disconnect(_on_zone_changed)
	zone.configuration_changed.disconnect(_on_zone_configuration_changed)
	_refresh_processing()
	_refresh_wind()


func _on_zone_changed(_active: bool) -> void:
	_refresh_wind()


func _on_zone_configuration_changed() -> void:
	_refresh_processing()
	_refresh_wind()


func _refresh_processing() -> void:
	var pulsed: bool = false
	for zone in _zones:
		if zone.data != null and zone.data.pulse_enabled:
			pulsed = true
			break
	set_process(pulsed)


func _refresh_wind() -> void:
	var total: Vector3 = Vector3.ZERO
	for zone in _zones:
		total += zone.get_wind_at(global_position)
	if total.distance_squared_to(_last_wind) < 0.0001:
		return
	_last_wind = total
	wind_changed.emit(total.normalized() if not total.is_zero_approx() else Vector3.ZERO, total.length())
