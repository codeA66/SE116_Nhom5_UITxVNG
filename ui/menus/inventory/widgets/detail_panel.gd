class_name DetailPanel
extends VBoxContainer
## Bảng chi tiết bên phải màn Tab: hình lớn, tên chữ có chân, dòng phụ, nét hoa văn, các đoạn mô tả, câu truyện, hướng dẫn.
## Phần mô tả nằm trong vùng cuộn: nội dung dài không đẩy giãn cả màn.
## Hình kỹ năng dùng lại hình cáo nét trắng của bảng nhận kỹ năng (AbilityIllustration). Chỉ vẽ lại khi đổi ô đang chọn.

const ACQUIRE_DATA: Resource = preload("res://resources/feedback/ability_acquire/ability_acquire_default.tres")

var _style: InventoryStyle
## Nhãn đoạn mô tả dựng sẵn, dùng lại khi đổi ô (không tạo node mới mỗi lần chọn)
var _section_labels: Array[Label] = []
## Khối riêng của ô đang hiện (xóa khi đổi ô)
var _spawned_blocks: Array[Control] = []
## Nhãn bảng chỉ số dựng sẵn (cặp tên / giá trị), dùng lại khi đổi ô
var _stat_labels: Array[Label] = []
var _default_icon_size: Vector2
## Chấm cấp đang vẽ: (cấp, cấp tối đa); y <= 0 = ẩn
var _pip_values: Vector2i = Vector2i.ZERO
var _pip_color: Color = Color.WHITE


@onready var _art_box: Control = $ArtBox
@onready var _illustration: AbilityIllustration = $ArtBox/Illustration
@onready var _art_icon: TextureRect = $ArtBox/Icon
@onready var _title: Label = $Title
@onready var _subtitle: Label = $Subtitle
@onready var _pips: Control = $Pips
@onready var _rule: OrnamentDivider = $Rule
@onready var _scroll: ScrollContainer = $Scroll
@onready var _sections: VBoxContainer = $Scroll/Content/Sections

@onready var _stats: GridContainer = $Scroll/Content/Stats
@onready var _lore: Label = $Scroll/Content/Lore
@onready var _hint: Label = $HintRow/Hint
@onready var _hint_key: KeyGlyph = $HintRow/HintKey


func configure(style: InventoryStyle) -> void:
	_style = style
	_default_icon_size = _art_icon.custom_minimum_size
	custom_minimum_size.x = style.detail_width
	_art_box.custom_minimum_size.y = style.detail_art_height
	# Hình cáo cỡ vừa ô hình của bảng: chép dữ liệu bảng nhận kỹ năng, chỉ đổi cỡ
	var data := ACQUIRE_DATA.duplicate()
	data.set(&"illustration_size", style.detail_art_height)
	_illustration.configure(data)
	_title.add_theme_font_size_override(&"font_size", style.detail_title_font)
	_title.add_theme_color_override(&"font_color", style.ink)
	_subtitle.add_theme_font_size_override(&"font_size", style.heading_font)
	_subtitle.add_theme_color_override(&"font_color", style.dim)
	_rule.color = style.ornament
	_lore.add_theme_font_size_override(&"font_size", style.lore_font)
	_lore.add_theme_color_override(&"font_color", style.faint)
	_hint.add_theme_font_size_override(&"font_size", style.lore_font)
	_hint.add_theme_color_override(&"font_color", style.dim)
	_hint_key.font_size = style.key_font
	_hint_key.text_color = style.ink
	_hint_key.border_color = Color(style.dim, 0.7)
	_hint_key.fill_color = Color(0.0, 0.0, 0.0, 0.45)
	_pips.custom_minimum_size.y = style.level_gem_size * 3.2
	_pips.draw.connect(_draw_pips)
	_style_scrollbar()
	show_entry(null)


## Cấp đang hiện ở hàng chấm: (cấp, cấp tối đa); (0, 0) = không hiện
func get_pips() -> Vector2i:
	return _pip_values if _pips.visible else Vector2i.ZERO


