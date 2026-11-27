class_name DevConsole
extends Node
## Autoload "Dev": bảng cheat để test game (F1 mở / đóng, mở thì dừng game). Chỉ sống trong bản debug (chạy từ editor,
## export debug); bản export release tự huỷ ngay nên không có bảng, không nhận phím, không chặn lưu.
## Cheat tự tìm trong CHEAT_DIR (mỗi file một cheat kế thừa DevCheat). Trạng thái giữ suốt phiên chơi, đổi khu thì
## cheat đang bật áp lại cho player mới. Dùng cheat nào có blocks_saving thì không ghi save tới khi tắt game.

signal cheats_changed

const CHEAT_DIR := "res://dev/cheats/"
# Bản release không cần nạp hoặc giữ giao diện dev.
const MENU_PATH: String = "res://dev/dev_menu.tscn"

## Phím mở bảng (Input Map)
@export var toggle_action: StringName = &"dev_menu"

var cheats: Array[DevCheat] = []

var _menu: DevMenu
var _paused_by_menu: bool = false


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_cheats()
	_menu = (load(MENU_PATH) as PackedScene).instantiate() as DevMenu
	add_child(_menu)
	_menu.setup(self)
	SceneManager.zone_ready.connect(_on_zone_ready)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(toggle_action):
		get_viewport().set_input_as_handled()
		if _menu.is_open():
			close_menu()
		else:
			open_menu()


func open_menu() -> void:
	# Menu tạm dừng (Esc) đang mở thì không chồng bảng dev lên
	if get_tree().paused:
		return
	get_tree().paused = true
	_paused_by_menu = true
	_menu.open()


func close_menu() -> void:
	_menu.close()
	if _paused_by_menu:
		_paused_by_menu = false
		get_tree().paused = false


func set_enabled(cheat: DevCheat, on: bool) -> void:
	if cheat.enabled == on:
		return
	cheat.enabled = on
	if on:
		_mark_used(cheat)
		cheat.apply(self)
	else:
		cheat.remove(self)
	cheats_changed.emit()


func set_value(cheat: DevCheat, new_value: float) -> void:
	if not is_equal_approx(new_value, cheat.default_value):
		_mark_used(cheat)
	cheat.set_value(self, new_value)
	cheats_changed.emit()


## Lệnh và dịch chuyển chạy sau khi đóng bảng: đổi khu cần cây không bị dừng để màn tối / sáng chạy được
func run(cheat: DevCheat) -> void:
	_mark_used(cheat)
	close_menu()
	cheat.run(self)
	cheats_changed.emit()


func choose(cheat: DevCheat, index: int) -> void:
	_mark_used(cheat)
	close_menu()
	cheat.choose(self, index)
	cheats_changed.emit()


## Player trong khu hiện tại; null khi đang chuyển khu. Chỉ gọi khi bấm nút / đổi khu, không gọi mỗi frame
func find_player() -> Player:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	var found := scene.find_children("*", "Player", true, false)
	return found[0] as Player if not found.is_empty() else null


func _mark_used(cheat: DevCheat) -> void:
	if cheat.blocks_saving and not SaveManager.is_saving_blocked():
		SaveManager.block_saving()
		cheats_changed.emit()


func _on_zone_ready() -> void:
	for cheat in cheats:
		cheat.on_zone_ready(self)


func _load_cheats() -> void:
	var dir := DirAccess.open(CHEAT_DIR)
	if dir == null:
		push_warning("DevConsole: không mở được %s" % CHEAT_DIR)
		return
	for file in dir.get_files():
		# Bản export debug đổi .gd thành .gd.remap
		var script_file := file.trim_suffix(".remap")
		if not script_file.ends_with(".gd"):
			continue
		var script := load(CHEAT_DIR + script_file) as GDScript
		if script == null or not script.can_instantiate():
			continue
		var cheat := script.new() as DevCheat
		if cheat == null:
			continue
		cheat.value = cheat.default_value
		cheats.append(cheat)
	cheats.sort_custom(func(a: DevCheat, b: DevCheat) -> bool:
		return a.group < b.group if a.group != b.group else a.order < b.order)
