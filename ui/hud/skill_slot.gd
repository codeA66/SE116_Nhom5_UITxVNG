@tool
class_name SkillSlot
extends Control
## Một ô kỹ năng hình thoi kiểu Death's Door: icon, huy hiệu phím (lấy từ Input Map), lớp phủ hồi chiêu.
## Ô đang chọn to hơn và viền trắng đậm; chưa có (is_available sai) thì vẽ ô rỗng để giữ nguyên bố cục cụm.
## Lớp con chỉ quyết định is_available / is_ready / is_selected; thêm loại ô mới = thêm lớp con, không sửa file này.
## Đổi hình ô: ghi đè _shape_points ở lớp con.
## Hiệu năng: vẽ bằng _draw, chỉ vẽ lại khi đổi trạng thái; _process chỉ bật trong lúc hồi chiêu.

## Phát khi người chơi bấm phím của ô
signal activated(slot: SkillSlot)

## Để trống: ô không gắn phím (ô rỗng chờ kỹ năng sau)
@export var input_action: StringName = &""
@export var icon: Texture2D:
	set(value):
		icon = value
		queue_redraw()
## Tên signal trên player báo bắt đầu hồi chiêu, dạng (duration: float). Để trống nếu ô không có hồi chiêu
@export var cooldown_signal: StringName = &""
## Player đang ở một trong các state này (đang dùng chiêu) thì ô được chọn: phóng to, viền trắng
@export var active_states: Array[StringName] = []

@export_group("Shape")
## Nửa đường chéo hình thoi
@export var radius: float = 30.0:
	set(value):
		radius = value
		_update_size()
## Tỉ lệ icon so với đường chéo ô
@export_range(0.1, 1.0) var icon_scale: float = 0.5:
	set(value):
		icon_scale = value
		queue_redraw()
@export_range(-180.0, 180.0) var icon_rotation_degrees: float = 0.0:
	set(value):
		icon_rotation_degrees = value
		queue_redraw()
## Chừa lề quanh ô cho lúc phóng to khi được chọn và huy hiệu phím
@export var padding: float = 8.0:
	set(value):
		padding = value
		_update_size()
## Vị trí tâm huy hiệu phím so với tâm ô, tính theo bán kính. Mặc định nằm trong mũi dưới của ô:
## đặt ra cạnh thì bị ô bên cạnh vẽ đè
@export var badge_anchor: Vector2 = Vector2(0.0, 0.62):
	set(value):
		badge_anchor = value
		queue_redraw()
@export var show_key_badge: bool = true:
	set(value):
		show_key_badge = value
		queue_redraw()

@export_group("Colors")
@export var fill_color := Color(0.1, 0.1, 0.1, 0.8)
@export var selected_fill_color := Color(0.16, 0.16, 0.16, 0.9)
@export var empty_fill_color := Color(0.12, 0.12, 0.12, 0.55)
@export var border_color := Color(0.62, 0.62, 0.62, 0.7)
@export var selected_border_color := Color(0.96, 0.96, 0.96, 1.0)
@export var empty_border_color := Color(0.45, 0.45, 0.45, 0.45)
@export var icon_ready_color := Color(0.96, 0.96, 0.96, 1.0)
@export var icon_idle_color := Color(0.55, 0.55, 0.55, 1.0)
@export var cooldown_overlay_color := Color(0.0, 0.0, 0.0, 0.6)
## Hình thoi nhỏ lớn dần ở tâm: hồi được bao nhiêu thì to bấy nhiêu
@export var cooldown_fill_color := Color(1.0, 1.0, 1.0, 0.25)
@export var cooldown_text_color := Color(0.96, 0.96, 0.96, 1.0)
@export var badge_color := Color(0.06, 0.06, 0.06, 0.95)
@export var badge_border_color := Color(0.62, 0.62, 0.62, 0.8)
@export var badge_text_color := Color(0.92, 0.92, 0.92, 1.0)

@export_group("Feedback")
## Ô đang chọn to hơn các ô khác (mẫu: ô bom bên phải)
@export var selected_scale: float = 1.15
@export var select_time: float = 0.15
@export var border_width: float = 1.5
@export var selected_border_width: float = 3.0
## Ô đang chọn có thêm viền trong mảnh cách viền ngoài bấy nhiêu px
@export var selected_inner_gap: float = 4.0
@export var press_scale: float = 1.08
@export var press_time: float = 0.18
@export var key_font_size: int = 10
@export var cooldown_font_size: int = 12
## Huy hiệu phím dạng viên thuốc: phím một ký tự thành hình tròn
@export var badge_height: float = 15.0:
	set(value):
		badge_height = value
		queue_redraw()

