class_name DialogueBox
extends Control
## Hộp thoại NPC ở đáy màn: tên người nói, nét hoa văn trên dưới, chữ hiện dần, dấu "đọc tiếp" nhấp nháy.
## Hai chế độ: đọc một chuỗi câu (play_lines) hoặc hỏi kèm lựa chọn (ask) cho cửa hàng, gác cổng thu tiền...
## Kết quả trả qua signal finished: chuỗi câu = RESULT_DONE, lựa chọn = chỉ số đã chọn, thoát (Esc) = RESULT_CANCELLED.
## Chỉ process khi chữ đang hiện dần; chỉ nhận phím khi đang mở.

signal finished(result: int)
## Bắt đầu hiện một câu mới (NPC nảy nhẹ / đổi hoạt ảnh theo câu)
signal line_started(index: int)

enum Mode { IDLE, LINES, CHOICES }

const RESULT_DONE := 0
const RESULT_CANCELLED := -1
## Ký tự được dừng thêm một nhịp sau khi hiện
const PUNCTUATION := ".,!?…:;"

@export var style: DialogueStyle = preload("res://resources/ui/dialogue_style.tres")
## Các phím sang câu / hiện hết câu / xác nhận lựa chọn (chuột trái cũng được)
@export var advance_actions: Array[StringName] = [&"interact", &"ui_accept"]
@export var cancel_action: StringName = &"ui_cancel"

var _mode: Mode = Mode.IDLE
var _open: bool = false
var _lines: Array[DialogueLine] = []
var _line_index: int = 0
var _default_speaker: String = ""
var _options: PackedStringArray = PackedStringArray()
var _char_timer: float = 0.0
var _revealed_count: int = 0
var _tween: Tween
var _arrow_tween: Tween
var _panel_style: StyleBoxFlat = StyleBoxFlat.new()
## Nút lựa chọn dựng sẵn, dùng lại giữa các lần hỏi (không tạo node mới mỗi lần)
var _choice_buttons: Array[Button] = []

@onready var _box: VBoxContainer = $Box
@onready var _name: Label = $Box/Name
@onready var _top_rule: OrnamentDivider = $Box/TopRule
@onready var _panel: PanelContainer = $Box/Panel
@onready var _margin: MarginContainer = $Box/Panel/Margin
@onready var _text: Label = $Box/Panel/Margin/Content/Text
@onready var _choices: VBoxContainer = $Box/Panel/Margin/Content/Choices
@onready var _arrow: OrnamentDivider = $Box/Panel/Margin/Content/Arrow
@onready var _bottom_rule: OrnamentDivider = $Box/BottomRule
@onready var _sound: AudioStreamPlayer = $Sound
@onready var _blip: AudioStreamPlayer = $Blip


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_apply_style()
	set_process(false)
	set_process_unhandled_input(false)
	get_viewport().size_changed.connect(_fit_width)
	_fit_width()


func _process(delta: float) -> void:
	_char_timer -= delta
	var total := _text.get_total_character_count()
	while _char_timer <= 0.0 and _revealed_count < total:
		_revealed_count += 1
		var character := _text.text[_revealed_count - 1] if _revealed_count <= _text.text.length() else ""
		_char_timer += 1.0 / style.chars_per_second + (style.punctuation_pause if PUNCTUATION.contains(character) else 0.0)
		if _revealed_count % style.blip_interval == 0:
			_play(_blip, style.sound_blip)
	_text.visible_characters = _revealed_count
	if _revealed_count >= total:
		_on_line_revealed()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(cancel_action):
		get_viewport().set_input_as_handled()
		_finish(RESULT_CANCELLED, true)
		return
	if not _is_advance(event):
		return
	get_viewport().set_input_as_handled()
	if _is_typing():
		_reveal_all()
		return
	match _mode:
		Mode.LINES:
			_play(_sound, style.sound_advance)
			_show_line(_line_index + 1)
		Mode.CHOICES:
			var focused := get_viewport().gui_get_focus_owner() as Button
			var index := _choice_buttons.find(focused)
			if index >= 0 and index < _options.size():
				_choose(index)


## Đọc lần lượt các câu. Người nói để trống trong câu = default_speaker. Hết câu -> finished(RESULT_DONE), hộp vẫn mở
## (người gọi tự close() hoặc nói tiếp).
func play_lines(lines: Array[DialogueLine], default_speaker: String) -> void:
	_lines = lines.filter(func(line: DialogueLine) -> bool: return line != null)
	_default_speaker = default_speaker
	_mode = Mode.LINES
	if _lines.is_empty():
		# Phát trễ một nhịp: người gọi kịp await signal sau khi gọi hàm này
		_mode = Mode.IDLE
		finished.emit.call_deferred(RESULT_DONE)
		return
	_open_box()
	_show_line(0)


