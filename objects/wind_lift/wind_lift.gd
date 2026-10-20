@tool
class_name WindLift
extends Node3D
## Bệ nâng bằng gió: trụ quạt (charger) nạp đầy thì gió dưới đế mạnh dần và đẩy bệ lên điểm dừng trên;
## đèn trụ tắt dần thì gió yếu dần, tắt hết thì bệ sụp xuống. Người đứng trên bệ đi lên/xuống cùng bệ.
## Chỉ nghe signal của đúng trụ gán ở ô Charger, nên nhiều bộ trụ + bệ trong một map chạy độc lập.
## Điểm dừng lấy từ marker LowerStop / UpperStop trong model. Hành vi theo FSM dạng node (states/).

signal raised
signal lowered

@export var data: WindLiftData
## Trụ quạt điều khiển bệ này. Nhiều bệ có thể trỏ chung một trụ
@export var charger: WindCharger:
	set(value):
		charger = value
		update_configuration_warnings()

## Sức gió hiện tại 0..1 (state đọc/ghi qua set_wind)
var wind: float = 0.0
## Vận tốc đứng của bệ (m/s), state đọc/ghi
var speed: float = 0.0

var _lower_y: float = 0.0
var _upper_y: float = 0.0
var _wind_data: WindData
var _shown_wind: float = -1.0

@onready var state_machine: StateMachine = $StateMachine
@onready var platform: AnimatableBody3D = $Platform
@onready var _wind_column: WindZone = $WindColumn
@onready var _model_follow: RemoteTransform3D = $Platform/ModelFollow
## Chặn lối vào bệ ở chân (đỉnh dốc) khi bệ không nằm dưới, và ở mép trên khi bệ không nằm trên:
## không cho người chơi bước vào khoảng trống rồi bị bệ rơi đè
@onready var _bottom_gate: CollisionShape3D = $Gates/BottomGate
@onready var _top_gate: CollisionShape3D = $Gates/TopGate


func _ready() -> void:
	# @tool chỉ để hiện cảnh báo cấu hình; trong editor không chạy logic
	if Engine.is_editor_hint():
		set_physics_process(false)
		return
	if data == null:
		push_error("%s thiếu WindLiftData, bệ bị tắt" % get_path())
		set_physics_process(false)
		return
	var lower := $Model.find_child("LowerStop", true, false) as Node3D
	var upper := $Model.find_child("UpperStop", true, false) as Node3D
	if lower == null or upper == null:
		push_error("%s: model thiếu marker LowerStop/UpperStop" % get_path())
		set_physics_process(false)
		return
	# Marker tính theo gốc WindLift; bệ chỉ chạy theo trục Y cục bộ
	_lower_y = to_local(lower.global_position).y
	_upper_y = to_local(upper.global_position).y
	platform.position.y = _lower_y
	# Phần hình của bệ bám theo thân va chạm. Tìm theo tên thay vì gõ đường dẫn:
	# GLB nhập vào có thêm tầng node gốc, đường dẫn cứng dễ trỏ sai mà không báo
	var visual := $Model.find_child("Platform", true, false) as Node3D
	if visual == null:
		push_error("%s: model thiếu node Platform, phần hình của bệ sẽ không chuyển động" % get_path())
	else:
		_model_follow.remote_path = _model_follow.get_path_to(visual)
	# Bản sao riêng: đổi sức gió hiển thị của bệ này không ảnh hưởng bệ khác
	_wind_data = (_wind_column.data as WindData).duplicate() as WindData
	_wind_column.data = _wind_data
	_apply_wind_visual()
	if charger == null:
		push_warning("%s chưa gán trụ quạt (Charger): bệ sẽ không bao giờ lên" % get_path())
		return
	charger.fully_charged.connect(_on_charger_full)
	charger.discharged.connect(_on_charger_discharged)


func _get_configuration_warnings() -> PackedStringArray:
	if charger == null:
		return ["Chưa gán Charger: kéo node WindCharger điều khiển bệ này vào ô Charger."]
	return []


func _physics_process(delta: float) -> void:
	state_machine.physics_update(delta)


func get_charger_level() -> float:
	return charger.get_level() if charger else 0.0


func get_platform_height() -> float:
	return platform.position.y


func get_lower_y() -> float:
	return _lower_y


func get_upper_y() -> float:
	return _upper_y


## Đặt độ cao bệ (kẹp trong hai điểm dừng). AnimatableBody tự mang người đứng trên theo
func set_platform_height(y: float) -> void:
	platform.position.y = clampf(y, _lower_y, _upper_y)


## Bật/tắt cổng chặn theo vị trí bệ; state gọi khi vào trạng thái mới
func set_gates(open_bottom: bool, open_top: bool) -> void:
	_bottom_gate.set_deferred(&"disabled", open_bottom)
	_top_gate.set_deferred(&"disabled", open_top)


func set_wind(value: float) -> void:
	wind = clampf(value, 0.0, 1.0)
	_apply_wind_visual()


## Đổi dữ liệu gió làm VFX dựng lại: chỉ cập nhật theo bậc 0.1 thay vì mỗi frame
func _apply_wind_visual() -> void:
	var stepped := snappedf(wind, 0.1)
	if is_equal_approx(stepped, _shown_wind):
		return
	_shown_wind = stepped
	_wind_column.visible = stepped > 0.0
	if stepped > 0.0:
		_wind_data.strength = data.visual_wind_strength * stepped


func _on_charger_full() -> void:
	(state_machine.current_state as WindLiftState).on_charger_full()


func _on_charger_discharged() -> void:
	(state_machine.current_state as WindLiftState).on_charger_discharged()


## State gọi khi bệ tới đỉnh / về đáy: signal phát từ chính class khai báo nó
func notify_raised() -> void:
	raised.emit()


func notify_lowered() -> void:
	lowered.emit()
