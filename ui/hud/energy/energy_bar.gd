@tool
class_name EnergyBar
extends Control
## DONE: ấn Linh Ngọc ôm đuôi cáo, lõi chất lỏng tròn hạ/dâng qua signal; nghỉ thì CPU không process.
## NOTES: không biết Player/GameState; lớp ghép HUD truyền màu nguyên tố vào.
const Style = preload("res://resources/ui/hud_style.gd")
const VESSEL_SHADER: Shader = preload("res://ui/hud/energy/shaders/energy_vessel.gdshader")
@export_group("Binding")
@export var energy: EnergyComponent
@export var style: Style = preload("res://resources/ui/hud_style.tres")
var _surface: ColorRect
var _material: ShaderMaterial
var _maximum: int = 0
var _fill_ratio: float = 0.0
var _from: float = 0.0
var _target: float = 0.0
var _age: float = INF
var _warn_age: float = INF
var _ready_age: float = INF
var _clock: float = 0.0
var _pulse: float = 0.0
var _warning: float = 0.0
var _rest: Vector2
var _warn_active: bool = false
var _initialized: bool = false
var _tint: Color
var _font: Font
var _shell: Resource
var _fox_head: HudGlyph
var _fox_cream: HudGlyph
var _fox_ink: HudGlyph
var _frame_rect: Rect2
var _duration: float = 0.0
## Khởi tạo hình trước, chờ component sẵn sàng trước khi đọc giá trị ban đầu.
func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = VESSEL_SHADER
	_surface = ColorRect.new()
	_surface.name = "VesselSurface"
	_surface.mouse_filter = MOUSE_FILTER_IGNORE
	_surface.material = _material
	_surface.show_behind_parent = true
	add_child(_surface)
	_tint = style.energy_fallback
	apply_style()
	set_process(false)
	if Engine.is_editor_hint():
		_maximum = style.energy_preview_units
		_fill_ratio = 1.0 if _maximum>0 else 0.0
		_write_fill()
		return
	if energy == null:
		_write_fill()
		return
	if not energy.is_node_ready(): await energy.ready
	if not is_inside_tree(): return
	energy.energy_changed.connect(_refresh)
	energy.insufficient.connect(_on_insufficient)
	_refresh(energy.current,energy.get_max())
## Không giữ chuyển động/rung khi widget rời scene.
func _exit_tree() -> void:
	if _warn_active: position = _rest
## Style có thể được đổi ở preview, không phải tạo lại material.
func apply_style() -> void:
	theme = style.theme
	_font = get_theme_default_font()
	custom_minimum_size = Vector2(clampf(style.energy_size.x,1.0,maxf(style.energy_size_limit.x,1)),clampf(style.energy_size.y,1.0,maxf(style.energy_size_limit.y,1)))
	size = custom_minimum_size
	if _warn_active:
		position = _rest
		_warn_active = false
		_warning = 0.0
		_warn_age = INF
	if not is_instance_valid(_surface): return
	var diameter: float = clampf(style.energy_diameter,1.0,minf(size.x,size.y))
	var inset: float = clampf(style.energy_rim,0.0,diameter*0.4)
	_surface.position = Vector2((size.x-diameter)*0.5+inset,inset)
	_surface.size = Vector2.ONE*maxf(diameter-inset*2.0,1.0)
	_frame_rect = Rect2(Vector2((size.x-diameter)*0.5,0),Vector2.ONE*diameter)
	var vessel_uv: Rect2 = style.energy_frame_vessel_uv.intersection(Rect2(Vector2.ZERO,Vector2.ONE))
	if style.energy_frame_texture != null and vessel_uv.has_area():
		var art_size: Vector2 = style.energy_frame_texture.get_size()
		var available: Vector2 = Vector2(size.x,maxf(size.y-style.energy_font_size,1.0))
		var fit: float = minf(available.x/art_size.x,available.y/art_size.y)
		_frame_rect.size = art_size*fit
		_frame_rect.position = Vector2((size.x-_frame_rect.size.x)*0.5,0)
		_surface.position = _frame_rect.position+vessel_uv.position*_frame_rect.size
		_surface.size = vessel_uv.size*_frame_rect.size
	_material.set_shader_parameter(&"ink",style.empty_ink)
	_material.set_shader_parameter(&"hot",style.ivory)
	_material.set_shader_parameter(&"wave_height",clampf(style.energy_wave_height,0.0,0.12))
	_material.set_shader_parameter(&"wave_speed",style.energy_wave_speed)
	_material.set_shader_parameter(&"wave_frequency",style.energy_wave_frequency)
	_material.set_shader_parameter(&"idle_wave",clampf(style.energy_idle_wave,0,1))
	_material.set_shader_parameter(&"facet_strength",clampf(style.energy_facet_strength,0.0,0.3))
	_shell = style.glyphs.get(&"energy_shell")
	_fox_head = style.glyphs.get(&"energy_fox_head")
	_fox_cream = style.glyphs.get(&"energy_fox_cream")
	_fox_ink = style.glyphs.get(&"energy_fox_ink")
	_material.set_shader_parameter(&"masked",style.energy_mask_texture != null)
	if style.energy_mask_texture != null: _material.set_shader_parameter(&"mask_texture",style.energy_mask_texture)
	_write_fill()
	queue_redraw()
