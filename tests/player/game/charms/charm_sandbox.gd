extends Node
## Sân thử bùa: nhặt -> ghép -> buff. Foxy có kiếm; Bùa Phong Kiếm và Bùa Tâm Cáo nằm trên đất; checkpoint là chỗ đổi bùa;
## vài thùng gỗ để chém, bẫy gai để thử mất máu.
## Chơi tay: F nhặt bùa -> đứng trong vạch vàng, Tab -> trang Bùa, đeo:
## - Phong Kiếm: chém nhanh hơn 25% (so nhịp chém thùng trước / sau).
## - Tâm Cáo: thanh máu 4 -> 6 ô, hai ô mới đầy luôn; dẫm bẫy gai thấy trừ đúng; tháo thì về 4.
## Mỗi bùa tốn 1 ô khắc, có 3 ô: đeo được cả hai bùa cùng lúc.
## Tắt tự lưu và đổi thư mục lưu khi mở sân: không ghi vào save thật đang chơi dở.

const STORAGE := "user://test_charms/"
const CAPTURE_ARG: String = "--charms-capture="
const LOCALE_ARG: String = "--charms-locale="
const SIZE_ARG: String = "--charms-size="
const MANY_CHARMS: int = 30
const LONG_DESCRIPTION_REPEATS: int = 20
const ALT_ICONS: Array[Texture2D] = [
	preload("res://ui/hud/icons/wind.svg"), preload("res://ui/hud/icons/fire.svg"),
	preload("res://ui/hud/icons/sword.svg"), preload("res://ui/hud/icons/bow.svg"),
]

@export var weapons: Array[Resource] = []
@export var abilities: Array[Resource] = []

var _capture_dir: String = ""
var _capture_locale: String = "vi"
var _capture_size: Vector2i = Vector2i.ZERO
var _failures: int = 0
var _player: Player
var _menu: InventoryMenu


func _enter_tree() -> void:
	SaveManager.use_storage_dir(STORAGE)
	for progress_signal: Signal in [GameState.progress_changed, GameState.progress_committed]:
		if progress_signal.is_connected(SaveManager.save_game):
			progress_signal.disconnect(SaveManager.save_game)


func _ready() -> void:
	for weapon in weapons:
		GameState.add_weapon(weapon as WeaponData)
	if not weapons.is_empty():
		GameState.set_weapon(weapons[0] as WeaponData)
	for ability in abilities:
		GameState.unlock_ability(ability as AbilityData)
	# Sân luôn bắt đầu chưa có bùa nào, bùa trên đất chưa bị nhặt
	GameState.progress.charms.clear()
	GameState.progress.equipped_charms.clear()
	GameState.progress.flags.clear()
	GameState.charms_changed.emit()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(CAPTURE_ARG):
			_capture_dir = argument.trim_prefix(CAPTURE_ARG)
		elif argument.begins_with(LOCALE_ARG):
			_capture_locale = argument.trim_prefix(LOCALE_ARG)
		elif argument.begins_with(SIZE_ARG):
			var axes: PackedStringArray = argument.trim_prefix(SIZE_ARG).split("x")
			if axes.size() == 2 and axes[0].is_valid_int() and axes[1].is_valid_int():
				_capture_size = Vector2i(axes[0].to_int(), axes[1].to_int())
	if not _capture_dir.is_empty():
		_run_capture.call_deferred()


