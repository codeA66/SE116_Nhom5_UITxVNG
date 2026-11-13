class_name UpgradePath
extends VBoxContainer
## Lộ trình nâng cấp kỹ năng trong bảng chi tiết: từng cấp I -> II -> III kèm ngọc cấp, tên, tác dụng, trạng thái;
## cấp kế tiếp có biểu tượng + số vật phẩm cần (xanh đủ / đỏ thiếu) và lời nhắc cách nâng cấp ngay trên thẻ.
## Dựng lại mỗi lần chọn thẻ (sự kiện, không chạy mỗi frame). Thêm cấp = thêm SkillUpgradeData vào kỹ năng.

## Khoảng cách giữa các hàng cấp (px): nét nối giữa hai viên ngọc dài bằng khoảng này
const ROW_GAP := 10
const TEXT_GAP := 2

var _style: InventoryStyle


func setup(ability: AbilityData, level: int, accent: Color, menu_style: InventoryStyle) -> void:
	_style = menu_style
	add_theme_constant_override(&"separation", ROW_GAP)
	# Tiêu đề cùng kiểu các đoạn chữ của bảng chi tiết (chữ hoa, cỡ chữ thân)
	add_child(_make_label("LỘ TRÌNH NÂNG CẤP", _style.body_font, _style.ink))
	var max_level := ability.get_max_level()
	for row_level in range(1, max_level + 1):
		add_child(_make_row(ability, row_level, level, accent))
		if row_level == level + 1:
			var step := ability.get_upgrade(level)
			if step:
				add_child(_make_requirements(step))
	if level >= max_level:
		add_child(_make_label("Đã đạt cấp tối đa.", _style.lore_font, _style.dim))


func _make_row(ability: AbilityData, row_level: int, level: int, accent: Color) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	var gem := LevelGem.new()
	var state := LevelGem.GemState.CURRENT if row_level == level else (LevelGem.GemState.OWNED if row_level < level else LevelGem.GemState.LOCKED)
	gem.setup(state, accent, _style.faint, _style.path_gem_size)
	gem.link_above = float(ROW_GAP) if row_level > 1 else 0.0
	gem.link_color = Color(accent, 0.45) if row_level <= level else Color(_style.faint, 0.5)
	gem.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(gem)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override(&"separation", TEXT_GAP)
	var title_color := _style.ink if row_level <= level else _style.dim
	var title := _make_label(ability.get_level_name(row_level), _style.heading_font + 2, title_color)
	text.add_child(title)
	var step := ability.get_upgrade(row_level - 1) if row_level > 1 else null
	var description := step.description if step else "Kỹ năng gốc."
	text.add_child(_make_label(description, _style.lore_font, _style.ink if row_level <= level else _style.faint))
	row.add_child(text)
	var tag := "ĐANG DÙNG" if row_level == level else ("ĐÃ MỞ" if row_level < level else "")
	if not tag.is_empty():
		var tag_label := _make_label(tag, _style.key_font, accent if row_level == level else _style.dim)
		tag_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		tag_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(tag_label)
	return row


## Hàng vật phẩm cần cho cấp kế tiếp, thụt vào thẳng cột chữ
func _make_requirements(step: SkillUpgradeData) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 4)
	var indent := _style.path_gem_size * LevelGem.HALO_SCALE * 2.0 + 12.0
	for cost: ItemCost in step.requirements:
		if cost.item == null:
			continue
		var have := GameState.get_item_count(cost.item)
		var line := HBoxContainer.new()
		line.add_theme_constant_override(&"separation", 8)
		var spacer := Control.new()
		spacer.custom_minimum_size.x = indent
		line.add_child(spacer)
		var icon := TextureRect.new()
		icon.texture = cost.item.icon
		icon.custom_minimum_size = Vector2.ONE * _style.path_icon_size
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		line.add_child(icon)
		var enough := have >= cost.count
		var label := _make_label("%s   %d / %d" % [tr(cost.item.display_name), have, cost.count], _style.body_font, _style.success if enough else _style.warning)
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(label)
		box.add_child(line)
	var affordable := step.is_affordable(GameState.progress)
	var hint_text := "Chuột phải / phím tương tác trên thẻ để nâng cấp." if affordable else "Chưa đủ vật phẩm để nâng cấp."
	var hint := _make_label(hint_text, _style.lore_font, _style.success if affordable else _style.dim)
	var hint_row := HBoxContainer.new()
	var spacer2 := Control.new()
	spacer2.custom_minimum_size.x = indent
	hint_row.add_child(spacer2)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint_row.add_child(hint)
	box.add_child(hint_row)
	return box


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	return label
