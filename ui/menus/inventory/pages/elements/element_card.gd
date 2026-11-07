class_name ElementCard
extends MenuTile
## Thẻ một nguyên tố: huy hiệu màu nguyên tố, tên, chấm cấp kỹ năng (I · II · III). Chưa có thì là bóng tối "???".
## Kéo thẻ thả vào ô vũ khí để ghép; thả nguyên tố đang ghép về thẻ của nó để tháo.

const EMBLEM_RADIUS := 34.0
const PIP_SIZE := 5.0
const PIP_GAP := 18.0

var element: ElementData
var owned: bool = false
## Ô vũ khí đang chứa nguyên tố này; -1 = chưa ghép
var fused_slot: int = -1
var level: int = 0
var max_level: int = 1


func setup(data: ElementData, is_owned: bool, in_slot: int) -> void:
	element = data
	owned = is_owned
	fused_slot = in_slot
	var ability := data.ability
	level = GameState.get_ability_level(ability) if ability else 0
	max_level = ability.get_max_level() if ability else 1
	queue_redraw()


func get_detail() -> DetailEntry:
	var entry := DetailEntry.new()
	if not owned:
		entry.title = "???"
		entry.subtitle = "Nguyên tố chưa tìm thấy"
		entry.add_section("", "Một sức mạnh còn ngủ yên đâu đó trên đảo.")
		return entry
	var ability := element.ability
	entry.title = ability.get_level_name(level)
	entry.subtitle = "Nguyên tố %s  ·  Cấp %d / %d" % [element.display_name, level, max_level]
	entry.accent = element.color
	entry.art_ability = ability
	entry.art_texture = element.icon
	entry.add_section("Kỹ năng", ability.description)
	if fused_slot >= 0:
		var holder := GameState.get_weapon_in_slot(fused_slot as WeaponData.Slot)
		entry.add_section("", "Đang ghép vào %s: kỹ năng này tạm khóa." % (holder.display_name if holder else "vũ khí"), true)
	for value: int in WeaponData.Slot.values():
		var slot := value as WeaponData.Slot
		var fusion := GameState.FUSIONS.get_fusion(slot, element.id)
		var weapon := GameState.get_weapon_in_slot(slot)
		if fusion and weapon:
			entry.add_section("Ghép vào %s" % weapon.display_name, fusion.description)
	_add_upgrade_section(entry, ability)
	entry.hint = "Enter: cầm nguyên tố rồi chọn vũ khí để ghép  ·  hoặc kéo thả bằng chuột"
	return entry


func _add_upgrade_section(entry: DetailEntry, ability: AbilityData) -> void:
	var step := ability.get_upgrade(level)
	if step == null:
		if max_level > 1:
			entry.add_section("Cấp tiếp theo", "Đã đạt cấp cao nhất.")
		return
	var needs := PackedStringArray()
	for cost: ItemCost in step.requirements:
		if cost.item:
			needs.append("%d %s (đang có %d)" % [cost.count, cost.item.display_name, GameState.get_item_count(cost.item)])
	var text := step.description
	if not needs.is_empty():
		text += "\nCần: %s. Mang tới người thợ ấn để nâng cấp." % ", ".join(needs)
	entry.add_section("Cấp tiếp theo · %s" % ability.get_level_name(level + 1), text, not step.is_affordable(GameState.progress))


func _get_drag_data(_at_position: Vector2) -> Variant:
	if not owned:
		return null
	set_drag_preview(make_drag_preview(element))
	return {"element": element.id}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return owned and data is Dictionary and data.has("from_slot") and data.get("element") == element.id


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	GameState.unfuse(data["from_slot"])


## Huy hiệu nhỏ bám theo con trỏ khi kéo
static func make_drag_preview(data: ElementData) -> Control:
	var holder := Control.new()
	var dot := TextureRect.new()
	dot.texture = data.icon
	dot.modulate = data.color
	dot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	dot.size = Vector2(44, 44)
	dot.position = -dot.size * 0.5
	holder.add_child(dot)
	return holder


func _draw_content(rect: Rect2) -> void:
	draw_rect(rect, style.tile_fill)
	draw_rect(rect, style.tile_border, false, 1.0)
	var emblem_center := Vector2(rect.get_center().x, rect.position.y + 20.0 + EMBLEM_RADIUS)
	var name_at := Vector2(rect.get_center().x, rect.end.y - 44.0)
	if not owned:
		draw_circle(emblem_center, EMBLEM_RADIUS, Color(0.0, 0.0, 0.0, 0.5))
		draw_arc(emblem_center, EMBLEM_RADIUS, 0.0, TAU, 40, style.faint, 1.2, true)
		_draw_centered_text("?", emblem_center, 28, style.faint)
		_draw_centered_text("???", name_at, style.body_font, style.faint)
		return
	# Đang ghép: huy hiệu mờ đi như "đã lấy ra khỏi thẻ"
	var strength := 0.35 if fused_slot >= 0 else 1.0
	draw_circle(emblem_center, EMBLEM_RADIUS + 6.0, Color(element.color, 0.12 * strength))
	draw_circle(emblem_center, EMBLEM_RADIUS, Color(0.02, 0.025, 0.03, 0.9))
	draw_arc(emblem_center, EMBLEM_RADIUS, 0.0, TAU, 48, Color(element.color, strength), 1.6, true)
	_draw_emblem(element.icon, emblem_center, EMBLEM_RADIUS * 1.1, Color(element.color, strength), element.display_name)
	_draw_centered_text(element.display_name, name_at, style.body_font, style.ink if fused_slot < 0 else style.dim)
	_draw_level_pips(Vector2(rect.get_center().x, rect.end.y - 20.0))


## Chấm cấp hình thoi: đã đạt = đặc, chưa đạt = viền
func _draw_level_pips(center: Vector2) -> void:
	var start := center.x - PIP_GAP * float(max_level - 1) * 0.5
	for index in max_level:
		var c := Vector2(start + PIP_GAP * index, center.y)
		var diamond := PackedVector2Array([c + Vector2(0, -PIP_SIZE), c + Vector2(PIP_SIZE, 0), c + Vector2(0, PIP_SIZE), c + Vector2(-PIP_SIZE, 0)])
		if index < level:
			draw_colored_polygon(diamond, element.color)
		else:
			diamond.append(diamond[0])
			draw_polyline(diamond, style.faint, 1.2, true)
