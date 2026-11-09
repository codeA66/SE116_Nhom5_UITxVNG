class_name ElementCard
extends MenuTile
## Thẻ một nguyên tố: huy hiệu màu nguyên tố, tên, chấm cấp kỹ năng (I · II · III). Chưa có thì là bóng tối "???".
## Kéo thẻ thả vào ô vũ khí để ghép; thả nguyên tố đang ghép về thẻ của nó để tháo.

const EMBLEM_RADIUS := 34.0
## Khoảng cách giữa hai ngọc cấp, tính theo cỡ ngọc
const PIP_GAP_SCALE := 2.6

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
	# Lộ trình nâng cấp ngay sau kỹ năng: thấy ngay không cần cuộn
	if max_level > 1:
		var path := UpgradePath.new()
		path.setup(ability, level, element.color, style)
		entry.add_block(path)
	for value: int in WeaponData.Slot.values():
		var slot := value as WeaponData.Slot
		var fusion := GameState.FUSIONS.get_fusion(slot, element.id)
		var weapon := GameState.get_weapon_in_slot(slot)
		if fusion and weapon:
			entry.add_section("Ghép vào %s" % weapon.display_name, fusion.description)
	entry.hint = "Enter: cầm nguyên tố rồi chọn vũ khí để ghép  ·  hoặc kéo thả bằng chuột"
	return entry


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
	_draw_level_burst(emblem_center)
	_draw_centered_text(element.display_name, name_at, style.body_font, style.ink if fused_slot < 0 else style.dim)
	_draw_level_pips(Vector2(rect.get_center().x, rect.end.y - 20.0))


## Ngọc cấp: đã mở = màu nguyên tố, cấp đang dùng có quầng sáng, chưa mở = viên tối
func _draw_level_pips(center: Vector2) -> void:
	var gap := style.level_gem_size * PIP_GAP_SCALE
	var start := center.x - gap * float(max_level - 1) * 0.5
	for index in max_level:
		var state := LevelGem.GemState.CURRENT if index == level - 1 else (LevelGem.GemState.OWNED if index < level else LevelGem.GemState.LOCKED)
		LevelGem.draw_gem(self, Vector2(start + gap * index, center.y), style.level_gem_size, state, element.color, style.faint)


## Vừa lên cấp: vòng sáng nở ra từ huy hiệu (đi kèm lớp sáng chung của MenuTile)
func _draw_level_burst(center: Vector2) -> void:
	if _flash <= 0.0:
		return
	var grow := (1.0 - _flash) * EMBLEM_RADIUS
	draw_arc(center, EMBLEM_RADIUS + 4.0 + grow, 0.0, TAU, 48, Color(element.color, _flash), 2.5, true)
	draw_circle(center, EMBLEM_RADIUS, Color(element.color, 0.25 * _flash))
