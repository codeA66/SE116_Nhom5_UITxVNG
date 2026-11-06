class_name AbilityAcquireSlotFx
extends Control
## Một slot glow dùng lại; chỉ vẽ khi icon thực sự tới HUD.
signal finished
const Tuning = preload("res://resources/feedback/ability_acquire/ability_acquire_data.gd")
@export var data: Tuning = preload("res://resources/feedback/ability_acquire/ability_acquire_default.tres")
var _age: float = 0.0
var _center: Vector2
var _accent: Color
var _panel_mode: bool = false
## Idle không giữ vòng vẽ hoặc process.
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stop()
## Tái dùng cùng một Control để nhiều lần nhận không sinh node glow mới.
func play_at(center: Vector2, accent: Color) -> void:
	_panel_mode = false
	_center = center
	_accent = accent
	_age = 0.0
	show()
	set_process(true)
	queue_redraw()
## Panel dùng cùng slot hình nhưng chạy nhẹ quanh minh họa, không sinh hạt UI riêng.
func play_panel(center: Vector2, accent: Color) -> void:
	play_at(center,accent)
	_panel_mode = true
## Thời gian thực giữ nhịp HUD ổn định trong hitstop.
func _process(delta: float) -> void:
	_age += delta / maxf(Engine.time_scale, data.minimum_time)
	if _panel_mode:
		queue_redraw()
		return
	if _age >= maxf(data.slot_time, data.minimum_time):
		stop()
		finished.emit()
	else: queue_redraw()
## Tắt hẳn thay vì giữ alpha bằng không.
func stop() -> void:
	hide()
	set_process(false)
## Vòng thoi đồng bộ hình ô kỹ năng, không truy cập mesh hay biến riêng của HUD.
func _draw() -> void:
	if _panel_mode:
		for index: int in range(clampi(data.panel_motes,0,24)):
			var angle: float = float(index)*2.399963 + _age*data.panel_mote_speed
			var mote_position: Vector2 = _center + Vector2(cos(angle),sin(angle))*data.panel_mote_radius
			var mote_tint: Color = _accent
			mote_tint.a = 0.25 + 0.25*sin(angle+_age)
			draw_circle(mote_position,data.panel_mote_size,mote_tint)
		return
	var progress: float = clampf(_age / maxf(data.slot_time, data.minimum_time), 0.0, 1.0)
	var radius: float = data.pulse_radius * (1.0 + progress * 0.35)
	var tint: Color = _accent
	tint.a = 1.0 - progress
	var top: Vector2 = _center + Vector2.UP * radius
	var right: Vector2 = _center + Vector2.RIGHT * radius
	var bottom: Vector2 = _center + Vector2.DOWN * radius
	var left: Vector2 = _center + Vector2.LEFT * radius
	draw_line(top, right, tint, 2.0, true)
	draw_line(right, bottom, tint, 2.0, true)
	draw_line(bottom, left, tint, 2.0, true)
	draw_line(left, top, tint, 2.0, true)
