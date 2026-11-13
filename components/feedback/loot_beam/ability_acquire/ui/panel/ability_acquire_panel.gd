class_name AbilityAcquirePanel
extends Control
## Bảng nhận kỹ năng sau đoạn diễn: nền đen đặc; hình cáo vẽ nét sáng đang dùng kỹ năng; dòng nhỏ ("Đã lĩnh hội");
## tên in hoa loang mực; nét hoa văn tự cuộn; câu hướng dẫn có hình phím thật; mô tả; dấu "có thể đóng" nhấp nháy.
## Thứ tự hiện theo bảng nhận kỹ năng kiểu Hollow Knight: hình + tên sáng dần từ tối lên trắng (đổi độ sáng, không mờ dần vào),
## sau đó nét hoa văn, rồi câu hướng dẫn + mô tả. Bảng chỉ diễn, việc đóng do AbilityAcquireUi quyết định.
## Mọi chữ lấy từ AbilityData, mọi màu / cỡ / nhịp lấy từ AbilityAcquireData: kỹ năng mới không cần sửa file này.

signal intro_finished
signal closed

const Tuning = preload("res://resources/feedback/ability_acquire/ability_acquire_data.gd")
## Chỗ chèn hình phím trong câu hướng dẫn
const KEY_TOKEN := "{key}"
## Mặt nạ mực của tên mở hết (xem area_title_reveal.gdshader): tên sáng dần thay vì loang
const TITLE_REVEAL_FULL := 0.62
## Màu bắt đầu khi sáng dần: đen trên nền đen = chưa thấy gì
const DARK := Color(0.0, 0.0, 0.0, 1.0)

var _data: Tuning
var _intro: Tween
var _marker: Tween
var _closing: Tween
var _intro_done: bool = false

@onready var _backdrop: ColorRect = $Backdrop
@onready var _content: VBoxContainer = $Content
@onready var _illustration: AbilityIllustration = $Content/Illustration
@onready var _verb: Label = $Content/Verb
@onready var _title: Label = $Content/Title
@onready var _rule: OrnamentDivider = $Content/Rule
@onready var _prompt: HBoxContainer = $Content/Prompt
@onready var _prompt_before: Label = $Content/Prompt/Before
@onready var _key: KeyGlyph = $Content/Prompt/Key
@onready var _prompt_after: Label = $Content/Prompt/After
@onready var _description: Label = $Content/Description
@onready var _continue: OrnamentDivider = $Continue
@onready var _title_material: ShaderMaterial = _title.material as ShaderMaterial


func _ready() -> void:
	hide()


## Áp màu / cỡ chữ / nhịp một lần lúc tạo; vẽ sẵn hình cáo một khung để biên dịch shader khi màn còn đen
func configure(data: Tuning) -> void:
	_data = data
	_content.add_theme_constant_override(&"separation", data.content_spacing)
	_content.anchor_top = data.content_center_y
	_content.anchor_bottom = data.content_center_y
	_style_label(_verb, data.verb_font, data.verb_color)
	_style_label(_title, data.title_font, data.title_color)
	_style_label(_prompt_before, data.prompt_font, data.prompt_color)
	_style_label(_prompt_after, data.prompt_font, data.prompt_color)
	_style_label(_description, data.body_font, data.body_color)
	_description.custom_minimum_size.x = data.description_width
	_rule.color = data.rule_color
	_rule.custom_minimum_size.x = data.rule_width
	_continue.color = data.continue_color
	_key.font_size = data.key_font
	_key.text_color = data.prompt_color
	_key.fill_color = data.key_fill_color
	_key.border_color = data.key_border_color
	_illustration.configure(data)
	_illustration.prewarm()


## Bắt đầu diễn bảng cho một kỹ năng. key_text rỗng = kỹ năng không có phím (bị động)
func play(ability: AbilityData, key_text: String) -> void:
	_stop_tweens()
	_intro_done = false
	_illustration.setup(ability)
	_verb.text = ability.acquire_verb
	_verb.visible = not ability.acquire_verb.is_empty()
	_title.text = ability.display_name
	_fill_prompt(ability, key_text)
	_description.text = ability.description
	_description.visible = not ability.description.is_empty()
	modulate.a = 1.0
	_backdrop.modulate.a = 0.0
	for node: CanvasItem in [_illustration, _verb, _title, _rule, _prompt, _description]:
		node.modulate = DARK
	_continue.modulate.a = 0.0
	_rule.reveal = 0.0
	_illustration.set_reveal(1.0)
	_set_title_reveal(TITLE_REVEAL_FULL)
	show()
	_run_intro()


