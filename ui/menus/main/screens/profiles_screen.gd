class_name ProfilesScreen
extends MenuScreen
## Chọn hồ sơ: SaveManager.SLOT_COUNT ô (tạo một lần, mỗi lần hiện chỉ đổ lại dữ liệu) + "Quay lại".

signal slot_chosen(slot: int)
signal delete_requested(slot: int)
signal back_pressed

const SLOT_SCENE := preload("res://ui/menus/main/widgets/profile_slot.tscn")

var _slots: Array[ProfileSlot] = []

@onready var _list: VBoxContainer = $List
@onready var _back: MenuItem = $Back


func _ready() -> void:
	super._ready()
	for i in SaveManager.SLOT_COUNT:
		var slot := SLOT_SCENE.instantiate() as ProfileSlot
		_list.add_child(slot)
		slot.chosen.connect(slot_chosen.emit)
		slot.delete_requested.connect(delete_requested.emit)
		_slots.append(slot)
	_back.pressed.connect(back_pressed.emit)
	default_focus = _slots[0].get_main_button()


## Đọc lại mọi ô từ file (sau khi xóa / khi mở màn)
func refresh(data: MainMenuData, registry: ZoneRegistry) -> void:
	for i in _slots.size():
		_slots[i].setup(i + 1, SaveManager.peek_slot(i + 1), data, registry)


func get_slot_button(slot: int) -> Control:
	return _slots[clampi(slot, 1, _slots.size()) - 1].get_main_button()


## Bật / tắt nhận thao tác (hộp xác nhận đang mở thì phím mũi tên không được lạc xuống các ô phía sau)
func set_interactive(enabled: bool) -> void:
	for slot in _slots:
		slot.get_main_button().focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
		var delete := slot.get_delete_button()
		delete.focus_mode = Control.FOCUS_ALL if enabled and not delete.disabled else Control.FOCUS_NONE
	_back.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
