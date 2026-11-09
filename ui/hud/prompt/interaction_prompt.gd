class_name InteractionPrompt
extends PanelContainer
## Serif và nét trang trí bám điểm 3D; chỉ process khi có focus hoặc đang fade-out.
const Style = preload("res://resources/ui/hud_style.gd")
@export_group("Binding")
@export var interactor: InteractorComponent
@export var action: StringName = &"interact"
@export var style: Style = preload("res://resources/ui/hud_style.tres")
var _target: InteractableComponent
var _camera: Camera3D
var _alpha: float = 0.0
var _anchor: Vector2 = Vector2.ZERO
var _key_style: StyleBoxFlat = StyleBoxFlat.new()
var _empty: StyleBoxEmpty = StyleBoxEmpty.new()
@onready var _key_label: Label = %KeyLabel
@onready var _action_label: Label = %ActionLabel
@onready var _key_box: PanelContainer = $HBox/KeyBox
@onready var _row: HBoxContainer = $HBox
## Không gọi process mãi khi HUD vừa nạp mà chưa có vật tương tác.
func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	apply_style()
	hide()
	set_process(false)
	if interactor != null: interactor.focus_changed.connect(_on_focus_changed)
## Dùng cùng Resource, không dùng font/menu state hoặc sửa widget menu.
func apply_style() -> void:
	theme = style.theme
	add_theme_stylebox_override(&"panel",_empty)
	_key_style.bg_color = style.ink
	_key_style.border_color = style.gold
	_key_style.set_border_width_all(maxi(roundi(style.stroke_width()),1))
	_key_style.set_corner_radius_all(2)
	_key_box.add_theme_stylebox_override(&"panel",_key_style)
	_key_box.custom_minimum_size = Vector2(maxf(style.prompt_key_size.x,1),maxf(style.prompt_key_size.y,1))
	_row.add_theme_constant_override(&"separation",maxi(style.prompt_gap,0))
	_key_label.add_theme_font_size_override(&"font_size",clampi(style.prompt_key_font,1,64))
	_action_label.add_theme_font_size_override(&"font_size",clampi(style.prompt_font,1,64))
	_action_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_action_label.custom_minimum_size.x = clampf(style.prompt_text_width,20,get_viewport_rect().size.x*0.5)
	_key_label.add_theme_color_override(&"font_color",style.gold)
	_action_label.add_theme_color_override(&"font_color",style.ivory)
	for label: Label in [_key_label,_action_label]:
		label.add_theme_color_override(&"font_outline_color",style.text_outline_color)
		label.add_theme_constant_override(&"outline_size",clampi(style.text_outline_size,0,8))
	_key_label.text = _get_key_text()
	queue_redraw()
## Vị trí cần cập nhật theo camera; không tìm group/overlap hoặc dựng lại UI trong vòng này.
func _process(delta: float) -> void:
	if not is_instance_valid(_target) or not _target.enabled: _target = null
	var has_target: bool = _target != null
	if has_target:
		if not is_instance_valid(_camera): _camera = get_viewport().get_camera_3d()
		if _camera == null: return
		var world: Vector3 = _target.get_prompt_position()
		if _camera.is_position_behind(world):
			hide()
			return
		_anchor = _camera.unproject_position(world)+style.prompt_offset-Vector2(size.x*0.5,0)
		_anchor = _anchor.clamp(Vector2.ZERO,(get_viewport_rect().size-size).max(Vector2.ZERO))
		_alpha = minf(_alpha+delta/maxf(style.prompt_appear_time,0.001),1.0)
	else:
		_alpha = maxf(_alpha-delta/maxf(style.prompt_fade_time,0.001),0.0)
	position = _anchor+Vector2(0,clampf(style.prompt_slide,-64,64)*(1.0-_alpha))
	modulate.a = _alpha
	visible = _alpha>0.0
	if not has_target and _alpha<=0.0: set_process(false)
## Đổi mục tiêu không nhấp nháy từ zero; binding được đọc lại khi focus mới.
func _on_focus_changed(target: InteractableComponent) -> void:
	_target = target
	if is_instance_valid(target):
		_camera = get_viewport().get_camera_3d()
		_action_label.text = target.prompt_text.to_upper()
		_key_label.text = _get_key_text()
		reset_size()
	elif get_tree().paused:
		# Game đang dừng (trình diễn nhận kỹ năng...) thì _process không chạy để mờ dần: ẩn ngay
		_alpha = 0.0
		hide()
	set_process(is_instance_valid(target) or _alpha>0.0)
## Không gán cứng phím để người chơi đổi binding vẫn có prompt đúng.
func _get_key_text() -> String:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key: InputEventKey = event as InputEventKey
			return OS.get_keycode_string(key.physical_keycode if key.physical_keycode!=KEY_NONE else key.keycode)
		return event.as_text()
	return "?"
## Nét mờ về hai đầu và hạt thoi nhỏ, không đặt nền hộp lớn lên vật thể.
func _draw() -> void:
	var middle: Vector2 = Vector2(size.x*0.5,-style.prompt_rule_gap)
	var half: float = clampf(style.prompt_rule_width*0.5,0,512)
	var gap: float = maxf(style.prompt_diamond_size*2,0)
	for index: int in range(8):
		var a: float = float(index)/8.0
		var b: float = float(index+1)/8.0
		var tint: Color = Color(style.gold,(1.0-a)*0.8)
		for side_index: int in range(2):
			var side: float = float(side_index)*2.0-1.0
			draw_line(middle+Vector2(side*lerpf(gap,half,a),0),middle+Vector2(side*lerpf(gap,half,b),0),tint,style.stroke_width(),true)
	var d: float = maxf(style.prompt_diamond_size,0)
	draw_line(middle+Vector2(0,-d),middle+Vector2(d,0),style.gold,style.stroke_width(),true)
	draw_line(middle+Vector2(d,0),middle+Vector2(0,d),style.gold,style.stroke_width(),true)
	draw_line(middle+Vector2(0,d),middle+Vector2(-d,0),style.gold,style.stroke_width(),true)
	draw_line(middle+Vector2(-d,0),middle+Vector2(0,-d),style.gold,style.stroke_width(),true)
