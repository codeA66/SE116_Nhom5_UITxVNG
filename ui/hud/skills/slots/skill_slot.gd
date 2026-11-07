@tool
class_name SkillSlot
extends Control
## DONE: nét mực, glyph dữ liệu, quét hồi chiêu; bộ đệm hình chỉ tạo khi đổi style.
## NOTES: lớp con quyết định sở hữu/sẵn sàng; input HUD không tiêu sự kiện gameplay.
signal activated(slot: SkillSlot)
const Style = preload("res://resources/ui/hud_style.gd")
@export_group("Binding")
@export var input_action: StringName = &""
@export var cooldown_signal: StringName = &""
@export var active_states: Array[StringName] = []
@export var glyph_id: StringName = &""
@export var icon: Texture2D
@export var style: Style = preload("res://resources/ui/hud_style.tres")
var show_key_badge: bool:
	get: return style.skill_show_key_badges
var icon_rotation_degrees: float:
	get: return style.skill_icon_rotations.get(glyph_id,0.0)
var radius: float = 25.0
var padding: float = 9.0
var highlighted: bool = false
var selected: bool = false
var _available: bool = false
var _active: bool = false
var _cooldown_total: float = 0.0
var _cooldown_left: float = 0.0
var _scale_from: float = 1.0
var _scale_target: float = 1.0
var _scale_age: float = INF
var _scale_duration: float = 0.0
var _key_label: String = ""
var _cooldown_text: String = ""
var _tick: int = -1
var _font: Font
var _badge_style: StyleBoxFlat = StyleBoxFlat.new()
var _badge_rect: Rect2
var _points: PackedVector2Array = PackedVector2Array()
var _outline: PackedVector2Array = PackedVector2Array()
var _inner: PackedVector2Array = PackedVector2Array()
var _sweep: PackedVector2Array = PackedVector2Array()
var _glyph: Resource
var _texture: Texture2D
## Ready của con không đọc bất kỳ onready nào của Player.
func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	apply_style()
	set_process(false)
	set_process_unhandled_input(false)
	resized.connect(_cache_geometry)
	refresh()
## Đồng hồ chỉ phục vụ các phản hồi hữu hạn; kết thúc hồi chiêu tự tắt xử lý.
func _process(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left-delta,0)
	_scale_age += delta
	var t: float = clampf(_scale_age/maxf(_scale_duration,0.001),0,1)
	scale = Vector2.ONE*lerpf(_scale_from,_scale_target,1.0-pow(1.0-t,2.0))
	if _cooldown_left>0.0:
		_update_sweep()
	else:
		if _cooldown_total>0.0:
			_cooldown_total = 0.0
			refresh()
	queue_redraw()
	if _cooldown_left<=0.0 and _scale_age>=maxf(_scale_duration,0.001): set_process(false)
## Không chặn input; cùng phím vẫn đến state machine của nhân vật.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(input_action,false,true): play_press()
## Mặc định là ô rỗng; mở rộng bằng lớp con/dữ liệu, không sửa bộ vẽ.
func is_available() -> bool:
	return false
## Sẵn sàng do lớp con quyết định.
func is_ready() -> bool:
	return false
## Giữ API chọn chủ động cho các loại ô mở rộng.
func is_selected() -> bool:
	return false
## API công khai phục vụ gameplay preview/test.
func is_cooling_down() -> bool:
	return _cooldown_left>0.0
## Trạng thái đang dùng không suy ra từ số lần bấm.
func is_active() -> bool:
	return _active
## Nhận state_changed từ SkillCluster thay vì dò Player mỗi frame.
func set_active(value: bool) -> void:
	if _active == value: return
	_active = value
	refresh()
## Signal tiến trình/weapon/cooldown cùng cập nhật một đường, không khởi động lại cooldown.
func refresh() -> void:
	_available = Engine.is_editor_hint() or is_available()
	highlighted = _available and (Engine.is_editor_hint() or is_ready()) and not is_cooling_down()
	var previous: bool = selected
	selected = _available and (_active or is_selected())
	z_index = 1 if selected else 0
	set_process_unhandled_input(not Engine.is_editor_hint() and _available and InputMap.has_action(input_action))
	if previous != selected: _animate_scale(_base_scale(),style.skill_active_time)
	refresh_binding()
	queue_redraw()
