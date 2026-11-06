extends CanvasLayer
## Autoload "AreaTitle": chữ giới thiệu khu vực hiện giữa màn khi tới một khu / vùng con.
## Lần đầu tới: nét kẻ mở ra, tên loang như mực, dòng phụ hiện sau (bản đầy đủ). Các lần sau: chỉ tên, ngắn.
## Nơi gọi là AreaTitleTrigger trong scene; ở đây chỉ quyết định hiện hay không và diễn hiệu ứng.
## Không chặn điều khiển. Chỉ chạy tween khi đang hiện, xong thì ẩn hẳn.

signal title_shown(area: AreaData, full: bool)
signal title_finished

## Vượt nửa bề ngang màn + mép lởm chởm: chữ chắc chắn hiện hết
const REVEAL_END := 0.62
## Phần vượt quá chữ cuối để mép mềm + lởm chởm của shader đi hết qua chữ
const REVEAL_MARGIN := 0.06

@export var style: AreaTitleStyle = preload("res://resources/ui/area_title.tres")

var _current_zone_id: StringName
var _last_area_id: StringName
var _last_accept_msec: int = -1000000
var _tween: Tween
var _zoom: float = 1.0
var _rise: float = 0.0

@onready var _root: Control = $Root
@onready var _band: TextureRect = $Root/Band
@onready var _block: VBoxContainer = $Root/Block
@onready var _title: Label = $Root/Block/Title
@onready var _rule: OrnamentDivider = $Root/Block/Rule
@onready var _subtitle: Label = $Root/Block/Subtitle
@onready var _sound: AudioStreamPlayer = $Sound
@onready var _title_material: ShaderMaterial = _title.material as ShaderMaterial
@onready var _title_font: FontVariation = _title.get_theme_font(&"font") as FontVariation


func _ready() -> void:
	apply_style()
	# Đổi hồ sơ = lượt chơi khác: quên khu vừa hiện để vào lại vẫn có chữ
	SaveManager.slot_changed.connect(reset_history.unbind(1))
	_warm_up_shader()


## Gọi khi tới một nơi. Bỏ qua nếu vẫn là nơi vừa hiện (chết hồi sinh trong cùng khu, nạp lại scene)
func announce(area: AreaData) -> void:
	if area == null or area.display_name.is_empty():
		return
	if area is ZoneData:
		if area.id == _current_zone_id:
			return
		_current_zone_id = area.id
	elif area.id == _last_area_id:
		return
	_last_area_id = area.id
	var now := Time.get_ticks_msec()
	# Vừa xuất hiện ở khu là đã đứng trong vùng con: gộp, không hiện 2 chữ liền. Không đánh dấu đã thấy
	# để lần sau quay lại vùng này vẫn được xem bản đầy đủ
	if is_showing() and now - _last_accept_msec < int(style.merge_window * 1000.0):
		return
	_last_accept_msec = now
	var full := not area.is_seen()
	GameState.set_flag(area.get_seen_flag())
	_play(area, full)


func is_showing() -> bool:
	return _tween != null and _tween.is_valid()


## Vẽ sẵn các chữ cái của nơi này vào bộ nhớ font (trigger gọi lúc nạp khu, màn còn đen):
## lần đầu hiện chữ không bị khựng vì phải vẽ chữ giữa lúc chơi
func prepare(area: AreaData) -> void:
	if area == null:
		return
	var title := area.display_name.to_upper() if style.uppercase_title else area.display_name
	_render_glyphs(_title_font, title, [style.title_font_size, style.short_title_font_size])
	_render_glyphs(_subtitle.get_theme_font(&"font"), area.subtitle, [style.subtitle_font_size])


## Quên các nơi đã hiện trong lượt này (đổi hồ sơ, test)
func reset_history() -> void:
	_current_zone_id = &""
	_last_area_id = &""
	_last_accept_msec = -1000000


func apply_style() -> void:
	_band.anchor_top = style.vertical_anchor
	_band.anchor_bottom = style.vertical_anchor
	_band.offset_top = -style.band_height * 0.5
	_band.offset_bottom = style.band_height * 0.5
	_band.self_modulate = style.band_color
	_block.anchor_top = style.vertical_anchor
	_block.anchor_bottom = style.vertical_anchor
	_title.uppercase = style.uppercase_title
	_title.add_theme_color_override(&"font_color", style.title_color)
	_subtitle.add_theme_color_override(&"font_color", style.subtitle_color)
	_subtitle.add_theme_font_size_override(&"font_size", style.subtitle_font_size)
	_rule.color = style.rule_color
	_rule.custom_minimum_size.x = style.rule_width
	_title_material.set_shader_parameter(&"glow_color", style.reveal_glow_color)
	_title_font.spacing_glyph = roundi(style.letter_spacing)


func _play(area: AreaData, full: bool) -> void:
	if is_showing():
		_tween.kill()
		# Đang có chữ khác: tắt nhanh rồi mới hiện chữ mới, không cắt ngang thô
		if _root.visible:
			_tween = _new_tween()
			_tween.tween_property(_root, "modulate:a", 0.0, style.interrupt_fade_time)
			_tween.tween_callback(_start.bind(area, full))
			return
	_start(area, full)


