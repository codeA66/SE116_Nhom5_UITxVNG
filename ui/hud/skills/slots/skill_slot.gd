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
var _press_left: float = 0.0
var _key_label: String = ""
var _mouse_button: MouseButton = MOUSE_BUTTON_NONE
var _binding_width: float = INF
var _binding_scale: float = 1.0
var _cooldown_text: String = ""
var _tick: int = -1
var _font: Font
var _badge_style: StyleBoxFlat = StyleBoxFlat.new()
var _badge_rect: Rect2
var _points: PackedVector2Array = PackedVector2Array()
var _outline: PackedVector2Array = PackedVector2Array()
var _inner: PackedVector2Array = PackedVector2Array()
var _bevel: PackedVector2Array = PackedVector2Array()
var _top_gem: PackedVector2Array = PackedVector2Array()
var _sweep: PackedVector2Array = PackedVector2Array()
var _glyph: Resource
var _texture: Texture2D
var _accent: Color
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
	_press_left = maxf(_press_left-delta,0.0)
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
	if _cooldown_left<=0.0 and _press_left<=0.0 and _scale_age>=maxf(_scale_duration,0.001): set_process(false)
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
	selected = _available and (_active or is_selected())
	z_index = 1 if selected else 0
	set_process_unhandled_input(not Engine.is_editor_hint() and _available and InputMap.has_action(input_action))
	var target_scale: float = _base_scale()
	if not is_equal_approx(_scale_target,target_scale): _animate_scale(target_scale,style.skill_active_time)
	refresh_binding()
	queue_redraw()
## Cấu hình hình học chỉ chạy khi ready hoặc thay style, không ở mỗi nhát đánh.
func apply_style() -> void:
	theme = style.theme
	_font = style.skill_font if style.skill_font != null else get_theme_default_font()
	radius = style.get_skill_radius()
	padding = clampf(style.skill_padding,0,16)
	custom_minimum_size = Vector2.ONE*(radius+padding)*2.0
	size = custom_minimum_size
	pivot_offset = size*0.5
	_glyph = style.glyphs.get(glyph_id)
	_texture = icon if icon != null else style.texture_overrides.get(glyph_id)
	_accent = style.skill_icon_colors.get(glyph_id,style.ivory)
	_badge_style.bg_color = style.ink
	_badge_style.border_color = Color(style.gold,0.65)
	_badge_style.set_border_width_all(maxi(roundi(style.stroke_width()),1))
	_badge_style.set_corner_radius_all(3)
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
	if style.skill_input_tiles and not is_cooling_down():
		_press_left = maxf(style.skill_press_time,0.0)
		queue_redraw()
	scale = Vector2.ONE*_base_scale()*clampf(style.skill_press_scale,1,maxf(style.skill_scale_limit,1))
	_animate_scale(_base_scale(),style.skill_press_time)
	activated.emit(self)
## Binding chỉ đổi khi InputMap thực sự đổi chuỗi, không tạo chữ mỗi draw.
func refresh_binding() -> void:
	var text: String = ""
	var button: MouseButton = MOUSE_BUTTON_NONE
	if InputMap.has_action(input_action):
		var events: Array[InputEvent] = InputMap.action_get_events(input_action)
		for event: InputEvent in events:
			var mouse: InputEventMouseButton = event as InputEventMouseButton
			if mouse != null and (mouse.button_index==MOUSE_BUTTON_LEFT or mouse.button_index==MOUSE_BUTTON_RIGHT) and not (
				mouse.ctrl_pressed or mouse.alt_pressed or mouse.shift_pressed or mouse.meta_pressed):
				button = mouse.button_index
				break
		if button == MOUSE_BUTTON_NONE and not events.is_empty(): text = _binding_label(events[0])
	if _key_label != text or _mouse_button != button:
		_key_label = text
		_mouse_button = button
		_cache_badge()
		queue_redraw()
