class_name AbilityAcquireUi
extends CanvasLayer
## UI nhận signal của chuỗi; icon bay vào target HUD công khai, không chạm _slots.
signal close_finished
signal icon_landed
signal transfer_started
const Tuning = preload("res://resources/feedback/ability_acquire/ability_acquire_data.gd")
const SlotFx = preload("res://components/feedback/loot_beam/ability_acquire/ui/ability_acquire_slot_fx.gd")
const SCREEN: Shader = preload("res://assets/shaders/screen/ability_acquire/canvas/acquire_screen.gdshader")
const REVEAL: Shader = preload("res://assets/shaders/screen/ability_acquire/canvas/acquire_reveal.gdshader")
const TARGET_GROUP: StringName = &"ability_acquire_target"
@export var data: Tuning = preload("res://resources/feedback/ability_acquire/ability_acquire_default.tres")
var _root: Control
var _shade: ColorRect
var _panel: Control
var _icon: TextureRect
var _fly: TextureRect
var _title: Label
var _description: Label
var _hint: Label
var _caption: Label
var _continue: Label
var _slot_fx: SlotFx
var _screen_mat: ShaderMaterial
var _icon_mat: ShaderMaterial
var _target: Control
var _ability: AbilityData
var _previous_pending: bool = false
var _clock: float = 0.0
var _mode: int = 0
var _fly_start: Vector2
var _landed: bool = false
## Tạo panel một lần, mọi lần nhận chỉ đổi texture và chuỗi hiển thị.
func _ready() -> void:
	layer = data.canvas_layer
	_build()
	stop_all()
## Cache target ở đầu lượt; tìm group chỉ khi bắt đầu, không tìm mỗi frame.
func begin(ability: AbilityData) -> void:
	stop_all()
	_ability = ability
	_root.show()
	set_process_input(true)
	for node: Node in get_tree().get_nodes_in_group(TARGET_GROUP):
		if node is Control and node.get("ability_id") == ability.id:
			_target = node as Control
			_previous_pending = bool(node.get("acquisition_pending"))
			node.call(&"set_acquisition_pending", true)
			node.connect(&"acquire_pulse_requested", _on_slot_pulse)
			break
	_icon.texture = ability.illustration if ability.illustration != null else ability.icon
	_fly.texture = ability.icon
	_icon_mat.set_shader_parameter(&"accent", ability.accent_color)
	_screen_mat.set_shader_parameter(&"accent", ability.accent_color)
	_title.text = ability.display_name
	_description.text = ability.description
	_caption.text = data.caption
	_continue.text = data.continue_caption
	_hint.text = _control_hint(ability)
## Lớp dim tồn tại ở pha thế giới; panel chỉ bật sau khi cáo đã hạ xuống.
func set_grade(dim: float, desaturation: float, pulse: float = 0.0, charge: float = 0.0, shock: float = -1.0) -> void:
	_root.show()
	_shade.show()
	_screen_mat.set_shader_parameter(&"dim", clampf(dim, 0.0, 1.0))
	_screen_mat.set_shader_parameter(&"desaturate", clampf(desaturation, 0.0, 1.0))
	_screen_mat.set_shader_parameter(&"pulse", clampf(pulse, 0.0, 1.0))
	_screen_mat.set_shader_parameter(&"charge",clampf(charge,0.0,data.maximum_intensity))
	_screen_mat.set_shader_parameter(&"shock",shock)
	_screen_mat.set_shader_parameter(&"local_focus", _mode == 0)
## Điểm tập trung theo camera game, không dựa vào kích thước ảnh chụp cố định.
func set_focus(world: Vector3) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera != null:
		_screen_mat.set_shader_parameter(&"focus", camera.unproject_position(world) / get_viewport().get_visible_rect().size)
## Reveal giữ nguyên tới khi người chơi xác nhận, không tự đóng khi đang đọc.
func show_panel() -> void:
	_clock = 0.0
	_mode = 1
	_panel.show()
	_panel.modulate.a = 0.0
	_title.visible_characters = 0
	set_process(true)
	_slot_fx.play_panel(_icon.get_global_rect().get_center(),_ability.accent_color)