## Hỏi một câu rồi hiện lựa chọn. Chọn -> finished(chỉ số), Esc -> finished(RESULT_CANCELLED) và đóng hộp.
func ask(question: String, speaker: String, options: PackedStringArray) -> void:
	if options.is_empty():
		push_warning("DialogueBox.ask: không có lựa chọn nào, coi như thoát")
		finished.emit.call_deferred(RESULT_CANCELLED)
		return
	_options = options
	_mode = Mode.CHOICES
	_lines.clear()
	_open_box()
	_set_speaker(speaker)
	_hide_choices()
	_start_typing(question)


func close() -> void:
	if not _open:
		return
	_open = false
	_mode = Mode.IDLE
	set_process(false)
	set_process_unhandled_input(false)
	_hide_choices()
	_stop_arrow()
	_play(_sound, style.sound_close)
	_animate(false)


func is_open() -> bool:
	return _open


func _open_box() -> void:
	set_process_unhandled_input(true)
	if _open:
		return
	_open = true
	_play(_sound, style.sound_open)
	_animate(true)


func _show_line(index: int) -> void:
	if index >= _lines.size():
		_finish(RESULT_DONE, false)
		return
	_line_index = index
	var line := _lines[index]
	_set_speaker(line.speaker if not line.speaker.is_empty() else _default_speaker)
	_start_typing(line.text)
	line_started.emit(index)


func _set_speaker(speaker: String) -> void:
	_speaker_source = speaker
	_name.text = tr(speaker).to_upper()
	_name.modulate.a = 0.0 if speaker.is_empty() else 1.0


func _start_typing(text: String) -> void:
	_stop_arrow()
	_line_source = text
	_text.text = tr(text)
	_revealed_count = 0
	_char_timer = 0.0
	if style.chars_per_second <= 0.0 or text.is_empty():
		_reveal_all()
		return
	_text.visible_characters = 0
	set_process(true)


var _speaker_source: String = ""
var _line_source: String = ""


func _notification(what: int) -> void:
	if what != NOTIFICATION_TRANSLATION_CHANGED or not is_node_ready() or not _open:
		return
	_name.text = tr(_speaker_source).to_upper()
	_text.text = tr(_line_source)
	if _is_typing():
		_revealed_count = mini(_revealed_count, _text.get_total_character_count())
		_text.visible_characters = _revealed_count
	if _choices.visible:
		_refresh_choice_marks()


func _is_typing() -> bool:
	return is_processing()


func _reveal_all() -> void:
	_revealed_count = _text.get_total_character_count()
	_text.visible_characters = -1
	_on_line_revealed()


func _on_line_revealed() -> void:
	set_process(false)
	_text.visible_characters = -1
	if _mode == Mode.CHOICES:
		_show_choices()
	elif _mode == Mode.LINES:
		_start_arrow()


func _show_choices() -> void:
	while _choice_buttons.size() < _options.size():
		_choice_buttons.append(_make_choice_button(_choice_buttons.size()))
	for index in _choice_buttons.size():
		var button := _choice_buttons[index]
		button.visible = index < _options.size()
		if button.visible:
			button.text = _options[index]
	_choices.visible = true
	_choice_buttons[0].grab_focus()
	_refresh_choice_marks()


func _hide_choices() -> void:
	_choices.visible = false
	for button: Button in _choice_buttons:
		if button.has_focus():
			button.release_focus()


func _make_choice_button(index: int) -> Button:
	var button := Button.new()
	button.flat = true
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_font_size_override(&"font_size", style.choice_font)
	for color_name: StringName in [&"font_color", &"font_disabled_color"]:
		button.add_theme_color_override(color_name, style.choice_color)
	for color_name: StringName in [&"font_focus_color", &"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color"]:
		button.add_theme_color_override(color_name, style.choice_focus_color)
	button.pressed.connect(_choose.bind(index))
	# Rê chuột lên lựa chọn = chọn nó, giống phím lên / xuống
	button.mouse_entered.connect(button.grab_focus)
	button.focus_entered.connect(_on_choice_focused)
	_choices.add_child(button)
	return button