## Gọi qua Player, trạm và input trong cảnh thật để ảnh phản ánh trạng thái chơi.
func _run_capture() -> void:
	print("CHARM_CAPTURE_BEGIN locale=", _capture_locale)
	TranslationServer.set_locale(_capture_locale)
	if _capture_size != Vector2i.ZERO and get_window().size != _capture_size:
		# Bỏ viền cửa sổ thử để Windows không cắt bớt chiều cao vì thanh tiêu đề.
		get_window().borderless = true
		DisplayServer.window_set_size(_capture_size)
	var zone: ZoneRoot = get_parent() as ZoneRoot
	if not zone.is_combat_ready():
		await zone.combat_ready
	_player = zone.get_node(^"Player") as Player
	_menu = _player.get_node(^"HUD/InventoryMenu") as InventoryMenu
	var station: Checkpoint = zone.get_node(^"CharmCheckpoint") as Checkpoint
	var swift: CharmPickup = zone.get_node(^"SwiftSlashCharm") as CharmPickup
	var heart: CharmPickup = zone.get_node(^"HeartCharm") as CharmPickup
	var catalog: Array[CharmData] = GameState.ITEMS.charms.duplicate()
	var origin: Vector3 = _player.global_position
	var swift_id: StringName = swift.charm.id
	var heart_id: StringName = heart.charm.id
	if DirAccess.make_dir_recursive_absolute(_capture_dir) != OK:
		get_tree().quit(1)
		return

	await _key(KEY_TAB)
	await _key(KEY_C)
	await _key(KEY_C)
	await _settle()
	var page: CharmsPage = _menu.get_current_page() as CharmsPage
	_check(page != null, "Tab → C → C opens Charms")
	if not page:
		get_tree().quit(1)
		return
	_check(GameState.progress.charms.is_empty(), "no charms owned")
	await _capture("01_empty")

	await _close_menu()
	await _pick_up(swift, swift_id)
	await _key(KEY_TAB)
	await _settle()
	var first: CharmTile = _focus_charm(page, swift_id)
	_check(first != null and GameState.progress.charms.size() == 1, "first physical pickup shows one owned charm")
	await _capture("02_first_charm")

	await _close_menu()
	await _pick_up(heart, heart_id)
	await _move_to(station.global_position)
	_check(GameState.can_change_charms(), "player enters the physical charm station")
	await _key(KEY_TAB)
	await _settle()
	first = _focus_charm(page, swift_id)
	await _key(KEY_ENTER)
	await _settle()
	var second: CharmTile = _focus_charm(page, heart_id)
	_check(second != null and GameState.get_used_notches() == 1, "one notch used and second charm selected")
	await _capture("03_cost_preview")
	if second:
		await _click(second)
	await _settle()
	_check(GameState.is_charm_equipped(heart_id) and GameState.get_used_notches() == 2,
		"mouse click equips the second charm")
	await _capture("04_equipped")

	var expensive: CharmData = _make_charm(0, 6)
	GameState.ITEMS.charms.append(expensive)
	GameState.add_charm(expensive)
	_focus_charm(page, expensive.id)
	await _key(KEY_ENTER)
	_check(not GameState.is_charm_equipped(expensive.id) and GameState.get_used_notches() == 2,
		"six-notch refusal preserves the loadout")
	await _capture("05_refusal")

	await _close_menu()
	await _move_to(origin)
	_check(not GameState.can_change_charms(), "player leaves the physical charm station")
	await _key(KEY_TAB)
	await _settle()
	_focus_charm(page, swift_id)
	await _capture("06_outside_station")
	await _key(KEY_ENTER)
	_check(GameState.is_charm_equipped(swift_id), "outside station Enter cannot remove charm")

	var empty_progress: PlayerProgress = GameState.progress.snapshot()
	empty_progress.charms.clear()
	empty_progress.equipped_charms.clear()
	GameState.ITEMS.charms.clear()
	GameState.replace_progress(empty_progress)
	await _settle()
	_check(_tiles_in(page, CharmTile.Mode.COLLECTION).is_empty(), "empty catalog has zero collection tiles")
	await _capture("07_zero_catalog")
	var dummy_progress: PlayerProgress = empty_progress.snapshot()
	for index: int in range(MANY_CHARMS):
		var charm: CharmData = _make_charm(index, 1 if index < MANY_CHARMS - 1 else 6)
		GameState.ITEMS.charms.append(charm)
		dummy_progress.charms.append(charm.id)
	GameState.replace_progress(dummy_progress)
	await _settle()
	var grid: Array[CharmTile] = _tiles_in(page, CharmTile.Mode.COLLECTION)
	_check(grid.size() == MANY_CHARMS, "30 collection tiles")
	if not grid.is_empty():
		grid.back().grab_focus()
		await _settle()
		var scroll: ScrollContainer = page.get_node(^"Layout/Collection/Scroll") as ScrollContainer
		var description: ScrollContainer = _menu.get_node(^"Body/Columns/Detail/Scroll") as ScrollContainer
		_check(scroll.scroll_vertical > 0 and scroll.get_global_rect().encloses(grid.back().get_global_rect()),
			"focus scrolls to the last charm")
		_check(description.get_v_scroll_bar().visible, "long description stays within a scrollable panel")
	await _capture("08_many_long")
	GameState.ITEMS.charms.assign(catalog)
	print("CHARM_CAPTURE_RESULT locale=%s fails=%d" % [_capture_locale, _failures])
	get_tree().quit(1 if _failures else 0)