## UI test và nút xác nhận cùng dùng một đường đóng.
func request_close() -> void:
	if _mode != 1 or _clock < maxf(data.panel_time, data.title_time): return
	_fly_start = _icon.get_global_rect().get_center()
	_fly.position = _fly_start - _fly.size * 0.5
	_fly.show()
	_panel.hide()
	_slot_fx.stop()
	_clock = 0.0
	_landed = false
	_mode = 2
	transfer_started.emit()
## Chỉ chặn input trong lượt modal, không thay InputMap.
func _input(event: InputEvent) -> void:
	if _mode == 1:
		var confirm: bool = event.is_action_pressed(data.confirm_action) and not event.is_echo()
		if event is InputEventMouseButton:
			var mouse: InputEventMouseButton = event as InputEventMouseButton
			confirm = confirm or (mouse.pressed and mouse.button_index == data.confirm_mouse_button)
		if confirm: request_close()
	if _root.visible: get_viewport().set_input_as_handled()
## Một icon được tái sử dụng cho đường bay và một glow cho ô đích.
func _process(delta: float) -> void:
	_clock += delta / maxf(Engine.time_scale, data.minimum_time)
	if _mode == 1:
		var t: float = clampf(_clock / maxf(data.panel_time, data.minimum_time), 0.0, 1.0)
		_panel.modulate.a = t
		_icon_mat.set_shader_parameter(&"progress", t)
		_title.visible_characters = floori(_title.text.length() * clampf(_clock / maxf(data.title_time, data.minimum_time), 0.0, 1.0))
		set_grade(lerpf(data.gather_dim, data.reveal_dim, t), data.gather_desaturation)
	elif _mode == 2:
		var t: float = clampf(_clock / maxf(data.fly_time, data.minimum_time), 0.0, 1.0)
		var end: Vector2 = _target_center() if is_instance_valid(_target) else get_viewport().get_visible_rect().size * 0.5
		var bend: Vector2 = (_fly_start + end) * 0.5 + Vector2.UP * data.illustration_size
		var eased: float = t * t * (3.0 - 2.0 * t)
		_fly.position = (1.0-eased)*(1.0-eased)*_fly_start + 2.0*(1.0-eased)*eased*bend + eased*eased*end - _fly.size*0.5
		_fly.scale = Vector2.ONE * lerpf(1.0, 0.7, t)
		set_grade(data.reveal_dim * (1.0-t), data.gather_desaturation*(1.0-t))
		if t >= 1.0 and not _landed:
			_landed = true
			_fly.hide()
			if is_instance_valid(_target):
				_target.call(&"set_acquisition_pending", false)
				_target.call(&"notify_acquired", _ability.accent_color)
			icon_landed.emit()
		if _clock >= data.fly_time + data.slot_time:
			_mode = 0
			set_process(false)
			close_finished.emit()
## Khôi phục ô kể cả khi bị hủy trong lúc icon đang bay.
func stop_all() -> void:
	set_process(false)
	set_process_input(false)
	_mode = 0
	if is_instance_valid(_target):
		_target.call(&"set_acquisition_pending", _previous_pending)
		if _target.is_connected(&"acquire_pulse_requested", _on_slot_pulse):
			_target.disconnect(&"acquire_pulse_requested", _on_slot_pulse)
	_target = null
	if is_instance_valid(_root): _root.hide()
	if is_instance_valid(_panel): _panel.hide()
	if is_instance_valid(_fly): _fly.hide()
	if is_instance_valid(_slot_fx): _slot_fx.stop()
## Trạng thái đọc công khai phục vụ fixture mà không truy cập biến UI riêng.
func is_waiting_for_confirm() -> bool:
	return _mode == 1 and _clock >= maxf(data.panel_time, data.title_time)
## Vị trí target dùng transform canvas để chịu được HUD scale/resize.
func _target_center() -> Vector2:
	return _target.get_global_transform_with_canvas() * (_target.size * 0.5)