## Bấm khi đang diễn: hiện hết ngay (giống bấm sớm ở bảng nhận kỹ năng kiểu Hollow Knight)
func skip_intro() -> void:
	if _intro_done or _intro == null or not _intro.is_valid():
		return
	# Đẩy thời gian tween tới cuối: mọi phần về trạng thái hiện hết, callback kết thúc vẫn chạy
	_intro.custom_step(_intro_length() + 1.0)


func is_intro_done() -> bool:
	return _intro_done


## Mờ cả bảng (kể cả nền đen) rồi phát closed
func close() -> void:
	_stop_tweens()
	_closing = create_tween()
	_closing.tween_property(self, "modulate:a", 0.0, _data.close_time)
	_closing.tween_callback(_on_closed)


## Dừng ngay, không hiệu ứng (hủy chuỗi nhận kỹ năng)
func stop() -> void:
	_stop_tweens()
	_illustration.release()
	hide()


func get_illustration_center() -> Vector2:
	return _illustration.get_center()


func _run_intro() -> void:
	var head := _data.head_delay
	var rule_at := head + _data.head_fade_time
	var body_at := rule_at + _data.rule_time + _data.body_pause
	_intro = create_tween().set_parallel(true)
	_intro.tween_property(_backdrop, "modulate:a", 1.0, _data.panel_time)
	for node: CanvasItem in [_illustration, _verb, _title]:
		_intro.tween_property(node, "modulate", Color.WHITE, _data.head_fade_time).set_delay(head) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_intro.tween_property(_rule, "modulate", Color.WHITE, _data.rule_time).set_delay(rule_at)
	_intro.tween_property(_rule, "reveal", 1.0, _data.rule_time).set_delay(rule_at) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_intro.tween_property(_prompt, "modulate", Color.WHITE, _data.body_fade_time).set_delay(body_at)
	_intro.tween_property(_description, "modulate", Color.WHITE, _data.body_fade_time).set_delay(body_at)
	_intro.tween_callback(_finish_intro).set_delay(_intro_length())
	# Dấu "có thể đóng" đếm từ lúc mở bảng, độc lập với việc bấm bỏ qua
	_marker = create_tween()
	_marker.tween_interval(_data.continue_delay)
	_marker.tween_callback(_start_marker)


func _intro_length() -> float:
	var head := _data.head_delay
	var body_end := head + _data.head_fade_time + _data.rule_time + _data.body_pause + _data.body_fade_time
	return maxf(body_end, _data.panel_time)


func _finish_intro() -> void:
	if _intro_done:
		return
	_intro_done = true
	intro_finished.emit()


func _start_marker() -> void:
	_marker = create_tween().set_loops()
	var half := maxf(_data.continue_blink_period * 0.5, _data.minimum_time)
	_marker.tween_property(_continue, "modulate:a", 1.0, half).set_trans(Tween.TRANS_SINE)
	_marker.tween_property(_continue, "modulate:a", 0.25, half).set_trans(Tween.TRANS_SINE)


func _on_closed() -> void:
	_illustration.release()
	hide()
	closed.emit()


func _stop_tweens() -> void:
	for tween: Tween in [_intro, _marker, _closing]:
		if tween and tween.is_valid():
			tween.kill()
	_intro = null
	_marker = null
	_closing = null


func _set_title_reveal(value: float) -> void:
	_title_material.set_shader_parameter(&"reveal", value)


## Tách câu hướng dẫn quanh {key}: chữ trước + hình phím + chữ sau. Không có phím thì bỏ câu có {key}
func _fill_prompt(ability: AbilityData, key_text: String) -> void:
	var template := ability.acquire_prompt if not ability.acquire_prompt.is_empty() else _data.default_prompt
	template = tr(template)
	var index := template.find(KEY_TOKEN)
	if index < 0:
		_prompt_before.text = template
		_prompt_after.text = ""
		_key.visible = false
		_prompt.visible = not template.is_empty()
		return
	_prompt.visible = not key_text.is_empty()
	_prompt_before.text = template.left(index).strip_edges()
	_prompt_after.text = template.substr(index + KEY_TOKEN.length()).strip_edges()
	_prompt_before.visible = not _prompt_before.text.is_empty()
	_prompt_after.visible = not _prompt_after.text.is_empty()
	_key.visible = true
	_key.text = key_text


func _style_label(label: Label, font_size: int, color: Color) -> void:
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
