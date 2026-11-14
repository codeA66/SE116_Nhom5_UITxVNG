class_name TutorialPopup
extends CanvasLayer
## Gợi ý phím trong lúc chơi, dùng dữ liệu chung với Sổ Hướng Dẫn.

signal popup_opened(tutorial: TutorialData)
signal popup_closed(tutorial: TutorialData)

const INK: Color = Color("#262c31")
const IVORY: Color = Color("#f7e9cd")
const GOLD: Color = Color("#efba71")

class MouseGlyph extends Control:
	var right_button: bool

	func _draw() -> void:
		var body: StyleBoxFlat = StyleBoxFlat.new()
		body.bg_color = TutorialPopup.INK
		body.border_color = TutorialPopup.IVORY
		body.set_border_width_all(2)
		body.set_corner_radius_all(10)
		body.shadow_color = Color(0.06, 0.08, 0.09, 0.65)
		body.shadow_size = 3
		draw_style_box(body, Rect2(2, 2, 26, 36))
		var button: Rect2 = Rect2(16 if right_button else 5, 6, 9, 12)
		draw_rect(button, TutorialPopup.GOLD)
		draw_line(Vector2(5, 20), Vector2(25, 20), TutorialPopup.IVORY, 1.0, true)

static var _token_regex: RegEx

@export_group("Hiển thị")
@export var fade_duration: float = 0.2
@export var display_duration: float = 6.0
@export var entrance_offset: float = 6.0

var _queue: Array[TutorialData] = []
var _current: TutorialData
var _closing: bool = false
var _tween: Tween
var _first_key_glyph: Control

@onready var _root: Control = $Root
@onready var _prompt: HBoxContainer = %Prompt
@onready var _timeout: Timer = $Timeout


func _ready() -> void:
	hide()
	_timeout.timeout.connect(dismiss)
	GameState.tutorial_unlocked.connect(show_tutorial)
	_bind_player.call_deferred()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and _current != null:
		_setup_prompt(_current)


func show_tutorial(tutorial: TutorialData) -> void:
	if tutorial == null or tutorial == _current or _queue.has(tutorial):
		return
	_queue.append(tutorial)
	if _current == null:
		_show_next()


func dismiss() -> void:
	if _current == null or _closing:
		return
	_closing = true
	_timeout.stop()
	_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_root, "modulate:a", 0.0, fade_duration)
	_tween.tween_callback(_finish_current)


func _bind_player() -> void:
	var ancestor: Node = get_parent()
	while ancestor != null and not ancestor is Player:
		ancestor = ancestor.get_parent()
	var player: Player = ancestor as Player
	if player == null:
		return
	player.state_machine.state_changed.connect(_on_state_changed)
	player.bow_cooldown_started.connect(_on_bow_shot)
	player.skill_cooldown_started.connect(_on_skill_used)


func _on_state_changed(_previous: StringName, current: StringName) -> void:
	if _current != null and _current.completion_state == current:
		dismiss()


func _on_bow_shot(_duration: float) -> void:
	if _current != null and _current.complete_on_bow_shot:
		dismiss()


func _on_skill_used(skill_id: StringName, _duration: float) -> void:
	if _current != null and _current.completion_skill == skill_id:
		dismiss()