## Glow được phát từ signal của chính ô HUD.
func _on_slot_pulse(accent: Color) -> void:
	if is_instance_valid(_target): _slot_fx.play_at(_target_center(), accent)
## Hint dùng binding thật, kỹ năng thụ động không tự bịa một nút bấm.
func _control_hint(ability: AbilityData) -> String:
	if not ability is SkillData: return ""
	var action: StringName = (ability as SkillData).input_action
	if not InputMap.has_action(action): return ""
	var events: Array[InputEvent] = InputMap.action_get_events(action)
	if events.is_empty(): return ""
	var label: String = events[0].as_text()
	if events[0] is InputEventKey:
		var key: InputEventKey = events[0] as InputEventKey
		label = OS.get_keycode_string(key.physical_keycode if key.physical_keycode != 0 else key.keycode)
	return data.control_caption % label
## Layout dùng tỷ lệ của khung cấu hình, không phụ thuộc độ phân giải cửa sổ.
func _build() -> void:
	_root = Control.new()
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_shade = ColorRect.new()
	_root.add_child(_shade)
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen_mat = ShaderMaterial.new()
	_screen_mat.shader = SCREEN
	_screen_mat.set_shader_parameter(&"focus_radius", data.focus_radius)
	_screen_mat.set_shader_parameter(&"exposure_gain", data.exposure_gain)
	_screen_mat.set_shader_parameter(&"local_radiance", data.local_radiance)
	_screen_mat.set_shader_parameter(&"shock_gain",data.shock_gain)
	_screen_mat.set_shader_parameter(&"shock_width",data.shock_width)
	_shade.material = _screen_mat
	_panel = Control.new()
	_root.add_child(_panel)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.size = data.panel_size
	_panel.position = -data.panel_size * 0.5
	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.size = Vector2.ONE * data.illustration_size
	_icon.position = Vector2((data.panel_size.x-data.illustration_size)*0.5,0)
	_panel.add_child(_icon)
	_icon_mat = ShaderMaterial.new()
	_icon_mat.shader = REVEAL
	_icon.material = _icon_mat
	_caption = _label(data.caption_font, data.caption_y, Color(0.65,0.72,0.76))
	_title = _label(data.title_font, data.title_y, Color(0.94,0.98,1.0))
	if data.title_typeface != null: _title.add_theme_font_override(&"font",data.title_typeface)
	var divider: ColorRect = ColorRect.new()
	divider.color = Color(0.45,0.65,0.7,0.7)
	divider.position = Vector2(data.panel_size.x*0.22,data.panel_size.y*data.divider_y)
	divider.size = Vector2(data.panel_size.x*0.56,1.0)
	_panel.add_child(divider)
	_hint = _label(data.hint_font, data.hint_y, Color(0.88,0.94,0.96))
	_description = _label(data.body_font, data.description_y, Color(0.55,0.64,0.68))
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_continue = _label(data.hint_font, data.continue_y, Color(0.45,0.55,0.60))
	_fly = TextureRect.new()
	_fly.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fly.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_fly.size = Vector2.ONE * data.fly_icon_size
	_fly.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_fly)
	_slot_fx = SlotFx.new()
	_slot_fx.data = data
	_root.add_child(_slot_fx)
	get_viewport().size_changed.connect(_layout)
	_layout()
## Position là tọa độ local thực, không phải offset của anchor center.
func _layout() -> void:
	_root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_shade.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_root.size = get_viewport().get_visible_rect().size
	_shade.size = _root.size
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_panel.position = (_root.size-data.panel_size)*0.5
## Label tạo một lần; pha reveal chỉ cập nhật visible_characters.
func _label(font_size: int, y: float, color: Color) -> Label:
	var label: Label = Label.new()
	label.position = Vector2(0,data.panel_size.y*y)
	label.size = Vector2(data.panel_size.x,data.panel_size.y*0.12)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override(&"font_size",font_size)
	label.add_theme_color_override(&"font_color",color)
	_panel.add_child(label)
	return label