func _make_charm(index: int, cost: int) -> CharmData:
	var charm: CharmData = CharmData.new()
	charm.id = StringName("capture_charm_%d" % index)
	charm.display_name = "Stormheart" if index == 0 else "Charm %02d" % (index + 1)
	charm.description = "A relic that stores the force of an entire storm."
	charm.notch_cost = cost
	charm.icon = ALT_ICONS[index % ALT_ICONS.size()]
	if index == MANY_CHARMS - 1:
		charm.display_name = "The Watchkeeper's Last Charm from the Hall Beyond the Silent Mountain Pass"
		charm.description = ("%s " % charm.description).repeat(LONG_DESCRIPTION_REPEATS)
	return charm


func _move_to(position: Vector3) -> void:
	_player.teleport(position)
	for frame: int in range(4):
		await get_tree().physics_frame


func _pick_up(pickup: CharmPickup, id: StringName) -> void:
	if not is_instance_valid(pickup):
		_check(false, "pickup present for %s" % id)
		return
	await _move_to(pickup.global_position)
	await _key(KEY_F)
	_check(GameState.owns_charm(id), "F collects %s" % id)


func _tiles_in(page: CharmsPage, mode: CharmTile.Mode) -> Array[CharmTile]:
	var result: Array[CharmTile] = []
	for node: Node in page.find_children("*", "Control", true, false):
		var tile: CharmTile = node as CharmTile
		if tile and tile.mode == mode and tile.is_visible_in_tree():
			result.append(tile)
	return result


func _focus_charm(page: CharmsPage, id: StringName) -> CharmTile:
	for tile: CharmTile in _tiles_in(page, CharmTile.Mode.COLLECTION):
		if tile.charm and tile.charm.id == id:
			tile.grab_focus()
			return tile
	return null


func _key(key: Key) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.physical_keycode = key
		event.keycode = key
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().process_frame


func _close_menu() -> void:
	await _key(KEY_TAB)
	if _menu.visible:
		await _menu.visibility_changed


func _click(tile: CharmTile) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = tile.get_global_rect().get_center()
		event.global_position = event.position
		get_viewport().push_input(event, true)
		await get_tree().process_frame


func _settle() -> void:
	await get_tree().create_timer(maxf(_menu.style.page_time, _menu.style.charm_fly_time) + 0.18).timeout


func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var screenshot: Image = get_viewport().get_texture().get_image()
	var path: String = _capture_dir.path_join(label + ".png")
	if _capture_size != Vector2i.ZERO:
		_check(screenshot.get_size() == _capture_size, "viewport matches requested size: %s" % _capture_size)
	_check(screenshot.save_png(path) == OK, "%s %s" % [screenshot.get_size(), path])


func _check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		_failures += 1
