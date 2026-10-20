class_name WindCharger
extends Node3D
## Trụ quạt nạp gió: Wind Blast thổi trúng cánh quạt thì đèn sáng lần lượt, giữ đầy một lúc rồi tắt dần.
## Không phát tín hiệu toàn cục: vật bị điều khiển (bệ nâng...) tự trỏ tới đúng trụ này qua @export
## và chỉ nghe signal của trụ đó, nên một map đặt nhiều trụ không ảnh hưởng lẫn nhau.
## Hành vi theo FSM dạng node (objects/wind_charger/states/).

## Đèn vừa đổi: level = số đèn sáng / tổng số đèn (0..1)
signal charge_changed(level: float)
## Vừa sáng đủ tất cả đèn
signal fully_charged
## Đèn cuối cùng vừa tắt
signal discharged

@export var data: WindChargerData

## Số đèn đang sáng; các state đọc/ghi qua set_lit_count()
var lit_count: int = 0

var _lenses: Array[MeshInstance3D] = []
var _lit_material: StandardMaterial3D
var _rotor_speed: float = 0.0
var _rotor_target: float = 0.0

@onready var state_machine: StateMachine = $StateMachine
@onready var wind_receiver: WindReceiverComponent = $WindReceiver
@onready var _rotor: Node3D = $Model.find_child("Rotor", true, false) as Node3D


func _ready() -> void:
	if data == null:
		push_error("%s thiếu WindChargerData, trụ bị tắt" % get_path())
		set_physics_process(false)
		set_process(false)
		return
	for i in data.light_count:
		var lens := $Model.find_child("Charge_Lens_%d" % i, true, false) as MeshInstance3D
		if lens:
			_lenses.append(lens)
		else:
			push_warning("%s: model thiếu Charge_Lens_%d" % [get_path(), i])
	# Một material sáng dùng chung cho mọi đèn của trụ này, tạo một lần
	_lit_material = StandardMaterial3D.new()
	_lit_material.albedo_color = data.lit_color
	_lit_material.emission_enabled = true
	_lit_material.emission = data.lit_color
	_lit_material.emission_energy_multiplier = data.lit_energy
	if _rotor == null:
		push_warning("%s: model thiếu node Rotor" % get_path())
	# Vùng nhận gió chỉ bao cánh quạt: thổi trúng quạt mới tính
	wind_receiver.pushed.connect(_on_wind_pushed)
	set_process(false)


func _physics_process(delta: float) -> void:
	state_machine.physics_update(delta)


## Quay cánh quạt; chỉ chạy khi cánh đang quay hoặc đang đổi tốc độ
func _process(delta: float) -> void:
	_rotor_speed = move_toward(_rotor_speed, _rotor_target, data.rotor_acceleration * delta)
	if _rotor and not data.rotor_axis.is_zero_approx():
		_rotor.rotate_object_local(data.rotor_axis.normalized(), deg_to_rad(_rotor_speed) * delta)
	if is_zero_approx(_rotor_speed) and is_zero_approx(_rotor_target):
		set_process(false)


func get_level() -> float:
	return float(lit_count) / float(maxi(data.light_count, 1))


func is_full() -> bool:
	return lit_count >= data.light_count


func set_lit_count(count: int) -> void:
	count = clampi(count, 0, data.light_count)
	if count == lit_count:
		return
	lit_count = count
	for i in _lenses.size():
		_lenses[i].material_override = _lit_material if i < lit_count else null
	charge_changed.emit(get_level())


func _on_wind_pushed(_impulse: Vector3) -> void:
	(state_machine.current_state as ChargerState).on_blown()


## 0..1: cánh quạt quay theo tỉ lệ tốc độ tối đa
func set_rotor_power(power: float) -> void:
	_rotor_target = data.rotor_max_speed * clampf(power, 0.0, 1.0)
	set_process(true)