## Cấu hình hình học chỉ chạy khi ready hoặc thay style, không ở mỗi nhát đánh.
func apply_style() -> void:
	theme = style.theme
	_font = get_theme_default_font()
	radius = style.get_skill_radius()
	padding = clampf(style.skill_padding,0,16)
	custom_minimum_size = Vector2.ONE*(radius+padding)*2.0
	size = custom_minimum_size
	pivot_offset = size*0.5
	_glyph = style.glyphs.get(glyph_id)
	_texture = icon if icon != null else style.texture_overrides.get(glyph_id)
	_badge_style.bg_color = style.ink
	_badge_style.border_color = style.gold
	_badge_style.set_border_width_all(maxi(roundi(style.stroke_width()),1))
	_badge_style.set_corner_radius_all(2)
	_sweep.resize(clampi(style.skill_sweep_steps,8,96)+2)
	_cache_geometry()
	refresh_binding()
	queue_redraw()
## Signal dùng duration thật, thời gian <=0 không để lớp phủ bị kẹt.
func start_cooldown(duration: float) -> void:
	if duration<=0:
		_cooldown_left = 0.0
		_cooldown_total = 0.0
		refresh()
		return
	_cooldown_total = duration
	_cooldown_left = duration
	_tick = -1
	_update_sweep()
	set_process(true)
	refresh()
## Phản hồi bấm dùng đồng hồ sẵn có, không tạo một Tween mới mỗi lần.
func play_press() -> void:
	scale = Vector2.ONE*_base_scale()*clampf(style.skill_press_scale,1,maxf(style.skill_scale_limit,1))
	_animate_scale(_base_scale(),style.skill_press_time)
	activated.emit(self)
## Binding chỉ đổi khi InputMap thực sự đổi chuỗi, không tạo chữ mỗi draw.
func refresh_binding() -> void:
	var text: String = ""
	if InputMap.has_action(input_action):
		var events: Array[InputEvent] = InputMap.action_get_events(input_action)
		if not events.is_empty(): text = _binding_label(events[0])
	if _key_label != text:
		_key_label = text
		_cache_badge()
		queue_redraw()
## VFX nhận kỹ năng vẫn lấy tâm ô bằng API này.
func get_center() -> Vector2:
	return size*0.5
## Đường hình là điểm mở rộng; chỉ gọi khi cache thay đổi.
func _shape_points(center: Vector2, extent: float) -> PackedVector2Array:
	return PackedVector2Array([center+Vector2(0,-extent),center+Vector2(extent,0),center+Vector2(0,extent),center+Vector2(-extent,0)])
## Tách kích thước đang dùng với press ngắn hạn.
func _base_scale() -> float:
	return style.get_active_scale() if selected else 1.0
## Chỉ giữ một trạng thái scale, input dồn không tạo hàng đợi vô hạn.
func _animate_scale(target: float, duration: float) -> void:
	_scale_from = scale.x
	_scale_target = target
	_scale_duration = duration
	_scale_age = 0.0
	set_process(true)
## Các polygon/viền đã đóng được cache để draw không duplicate/append.
func _cache_geometry() -> void:
	_points = _shape_points(get_center(),radius)
	_outline = _points.duplicate()
	_outline.append(_points[0])
	_inner = _shape_points(get_center(),maxf(radius-style.skill_inner_gap,0.01))
	_inner.append(_inner[0])
	_cache_badge()
	if is_cooling_down(): _update_sweep()
## Kích thước chữ phím không phải đo lại trong từng frame cooldown.
func _cache_badge() -> void:
	if _font == null: return
	var height: float = clampf(style.skill_badge_height,1,64)
	var width: float = maxf(height,_font.get_string_size(_key_label,HORIZONTAL_ALIGNMENT_LEFT,-1,maxi(style.skill_key_font,1)).x+style.skill_badge_padding)
	var center: Vector2 = get_center()+style.skill_badge_anchor*radius
	_badge_rect = Rect2(center-Vector2(width,height)*0.5,Vector2(width,height))