## Ô sáng (sẵn sàng dùng) / đang chọn (đang cầm)
var highlighted: bool = false
var selected: bool = false

var _available: bool = true
var _active: bool = false
var _cooldown_total: float = 0.0
var _cooldown_left: float = 0.0
var _scale_tween: Tween
var _key_label: String = ""
var _font: Font
## Tạo một lần, chỉ đổi màu/bo góc lúc vẽ
var _badge_style := StyleBoxFlat.new()


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_font = get_theme_default_font()
	_update_size()
	set_process(false)
	set_process_unhandled_input(false)
	if Engine.is_editor_hint():
		return
	refresh()


func _process(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	if _cooldown_left <= 0.0:
		set_process(false)
		refresh()
	else:
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	# Chỉ nghe sự kiện, không dò Input mỗi frame. Không tiêu sự kiện: gameplay vẫn nhận phím
	if event.is_action_pressed(input_action, false, true):
		play_press()


## Đã sở hữu / đã mở khóa chưa; chưa thì vẽ ô rỗng. Lớp gốc dùng trực tiếp làm ô rỗng chờ kỹ năng sau
func is_available() -> bool:
	return false


## Ô có sáng không khi không hồi chiêu. Lớp con ghi đè
func is_ready() -> bool:
	return false


## Ô có đang được chọn (phóng to) không. Lớp con ghi đè
func is_selected() -> bool:
	return false


func is_cooling_down() -> bool:
	return _cooldown_left > 0.0


func is_active() -> bool:
	return _active


func set_active(value: bool) -> void:
	if _active == value:
		return
	_active = value
	refresh()


func refresh() -> void:
	_available = is_available()
	highlighted = _available and is_ready() and not is_cooling_down()
	var was_selected := selected
	selected = _available and (_active or is_selected())
	# Ô to vẽ đè lên ô bên cạnh
	z_index = 1 if selected else 0
	set_process_unhandled_input(_available and InputMap.has_action(input_action))
	if was_selected != selected:
		_tween_scale(_base_scale(), select_time)
	refresh_binding()
	queue_redraw()


## Bắt đầu hiện thời gian hồi
func start_cooldown(duration: float) -> void:
	if duration <= 0.0:
		return
	_cooldown_total = duration
	_cooldown_left = duration
	set_process(true)
	refresh()


func play_press() -> void:
	scale = Vector2.ONE * _base_scale() * press_scale
	_tween_scale(_base_scale(), press_time)
	activated.emit(self)


func refresh_binding() -> void:
	var label := ""
	if InputMap.has_action(input_action):
		var events := InputMap.action_get_events(input_action)
		if not events.is_empty():
			label = _binding_label(events[0])
	if _key_label != label:
		_key_label = label
		queue_redraw()


## Tâm ô trong toạ độ của chính nó
func get_center() -> Vector2:
	return size * 0.5


## Các đỉnh của hình ô, theo chiều kim đồng hồ. Mặc định hình thoi
func _shape_points(center: Vector2, r: float) -> PackedVector2Array:
	return PackedVector2Array([center + Vector2(0, -r), center + Vector2(r, 0), center + Vector2(0, r), center + Vector2(-r, 0)])


func _base_scale() -> float:
	return selected_scale if selected else 1.0


func _tween_scale(target: float, duration: float) -> void:
	if _scale_tween:
		_scale_tween.kill()
	if not is_inside_tree() or duration <= 0.0:
		scale = Vector2.ONE * target
		return
	_scale_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_scale_tween.tween_property(self, ^"scale", Vector2.ONE * target, duration)


func _update_size() -> void:
	# Giữ nguyên tâm ô khi đổi bán kính: chỉnh radius không làm lệch bố cục cụm ô
	var center := position + size * 0.5
	custom_minimum_size = Vector2.ONE * (radius + padding) * 2.0
	size = custom_minimum_size
	position = center - size * 0.5
	pivot_offset = size * 0.5
	queue_redraw()


func _binding_label(event: InputEvent) -> String:
	if event is InputEventKey:
		if event.keycode != KEY_NONE:
			return event.as_text_keycode()
		if event.physical_keycode != KEY_NONE:
			return event.as_text_physical_keycode()
		return event.as_text_key_label()
	if event is InputEventMouseButton:
		var modifiers: Array[String] = []
		if event.ctrl_pressed:
			modifiers.append("Ctrl")
		if event.alt_pressed:
			modifiers.append("Alt")
		if event.shift_pressed:
			modifiers.append("Shift")
		if event.meta_pressed:
			modifiers.append("Meta")
		var button: String = {
			MOUSE_BUTTON_LEFT: "LMB", MOUSE_BUTTON_RIGHT: "RMB", MOUSE_BUTTON_MIDDLE: "MMB",
			MOUSE_BUTTON_WHEEL_UP: "Wheel ↑", MOUSE_BUTTON_WHEEL_DOWN: "Wheel ↓",
			MOUSE_BUTTON_WHEEL_LEFT: "Wheel ←", MOUSE_BUTTON_WHEEL_RIGHT: "Wheel →",
		}.get(event.button_index, "M%d" % event.button_index)
		modifiers.append(button)
		return "+".join(modifiers)
	if event is InputEventJoypadButton:
		return "Pad %d" % event.button_index
	if event is InputEventJoypadMotion:
		return "Axis %d%s" % [event.axis, "+" if event.axis_value >= 0.0 else "−"]
	return event.as_text()


func _draw() -> void:
	var center := get_center()
	var points := _shape_points(center, radius)
	if not _available:
		draw_colored_polygon(points, empty_fill_color)
		_draw_outline(points, empty_border_color, border_width)
		return
	draw_colored_polygon(points, selected_fill_color if selected else fill_color)
	if selected:
		_draw_outline(points, selected_border_color, selected_border_width)
		_draw_outline(_shape_points(center, radius - selected_inner_gap), Color(selected_border_color, 0.5), 1.0)
	else:
		_draw_outline(points, border_color, border_width)
	_draw_icon(center)
	if is_cooling_down():
		_draw_cooldown(center, points)
	if show_key_badge:
		_draw_badge(center)
	_draw_extra(center)


## Lớp con vẽ thêm lên trên cùng (vd. chấm nguyên tố đang ghép). Mặc định không vẽ gì
func _draw_extra(_center: Vector2) -> void:
	pass


func _draw_outline(points: PackedVector2Array, color: Color, width: float) -> void:
	var closed := PackedVector2Array(points)
	closed.append(points[0])
	draw_polyline(closed, color, width, true)


func _draw_icon(center: Vector2) -> void:
	if icon == null:
		return
	var icon_size := Vector2.ONE * radius * 2.0 * icon_scale
	var color := icon_ready_color if highlighted else icon_idle_color
	draw_set_transform(center, deg_to_rad(icon_rotation_degrees), Vector2.ONE)
	draw_texture_rect(icon, Rect2(-icon_size * 0.5, icon_size), false, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_cooldown(center: Vector2, points: PackedVector2Array) -> void:
	draw_colored_polygon(points, cooldown_overlay_color)
	var progress := 1.0 - _cooldown_left / maxf(_cooldown_total, 0.001)
	# Dưới 1 px thì đa giác suy biến, bỏ qua
	if radius * progress >= 1.0:
		draw_colored_polygon(_shape_points(center, radius * progress), cooldown_fill_color)
	if _font == null:
		return
	var text := "%.1f" % _cooldown_left if _cooldown_left < 1.0 else "%d" % ceili(_cooldown_left)
	var ascent := _font.get_ascent(cooldown_font_size)
	var pos := Vector2(center.x - radius, center.y + ascent * 0.5 - 1.0)
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, cooldown_font_size, cooldown_text_color)


func _draw_badge(center: Vector2) -> void:
	if _font == null or _key_label.is_empty():
		return
	var text_width := _font.get_string_size(_key_label, HORIZONTAL_ALIGNMENT_LEFT, -1, key_font_size).x
	var badge_size := Vector2(maxf(badge_height, text_width + badge_height * 0.6), badge_height)
	var badge_center := center + badge_anchor * radius
	var rect := Rect2(badge_center - badge_size * 0.5, badge_size)
	_badge_style.bg_color = badge_color
	_badge_style.border_color = selected_border_color if selected else badge_border_color
	_badge_style.set_border_width_all(1)
	_badge_style.set_corner_radius_all(ceili(badge_height * 0.5))
	_badge_style.anti_aliasing = true
	draw_style_box(_badge_style, rect)
	var ascent := _font.get_ascent(key_font_size)
	var text_pos := Vector2(rect.position.x, badge_center.y + ascent * 0.5 - 1.0)
	draw_string(_font, text_pos, _key_label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, key_font_size, badge_text_color)
