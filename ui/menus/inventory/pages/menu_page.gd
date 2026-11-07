class_name MenuPage
extends Control
## Một trang của màn Tab (Nguyên tố, Vật phẩm, Bùa...). Thêm trang mới = thêm node kế thừa lớp này vào Pages
## của màn Tab: thanh tên trang và việc đổi trang tự có, không sửa InventoryMenu.
## Trang tự dựng ô từ GameState và báo nội dung chi tiết lên màn Tab qua signal.

## Ô đang chọn đổi: màn Tab đưa nội dung này sang bảng chi tiết
signal detail_changed(entry: DetailEntry)
## Xin màn Tab phát âm thanh (move / confirm / error)
signal sound_requested(kind: StringName)

## Tên trang trên thanh tiêu đề
@export var page_title: String = ""

var style: InventoryStyle
## Ô được chọn lần cuối: quay lại trang thì con trỏ về đúng chỗ cũ
var _last_focus: MenuTile


func setup_style(menu_style: InventoryStyle) -> void:
	style = menu_style


## Trang có hiện trên thanh tiêu đề không (trang Bùa ẩn tới khi có bùa đầu tiên)
func is_available() -> bool:
	return true


## Dựng lại ô theo tiến trình hiện tại. Chỉ gọi khi đang mở và tiến trình đổi
func refresh() -> void:
	pass


## Đưa con trỏ vào trang (ô chọn lần trước, không có thì ô đầu tiên)
func focus_default() -> void:
	var target := _last_focus if is_instance_valid(_last_focus) and _last_focus.is_visible_in_tree() else _first_tile()
	if target:
		target.grab_focus()
	else:
		detail_changed.emit(null)


## Esc khi đang ở trang: trang được xử lý trước (bỏ nguyên tố đang cầm...). true = đã xử lý, màn Tab không đóng
func handle_cancel() -> bool:
	return false


## Nối signal chung của một ô (lớp con gọi khi tạo ô)
func bind_tile(tile: MenuTile) -> void:
	tile.setup_style(style)
	tile.focused.connect(_on_tile_focused)


func _first_tile() -> MenuTile:
	for node in find_children("*", "", true, false):
		if node is MenuTile and (node as MenuTile).is_visible_in_tree():
			return node as MenuTile
	return null


func _on_tile_focused(tile: MenuTile) -> void:
	if _last_focus != tile:
		sound_requested.emit(&"move")
	_last_focus = tile
	detail_changed.emit(tile.get_detail())
