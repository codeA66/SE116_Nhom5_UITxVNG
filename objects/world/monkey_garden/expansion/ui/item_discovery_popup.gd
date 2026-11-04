class_name ItemDiscoveryPopup
extends CanvasLayer
signal dismissed
@export var allow_cancel: bool = false
const BLUR: Shader = preload("res://assets/shaders/screen/item_discovery/discovery_blur.gdshader")
const MESSAGES: Dictionary[StringName,String] = {
	&"gun":"Khẩu súng chuối huyền thoại bắn ra đạn nổ một phạm vi nhỏ xung quanh, hữu ích cho việc tiêu diệt đám khỉ. Hãy cẩn thận khi sử dụng!!!\n\nĐạn nổ có thể được rớt ra từ những con khỉ cầm bom đặc biệt mà bạn sẽ gặp trên đường đi!",
	&"ammo":"Đạn cho súng bAKa-47, bọn khỉ cầm bom có vẻ mang theo rất nhiều!",
	&"boots":"Giày mang đặc tính đặc biệt giúp bạn không bị trượt khi dẫm lên vỏ chuối nữa!",
	&"healing":"Quả chuối thần kì mang đặc tính chữa trị cực cao, chỉ sử dụng được 3 lần, hãy suy nghĩ kĩ trước khi dùng!"
}
var _panel: PanelContainer
var _title: Label
var _body: Label
var _player: Player
var _opened_at: int
var _was_paused: bool
var _was_enabled: bool

func _ready() -> void:
	layer = 60; process_mode = Node.PROCESS_MODE_ALWAYS
	var backdrop: ColorRect = ColorRect.new(); add_child(backdrop); backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var material: ShaderMaterial = ShaderMaterial.new(); material.shader = BLUR; backdrop.material = material
	_panel = PanelContainer.new(); add_child(_panel)
	var style: StyleBoxFlat = StyleBoxFlat.new(); style.bg_color = Color("050b15f5"); style.border_color = Color("318fff")
	style.set_border_width_all(2); style.set_corner_radius_all(18)
	style.content_margin_left = 22; style.content_margin_right = 22; style.content_margin_top = 18; style.content_margin_bottom = 18
	_panel.add_theme_stylebox_override("panel",style)
	var column: VBoxContainer = VBoxContainer.new(); column.add_theme_constant_override("separation",12); _panel.add_child(column)
	_title = Label.new(); _title.modulate = Color("7fcaff"); _title.add_theme_font_size_override("font_size",18); column.add_child(_title)
	_body = Label.new(); _body.custom_minimum_size.x = 410; _body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_size_override("font_size",18); column.add_child(_body)
	var hint: Label = Label.new(); hint.text = "F  ·  Tiếp tục"; hint.modulate = Color("7fcaff"); hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; column.add_child(hint)
	hide(); set_process_input(false)

func present(player: Player, kind: StringName) -> void:
	present_text(player, {&"gun":"bAKa-47",&"ammo":"ĐẠN CHUỐI NỔ",&"boots":"GIÀY CHUỐI",&"healing":"CHUỐI DINH DƯỠNG"}.get(kind,""), MESSAGES[kind])

func present_text(player: Player, heading: String, message: String) -> void:
	_player = player; _was_paused = get_tree().paused; _was_enabled = player.controls_enabled
	_title.text = heading
	_body.text = message; _panel.size = Vector2(454,0); _panel.reset_size()
	var at: Vector2 = player.get_viewport().get_camera_3d().unproject_position(player.global_position+Vector3.UP)
	var viewport_size: Vector2 = player.get_viewport().get_visible_rect().size
	_panel.position = Vector2(clampf(at.x+55,20,viewport_size.x-_panel.size.x-20),clampf(at.y-_panel.size.y*0.6,20,viewport_size.y-_panel.size.y-20))
	_opened_at = Time.get_ticks_msec(); player.set_controls_enabled(false); show(); get_tree().paused = true; set_process_input(true)

func _input(event: InputEvent) -> void:
	if Time.get_ticks_msec()-_opened_at < 220 or event.is_echo(): return
	if event.is_action_pressed("interact") or (allow_cancel and event.is_action_pressed("ui_cancel")):
		close(); get_viewport().set_input_as_handled()

func close() -> void:
	if not visible: return
	hide(); set_process_input(false); get_tree().paused = _was_paused
	get_tree().create_timer(0.1).timeout.connect(func() -> void:
		if is_instance_valid(_player): _player.set_controls_enabled(_was_enabled))
	dismissed.emit()

func _exit_tree() -> void:
	if visible and is_instance_valid(get_tree()): get_tree().paused = _was_paused
