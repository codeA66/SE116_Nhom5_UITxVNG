class_name EnergyBar
extends HBoxContainer
## Thanh năng lượng dạng ô, nằm dưới thanh máu. Chỉ nghe signal của EnergyComponent.
## Thiếu năng lượng thì nháy đỏ và rung nhẹ. Không chạy mỗi frame; tạo ô một lần, chỉ đổi style.

@export var energy: EnergyComponent
@export var filled_style: StyleBox
@export var empty_style: StyleBox
@export var segment_size: Vector2 = Vector2(18.0, 18.0)
@export_group("Feedback")
## Ô vừa nạp phồng to bấy nhiêu lần rồi co về
@export var pop_scale: float = 1.5
@export var pop_time: float = 0.25
@export_group("Insufficient")
@export var warn_color: Color = Color(1.0, 0.35, 0.3)
@export var warn_time: float = 0.35
## Biên độ rung ngang (px)
@export var shake_amount: float = 5.0

var _segments: Array[Panel] = []
var _tween: Tween
var _rest_x: float
## Số ô đang hiện, để biết ô nào vừa nạp / vừa tiêu; -1 = chưa dựng
var _shown: int = -1


func _ready() -> void:
	_rest_x = position.x
	if energy == null:
		push_warning("%s chưa gán EnergyComponent" % get_path())
		return
	energy.energy_changed.connect(_refresh)
	energy.insufficient.connect(_on_insufficient)
	_refresh(energy.current, energy.get_max())


func _refresh(current: int, max_value: int) -> void:
	while _segments.size() < max_value:
		var segment := Panel.new()
		segment.custom_minimum_size = segment_size
		segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Ô hình thoi: xoay 45° quanh tâm
		segment.pivot_offset = segment_size * 0.5
		segment.rotation = PI / 4.0
		add_child(segment)
		_segments.append(segment)
	while _segments.size() > max_value:
		_segments.pop_back().queue_free()
	for i in _segments.size():
		_segments[i].add_theme_stylebox_override(&"panel", filled_style if i < current else empty_style)
	# Ô vừa nạp phồng sáng lên, ô vừa tiêu nháy trắng rồi tắt (bỏ qua lần dựng đầu tiên)
	if _shown >= 0:
		for i in range(mini(_shown, current), maxi(_shown, current)):
			if i < _segments.size():
				_pop(_segments[i], i < current)
	_shown = current


func _pop(segment: Panel, gained: bool) -> void:
	var tween := segment.create_tween().set_parallel()
	if gained:
		segment.scale = Vector2.ONE * pop_scale
		segment.modulate = Color(1.6, 1.6, 1.6)
		tween.tween_property(segment, ^"scale", Vector2.ONE, pop_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(segment, ^"modulate", Color.WHITE, pop_time)
	else:
		segment.modulate = Color(2.0, 2.0, 2.0)
		segment.scale = Vector2.ONE * 1.15
		tween.tween_property(segment, ^"scale", Vector2.ONE, pop_time * 0.7)
		tween.tween_property(segment, ^"modulate", Color.WHITE, pop_time * 0.7)


func _on_insufficient(_cost: int) -> void:
	if _tween:
		_tween.kill()
	position.x = _rest_x
	modulate = warn_color
	_tween = create_tween()
	_tween.tween_property(self, ^"position:x", _rest_x + shake_amount, warn_time * 0.15)
	_tween.tween_property(self, ^"position:x", _rest_x - shake_amount, warn_time * 0.2)
	_tween.tween_property(self, ^"position:x", _rest_x, warn_time * 0.15)
	_tween.parallel().tween_property(self, ^"modulate", Color.WHITE, warn_time)