## Bộ ghép HUD quyết định nguyên tố; bình vẫn dùng lại được cho chủ sở hữu khác.
func set_element_color(value: Color) -> void:
	_tint = value
	if _material != null: _material.set_shader_parameter(&"tint",value)
	queue_redraw()
## Giá trị hiển thị phục vụ test mà không mở biến riêng.
func get_displayed_units() -> float:
	return _fill_ratio*float(_maximum)
## Tỷ lệ mặt chất lỏng đã hiển thị, độc lập số đơn vị năng lượng tối đa.
func get_fill_ratio() -> float:
	return _fill_ratio
## Sức chứa logic không dùng giá trị preview trong bản chạy thật.
func get_displayed_max() -> int:
	return _maximum
## Màu đã áp lên bình, không suy ra từ resource của lớp ghép.
func get_element_color() -> Color:
	return _tint
## Nội suy tỷ lệ để tăng sức chứa giữa lượt không làm mặt chất lỏng nhảy đột ngột.
func _refresh(current: int, max_value: int) -> void:
	_maximum = maxi(max_value,0)
	_from = _fill_ratio
	_target = float(clampi(current,0,_maximum))/float(_maximum) if _maximum>0 else 0.0
	if not _initialized or _maximum<=0:
		_fill_ratio = _target
		_from = _target
		_age = INF
		_ready_age = INF
		_initialized = true
		_write_fill()
		return
	_age = 0.0
	_duration = style.energy_drop_time if _target<_from else style.energy_fill_time
	if _target>=1.0 and _from<_target: _ready_age = 0.0
	elif _target<1.0: _ready_age = INF
	set_process(true)
	_write_fill()
## Rung lấy lại vị trí gốc mỗi lượt, không tích lũy sai lệch sau nhiều lần thiếu.
func _on_insufficient(_cost: int) -> void:
	if not _warn_active: _rest = position
	_warn_active = true
	_warn_age = 0.0
	set_process(true)
## CPU chỉ chạy lúc hạ/dâng/flash/cảnh báo; gợn nền rất nhẹ do shader xử lý.
func _process(delta: float) -> void:
	_clock += delta
	_age += delta
	_warn_age += delta
	_ready_age += delta
	var fill_t: float = clampf(_age/maxf(_duration,0.001),0.0,1.0)
	_fill_ratio = lerpf(_from,_target,fill_t*fill_t*(3.0-2.0*fill_t))
	_pulse = pow(1.0-clampf(_ready_age/maxf(style.energy_full_time,style.minimum_duration),0.0,1.0),2.0)
	_warning = 1.0-clampf(_warn_age/maxf(style.energy_warn_time,style.minimum_duration),0.0,1.0)
	if _warn_active:
		position = _rest+Vector2(sin(_warn_age*style.energy_shake_speed)*style.energy_shake*_warning,0)
		if _warning <= 0.0:
			position = _rest
			_warn_active = false
	_material.set_shader_parameter(&"clock",_clock)
	_material.set_shader_parameter(&"activity",maxf(1.0-fill_t,_pulse))
	_material.set_shader_parameter(&"flash",_pulse)
	_write_fill()
	queue_redraw()
	if fill_t >= 1.0 and _pulse <= 0.0 and not _warn_active: set_process(false)
