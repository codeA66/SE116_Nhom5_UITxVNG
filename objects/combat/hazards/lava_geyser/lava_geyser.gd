class_name LavaGeyser
extends Node3D
## Mạch dung nham phụt lên từ dưới: cảnh báo (vòng đỏ nạp dần) → cột dung nham phụt, gây sát thương lửa → nghỉ.
## auto_cycle bật: tự lặp (xếp so le bằng start_delay). Tắt: đứng chờ, chỉ phụt một lượt khi gọi trigger() (bẫy kích hoạt).
## Hiệu năng: chỉ dùng một Timer, không chạy _process; vùng sát thương tắt hẳn (shape disabled) ngoài lúc phụt.

signal erupted
signal subsided
## Hết lượt nghỉ của chế độ kích hoạt: mạch rảnh, gọi trigger() lại được
signal finished

enum Phase { REST, WARNING, BURST }

@export_group("Nhịp")
## Tự lặp chu kỳ; tắt thì chỉ phụt khi gọi trigger()
@export var auto_cycle: bool = true
## Trễ trước chu kỳ đầu tiên (giây): lệch pha giữa các mạch
@export_range(0.0, 10.0, 0.05) var start_delay: float = 0.0
@export_range(0.1, 5.0, 0.05) var warning_time: float = 0.9
@export_range(0.1, 5.0, 0.05) var burst_time: float = 0.8
@export_range(0.1, 10.0, 0.05) var rest_time: float = 1.5
@export_group("Hình dạng")
@export_range(0.3, 5.0, 0.05) var radius: float = 1.4
@export_range(0.5, 12.0, 0.1) var column_height: float = 4.0
## Thời gian cột dâng lên / hạ xuống (giây)
@export_range(0.01, 1.0, 0.01) var rise_time: float = 0.12

var phase: Phase = Phase.REST
## Đang trong một lượt (cảnh báo / phụt / nghỉ); chế độ kích hoạt chỉ nhận trigger() khi false
var busy: bool = false

var _tween: Tween

@onready var _timer: Timer = $PhaseTimer
@onready var _indicator: AoeCircleIndicator = $Indicator
@onready var _column: Node3D = $Column
@onready var _column_mesh: MeshInstance3D = $Column/Mesh
@onready var _damage_shape: CollisionShape3D = $DamageArea/CollisionShape3D


func _ready() -> void:
	_apply_shape()
	_column.visible = false
	_damage_shape.disabled = true
	_timer.one_shot = true
	_timer.timeout.connect(_advance)
	if not auto_cycle:
		return
	busy = true
	if start_delay > 0.0:
		_timer.start(start_delay)
	else:
		_enter(Phase.WARNING)


## Phụt một lượt tại vị trí at (mặt sàn). Trả về false nếu mạch đang bận
func trigger(at: Vector3) -> bool:
	if busy:
		return false
	busy = true
	global_position = at
	_enter(Phase.WARNING)
	return true


func _advance() -> void:
	match phase:
		Phase.REST:
			if auto_cycle:
				_enter(Phase.WARNING)
			else:
				busy = false
				finished.emit()
		Phase.WARNING:
			_enter(Phase.BURST)
		Phase.BURST:
			_enter(Phase.REST)


func _enter(next: Phase) -> void:
	phase = next
	match next:
		Phase.WARNING:
			_indicator.show_indicator(global_position, radius, warning_time)
			_timer.start(warning_time)
		Phase.BURST:
			_indicator.hide_indicator()
			_set_column(true)
			# set_deferred: đổi shape trong callback vật lý phải hoãn tới cuối frame
			_damage_shape.set_deferred(&"disabled", false)
			erupted.emit()
			_timer.start(burst_time)
		Phase.REST:
			_set_column(false)
			_damage_shape.set_deferred(&"disabled", true)
			subsided.emit()
			_timer.start(rest_time)


func _set_column(up: bool) -> void:
	if _tween:
		_tween.kill()
	_column.visible = true
	_tween = create_tween()
	_tween.tween_property(_column, ^"scale:y", 1.0 if up else 0.01, rise_time)
	if not up:
		_tween.tween_callback(_column.hide)


## Kích thước cột và vùng sát thương theo radius / column_height. Cột là Node3D đặt ở mặt cầu, mesh con dời lên nửa chiều cao
## nên co giãn scale.y của Column là cột mọc từ dưới lên
func _apply_shape() -> void:
	var mesh: CylinderMesh = (_column_mesh.mesh as CylinderMesh).duplicate() as CylinderMesh
	mesh.top_radius = radius * 0.7
	mesh.bottom_radius = radius
	mesh.height = column_height
	# Lửa (shader grid_flame) cần biết chiều cao trụ để chuyển màu gốc → ngọn đúng tỉ lệ
	if mesh.material is ShaderMaterial:
		var mat: ShaderMaterial = (mesh.material as ShaderMaterial).duplicate() as ShaderMaterial
		mat.set_shader_parameter(&"height", column_height)
		mesh.material = mat
	_column_mesh.mesh = mesh
	_column_mesh.position.y = column_height * 0.5
	_column.scale = Vector3(1.0, 0.01, 1.0)
	var shape: CylinderShape3D = (_damage_shape.shape as CylinderShape3D).duplicate() as CylinderShape3D
	shape.radius = radius
	shape.height = column_height
	_damage_shape.shape = shape
	_damage_shape.position.y = column_height * 0.5