func _on_choice_focused() -> void:
	if _choices.visible:
		_play(_sound, style.sound_choice_move)
	_refresh_choice_marks()


## Thêm dấu trước lựa chọn đang chọn (màu thôi khó thấy khi chỉ có 2 lựa chọn)
func _refresh_choice_marks() -> void:
	for index in _options.size():
		var button := _choice_buttons[index]
		var marker := "%s  " % style.choice_marker if button.has_focus() else ""
		button.text = marker + tr(_options[index])


func _choose(index: int) -> void:
	if _mode != Mode.CHOICES or _is_typing():
		return
	_play(_sound, style.sound_choice_confirm)
	_finish(index, false)


## close_box: Esc đóng hộp ngay; xong bình thường thì để người gọi quyết định (nói tiếp, mở cửa hàng...)
func _finish(result: int, close_box: bool) -> void:
	_mode = Mode.IDLE
	set_process(false)
	set_process_unhandled_input(false)
	_stop_arrow()
	_hide_choices()
	if close_box:
		close()
	finished.emit(result)


func _is_advance(event: InputEvent) -> bool:
	var mouse := event as InputEventMouseButton
	if mouse and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
		return true
	for action: StringName in advance_actions:
		if InputMap.has_action(action) and event.is_action_pressed(action):
			return true
	return false


func _start_arrow() -> void:
	_stop_arrow()
	_arrow.modulate.a = 1.0
	_arrow_tween = create_tween().set_loops()
	_arrow_tween.tween_property(_arrow, "modulate:a", 0.25, style.arrow_pulse_time).set_trans(Tween.TRANS_SINE)
	_arrow_tween.tween_property(_arrow, "modulate:a", 1.0, style.arrow_pulse_time).set_trans(Tween.TRANS_SINE)


func _stop_arrow() -> void:
	if _arrow_tween and _arrow_tween.is_valid():
		_arrow_tween.kill()
	_arrow.modulate.a = 0.0


func _animate(showing: bool) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	if not is_inside_tree():
		# Đang bị xóa cùng NPC: không tạo tween được, ẩn / hiện ngay
		visible = showing
		return
	_tween = create_tween().set_parallel(true)
	if showing:
		visible = true
		modulate.a = 0.0
		# Neo đáy + mọc lên trên: kéo offset_bottom là cả hộp trượt, nội dung dài thì hộp tự cao lên phía trên
		_box.offset_bottom = -style.bottom_margin + style.slide
		_tween.tween_property(self, "modulate:a", 1.0, style.open_time).set_trans(Tween.TRANS_SINE)
		_tween.tween_property(_box, "offset_bottom", -style.bottom_margin, style.open_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		_tween.tween_property(self, "modulate:a", 0.0, style.close_time).set_trans(Tween.TRANS_SINE)
		_tween.chain().tween_callback(hide)


func _apply_style() -> void:
	_name.add_theme_font_size_override(&"font_size", style.name_font)
	_name.add_theme_color_override(&"font_color", style.name_color)
	_text.add_theme_font_size_override(&"font_size", style.text_font)
	_text.add_theme_color_override(&"font_color", style.text_color)
	_text.custom_minimum_size.y = style.text_min_height
	for rule: OrnamentDivider in [_top_rule, _bottom_rule]:
		rule.color = style.ornament
		rule.custom_minimum_size.y = style.rule_height
	_arrow.color = style.ornament
	_panel_style.bg_color = style.panel_fill
	_panel.add_theme_stylebox_override(&"panel", _panel_style)
	_margin.add_theme_constant_override(&"margin_left", roundi(style.padding.x))
	_margin.add_theme_constant_override(&"margin_right", roundi(style.padding.x))
	_margin.add_theme_constant_override(&"margin_top", roundi(style.padding.y))
	_margin.add_theme_constant_override(&"margin_bottom", roundi(style.padding.y))


## Hộp rộng box_width nhưng không vượt màn hẹp; luôn nằm giữa, cách đáy bottom_margin
func _fit_width() -> void:
	var screen := get_viewport_rect().size
	var width := maxf(minf(style.box_width, screen.x - style.padding.x * 2.0), 1.0)
	_box.offset_left = -width * 0.5
	_box.offset_right = width * 0.5
	if not (_tween and _tween.is_running()):
		_box.offset_bottom = -style.bottom_margin
	_box.offset_top = _box.offset_bottom


func _play(player: AudioStreamPlayer, stream: AudioStream) -> void:
	if stream == null:
		return
	player.stream = stream
	player.play()
