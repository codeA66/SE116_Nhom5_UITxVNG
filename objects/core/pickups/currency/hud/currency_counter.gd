class_name CurrencyCounter
extends HBoxContainer
## HUD số tiền của một loại tiền (gán CurrencyData): icon + con số. Dùng lại cho mọi loại tiền, chỉ đổi dữ liệu.
## Kiểu Death's Door: ẩn khi đánh nhau, chỉ hiện show_time giây khi tiền đổi (nhặt / nộp) rồi mờ đi; không có "+N".
## Chết / nạp save (progress_replaced) -> số cập nhật, ẩn ngay. Nghe GameState, không kiểm tra mỗi frame.
## Icon lấy từ CurrencyData.icon; chưa có icon thì vẽ hình thoi theo CurrencyData.color.

@export var currency: CurrencyData
## Viền hình thoi (khi chưa có icon)
@export var icon_outline: Color = Color(0.05, 0.2, 0.2)
@export var icon_size: Vector2 = Vector2(14, 20)
@export var font_size: int = 20
@export_group("Show")
## Hiện bao lâu sau lần đổi tiền cuối (s), rồi mờ trong fade_time (s); hiện ra trong appear_time (s)
@export_range(0.1, 10.0, 0.05) var show_time: float = 2.5
@export_range(0.05, 2.0, 0.01) var fade_time: float = 0.4
@export_range(0.0, 1.0, 0.01) var appear_time: float = 0.12

var _shown: int = 0
var _tween: Tween

@onready var _icon: TextureRect = $Icon
@onready var _label: Label = $Count


func _ready() -> void:
	_icon.custom_minimum_size = icon_size
	_label.add_theme_font_size_override(&"font_size", font_size)
	_hide_now()
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


## Đang hiện trên màn hình (kể cả lúc đang hiện dần / mờ dần; test)
func is_showing() -> bool:
	return visible


## Màu icon (màu của loại tiền; test)
func get_icon_color() -> Color:
	return currency.color if currency else Color.WHITE


## Icon đang hiện; null = đang vẽ hình thoi (test)
func get_icon_texture() -> Texture2D:
	return _icon.texture


func _on_changed(id: StringName, total: int) -> void:
	if id != currency.id:
		return
	_set_value(total)
	_show_then_fade()


func _on_replaced() -> void:
	_set_value(GameState.get_currency(currency.id))
	_hide_now()


func _set_value(value: int) -> void:
	_shown = value
	_label.text = str(value)


## Hiện (hoặc giữ hiện nếu đang hiện), đếm lại show_time từ lần đổi tiền này rồi mờ đi
func _show_then_fade() -> void:
	if _tween:
		_tween.kill()
	visible = true
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, appear_time * (1.0 - modulate.a))
	_tween.tween_interval(show_time)
	_tween.tween_property(self, "modulate:a", 0.0, fade_time)
	_tween.tween_callback(_hide_now)


func _hide_now() -> void:
	if _tween:
		_tween.kill()
		_tween = null
	modulate.a = 0.0
	visible = false


## Hình thoi tinh thể có viền khi loại tiền chưa có icon (Control chỉ vẽ lại khi cần)
func _draw_diamond() -> void:
	var s := _icon.size
	var points := PackedVector2Array([Vector2(s.x * 0.5, 0), Vector2(s.x, s.y * 0.5), Vector2(s.x * 0.5, s.y), Vector2(0, s.y * 0.5)])
	_icon.draw_colored_polygon(points, get_icon_color())
	var outline := points.duplicate()
	outline.append(points[0])
	_icon.draw_polyline(outline, icon_outline, 1.5, true)
	_icon.draw_line(Vector2(s.x * 0.5, s.y * 0.15), Vector2(s.x * 0.5, s.y * 0.85), Color(1, 1, 1, 0.5), 1.0, true)
