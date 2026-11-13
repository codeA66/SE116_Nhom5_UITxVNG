class_name TutorialPopup
extends CanvasLayer
## Cửa sổ popup hướng dẫn 1 lần: giao diện phong cách bảng nhận kỹ năng (ảnh minh họa, chữ in hoa,
## hoa văn uốn lượn, phím bấm bo góc đọc tự động từ InputMap).
## Nền trong suốt làm mờ giống màn Tab (menu_vignette shader).
## Nếu không có hình ở trên thì tự động ẩn và dồn các phần chữ ở dưới lên giữa màn hình.
## Hỗ trợ nhiều phím trong prompt_template qua token {key}, {key1}, {key2}... hoặc {action:name}.

signal popup_opened(tutorial: TutorialData)
signal popup_closed(tutorial: TutorialData)

const ACQUIRE_DATA: Resource = preload("res://resources/feedback/ability_acquire/ability_acquire_default.tres")
const KEY_GLYPH_SCRIPT := preload("res://components/feedback/loot_beam/ability_acquire/ui/panel/key_glyph.gd")

static var _TOKEN_REGEX: RegEx

var _queue: Array[TutorialData] = []
var _current: TutorialData
var _is_open: bool = false
var _intro_done: bool = false
var _tween: Tween
var _marker_tween: Tween

@onready var _root: Control = $Root
@onready var _backdrop: ColorRect = $Root/Backdrop
@onready var _content: VBoxContainer = $Root/Content
@onready var _art_box: Control = %ArtBox
@onready var _illustration: AbilityIllustration = %Illustration
@onready var _icon: TextureRect = %Icon
@onready var _verb: Label = %Verb
@onready var _title: Label = %Title
@onready var _rule: OrnamentDivider = %Rule
@onready var _prompt: HBoxContainer = %Prompt
@onready var _description: Label = %Description
@onready var _continue_box: VBoxContainer = %ContinueBox


static func _get_regex() -> RegEx:
	if _TOKEN_REGEX == null:
		_TOKEN_REGEX = RegEx.new()
		_TOKEN_REGEX.compile(r"\{key(?<num>\d+)?\}|\{action:(?<act>[a-zA-Z0-9_]+)\}")
	return _TOKEN_REGEX


func _ready() -> void:
	visible = false
	_root.modulate.a = 0.0
	_backdrop.gui_input.connect(_on_backdrop_input)
	
	if ACQUIRE_DATA:
		var ill_data := ACQUIRE_DATA.duplicate()
		ill_data.set(&"illustration_size", 200.0)
		_illustration.configure(ill_data)
	
	GameState.tutorial_unlocked.connect(_on_tutorial_unlocked)


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"jump"):
		get_viewport().set_input_as_handled()
		dismiss()
	elif event.is_action_pressed(&"help"):
		dismiss()


func _on_backdrop_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		dismiss()


func _on_tutorial_unlocked(tutorial: TutorialData) -> void:
	if tutorial == null:
		return
	_queue.append(tutorial)
	if not _is_open:
		_show_next()


func _show_next() -> void:
	if _queue.is_empty():
		_is_open = false
		visible = false
		return
	
	_current = _queue.pop_front()
	_is_open = true
	_intro_done = false
	visible = true
	
	# 1. Cấu hình hình ảnh phía trên (linh hoạt hoặc ẩn đi để dồn các phần dưới lên)
	_setup_art(_current)
	
	# 2. Tiêu đề và phân loại
	_refresh_localized_text()
	_run_intro()
	popup_opened.emit(_current)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and _current != null:
		_refresh_localized_text()


func _refresh_localized_text() -> void:
	_verb.text = tr(_current.category).to_upper() if not _current.category.is_empty() else "HƯỚNG DẪN"
	_title.text = _current.title
	
	# 3. Phím bấm và câu nhắc (dựng động theo template và InputMap)
	_setup_prompt(_current)
	
	# 4. Mô tả chi tiết
	var desc_text := _current.summary
	if desc_text.is_empty() and not _current.sections.is_empty():
		desc_text = _current.sections[0].get("text", "")
	_description.text = desc_text
	_description.visible = not desc_text.is_empty()
	


func _setup_art(data: TutorialData) -> void:
	if data.art_ability != null:
		_illustration.setup(data.art_ability)
		_illustration.show()
		_icon.hide()
		_art_box.show()
	elif data.art_texture != null or data.icon != null:
		_illustration.hide()
		_icon.texture = data.art_texture if data.art_texture else data.icon
		_icon.show()
		_art_box.show()
	else:
		# Không có ảnh: ẩn toàn bộ ArtBox để VBoxContainer tự dồn các chữ lên giữa
		_illustration.hide()
		_icon.hide()
		_art_box.hide()


