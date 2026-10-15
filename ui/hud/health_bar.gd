class_name HealthBar
extends HBoxContainer
## Thanh máu dạng từng ô. Chỉ nghe signal của HealthComponent, không biết chủ sở hữu là ai:
## dùng lại cho quái, boss bằng cách gán health khác.
## Hiệu năng: chỉ cập nhật khi máu đổi, không chạy mỗi frame; tạo ô một lần, chỉ đổi style.

@export var health: HealthComponent
@export var filled_style: StyleBox
@export var empty_style: StyleBox
@export var segment_size: Vector2 = Vector2(26.0, 12.0)

var _segments: Array[Panel] = []


func _ready() -> void:
	if health == null:
		push_warning("%s chưa gán HealthComponent" % get_path())
		return
	health.health_changed.connect(_refresh)
	_refresh(health.current_health, health.max_health)


func _refresh(current: int, max_value: int) -> void:
	_resize_segments(max_value)
	for i in _segments.size():
		_segments[i].add_theme_stylebox_override(&"panel", filled_style if i < current else empty_style)


## Chỉ tạo/xóa ô khi máu tối đa thay đổi
func _resize_segments(count: int) -> void:
	while _segments.size() < count:
		var segment := Panel.new()
		segment.custom_minimum_size = segment_size
		segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(segment)
		_segments.append(segment)
	while _segments.size() > count:
		_segments.pop_back().queue_free()
