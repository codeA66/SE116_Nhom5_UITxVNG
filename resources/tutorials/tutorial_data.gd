class_name TutorialData
extends Resource
## Dữ liệu bài hướng dẫn: hiển thị ở cửa sổ Popup khi nhận lần đầu và lưu vào trang Hướng dẫn (màn Tab / phím H).
## Thêm hướng dẫn mới = tạo file .tres gán vào TutorialCatalog, không sửa code.

@export var id: StringName
@export var title: String = ""
@export var category: String = "Cơ bản"
@export var icon: Texture2D
@export var art_texture: Texture2D
@export var art_ability: AbilityData
## Danh sách các action trong InputMap để đọc phím động ({key1}, {key2}, {key3}...)
@export var input_actions: Array[StringName] = []
## Action đơn lẻ (dành cho bài chỉ có 1 phím hoặc tương thích ngược)
@export var input_action: StringName = &""
## Mẫu câu hướng dẫn chứa token {key}, {key1}, {key2}... hoặc {action:name}
@export var prompt_template: String = ""
## Tóm tắt ngắn gọn dùng cho Popup nổi 1 lần trên màn hình
@export_multiline var summary: String = ""
## Nội dung chi tiết các phần: mảng Dictionary [{"heading": "...", "text": "...", "warning": bool}]
@export var sections: Array[Dictionary] = []
## Gợi ý phím tắt ở cuối bảng (ví dụ: "[W, A, S, D] Di chuyển")
@export var hint: String = ""
## Câu ghi chú / mẹo nhỏ ở đáy bảng
@export_multiline var lore: String = ""
## Thứ tự sắp xếp hiển thị
@export var order: int = 0


## Tạo DetailEntry để đổ sang DetailPanel của màn Tab
func create_detail_entry() -> DetailEntry:
	var entry := DetailEntry.new()
	entry.title = title
	entry.subtitle = category.to_upper()
	entry.art_ability = art_ability
	entry.art_texture = art_texture if art_texture else icon
	entry.sections = sections.duplicate(true)
	entry.lore = lore
	entry.hint = hint
	return entry


## Lấy danh sách đầy đủ tất cả actions được gán
func get_all_actions() -> Array[StringName]:
	var result: Array[StringName] = input_actions.duplicate()
	if not input_action.is_empty() and not result.has(input_action):
		result.insert(0, input_action)
	return result


## Lấy tên phím theo thứ tự (index bắt đầu từ 0)
func get_key_at(index: int) -> String:
	var actions := get_all_actions()
	if index >= 0 and index < actions.size():
		return get_action_key_name(actions[index])
	return ""


## Lấy tên phím đầu tiên (tương thích hàm cũ)
func get_key_display_name() -> String:
	return get_key_at(0)


## Hàm tiện ích đọc tên phím hiển thị từ bất kỳ action nào trong InputMap
static func get_action_key_name(action: StringName) -> String:
	if action.is_empty() or not InputMap.has_action(action):
		return ""
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key := event as InputEventKey
			var code := key.physical_keycode if key.physical_keycode != 0 else key.keycode
			return OS.get_keycode_string(code)
		elif event is InputEventMouseButton:
			var mouse := event as InputEventMouseButton
			match mouse.button_index:
				MOUSE_BUTTON_LEFT:
					return "Chuột trái"
				MOUSE_BUTTON_RIGHT:
					return "Chuột phải"
				MOUSE_BUTTON_MIDDLE:
					return "Chuột giữa"
	return ""
