class_name AbilityAcquireUi
extends CanvasLayer
## UI nhận signal của chuỗi; icon bay vào target HUD công khai, không chạm _slots.
signal close_finished
signal icon_landed
signal transfer_started
const Tuning = preload("res://resources/feedback/ability_acquire/ability_acquire_data.gd")
const SlotFx = preload("res://components/feedback/loot_beam/ability_acquire/ui/ability_acquire_slot_fx.gd")
const SCREEN: Shader = preload("res://assets/shaders/screen/ability_acquire/canvas/acquire_screen.gdshader")
const PANEL_SCENE: PackedScene = preload("res://components/feedback/loot_beam/ability_acquire/ui/panel/ability_acquire_panel.tscn")
const TARGET_GROUP: StringName = &"ability_acquire_target"
@export var data: Tuning = preload("res://resources/feedback/ability_acquire/ability_acquire_default.tres")
var _root: Control
var _shade: ColorRect
## Màn đen trước bảng (pha Blackout); nằm trên lớp dim, dưới bảng
var _black: ColorRect
var _black_tween: Tween
var _panel: AbilityAcquirePanel
var _fly: TextureRect
var _slot_fx: SlotFx
var _screen_mat: ShaderMaterial
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
	_fly.texture = ability.icon
	_screen_mat.set_shader_parameter(&"accent", ability.accent_color)
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
## Phủ đen toàn màn (0..1) cho pha Blackout; bảng kỹ năng hiện đè lên
func set_black(amount: float) -> void:
	_root.show()
	_black.visible = amount > 0.0
	_black.color.a = clampf(amount, 0.0, 1.0)
## Điểm tập trung theo camera game, không dựa vào kích thước ảnh chụp cố định.
func set_focus(world: Vector3) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera != null:
		_screen_mat.set_shader_parameter(&"focus", camera.unproject_position(world) / get_viewport().get_visible_rect().size)
## Reveal giữ nguyên tới khi người chơi xác nhận, không tự đóng khi đang đọc.
func show_panel() -> void:
	_clock = 0.0
	_mode = 1
	_panel.play(_ability, _key_text(_ability))
	set_process(true)
	_play_panel_fx()
## UI test và nút xác nhận cùng dùng một đường đóng. Bấm khi bảng đang diễn = hiện hết ngay, bấm lần nữa mới đóng.
func request_close() -> void:
	if _mode != 1: return
	if not _panel.is_intro_done():
		_panel.skip_intro()
		return
	_fly_start = _panel.get_illustration_center()
	_fly.position = _fly_start - _fly.size * 0.5
	_fly.show()
	_panel.close()
	# Lớp đen tắt cùng nhịp với bảng để lộ lại cảnh game khi icon bay về HUD
	if _black.visible:
		_black_tween = create_tween()
		_black_tween.tween_method(set_black, _black.color.a, 0.0, data.close_time)
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
	if is_instance_valid(_panel): _panel.stop()
	if _black_tween and _black_tween.is_valid(): _black_tween.kill()
	if is_instance_valid(_black): _black.hide()
	if is_instance_valid(_fly): _fly.hide()
	if is_instance_valid(_slot_fx): _slot_fx.stop()
## Trạng thái đọc công khai phục vụ fixture mà không truy cập biến UI riêng.
func is_waiting_for_confirm() -> bool:
	return _mode == 1 and _panel.is_intro_done()
## Vị trí target dùng transform canvas để chịu được HUD scale/resize.
func _target_center() -> Vector2:
	return _target.get_global_transform_with_canvas() * (_target.size * 0.5)
## Glow được phát từ signal của chính ô HUD.
func _on_slot_pulse(accent: Color) -> void:
	if is_instance_valid(_target): _slot_fx.play_at(_target_center(), accent)
## Chờ bảng xếp bố cục xong mới lấy tâm hình minh họa cho vòng hạt quanh hình.
func _play_panel_fx() -> void:
	await get_tree().process_frame
	if _mode == 1 and is_instance_valid(_ability):
		_slot_fx.play_panel(_panel.get_illustration_center(), _ability.accent_color)
## Tên phím lấy từ binding thật; kỹ năng thụ động không tự bịa một nút bấm.
func _key_text(ability: AbilityData) -> String:
	if not ability is SkillData: return ""
	var action: StringName = (ability as SkillData).input_action
	if not InputMap.has_action(action): return ""
	var events: Array[InputEvent] = InputMap.action_get_events(action)
	if events.is_empty(): return ""
	var label: String = events[0].as_text()
	if events[0] is InputEventKey:
		var key: InputEventKey = events[0] as InputEventKey
		label = OS.get_keycode_string(key.physical_keycode if key.physical_keycode != 0 else key.keycode)
	return label
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
	_screen_mat.set_shader_parameter(&"focus_dim_keep",data.focus_dim_keep)
	_shade.material = _screen_mat
	_black = ColorRect.new()
	_black.color = Color(0.0, 0.0, 0.0, 0.0)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_black)
	# Anchor phủ kín: engine tự giãn theo cửa sổ, không cần nối size_changed (tránh gọi vào node đã rời cây)
	_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_black.hide()
	_panel = PANEL_SCENE.instantiate() as AbilityAcquirePanel
	_root.add_child(_panel)
	_panel.configure(data)
	_fly = TextureRect.new()
	_fly.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fly.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_fly.size = Vector2.ONE * data.fly_icon_size
	_fly.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_fly)
	_slot_fx = SlotFx.new()
	_slot_fx.data = data
	_root.add_child(_slot_fx)
