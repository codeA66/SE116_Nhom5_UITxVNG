class_name CurrencyCounter
extends HBoxContainer
## DONE: số đếm hội tụ trong thời gian cố định, hiện lại khi tiền đổi; nghỉ thì không process.
## NOTES: get_shown_value giữ tổng logic của API cũ; get_displayed_value là con số đang hoạt họa.
const Style = preload("res://resources/ui/hud_style.gd")
@export_group("Binding")
@export var currency: CurrencyData
@export var style: Style = preload("res://resources/ui/hud_style.tres")
var show_time: float:
	get: return style.currency_show_time
var fade_time: float:
	get: return style.currency_fade_time
var appear_time: float:
	get: return style.currency_appear_time
var _shown: int = 0
var _displayed: int = 0
var _from: float = 0.0
var _clock: float = 0.0
var _count_age: float = 0.0
@onready var _icon: TextureRect = $Icon
@onready var _label: Label = $Count
## Bắt signal tiền/tải save; không kiểm tra số tiền mỗi frame khi nghỉ.
func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	apply_style()
	_hide_now()
	if currency == null:
		_set_value(0)
		return
	GameState.currency_changed.connect(_on_changed)
	GameState.progress_replaced.connect(_on_replaced)
	_set_value(GameState.get_currency(currency.id))
## Toàn bộ màu/khoảng cách/thời gian lấy từ cùng style của HUD.
func apply_style() -> void:
	if not is_instance_valid(_icon): return
	theme = style.theme
	add_theme_constant_override(&"separation",maxi(style.currency_spacing,0))
	_icon.custom_minimum_size = Vector2(clampf(style.currency_icon_size.x,1,64),clampf(style.currency_icon_size.y,1,64))
	_icon.set(&"style",style)
	_icon.texture = style.currency_texture if style.currency_texture != null else (currency.icon if currency != null else null)
	_icon.set(&"jade_color",get_icon_color())
	_label.add_theme_font_size_override(&"font_size",clampi(style.currency_font_size,1,64))
	_label.add_theme_color_override(&"font_color",style.ivory)
	_label.add_theme_color_override(&"font_outline_color",style.ink)
	_label.add_theme_constant_override(&"outline_size",1)
	_icon.queue_redraw()
## Tổng mới nhất phản ánh signal ngay cả khi chữ đang đếm tới tổng đó.
func get_shown_value() -> int:
	return _shown
## Dùng để test count-up thật, không coi giá trị đích là animation đã kết thúc.
func get_displayed_value() -> int:
	return _displayed
## Giữ API bộ đếm cũ.
func is_showing() -> bool:
	return visible
## Màu nhận dạng loại tiền vẫn thuộc CurrencyData.
func get_icon_color() -> Color:
	return currency.color if currency != null else style.ivory
## Texture override có thể thay hình thủ tục sau này.
func get_icon_texture() -> Texture2D:
	return _icon.texture
## Chỉ đúng loại tiền mới khởi động lại cửa sổ hiện.
func _on_changed(id: StringName, total: int) -> void:
	if currency == null or id != currency.id: return
	_from = float(_displayed)
	_shown = total
	_clock = 0.0
	_count_age = 0.0
	show()
	set_process(true)
## Đọc checkpoint không phát thông báo nhặt tiền giả.
func _on_replaced() -> void:
	_set_value(GameState.get_currency(currency.id) if currency != null else 0)
	_hide_now()
## Giá trị ban đầu được đặt trực tiếp, không chạy count-up từ zero khi tải save.
func _set_value(value: int) -> void:
	_shown = value
	_displayed = value
	_label.text = str(value)
## Chỉ tạo chuỗi khi số nguyên đang hiển thị đổi, không lặp từng đơn vị của khoản lớn.
func _process(delta: float) -> void:
	_clock += delta
	_count_age += delta
	var count_t: float = clampf(_count_age/maxf(style.currency_count_time,0.001),0,1)
	var value: int = roundi(lerpf(_from,float(_shown),1.0-pow(1.0-count_t,3.0)))
	if value != _displayed:
		_displayed = value
		_label.text = str(value)
	var appear: float = maxf(style.currency_appear_time,0.001)
	var hold: float = maxf(style.currency_show_time,style.currency_count_time)
	var fade: float = maxf(style.currency_fade_time,0.001)
	modulate.a = clampf(_clock/appear,0,1)*(1.0-clampf((_clock-appear-hold)/fade,0,1))
	var pop: float = sin(clampf(_clock/maxf(style.currency_pop_time,0.001),0,1)*PI)
	_icon.pivot_offset = _icon.size*0.5
	_icon.scale = Vector2.ONE*(1.0+(style.currency_pop_scale-1.0)*pop)
	if _clock>=appear+hold+fade: _hide_now()
## Kết thúc trả scale/alpha/process về đúng trạng thái, không còn tween hoặc timer ẩn.
func _hide_now() -> void:
	set_process(false)
	modulate.a = 0.0
	if is_instance_valid(_icon): _icon.scale = Vector2.ONE
	hide()