## Giới hạn riêng trang có nhiều chữ để vùng mô tả luôn còn chỗ cuộn.
func set_art_layout(art_size: Vector2, title_lines: int) -> void:
	var compact: bool = art_size != Vector2.ZERO
	_art_box.custom_minimum_size.y = art_size.x if compact else _style.detail_art_height
	_art_icon.custom_minimum_size = Vector2.ONE * art_size.y if compact else _default_icon_size
	_title.max_lines_visible = title_lines
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS if compact else TextServer.OVERRUN_NO_TRIMMING
	_title.mouse_filter = Control.MOUSE_FILTER_PASS if compact else Control.MOUSE_FILTER_IGNORE
	_hint.add_theme_color_override(&"font_color", _style.charm_preview_color if compact else _style.dim)


func show_entry(entry: DetailEntry) -> void:
	var empty := entry == null
	_title.text = "" if empty else entry.title
	_title.tooltip_text = _title.text if _title.max_lines_visible > 0 else ""
	_subtitle.text = "" if empty else entry.subtitle
	_subtitle.visible = not _subtitle.text.is_empty()
	_rule.visible = not empty
	_show_art(entry)
	_show_sections(entry)
	_show_pips(entry)
	_show_stats(entry)
	_lore.text = "" if empty else entry.lore
	_lore.visible = not _lore.text.is_empty()
	_hint.text = "" if empty else entry.hint
	_hint_key.text = "" if empty else entry.hint_key
	_hint_key.visible = not _hint_key.text.is_empty() and not _hint.text.is_empty()
	# Có ô phím: chữ đi liền sau ô phím; không có thì chữ nằm giữa
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if _hint_key.visible else HORIZONTAL_ALIGNMENT_CENTER
	_hint.tooltip_text = _hint.text
	# Ô mới: cuộn về đầu phần mô tả
	_scroll.scroll_vertical = 0
	_hint.get_parent().visible = not _hint.text.is_empty()


## Tắt vẽ hình cáo (đóng màn Tab)
func release() -> void:
	_illustration.release()


func _show_art(entry: DetailEntry) -> void:
	var ability := entry.art_ability if entry else null
	var use_figure := ability != null and not ability.illustration_animation.is_empty()
	_illustration.visible = use_figure
	if use_figure:
		_illustration.setup(ability)
		_illustration.set_reveal(1.0)
	else:
		_illustration.release()
	var texture := entry.art_texture if entry else null
	_art_icon.visible = not use_figure and texture != null
	_art_icon.texture = texture
	# Chưa có hình vẽ (vật phẩm, bùa mới): bỏ khung hình để chữ không bị đẩy xuống quá xa
	_art_box.visible = use_figure or texture != null
	if entry:
		_art_icon.modulate = entry.accent


## Đoạn chữ dùng lại nhãn dựng sẵn; khối riêng (lộ trình nâng cấp...) được chèn đúng thứ tự giữa các đoạn.
## Khối của ô cũ bị xóa khi đổi ô (chỉ chạy khi đổi ô, không chạy mỗi frame)
func _show_sections(entry: DetailEntry) -> void:
	for old: Control in _spawned_blocks:
		if is_instance_valid(old):
			old.queue_free()
	_spawned_blocks.clear()
	var sections: Array[Dictionary] = []
	if entry:
		sections = entry.sections
	var text_count := 0
	for section: Dictionary in sections:
		if not section.has("block"):
			text_count += 1
	_ensure_section_labels(text_count)
	var label_index := 0
	for order in sections.size():
		var section: Dictionary = sections[order]
		if section.has("block"):
			var block: Control = section["block"]
			_sections.add_child(block)
			_sections.move_child(block, order)
			_spawned_blocks.append(block)
			continue
		var label := _section_labels[label_index]
		label_index += 1
		label.visible = true
		_sections.move_child(label, order)
		var heading := String(section["heading"])
		var body: String = tr(String(section["text"]))
		label.text = body if heading.is_empty() else "%s\n%s" % [tr(heading).to_upper(), body]
		label.add_theme_color_override(&"font_color", _style.warning if section["warning"] else _style.ink)
	for index in range(label_index, _section_labels.size()):
		_section_labels[index].visible = false