## Cụm ô cấp phần ngang để binding dài hoặc HUD nhỏ không chồng lên ô bên cạnh.
func set_binding_space(width: float, layout_scale: float) -> void:
	if is_equal_approx(_binding_width,width) and is_equal_approx(_binding_scale,layout_scale): return
	_binding_width = width
	_binding_scale = layout_scale
	queue_redraw()
## Dùng cùng điều kiện cho bố cục và lúc vẽ nhãn.
func is_binding_visible() -> bool:
	if not show_key_badge or not _available or _font == null: return false
	if _key_label.is_empty() and _mouse_button == MOUSE_BUTTON_NONE: return false
	var readable_size: float = float(maxi(style.skill_key_font,1)) if _mouse_button == MOUSE_BUTTON_NONE else _badge_rect.size.x
	return _badge_rect.size.x+clampi(style.text_outline_size,0,8)*2 <= _binding_width and readable_size*_binding_scale >= style.skill_label_min_size
## VFX nhận kỹ năng vẫn lấy tâm ô bằng API này.
func get_center() -> Vector2:
	return size*0.5
## Đường hình là điểm mở rộng; chỉ gọi khi cache thay đổi.
func _shape_points(center: Vector2, extent: float) -> PackedVector2Array:
	return PackedVector2Array([center+Vector2(0,-extent),center+Vector2(extent,0),center+Vector2(0,extent),center+Vector2(-extent,0)])
## Tách kích thước đang dùng với press ngắn hạn.
func _base_scale() -> float:
	var emphasize: bool = selected and (not style.skill_shared_panel or _active)
	return style.get_active_scale() if emphasize else 1.0
## Chỉ giữ một trạng thái scale, input dồn không tạo hàng đợi vô hạn.
func _animate_scale(target: float, duration: float) -> void:
	_scale_from = scale.x
	_scale_target = target
	_scale_duration = duration
	_scale_age = 0.0
	set_process(true)
## Các polygon/viền đã đóng được cache để draw không duplicate/append.
func _cache_geometry() -> void:
	var center: Vector2 = get_center()
	if style.skill_input_tiles:
		var corner: float = radius*(1.0-clampf(style.skill_tile_chamfer,0.05,0.8))
		_points = PackedVector2Array([center+Vector2(-corner,-radius),center+Vector2(corner,-radius),
			center+Vector2(radius,-corner),center+Vector2(radius,corner),
			center+Vector2(corner,radius),center+Vector2(-corner,radius),
			center+Vector2(-radius,corner),center+Vector2(-radius,-corner)])
	else:
		_points = _shape_points(center,radius)
	_outline = _points.duplicate()
	_outline.append(_points[0])
	_inner = _shape_points(get_center(),maxf(radius-style.skill_inner_gap,0.01))
	_inner.append(_inner[0])
	_bevel = PackedVector2Array([center + Vector2(-radius,0), center + Vector2(0,-radius),
		center + Vector2(radius,0), center + Vector2(0,-radius+style.skill_inner_gap*2.0)])
	var gem_y: float = -radius + style.skill_inner_gap
	var gem_size: float = clampf(style.stroke_width(),0.5,radius*0.2)
	_top_gem = _shape_points(center + Vector2(0,gem_y),gem_size)
	_cache_badge()
	if is_cooling_down(): _update_sweep()
## Kích thước chữ phím không phải đo lại trong từng frame cooldown.
func _cache_badge() -> void:
	if _font == null: return
	var height: float = clampf(style.skill_badge_height,1,64)
	var width: float = maxf(height,_font.get_string_size(_key_label,HORIZONTAL_ALIGNMENT_LEFT,-1,maxi(style.skill_key_font,1)).x+style.skill_badge_padding)
	if _mouse_button != MOUSE_BUTTON_NONE:
		var mouse_size: Vector2 = style.skill_mouse_size.clamp(Vector2.ONE,Vector2.ONE*64.0)
		width = mouse_size.x
		height = mouse_size.y
	var center: Vector2 = get_center()+style.skill_badge_anchor*radius
	_badge_rect = Rect2(center-Vector2(width,height)*0.5,Vector2(width,height))
