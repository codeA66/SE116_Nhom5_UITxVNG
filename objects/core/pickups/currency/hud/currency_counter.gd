class_name CurrencyCounter
extends HBoxContainer
## HUD số tiền của một loại tiền (gán CurrencyData): icon + con số. Dùng lại cho mọi loại tiền, chỉ đổi dữ liệu.
## Nghe GameState (không kiểm tra mỗi frame). Tăng -> số nảy nhẹ; giảm (nộp tiền) / chết / nạp save -> cập nhật, không nảy.
## Icon lấy từ CurrencyData.icon; chưa có icon thì vẽ hình thoi theo CurrencyData.color.

@export var currency: CurrencyData
## Viền hình thoi (khi chưa có icon)
@export var icon_outline: Color = Color(0.05, 0.2, 0.2)
@export var icon_size: Vector2 = Vector2(14, 20)
@export var font_size: int = 20
## Nảy khi tăng: phóng to tới mức này rồi về 1 trong pop_time giây
@export var pop_scale: float = 1.3
@export_range(0.05, 1.0, 0.01) var pop_time: float = 0.18

var _shown: int = 0
var _tween: Tween

@onready var _icon: TextureRect = $Icon
@onready var _label: Label = $Count


func _ready() -> void:
	_icon.custom_minimum_size = icon_size
	_label.add_theme_font_size_override(&"font_size", font_size)
	if currency == null:
		push_error("%s chưa gán currency (CurrencyData)" % get_path())
		_set_value(0)
		return
	_icon.texture = currency.icon
	if currency.icon == null:
		_icon.draw.connect(_draw_diamond)
	GameState.currency_changed.connect(_on_changed)
	GameState.progress_replaced.connect(_on_replaced)
	_set_value(GameState.get_currency(currency.id))


## Số đang hiện (test)
func get_shown_value() -> int:
	return _shown


## Đang nảy sau khi tiền tăng (test)
func is_popping() -> bool:
	return _tween != null and _tween.is_running()


## Màu icon (màu của loại tiền; test)
func get_icon_color() -> Color:
	return currency.color if currency else Color.WHITE


## Icon đang hiện; null = đang vẽ hình thoi (test)
func get_icon_texture() -> Texture2D:
	return _icon.texture


func _on_changed(id: StringName, total: int) -> void:
	if id != currency.id:
		return
	var grew := total > _shown
	_set_value(total)
	if grew:
		_pop()


func _on_replaced() -> void:
	_stop_pop()
	_set_value(GameState.get_currency(currency.id))


func _set_value(value: int) -> void:
	_shown = value
	_label.text = str(value)


func _pop() -> void:
	_stop_pop()
	_label.pivot_offset = _label.size * 0.5
	_label.scale = Vector2.ONE * pop_scale
	_tween = create_tween()
	_tween.tween_property(_label, "scale", Vector2.ONE, pop_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _stop_pop() -> void:
	if _tween:
		_tween.kill()
		_tween = null
	_label.scale = Vector2.ONE


## Hình thoi tinh thể có viền khi loại tiền chưa có icon (Control chỉ vẽ lại khi cần)
func _draw_diamond() -> void:
	var s := _icon.size
	var points := PackedVector2Array([Vector2(s.x * 0.5, 0), Vector2(s.x, s.y * 0.5), Vector2(s.x * 0.5, s.y), Vector2(0, s.y * 0.5)])
	_icon.draw_colored_polygon(points, get_icon_color())
	var outline := points.duplicate()
	outline.append(points[0])
	_icon.draw_polyline(outline, icon_outline, 1.5, true)
	_icon.draw_line(Vector2(s.x * 0.5, s.y * 0.15), Vector2(s.x * 0.5, s.y * 0.85), Color(1, 1, 1, 0.5), 1.0, true)
