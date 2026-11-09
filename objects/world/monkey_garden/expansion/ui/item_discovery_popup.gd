class_name ItemDiscoveryPopup
extends CanvasLayer
## Dùng cùng theme, màu và hoa văn màn Tab; hướng dẫn vẫn dừng thế giới.
signal dismissed
@export var allow_cancel: bool = false
const BLUR: Shader = preload("res://assets/shaders/screen/item_discovery/discovery_blur.gdshader")
const MENU_THEME: Theme = preload("res://ui/theme/menu_theme.tres")
const STYLE: InventoryStyle = preload("res://resources/ui/inventory_style.tres")
const BOOTS_ICON: Texture2D = preload("res://ui/hud/icons/banana_items/banana_boots.svg")
var _panel: PanelContainer
var _title: Label
var _illustration: TextureRect
var _body: Label
var _player: Player
var _opened_at: int
var _was_paused: bool
var _was_enabled: bool

func _ready() -> void:
	layer = 60; process_mode = Node.PROCESS_MODE_ALWAYS
	var root: Control = Control.new(); root.theme = MENU_THEME; add_child(root); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop: ColorRect = ColorRect.new(); root.add_child(backdrop); backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var blur: ShaderMaterial = ShaderMaterial.new(); blur.shader = BLUR; backdrop.material = blur
	var frame: CornerFrame = CornerFrame.new(); root.add_child(frame); frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.color = STYLE.ornament; frame.margin = STYLE.frame_margin; frame.corner_size = STYLE.corner_size
	_panel = PanelContainer.new(); root.add_child(_panel)
	var style: StyleBoxFlat = StyleBoxFlat.new(); style.bg_color = STYLE.tile_fill
	style.content_margin_left = 36; style.content_margin_right = 36; style.content_margin_top = 28; style.content_margin_bottom = 30
	_panel.add_theme_stylebox_override("panel",style)
	var border: CornerFrame = CornerFrame.new(); _panel.add_child(border); border.margin = 8; border.corner_size = 22; border.color = STYLE.ornament
	var column: VBoxContainer = VBoxContainer.new(); _panel.add_child(column); column.add_theme_constant_override("separation",18)
	_title = Label.new(); _title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; _title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.add_theme_font_size_override("font_size",STYLE.detail_title_font); column.add_child(_title)
	var divider: OrnamentDivider = OrnamentDivider.new(); divider.custom_minimum_size.y = 24; divider.flourish = true; divider.color = STYLE.ornament; column.add_child(divider)
	_illustration = TextureRect.new(); _illustration.custom_minimum_size = Vector2(0,64); _illustration.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_illustration.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; column.add_child(_illustration)
	_body = Label.new(); _body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; _body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_theme_font_size_override("font_size",STYLE.body_font+2); _body.add_theme_constant_override("line_spacing",6); column.add_child(_body)
	var hint: Label = Label.new(); hint.text = "F  ·  Tiếp tục"; hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size",STYLE.key_font); hint.add_theme_color_override("font_color",STYLE.dim); column.add_child(hint)
	_panel.resized.connect(_center_panel); get_viewport().size_changed.connect(_layout)
	hide(); set_process_input(false)

func present(player: Player, kind: StringName) -> void:
	if kind == &"boots": present_text(player,"GIÀY CHUỐI","Không bị trượt khi giẫm vỏ chuối. Giẫm vỏ chuối còn giúp tăng tốc chạy trong 3 giây!",BOOTS_ICON)

func present_text(player: Player, heading: String, message: String, illustration: Texture2D = null) -> void:
	if visible: return
	_player = player; _was_paused = get_tree().paused; _was_enabled = player.controls_enabled
	_title.text = heading; _body.text = message; _illustration.texture = illustration; _illustration.visible = illustration != null
	_opened_at = Time.get_ticks_msec(); player.set_controls_enabled(false); show(); get_tree().paused = true; set_process_input(true)
	_layout(); _layout.call_deferred()
	_panel.modulate.a = 0; create_tween().tween_property(_panel,"modulate:a",1.0,STYLE.open_time)

func _layout() -> void:
	if not is_instance_valid(_panel): return
	var width: float = minf(660,get_viewport().get_visible_rect().size.x-64)
	_body.custom_minimum_size.x = maxf(width-72,160); _title.custom_minimum_size.x = maxf(width-72,160)
	_panel.size = Vector2(width,0); _panel.reset_size(); _center_panel()

func _center_panel() -> void:
	_panel.position = (get_viewport().get_visible_rect().size-_panel.size)*0.5

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
