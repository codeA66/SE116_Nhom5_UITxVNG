class_name HealthBar
extends HBoxContainer
## Hàng đầu cáo dùng được cho bất kỳ HealthComponent nào; không biết Player/GameState.
const Style = preload("res://resources/ui/hud_style.gd")
const Segment = preload("res://ui/hud/health/segment/health_segment.gd")
@export_group("Binding")
@export var health: HealthComponent
@export var segment_scene: PackedScene
@export var style: Style = preload("res://resources/ui/hud_style.tres")
var _segments: Array[Control] = []
var _initialized: bool = false
var _fit_width: float = INF
## Widget có thể ready trước component của chủ; không đọc current_health trước thời điểm đó.
func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_process(false)
	add_theme_constant_override(&"separation",maxi(style.health_spacing,0))
	if health == null: return
	if not health.is_node_ready(): await health.ready
	if not is_inside_tree(): return
	health.health_changed.connect(_refresh)
	_refresh(health.current_health,health.max_health)
	_initialized = true
## Layout truyền chiều rộng hữu dụng để 20 đầu cáo không tràn màn.
func fit_width(value: float) -> void:
	if is_equal_approx(value,_fit_width): return
	_fit_width = maxf(value,1.0)
	_fit_segments()
## Preview dùng chung đường áp style với scene thật.
func apply_style() -> void:
	add_theme_constant_override(&"separation",maxi(style.health_spacing,0))
	for segment: Control in _segments:
		segment.set(&"style",style)
		segment.call(&"apply_style")
	_fit_segments()
## Signal máu thật điều khiển cả đầy/rỗng và cảnh báo; không kiểm tra từng frame.
func _refresh(current: int, max_value: int) -> void:
	_resize_segments(maxi(max_value,0))
	for index: int in range(_segments.size()):
		_segments[index].call(&"set_filled",index<current,_initialized)
		_segments[index].call(&"set_low_health",current>0 and current<=style.health_low_threshold and index==current-1)
	_fit_segments()
## Chỉ tạo/hủy node khi sức chứa thay đổi; damage và heal tái dùng mọi ô.
func _resize_segments(count: int) -> void:
	while _segments.size()<count:
		var segment: Control = segment_scene.instantiate() as Control if segment_scene != null else Segment.new()
		segment.set(&"style",style)
		add_child(segment)
		_segments.append(segment)
	while _segments.size()>count:
		var segment: Control = _segments.pop_back()
		remove_child(segment)
		segment.queue_free()
## Kích thước hữu hạn kể cả style bằng không hoặc rất lớn.
func _fit_segments() -> void:
	var available: float = minf(maxf(style.health_max_width,1),_fit_width)
	var count: int = maxi(_segments.size(),1)
	var spacing: int = maxi(style.health_spacing,0)
	var width: float = maxf(1.0,minf(style.health_icon_size.x,(available-float(spacing*(count-1)))/float(count)))
	var height: float = clampf(style.health_icon_size.y,1.0,maxf(style.health_icon_max_height,1.0))
	for segment: Control in _segments:
		var desired: Vector2 = Vector2(width,height)
		if segment.custom_minimum_size != desired: segment.custom_minimum_size = desired
