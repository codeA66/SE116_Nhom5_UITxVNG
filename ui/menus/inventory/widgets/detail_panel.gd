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


@onready var _art_box: Control = $ArtBox
@onready var _illustration: AbilityIllustration = $ArtBox/Illustration
@onready var _art_icon: TextureRect = $ArtBox/Icon
@onready var _title: Label = $Title
@onready var _subtitle: Label = $Subtitle
@onready var _rule: OrnamentDivider = $Rule
@onready var _scroll: ScrollContainer = $Scroll
@onready var _sections: VBoxContainer = $Scroll/Content/Sections

@onready var _lore: Label = $Scroll/Content/Lore
@onready var _hint: Label = $Hint


func configure(style: InventoryStyle) -> void:
	_style = style
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
	show_entry(null)


func show_entry(entry: DetailEntry) -> void:
	var empty := entry == null
	_title.text = "" if empty else entry.title
	_subtitle.text = "" if empty else entry.subtitle
	_subtitle.visible = not _subtitle.text.is_empty()
	_rule.visible = not empty
	_show_art(entry)
	_show_sections(entry)
	_lore.text = "" if empty else entry.lore
	_lore.visible = not _lore.text.is_empty()
	_hint.text = "" if empty else entry.hint
	# Ô mới: cuộn về đầu phần mô tả
	_scroll.scroll_vertical = 0
	_hint.visible = not _hint.text.is_empty()


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


func _ensure_section_labels(count: int) -> void:
	while _section_labels.size() < count:
		var label := Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override(&"font_size", _style.body_font)
		_sections.add_child(label)
		_section_labels.append(label)
