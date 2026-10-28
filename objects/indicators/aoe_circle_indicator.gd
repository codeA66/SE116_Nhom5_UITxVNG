class_name AoeCircleIndicator
extends Node3D
## Vòng tròn chỉ thị vùng cảnh báo sát thương AOE trên mặt đất.
## Dùng cho các kỹ năng như Jump Slam của Boss: hiển thị vòng biên cố định
## và vòng nạp đầy dần bên trong để người chơi căn thời gian né/nhảy.
## Hiệu năng: top_level để không phụ thuộc cha, set_physics_process(false) khi tắt.

@export var default_radius: float = 3.5
@export var fill_color: Color = Color(1.0, 0.15, 0.08, 0.35)
@export var border_color: Color = Color(1.0, 0.28, 0.1, 0.85)

var _target_radius: float = 3.5
var _duration: float = 1.0
var _timer: float = 0.0

@onready var _border: MeshInstance3D = $Border
@onready var _fill: MeshInstance3D = $Fill
@onready var _border_mat: StandardMaterial3D = null
@onready var _fill_mat: StandardMaterial3D = null


func _ready() -> void:
	top_level = true
	visible = false
	set_physics_process(false)
	
	if _border:
		_border_mat = _border.get_active_material(0) as StandardMaterial3D
		if _border_mat == null:
			_border_mat = StandardMaterial3D.new()
			_border_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_border_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_border_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			_border_mat.albedo_color = border_color
			_border.material_override = _border_mat
	
	if _fill:
		_fill_mat = _fill.get_active_material(0) as StandardMaterial3D
		if _fill_mat == null:
			_fill_mat = StandardMaterial3D.new()
			_fill_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_fill_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			_fill_mat.albedo_color = fill_color
			_fill.material_override = _fill_mat


## Kích hoạt hiển thị chỉ thị tại vị trí đích trên sàn với bán kính và thời gian nạp
func show_indicator(target_pos: Vector3, radius: float, duration: float) -> void:
	_target_radius = radius
	_duration = maxf(duration, 0.01)
	_timer = 0.0
	
	global_position = target_pos
	# Giữ sát mặt đất để tránh z-fighting
	global_position.y += 0.02
	
	if _border:
		_border.scale = Vector3(_target_radius, 1.0, _target_radius)
	if _fill:
		_fill.scale = Vector3(0.001, 1.0, 0.001)
	
	visible = true
	set_physics_process(true)


## Ẩn chỉ thị khi đòn đánh đã va chạm đất
func hide_indicator() -> void:
	visible = false
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	_timer += delta
	var progress := clampf(_timer / _duration, 0.0, 1.0)
	
	if _fill:
		var current_r: float = maxf(_target_radius * progress, 0.001)
		_fill.scale = Vector3(current_r, 1.0, current_r)
	
	if _timer >= _duration:
		# Đã nạp đầy, giữ trạng thái cho đến khi lệnh dậm đất tắt nó
		pass