## Quét góc được cắt theo hình thoi; ghi đè bộ đệm, không tạo mảng theo frame.
func _update_sweep() -> void:
	if not style.skill_shared_panel and not style.skill_input_tiles and _sweep.size()>=3:
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
		var decimal_limit: float = 10.0 if (style.skill_shared_panel or style.skill_input_tiles) else 1.0
		_cooldown_text = "%.1f" % _cooldown_left if _cooldown_left<decimal_limit else "%d" % ceili(_cooldown_left)
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
	if style.skill_input_tiles:
		_draw_input_tile(center)
		return
	if style.skill_shared_panel:
		_draw_shared_slot(center)
		return
	draw_colored_polygon(_points,style.skill_selected_fill if selected else style.skill_fill)
	if _available:
		draw_colored_polygon(_bevel,Color(_accent,0.14 if selected else 0.08))
		draw_colored_polygon(_top_gem,Color(_accent,0.95 if selected else 0.72))
		draw_polyline(_inner,Color(style.gold,0.54 if selected else 0.30),style.stroke_width(),true)
	draw_polyline(_outline,style.ink,style.stroke_width()*2.6,true)
	draw_polyline(_outline,style.ivory if selected else (style.gold if _available else style.muted),style.skill_active_line if selected else style.stroke_width(),true)
	if _available:
		var tint: Color = _accent if highlighted else _accent.lerp(style.muted,0.65)
		_draw_icon(center,tint)
		if is_cooling_down() and _cooldown_left/maxf(_cooldown_total,0.001)>0.001:
			draw_colored_polygon(_sweep,style.skill_cooldown_color)
			draw_line(center,_sweep[-1],style.skill_cooldown_line,style.stroke_width(),true)
			_draw_cooldown_number(center)
	if show_key_badge and _available: _draw_badge()
	_draw_extra(center)
## Giữ biểu tượng riêng để nền chung và khung rời dùng cùng dữ liệu.
func _draw_icon(center: Vector2,tint: Color) -> void:
	var extent: float = radius*style.skill_icon_scale
	if _texture != null:
		draw_texture_rect(_texture,Rect2(center-Vector2.ONE*extent,Vector2.ONE*extent*2),false,tint)
	elif _glyph != null:
		_glyph.draw_on(self,center,extent,tint,style.stroke_width(),deg_to_rad(icon_rotation_degrees))
## Ô chỉ nháy theo phím vừa bấm, màu gốc của atlas giữ nguyên khi nghỉ.
func _draw_input_tile(center: Vector2) -> void:
	var flash: float = clampf(_press_left/maxf(style.skill_press_time,style.minimum_duration),0.0,1.0)
	if is_cooling_down(): flash = 0.0
	draw_colored_polygon(_points,style.skill_fill.lerp(style.skill_press_fill,flash))
	var border: Color = style.skill_tile_border if _available else style.muted
	draw_polyline(_outline,border.lerp(style.ivory,flash),style.stroke_width(),true)
	if not _available: return
	var tint: Color = Color.WHITE.lerp(style.ink,flash*0.85)
	if is_cooling_down(): tint.a = 0.40
	_draw_icon(center,tint)
	if is_cooling_down():
		_draw_cooldown(center,center+Vector2.DOWN*radius*0.72,radius*0.65)
	if show_key_badge: _draw_badge()
	_draw_extra(center)
