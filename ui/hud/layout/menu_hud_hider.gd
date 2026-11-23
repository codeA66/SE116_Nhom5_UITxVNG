class_name MenuHudHider
extends Node
## Ẩn các lớp HUD khi một menu che màn hình đang mở (màn Tab), mở lại khi menu đóng. Nghe signal opened / closed của menu,
## không chạy mỗi frame. Chỉ bật lại lớp mà chính nó đã ẩn: lớp đã bị thứ khác tắt TRƯỚC khi menu mở (cắt cảnh,
## hội thoại) thì để nguyên. Thêm menu khác = thêm một node này trỏ tới menu đó, không sửa menu.

## Node có signal opened và closed (InventoryMenu...)
@export var menu: Node
## Các lớp cần ẩn khi menu mở
@export var layers: Array[CanvasLayer] = []
## Lớp nằm ngoài scene này (autoload ở gốc cây, ví dụ "AreaTitle"): tìm theo tên lúc menu mở
@export var root_layer_names: PackedStringArray = PackedStringArray()

## Lớp mà lần mở này đã ẩn (để chỉ bật lại đúng những lớp đó)
var _hidden: Array[CanvasLayer] = []


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	if menu == null or not menu.has_signal(&"opened") or not menu.has_signal(&"closed"):
		push_error("%s: menu phải có signal opened và closed" % get_path())
		return
	menu.connect(&"opened", _on_opened)
	menu.connect(&"closed", _on_closed)


func _on_opened() -> void:
	for layer in layers:
		_hide(layer)
	for layer_name in root_layer_names:
		_hide(get_tree().root.get_node_or_null(NodePath(layer_name)) as CanvasLayer)


func _hide(layer: CanvasLayer) -> void:
	if is_instance_valid(layer) and layer.visible and not _hidden.has(layer):
		layer.visible = false
		_hidden.append(layer)


func _on_closed() -> void:
	for layer in _hidden:
		if is_instance_valid(layer):
			layer.visible = true
	_hidden.clear()