func _show_pips(entry: DetailEntry) -> void:
	_pip_values = Vector2i(entry.level, entry.max_level) if entry else Vector2i.ZERO
	_pip_color = entry.accent if entry else Color.WHITE
	_pips.visible = _pip_values.y > 0
	_pips.queue_redraw()


## Hàng chấm cấp: đã có = màu nguyên tố, cấp đang dùng có quầng sáng, chưa có = viên tối (không ghi tên cấp sau)
func _draw_pips() -> void:
	var count := _pip_values.y
	if count <= 0:
		return
	var gap := _style.level_gem_size * 2.6
	var start := Vector2(_pips.size.x * 0.5 - gap * float(count - 1) * 0.5, _pips.size.y * 0.5)
	for index in count:
		var state := LevelGem.GemState.CURRENT if index == _pip_values.x - 1 			else (LevelGem.GemState.OWNED if index < _pip_values.x else LevelGem.GemState.LOCKED)
		LevelGem.draw_gem(_pips, start + Vector2(gap * index, 0.0), _style.level_gem_size, state, _pip_color, _style.faint)


## Bảng chỉ số: nhãn dựng sẵn dùng lại, chỉ chạy khi đổi ô
func _show_stats(entry: DetailEntry) -> void:
	var stats: Array[Dictionary] = []
	if entry:
		stats = entry.stats
	while _stat_labels.size() < stats.size() * 2:
		var label := Label.new()
		label.add_theme_font_size_override(&"font_size", _style.body_font)
		var is_value := _stat_labels.size() % 2 == 1
		label.add_theme_color_override(&"font_color", _style.ink if is_value else _style.dim)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if is_value else HORIZONTAL_ALIGNMENT_LEFT
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_stats.add_child(label)
		_stat_labels.append(label)
	for index in _stat_labels.size():
		var row := index / 2
		var used := row < stats.size()
		_stat_labels[index].visible = used
		if used:
			var key := "value" if index % 2 == 1 else "label"
			var text := tr(String(stats[row].get(key, "")))
			_stat_labels[index].text = text if index % 2 == 1 else text.to_upper()
	_stats.visible = not stats.is_empty()


## Thanh cuộn dọc mảnh (vạch mờ, con trượt màu chữ phụ) thay cho thanh dày mặc định của theme
func _style_scrollbar() -> void:
	var bar := _scroll.get_v_scroll_bar()
	var track := StyleBoxFlat.new()
	track.bg_color = Color(_style.faint, 0.25)
	track.content_margin_left = _style.detail_scrollbar_width * 0.5
	track.content_margin_right = _style.detail_scrollbar_width * 0.5
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = _style.dim
	grabber.set_corner_radius_all(int(_style.detail_scrollbar_width))
	var grabber_hot := grabber.duplicate() as StyleBoxFlat
	grabber_hot.bg_color = _style.ink
	bar.add_theme_stylebox_override(&"scroll", track)
	bar.add_theme_stylebox_override(&"scroll_focus", track)
	bar.add_theme_stylebox_override(&"grabber", grabber)
	bar.add_theme_stylebox_override(&"grabber_highlight", grabber_hot)
	bar.add_theme_stylebox_override(&"grabber_pressed", grabber_hot)
	bar.custom_minimum_size.x = _style.detail_scrollbar_width


func _ensure_section_labels(count: int) -> void:
	while _section_labels.size() < count:
		var label := Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override(&"font_size", _style.body_font)
		_sections.add_child(label)
		_section_labels.append(label)
