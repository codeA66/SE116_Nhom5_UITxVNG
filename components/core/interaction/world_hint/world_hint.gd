class_name WorldHint
extends Area3D
## Dòng gợi ý nổi trong thế giới (không phải nút F): player vào vùng thì hiện, ra thì ẩn.
## Chủ vật thể gán visible_check để chỉ hiện khi hợp ngữ cảnh (ví dụ lửa trại chưa cháy),
## và gọi flash() để hiện một câu tạm thời sau một hành động (ví dụ vừa lấy gậy).
## Thêm gợi ý cho vật mới = gắn node này vào scene, không sửa code.
## Hiệu năng: chỉ nghe body_entered/exited, không có _process; Label3D tạo một lần.

## Câu hiện khi player ở gần
@export_multiline var text: String = ""
## Vị trí chữ so với node
@export var label_offset: Vector3 = Vector3(0, 2.0, 0)
@export_group("Hiển thị")
@export var font_size: int = 40
@export var outline_size: int = 10
@export var text_color: Color = Color(1.0, 0.86, 0.62, 1.0)
@export var outline_color: Color = Color(0.08, 0.03, 0.02, 1.0)
@export_range(0.001, 0.05, 0.001) var pixel_size: float = 0.012
@export_range(0.0, 2.0, 0.01) var fade_time: float = 0.2

## Điều kiện thêm để hiện câu text (rỗng = luôn hiện khi player ở gần)
var visible_check: Callable
## Chữ theo người đang đứng trong vùng: func(actor: Node3D) -> String; trả "" thì ẩn. Có thì dùng thay cho text
var text_provider: Callable

var _player_inside: bool = false
var _actor: Node3D
var _tween: Tween
var _flash_timer: Timer

@onready var _label: Label3D = _make_label()


func _ready() -> void:
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_flash_timer = Timer.new()
	_flash_timer.one_shot = true
	_flash_timer.timeout.connect(refresh)
	add_child(_flash_timer)


## Hiện câu tạm thời trong duration giây, xong thì quay về trạng thái theo vùng/điều kiện
func flash(message: String, duration: float) -> void:
	_label.text = message
	_flash_timer.start(duration)
	_fade_to(1.0)


## Bỏ câu flash đang hiện (vd. bước gợi ý đã làm xong) và quay về trạng thái theo vùng
func cancel_flash() -> void:
	_flash_timer.stop()
	refresh()


## Gọi khi điều kiện visible_check có thể đã đổi (ví dụ lửa vừa cháy)
func refresh() -> void:
	# Đang hiện câu flash thì giữ nguyên tới khi timer hết
	if not _flash_timer.is_stopped():
		return
	var message: String = text
	if text_provider.is_valid():
		message = String(text_provider.call(_actor)) if _player_inside and is_instance_valid(_actor) else ""
	var should_show: bool = _player_inside and not message.is_empty() \
			and (not visible_check.is_valid() or bool(visible_check.call()))
	if should_show:
		_label.text = message
	_fade_to(1.0 if should_show else 0.0)


func _make_label() -> Label3D:
	var label: Label3D = Label3D.new()
	label.position = label_offset
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = font_size
	label.outline_size = outline_size
	label.modulate = Color(text_color, 0.0)
	label.outline_modulate = Color(outline_color, 0.0)
	label.pixel_size = pixel_size
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	label.visible = false
	add_child(label)
	return label


func _fade_to(alpha: float) -> void:
	if _tween:
		_tween.kill()
	if alpha > 0.0:
		_label.visible = true
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_label, ^"modulate:a", alpha, fade_time)
	_tween.tween_property(_label, ^"outline_modulate:a", alpha, fade_time)
	if alpha <= 0.0:
		_tween.chain().tween_callback(_label.hide)


func _on_body_entered(body: Node3D) -> void:
	_player_inside = true
	_actor = body
	refresh()


func _on_body_exited(_body: Node3D) -> void:
	_player_inside = false
	_actor = null
	refresh()