func _show_next() -> void:
	if _queue.is_empty():
		hide()
		return
	_current = _queue.pop_front()
	_setup_prompt(_current)
	_root.modulate.a = 0.0
	offset = Vector2(0.0, entrance_offset)
	show()
	_tween = create_tween()
	_tween.tween_property(_root, "modulate:a", 1.0, fade_duration)
	_tween.parallel().tween_property(self, "offset", Vector2.ZERO, fade_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if not _current.wait_for_action:
		_timeout.start(display_duration)
	popup_opened.emit(_current)


func _finish_current() -> void:
	var finished: TutorialData = _current
	_current = null
	_closing = false
	popup_closed.emit(finished)
	if _current == null:
		_show_next()


static func _get_regex() -> RegEx:
	if _token_regex == null:
		_token_regex = RegEx.new()
		_token_regex.compile(r"\{key(?<num>\d+)?\}|\{action:(?<act>[a-zA-Z0-9_]+)\}")
	return _token_regex


func _setup_prompt(data: TutorialData) -> void:
	_first_key_glyph = null
	for child in _prompt.get_children():
		_prompt.remove_child(child)
		child.queue_free()

	var template: String = data.prompt_template if not data.prompt_template.is_empty() else data.title
	var regex: RegEx = _get_regex()
	template = tr(template)
	var matches: Array[RegExMatch] = regex.search_all(template)
	if matches.is_empty():
		var lbl: Label = _create_prompt_label(template)
		_prompt.add_child(lbl)
		_prompt.show()
		return

	var last_pos: int = 0
	# Giữ hướng của từng phím theo bố cục bàn phím, kể cả khi đổi phím.
	if data.completion_state == PlayerState.RUN and matches.size() == 4:
		_prompt.add_child(_create_direction_keys(data))
		last_pos = matches[3].get_end()
		matches.clear()

	for m: RegExMatch in matches:
		var start: int = m.get_start()
		if start > last_pos:
			var chunk: String = template.substr(last_pos, start - last_pos)
			if not chunk.strip_edges().is_empty():
				_prompt.add_child(_create_prompt_label(chunk.strip_edges()))

		var key_str: String = ""
		var act: String = m.get_string("act")
		if not act.is_empty():
			key_str = TutorialData.get_action_key_name(StringName(act))
		else:
			var num_str: String = m.get_string("num")
			var index: int = (int(num_str) - 1) if not num_str.is_empty() else 0
			key_str = data.get_key_at(index)
			if key_str.is_empty() and index == 0 and data.art_ability is SkillData:
				var skill: SkillData = data.art_ability as SkillData
				key_str = TutorialData.get_action_key_name(skill.input_action)

		var glyph: Control = _create_prompt_glyph(key_str)
		_prompt.add_child(glyph)
		if _first_key_glyph == null:
			_first_key_glyph = glyph
		last_pos = m.get_end()

	if last_pos < template.length():
		var chunk: String = template.substr(last_pos).strip_edges()
		if not chunk.is_empty():
			_prompt.add_child(_create_prompt_label(chunk))

	_prompt.show()


## Dùng chung cho kiểm thử phím hiển thị lấy từ Input Map.
func get_first_key_glyph() -> Control:
	return _first_key_glyph


func _create_direction_keys(data: TutorialData) -> Control:
	var keys: VBoxContainer = VBoxContainer.new()
	keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	keys.add_theme_constant_override(&"separation", 3)
	for row_index: int in range(2):
		var row: HBoxContainer = HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override(&"separation", 3)
		keys.add_child(row)
		for key_index: int in range(0, 1) if row_index == 0 else range(1, 4):
			var glyph: Control = _create_prompt_glyph(data.get_key_at(key_index))
			row.add_child(glyph)
			if key_index == 0:
				_first_key_glyph = glyph
	return keys


func _create_prompt_label(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.add_theme_font_size_override(&"font_size", 24)
	label.add_theme_color_override(&"font_color", IVORY)
	label.add_theme_color_override(&"font_outline_color", INK)
	label.add_theme_constant_override(&"outline_size", 6)
	return label


func _create_prompt_glyph(key_text: String) -> Control:
	if key_text == "LMB" or key_text == "RMB":
		var mouse: MouseGlyph = MouseGlyph.new()
		mouse.right_button = key_text == "RMB"
		mouse.custom_minimum_size = Vector2(30.0, 42.0)
		mouse.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mouse.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		return mouse

	var glyph: Label = Label.new()
	glyph.text = key_text
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph.custom_minimum_size = Vector2(34.0, 32.0)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	glyph.add_theme_font_size_override(&"font_size", 18)
	glyph.add_theme_color_override(&"font_color", INK)
	var cap: StyleBoxFlat = StyleBoxFlat.new()
	cap.bg_color = IVORY
	cap.border_color = Color("#b79b73")
	cap.border_width_bottom = 3
	cap.set_corner_radius_all(5)
	cap.content_margin_left = 8.0
	cap.content_margin_right = 8.0
	cap.content_margin_bottom = 3.0
	cap.shadow_color = Color(0.06, 0.08, 0.09, 0.65)
	cap.shadow_size = 3
	cap.shadow_offset = Vector2(0, 2)
	glyph.add_theme_stylebox_override(&"normal", cap)
	return glyph