func _setup_prompt(data: TutorialData) -> void:
	for child in _prompt.get_children():
		_prompt.remove_child(child)
		child.queue_free()
	
	var template := data.prompt_template
	if template.is_empty():
		var all_actions := data.get_all_actions()
		if all_actions.size() == 1:
			template = "Nhấn {key1} để thực hiện."
		elif all_actions.size() > 1:
			var parts := PackedStringArray()
			for i in all_actions.size():
				parts.append("{key%d}" % (i + 1))
			template = tr("Nhấn %s để thực hiện.") % " ".join(parts)
		elif data.art_ability is SkillData:
			template = "Nhấn {key1} để thực hiện."
		else:
			_prompt.hide()
			return
	
	var regex := _get_regex()
	template = tr(template)
	var matches := regex.search_all(template)
	if matches.is_empty():
		var lbl := _create_prompt_label(template)
		_prompt.add_child(lbl)
		_prompt.show()
		return
	
	var last_pos := 0
	var first_glyph := true
	for m: RegExMatch in matches:
		var start := m.get_start()
		if start > last_pos:
			var chunk := template.substr(last_pos, start - last_pos)
			_prompt.add_child(_create_prompt_label(chunk))
		
		var key_str := ""
		var act := m.get_string("act")
		if not act.is_empty():
			key_str = TutorialData.get_action_key_name(StringName(act))
		else:
			var num_str := m.get_string("num")
			var index := (int(num_str) - 1) if not num_str.is_empty() else 0
			key_str = data.get_key_at(index)
			if key_str.is_empty() and index == 0 and data.art_ability is SkillData:
				var skill := data.art_ability as SkillData
				key_str = TutorialData.get_action_key_name(skill.input_action)
		
		var glyph := _create_prompt_glyph(key_str)
		_prompt.add_child(glyph)
		if first_glyph:
			glyph.name = "Key"
			glyph.owner = self
			glyph.unique_name_in_owner = true
			first_glyph = false
		last_pos = m.get_end()
	
	if last_pos < template.length():
		var chunk := template.substr(last_pos)
		_prompt.add_child(_create_prompt_label(chunk))
	
	_prompt.show()


## Lấy ô phím đầu tiên trong câu prompt (tiện ích cho test hoặc truy vấn)
func get_first_key_glyph() -> Control:
	for child in _prompt.get_children():
		if child.get_script() == KEY_GLYPH_SCRIPT:
			return child
	return null


func _create_prompt_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.add_theme_font_size_override(&"font_size", 18)
	label.add_theme_color_override(&"font_color", Color(0.95, 0.93, 0.88, 1.0))
	return label


func _create_prompt_glyph(key_text: String) -> Control:
	var glyph: Control = KEY_GLYPH_SCRIPT.new()
	glyph.set(&"font_size", 18)
	glyph.set(&"text", key_text if not key_text.is_empty() else "—")
	glyph.set(&"text_color", Color(0.95, 0.95, 0.92, 1.0))
	glyph.set(&"fill_color", Color(0.06, 0.06, 0.08, 0.85))
	glyph.set(&"border_color", Color(0.92, 0.88, 0.82, 0.9))
	glyph.set(&"corner_radius", 4.0)
	glyph.set(&"border_width", 1.5)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return glyph


func _run_intro() -> void:
	_stop_tweens()
	_root.modulate.a = 0.0
	_content.modulate.a = 0.0
	_continue_box.modulate.a = 0.0
	_rule.reveal = 0.0
	
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_root, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(_content, "modulate:a", 1.0, 0.35).set_delay(0.05).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(_rule, "reveal", 1.0, 0.45).set_delay(0.1).set_trans(Tween.TRANS_SINE)
	_tween.chain().tween_callback(_start_marker)


func _start_marker() -> void:
	_intro_done = true
	if _marker_tween and _marker_tween.is_valid():
		_marker_tween.kill()
	_marker_tween = create_tween().set_loops()
	_marker_tween.tween_property(_continue_box, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	_marker_tween.tween_property(_continue_box, "modulate:a", 0.3, 0.6).set_trans(Tween.TRANS_SINE)


func dismiss() -> void:
	if not _is_open:
		return
	_stop_tweens()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_root, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_SINE)
	_tween.chain().tween_callback(func():
		var finished := _current
		_current = null
		_is_open = false
		popup_closed.emit(finished)
		_show_next()
	)


func _stop_tweens() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null
	if _marker_tween and _marker_tween.is_valid():
		_marker_tween.kill()
	_marker_tween = null