## Quét góc được cắt theo hình thoi; ghi đè bộ đệm, không tạo mảng theo frame.
func _update_sweep() -> void:
	if _sweep.size()<3: return
	var steps: int = _sweep.size()-2
	var remaining: float = clampf(_cooldown_left/maxf(_cooldown_total,0.001),0,1)
	var center: Vector2 = get_center()
	_sweep[0] = center
	for index: int in range(steps+1):
		var angle: float = -PI*0.5+remaining*TAU*float(index)/float(steps)
		var direction: Vector2 = Vector2(cos(angle),sin(angle))
		_sweep[index+1] = center+direction*radius/maxf(absf(direction.x)+absf(direction.y),0.001)
	var tick: int = ceili(_cooldown_left*10.0)
	if tick != _tick:
		_tick = tick
		_cooldown_text = "%.1f" % _cooldown_left if _cooldown_left<1.0 else "%d" % ceili(_cooldown_left)
## Chuỗi tên phím xuất phát từ InputMap, không gán cứng E/Q/F trong artwork.
func _binding_label(event: InputEvent) -> String:
	if event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event as InputEventMouseButton
		var prefix: String = ""
		if mouse.ctrl_pressed: prefix += "Ctrl+"
		if mouse.alt_pressed: prefix += "Alt+"
		if mouse.shift_pressed: prefix += "Shift+"
		if mouse.meta_pressed: prefix += "Meta+"
		if mouse.button_index == MOUSE_BUTTON_LEFT: return prefix+"LMB"
		if mouse.button_index == MOUSE_BUTTON_RIGHT: return prefix+"RMB"
		if mouse.button_index == MOUSE_BUTTON_MIDDLE: return prefix+"MMB"
		return event.as_text()
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if key.keycode!=KEY_NONE: return key.as_text_keycode()
		if key.physical_keycode!=KEY_NONE: return key.as_text_physical_keycode()
		return key.as_text_key_label()
	if event is InputEventJoypadButton:
		return "Pad %d" % (event as InputEventJoypadButton).button_index
	if event is InputEventJoypadMotion:
		var motion: InputEventJoypadMotion = event as InputEventJoypadMotion
		return "Axis %d%s" % [motion.axis,"+" if motion.axis_value>=0 else "−"]
	return event.as_text()
## Tất cả dữ liệu đường bao/glyph đã có; nền tối giúp nét ngà không lẫn sàn sáng.
func _draw() -> void:
	if style == null or _points.size()<3: return
	var center: Vector2 = get_center()
	draw_colored_polygon(_points,style.skill_selected_fill if selected else style.skill_fill)
	draw_polyline(_outline,style.ivory if selected else (style.gold if _available else style.muted),style.skill_active_line if selected else style.stroke_width(),true)
	if selected: draw_polyline(_inner,Color(style.gold,0.5),style.stroke_width(),true)
	if _available:
		var tint: Color = style.ivory if highlighted else style.muted
		if _texture != null:
			var extent: float = radius*style.skill_icon_scale
			draw_texture_rect(_texture,Rect2(center-Vector2.ONE*extent,Vector2.ONE*extent*2),false,tint)
		elif _glyph != null:
			_glyph.draw_on(self,center,radius*style.skill_icon_scale,tint,style.stroke_width(),deg_to_rad(icon_rotation_degrees))
		if is_cooling_down() and _cooldown_left/maxf(_cooldown_total,0.001)>0.001:
			draw_colored_polygon(_sweep,style.skill_cooldown_color)
			draw_line(center,_sweep[-1],style.skill_cooldown_line,style.stroke_width(),true)
			draw_string(_font,center+Vector2(-radius,_font.get_ascent(maxi(style.skill_cooldown_font,1))*0.35),_cooldown_text,HORIZONTAL_ALIGNMENT_CENTER,radius*2,maxi(style.skill_cooldown_font,1),style.ivory)
	if show_key_badge and _available: _draw_badge()
	_draw_extra(center)
## Điểm mở rộng cho huy hiệu nguyên tố; lớp gốc không biết hệ fusion.
func _draw_extra(_center: Vector2) -> void:
	pass
## Huy hiệu nhỏ và vuông nhẹ, dùng cùng nét mực của cả HUD.
func _draw_badge() -> void:
	if _font == null or _key_label.is_empty(): return
	draw_style_box(_badge_style,_badge_rect)
	var font_size: int = maxi(style.skill_key_font,1)
	var baseline: Vector2 = Vector2(_badge_rect.position.x,_badge_rect.get_center().y+_font.get_ascent(font_size)*0.35)
	draw_string(_font,baseline,_key_label,HORIZONTAL_ALIGNMENT_CENTER,_badge_rect.size.x,font_size,style.ivory)