## Uniform thay đổi là scalar; không viết lại mesh hoặc tạo texture trong animation.
func _write_fill() -> void:
	if _material == null: return
	_material.set_shader_parameter(&"fill_ratio",_fill_ratio)
	_material.set_shader_parameter(&"tint",_tint)
## Khung đuôi cáo dùng dữ liệu nét có sẵn, không tạo mesh/hạt khi mức Linh lực thay đổi.
func _draw() -> void:
	if style == null: return
	var diameter: float = clampf(style.energy_diameter,1.0,minf(size.x,size.y))
	var center: Vector2 = Vector2(size.x*0.5,diameter*0.5)
	var radius: float = maxf(diameter*0.5-style.stroke_width()*2.0,1.0)
	var rim: Color = style.gold.lerp(style.damage_color,_warning)
	if style.energy_frame_texture != null:
		draw_texture_rect(style.energy_frame_texture,_frame_rect,false)
		if _warning > 0.0 or _pulse > 0.0:
			var vessel: Rect2 = Rect2(_surface.position,_surface.size)
			var feedback: Color = style.damage_color if _warning > 0.0 else style.ivory
			draw_arc(vessel.get_center(),vessel.size.y*0.5,0,TAU,style.energy_curve_steps,
				Color(feedback,maxf(_warning,_pulse)),style.stroke_width(),true)
	else:
		draw_arc(center,radius,0,TAU,style.energy_curve_steps,style.ink,style.stroke_width()*4.0,true)
		draw_arc(center,radius,PI,TAU,style.energy_curve_steps,Color(rim,clampf(style.energy_inner_rim_opacity+_pulse,0,1)),style.stroke_width(),true)
		if _shell != null:
			var extent: float = maxf(diameter*clampf(style.energy_shell_extent,0,0.5),0.001)
			draw_set_transform(center,0,Vector2.ONE*extent)
			for index: int in range(_shell.fills.size()):
				var polygon: PackedVector2Array = _shell.fills[index]
				var fill: Color = style.energy_shell_color if index<style.energy_shell_tip_start else style.energy_shell_tip_color
				if polygon.size()>=3: draw_colored_polygon(polygon,fill)
			for index: int in range(_shell.strokes.size()):
				var stroke: PackedVector2Array = _shell.strokes[index]
				var tint: Color = rim if index<style.energy_shell_tip_start else style.energy_shell_accent.lerp(style.ivory,_pulse)
				if stroke.size()>=2: draw_polyline(stroke,tint,style.stroke_width()/extent,true)
			draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
		var crest: Vector2 = Vector2(center.x, diameter * clampf(style.energy_fox_height, 0, 0.35))
		var crest_size: float = diameter * clampf(style.energy_fox_scale, 0, 0.35)
		if _fox_head != null: _fox_head.draw_on(self, crest, crest_size, style.energy_fox_color, style.stroke_width())
		if _fox_cream != null: _fox_cream.draw_on(self, crest, crest_size, style.ivory, style.stroke_width())
		if _fox_ink != null: _fox_ink.draw_on(self, crest, crest_size, style.ink, style.stroke_width())
	if _font != null:
		draw_string(_font,Vector2(0,size.y-1),style.energy_label,HORIZONTAL_ALIGNMENT_CENTER,size.x,maxi(style.energy_font_size,1),style.ink)
		draw_string(_font,Vector2(0,size.y-2),style.energy_label,HORIZONTAL_ALIGNMENT_CENTER,size.x,maxi(style.energy_font_size,1),Color(style.ivory,0.85))
