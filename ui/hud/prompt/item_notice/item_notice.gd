class_name ItemNotice
extends Control
## Banner "Nhận được" ở trên màn hình khi người chơi nhặt / nhận một vật (bùa, sau này vật phẩm khác).
## Nghe GameState.item_received, nên vật mới chỉ cần gọi GameState.announce_item(), không sửa file này.
## Nhận liền nhiều vật thì xếp hàng hiện lần lượt. Hiệu năng: không có _process, chỉ chạy tween khi đang hiện.

## Banner vừa hiện / vừa ẩn hẳn (âm thanh, hiệu ứng nối vào đây)
signal shown(display_name: String)
signal hidden_done

@export var header_text: String = "NHẬN ĐƯỢC"
## Thời gian banner đứng yên trên màn hình (s)
@export_range(0.2, 10.0, 0.1) var hold_time: float = 2.6
@export_range(0.05, 2.0, 0.05) var fade_in_time: float = 0.25
@export_range(0.05, 2.0, 0.05) var fade_out_time: float = 0.45
## Banner trượt từ trên xuống bấy nhiêu pixel lúc hiện
@export var slide_distance: float = 24.0

var _queue: Array[Dictionary] = []
var _busy: bool = false
var _rest_y: float = 0.0
## Vị trí đứng yên chỉ đúng sau khi khung đã xếp chỗ: đọc ở lần hiện đầu tiên
var _rest_known: bool = false
var _tween: Tween

@onready var _panel: Control = %Panel
@onready var _header: Label = %Header
@onready var _icon: TextureRect = %Icon
@onready var _name: Label = %Name


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header.text = header_text
	_panel.modulate.a = 0.0
	_panel.visible = false
	GameState.item_received.connect(_on_item_received)


func is_showing() -> bool:
	return _busy


## Tên vật đang hiện (rỗng khi không hiện)
func get_current_name() -> String:
	return _name.text if _busy else ""


func _on_item_received(display_name: String, icon: Texture2D) -> void:
	_queue.append({"name": display_name, "icon": icon})
	if not _busy:
		_show_next()


func _show_next() -> void:
	if _queue.is_empty():
		_busy = false
		_panel.visible = false
		hidden_done.emit()
		return
	_busy = true
	var entry: Dictionary = _queue.pop_front()
	_name.text = entry.name
	_icon.texture = entry.icon
	_icon.visible = entry.icon != null
	_panel.visible = true
	_panel.modulate.a = 0.0
	if not _rest_known:
		_rest_y = _panel.position.y
		_rest_known = true
	_panel.position.y = _rest_y - slide_distance
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_panel, ^"modulate:a", 1.0, fade_in_time)
	_tween.tween_property(_panel, ^"position:y", _rest_y, fade_in_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.chain().tween_interval(hold_time)
	_tween.chain().tween_property(_panel, ^"modulate:a", 0.0, fade_out_time)
	_tween.chain().tween_callback(_show_next)
	shown.emit(entry.name)
