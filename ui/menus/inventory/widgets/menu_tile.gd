class_name MenuTile
extends Control
## Ô chọn dùng chung của màn Tab (nguyên tố, vũ khí, vật phẩm, bùa). Lo phần chung: chọn bằng phím / tay cầm / chuột,
## khung góc hoa văn + phóng nhẹ khi đang chọn, phát signal khi bấm. Ô cụ thể chỉ vẽ nội dung và trả thông tin chi tiết.
## Thêm loại ô mới = lớp con mới, ghi đè _draw_content / get_detail.

## Bấm chọn (Enter / tay cầm A / chuột trái)
signal activated(tile: MenuTile)
## Bấm phụ (chuột phải): tháo nhanh...
signal alt_activated(tile: MenuTile)
signal focused(tile: MenuTile)

## Khung góc khi đang chọn: độ dài nét và khoảng lùi ra ngoài ô (px)
const BRACKET_LENGTH := 14.0
const BRACKET_OFFSET := 5.0

var style: InventoryStyle
## Ô đang được "cầm" (ví dụ nguyên tố chờ chọn vũ khí để ghép): vẽ sáng hơn
var held: bool = false:
	set(value):
		held = value
		queue_redraw()

var _focus_tween: Tween
var _fx_tween: Tween
## Độ phóng hiện tại khi vẽ. Phóng trong _draw thay vì đổi scale: Container đặt lại scale của ô con mỗi lần xếp
var _zoom: float = 1.0
## Độ lệch ngang khi rung (bị từ chối) và độ sáng lóe (vừa lên cấp / vừa đeo); vẽ trong _draw, không đổi position
var _shake: float = 0.0
var _flash: float = 0.0


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_entered.connect(_on_focus_changed.bind(true))
	focus_exited.connect(_on_focus_changed.bind(false))
	# Rê chuột lên ô = chọn ô: bàn phím và chuột dùng chung một con trỏ
	mouse_entered.connect(grab_focus)


func setup_style(menu_style: InventoryStyle) -> void:
	style = menu_style
	queue_redraw()


## Thông tin hiện ở bảng chi tiết khi ô được chọn
func get_detail() -> DetailEntry:
	return null


## Rung ngang tắt dần: báo thao tác bị từ chối (không đủ ô khắc, sai khu...)
func shake() -> void:
	if style == null:
		return
	_restart_fx()
	_fx_tween.tween_method(_set_shake, 1.0, 0.0, style.shake_time)


## Lóe sáng rồi tắt dần: báo vừa lên cấp / vừa đeo
func flash() -> void:
	if style == null:
		return
	_restart_fx()
	_fx_tween.tween_method(_set_flash, 1.0, 0.0, style.level_flash_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_accept"):
		activated.emit(self)
		accept_event()
		return
	# Phím tương tác = thao tác phụ của ô (như chuột phải), cho người chơi bàn phím / tay cầm
	if event.is_action_pressed(&"interact"):
		alt_activated.emit(self)
		accept_event()
		return
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_RIGHT:
		alt_activated.emit(self)
		accept_event()


func _draw() -> void:
	if style == null:
		return
	var rect := Rect2(Vector2.ZERO, size)
	var center := size * 0.5
	# Rung = sóng sin tắt dần theo _shake (1 -> 0)
	var offset := Vector2(sin(_shake * TAU * 3.0) * style.shake_strength * _shake, 0.0)
	draw_set_transform(center - center * _zoom + offset, 0.0, Vector2.ONE * _zoom)
	_draw_content(rect)
	if _flash > 0.0:
		draw_rect(rect.grow(2.0 + 6.0 * (1.0 - _flash)), Color(style.ink, 0.55 * _flash), false, 2.0, true)
		draw_rect(rect, Color(style.ink, 0.12 * _flash))
	if has_focus() or held:
		_draw_brackets(rect, style.ink if held else style.ornament)


## Lớp con vẽ nội dung ô ở đây
func _draw_content(_rect: Rect2) -> void:
	pass


## Khung 4 góc kiểu Hollow Knight / Hades: chỉ góc, không viền kín, có hạt kim cương nhỏ ở mỗi góc
func _draw_brackets(rect: Rect2, color: Color) -> void:
	var r := rect.grow(BRACKET_OFFSET)
	for corner: Vector2 in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		var horizontal := Vector2(-1.0 if corner.x > r.get_center().x else 1.0, 0.0) * BRACKET_LENGTH
		var vertical := Vector2(0.0, -1.0 if corner.y > r.get_center().y else 1.0) * BRACKET_LENGTH
		draw_polyline(PackedVector2Array([corner + horizontal, corner, corner + vertical]), color, 1.5, true)
		var d := 2.5
		draw_colored_polygon(PackedVector2Array([corner + Vector2(0, -d), corner + Vector2(d, 0), corner + Vector2(0, d), corner + Vector2(-d, 0)]), color)


## Vẽ chữ căn giữa theo điểm center (cỡ font_size)
func _draw_centered_text(text: String, center: Vector2, font_size: int, color: Color, max_width: float = -1.0) -> void:
	var font := get_theme_default_font()
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, max_width, font_size)
	var left := center.x - (text_size.x if max_width < 0.0 else max_width) * 0.5
	draw_string(font, Vector2(left, center.y + font.get_ascent(font_size) * 0.35), text, HORIZONTAL_ALIGNMENT_CENTER, max_width, font_size, color)


## Biểu tượng vừa khung; không có ảnh thì hình thoi + chữ cái đầu (chưa có hình vẽ tay)
func _draw_emblem(texture: Texture2D, center: Vector2, extent: float, color: Color, fallback: String) -> void:
	if texture:
		var box := Vector2.ONE * extent
		draw_texture_rect(texture, Rect2(center - box * 0.5, box), false, color)
		return
	var h := extent * 0.5
	draw_colored_polygon(PackedVector2Array([center + Vector2(0, -h), center + Vector2(h, 0), center + Vector2(0, h), center + Vector2(-h, 0)]), Color(color, 0.18))
	draw_polyline(PackedVector2Array([center + Vector2(0, -h), center + Vector2(h, 0), center + Vector2(0, h), center + Vector2(-h, 0), center + Vector2(0, -h)]), color, 1.5, true)
	_draw_centered_text(fallback.left(1).to_upper(), center, int(extent * 0.42), color)


func _on_focus_changed(is_focused: bool) -> void:
	if is_focused:
		focused.emit(self)
	if _focus_tween and _focus_tween.is_valid():
		_focus_tween.kill()
	var target := style.focus_scale if is_focused and style else 1.0
	_focus_tween = create_tween()
	_focus_tween.tween_method(_set_zoom, _zoom, target, style.focus_time if style else 0.1) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	queue_redraw()


func _set_zoom(value: float) -> void:
	_zoom = value
	queue_redraw()


func _restart_fx() -> void:
	if _fx_tween and _fx_tween.is_valid():
		_fx_tween.kill()
	_shake = 0.0
	_flash = 0.0
	_fx_tween = create_tween()


func _set_shake(value: float) -> void:
	_shake = value
	queue_redraw()


func _set_flash(value: float) -> void:
	_flash = value
	queue_redraw()