func _start(area: AreaData, full: bool) -> void:
	var with_subtitle := full and not area.subtitle.is_empty()
	_title.text = area.display_name
	_title.add_theme_font_size_override(&"font_size", style.title_font_size if full else style.short_title_font_size)
	_subtitle.text = area.subtitle
	_subtitle.visible = with_subtitle
	_rule.visible = full
	_rule.reveal = 0.0
	_subtitle.modulate.a = 0.0
	_band.modulate.a = 0.0
	_title_material.set_shader_parameter(&"reveal", 0.0)
	_root.modulate.a = 1.0
	_rise = 0.0
	_set_zoom(style.zoom_from)
	_root.show()

	var start := style.start_delay
	var reveal_time := style.title_reveal_time if full else style.short_reveal_time
	var title_at := start + (style.title_delay if full else 0.0)
	var shown_at := title_at + reveal_time
	_tween = _new_tween().set_parallel(true)
	if full:
		_tween.tween_property(_band, "modulate:a", 1.0, style.rule_time).set_delay(start)
		_tween.tween_property(_rule, "reveal", 1.0, style.rule_time).set_delay(start) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		if with_subtitle:
			_tween.tween_property(_subtitle, "modulate:a", 1.0, style.subtitle_time).set_delay(start + style.subtitle_delay)
			shown_at = maxf(shown_at, start + style.subtitle_delay + style.subtitle_time)
		shown_at = maxf(shown_at, start + style.rule_time)
	else:
		_tween.tween_property(_band, "modulate:a", style.short_band_strength, reveal_time).set_delay(start)
	# Mép mực dừng ngay sau chữ cuối (tính theo bề ngang tên): tên ngắn hay dài đều loang đủ reveal_time
	var reveal_end := _title_reveal_extent()
	_title_material.set_shader_parameter(&"reveal_end", reveal_end)
	_tween.tween_property(_title_material, "shader_parameter/reveal", reveal_end, reveal_time).set_delay(title_at) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Sau đó bỏ hẳn mặt nạ: không giữ mép ở đúng sát chữ cuối suốt lúc hiện
	_tween.tween_callback(_title_material.set_shader_parameter.bind(&"reveal", REVEAL_END)).set_delay(title_at + reveal_time)
	_tween.tween_callback(_play_sound.bind(full)).set_delay(title_at)

	var fade_at := shown_at + (style.hold_time if full else style.short_hold_time)
	var fade_time := style.fade_out_time if full else style.short_fade_out_time
	# Khối chữ thu nhẹ về cỡ thật suốt lúc hiện: cảm giác tên "thở", không đứng im.
	# Phóng cả lớp bằng transform (mượt dưới 1 px), không đổi bố cục / khoảng cách chữ
	_tween.tween_method(_set_zoom, style.zoom_from, 1.0, fade_at + fade_time - title_at) \
		.set_delay(title_at).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_root, "modulate:a", 0.0, fade_time).set_delay(fade_at) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.tween_method(_set_rise, 0.0, style.fade_rise, fade_time).set_delay(fade_at) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.tween_callback(_finish).set_delay(fade_at + fade_time)
	title_shown.emit(area, full)


func _new_tween() -> Tween:
	# Không dùng set_ignore_time_scale: đo thực tế tween bỏ qua cả delay, chạy xong gần như ngay.
	# Theo time_scale thì hitstop chỉ làm chữ chậm lại vài phần trăm giây, không thấy được
	return create_tween()


func _finish() -> void:
	_tween = null
	_root.hide()
	_rise = 0.0
	_set_zoom(1.0)
	title_finished.emit()


func _play_sound(full: bool) -> void:
	_sound.stream = style.full_sound if full else style.short_sound
	if _sound.stream:
		_sound.play()


## Nửa bề ngang tên (theo bề ngang màn) + phần mép mềm/lởm chởm của shader
func _title_reveal_extent() -> float:
	var screen_width := get_viewport().get_visible_rect().size.x
	var half_width := _title.get_minimum_size().x * 0.5 / maxf(screen_width, 1.0)
	return minf(half_width + REVEAL_MARGIN, REVEAL_END)


func _set_zoom(value: float) -> void:
	_zoom = value
	_apply_layer_transform()


func _set_rise(value: float) -> void:
	_rise = value
	_apply_layer_transform()


## Phóng quanh tâm khối chữ (giữa màn, ở vertical_anchor) rồi dời lên _rise px
func _apply_layer_transform() -> void:
	var screen := get_viewport().get_visible_rect().size
	var pivot := Vector2(screen.x * 0.5, screen.y * style.vertical_anchor)
	scale = Vector2.ONE * _zoom
	offset = pivot - pivot * _zoom + Vector2.UP * _rise


func _render_glyphs(font: Font, text: String, sizes: Array[int]) -> void:
	if font == null or text.is_empty():
		return
	var server := TextServerManager.get_primary_interface()
	for rid: RID in font.get_rids():
		for size: int in sizes:
			for index: int in text.length():
				var code := text.unicode_at(index)
				server.font_render_range(rid, Vector2i(size, 0), code, code)


## Shader mặt nạ mực biên dịch lúc mở game (vẽ 2 khung, chữ bị che hết nên không thấy gì)
func _warm_up_shader() -> void:
	_title.text = "A"
	_title_material.set_shader_parameter(&"reveal", 0.0)
	_band.modulate.a = 0.0
	_rule.visible = false
	_subtitle.visible = false
	_root.show()
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_showing():
		_root.hide()