## Nhãn phím, dấu trang bị và thời gian hồi nằm riêng để giữ silhouette của kỹ năng.
func _draw_shared_slot(center: Vector2) -> void:
	if not _available: return
	var tint: Color = _accent if highlighted else _accent.lerp(style.ink,0.50)
	var icon_center: Vector2 = center-Vector2.DOWN*radius*0.12
	_draw_icon(icon_center,tint)
	var line: float = style.stroke_width()
	var marker: Vector2 = center+Vector2.DOWN*radius*0.75
	if is_cooling_down():
		_draw_cooldown(icon_center,marker,radius*0.47)
	elif selected:
		var extent: float = line*1.8
		draw_set_transform(marker,PI*0.25)
		draw_rect(Rect2(-Vector2.ONE*extent,Vector2.ONE*extent*2),_accent)
		draw_set_transform(Vector2.ZERO)
	if show_key_badge: _draw_badge()
	_draw_extra(center)
## Cả hai kiểu bố cục dùng thời gian hồi thật để vẽ số và vạch tiến độ.
func _draw_cooldown(icon_center: Vector2,marker: Vector2,half_width: float) -> void:
	var progress: float = 1.0-clampf(_cooldown_left/maxf(_cooldown_total,style.minimum_duration),0.0,1.0)
	var left: Vector2 = marker-Vector2.RIGHT*half_width
	var right: Vector2 = marker+Vector2.RIGHT*half_width
	var line: float = style.stroke_width()
	draw_line(left,right,Color(_accent,0.30),line,true)
	draw_line(left,left.lerp(right,progress),_accent,line,true)
	_draw_cooldown_number(icon_center)
## Số hồi chiêu vẫn rõ khi icon bên dưới sáng.
func _draw_cooldown_number(icon_center: Vector2) -> void:
	if _font == null: return
	var font_size: int = maxi(style.skill_cooldown_font,1)
	var baseline: Vector2 = icon_center+Vector2(-radius,_font.get_ascent(font_size)*0.35)
	draw_string_outline(_font,baseline,_cooldown_text,HORIZONTAL_ALIGNMENT_CENTER,radius*2,font_size,clampi(style.text_outline_size,0,8),style.text_outline_color)
	draw_string(_font,baseline,_cooldown_text,HORIZONTAL_ALIGNMENT_CENTER,radius*2,font_size,style.ivory)
## Điểm mở rộng cho huy hiệu nguyên tố; lớp gốc không biết hệ fusion.
func _draw_extra(_center: Vector2) -> void:
	pass
## Huy hiệu nhỏ và vuông nhẹ, dùng cùng nét mực của cả HUD.
func _draw_badge() -> void:
	if not is_binding_visible(): return
	var font_size: int = maxi(style.skill_key_font,1)
	var outline_size: int = clampi(style.text_outline_size,0,8)
	draw_style_box(_badge_style,_badge_rect)
	if _mouse_button != MOUSE_BUTTON_NONE:
		_draw_mouse_button()
		return
	var baseline: Vector2 = Vector2(_badge_rect.position.x,_badge_rect.get_center().y+_font.get_ascent(font_size)*0.35)
	draw_string_outline(_font,baseline,_key_label,HORIZONTAL_ALIGNMENT_CENTER,_badge_rect.size.x,font_size,outline_size,style.text_outline_color)
	draw_string(_font,baseline,_key_label,HORIZONTAL_ALIGNMENT_CENTER,_badge_rect.size.x,font_size,style.ivory)
## Nút chuột dùng cùng màu chữ và chia nửa trái/phải theo binding hiện tại.
func _draw_mouse_button() -> void:
	var edge: float = minf(style.stroke_width(),_badge_rect.size.x*0.25)
	var inner: Rect2 = _badge_rect.grow(-edge)
	var button_height: float = inner.size.y*clampf(style.skill_mouse_split,0.2,0.75)
	var button_width: float = (inner.size.x-edge)*0.5
	var offset: float = button_width+edge if _mouse_button == MOUSE_BUTTON_RIGHT else 0.0
	draw_rect(Rect2(inner.position+Vector2(offset,0),Vector2(button_width,button_height)),style.ivory)
	var divider: Vector2 = inner.position+Vector2(0,button_height)
	draw_line(divider,divider+Vector2(inner.size.x,0),style.gold,edge,true)
