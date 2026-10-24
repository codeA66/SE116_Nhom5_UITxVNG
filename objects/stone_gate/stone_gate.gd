@tool
class_name StoneGate
extends StaticBody3D
## Cổng đá: chìm xuống đất khi TẤT CẢ nguồn kích hoạt gán ở ô Sources đã bật.
## Nguồn là node bất kỳ có signal "activated" và hàm is_active() (ổ đá, sau này thêm loại khác không sửa file này).
## Chỉ nghe đúng các nguồn được gán, nên map có nhiều cổng không ảnh hưởng nhau.
## Mở một lần rồi giữ nguyên; có persistent_id thì nhớ qua lần chơi sau.

signal opened
## Vừa đủ nguồn, đang chờ wait_source báo mới chìm (camera cắt cảnh nghe signal này để bay tới)
signal unlock_started

@export var sources: Array[Node] = []:
	set(value):
		sources = value
		update_configuration_warnings()
## Cờ lưu trạng thái đã mở. Để trống = mỗi lần vào khu cổng lại đóng
@export var persistent_id: StringName
@export_range(0.1, 5.0, 0.05) var open_time: float = 1.2
## Cổng chìm xuống bấy nhiêu mét (thường bằng chiều cao cổng)
@export var sink_depth: float = 3.2
@export_range(0.0, 1.0) var open_trauma: float = 0.2

@export_group("Wait")
## Đủ nguồn thì chờ signal wait_signal (không tham số) của node này rồi mới chìm, ví dụ camera cắt cảnh đã tới khung hình.
## Để trống = chìm ngay
@export var wait_source: Node
@export var wait_signal: StringName = &"shot_reached"
## Quá thời gian này (giây) mà chưa có tín hiệu thì vẫn chìm: không để cổng kẹt vĩnh viễn
@export_range(0.5, 10.0, 0.1) var wait_timeout: float = 3.0

@export_group("Feedback")
## Đèn bừng sáng lúc bắt đầu chìm rồi tắt dần theo cổng: người chơi biết chính cổng này vừa được mở. Để trống = bỏ qua
@export var flash_light: Light3D
@export var flash_energy: float = 6.0
## Bụi phụt ở chân cổng lúc chìm (one shot). Để trống = bỏ qua
@export var dust: GPUParticles3D
## Tiếng đá ầm khi chìm; chưa gán stream thì im lặng
@export var open_sound: AudioStreamPlayer3D

var is_open: bool = false
var _sinking: bool = false

@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var _visual: Node3D = $Visual


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if not persistent_id.is_empty() and GameState.has_flag(persistent_id):
		_finish_open(true)
		return
	for source in sources:
		if source == null or not source.has_signal(&"activated") or not source.has_method(&"is_active"):
			push_error("%s: nguồn %s không có signal activated / hàm is_active()" % [get_path(), source])
			continue
		source.connect(&"activated", _refresh)
	_refresh()


func _get_configuration_warnings() -> PackedStringArray:
	if sources.is_empty():
		return ["Chưa gán nguồn ở ô Sources: cổng sẽ không bao giờ mở."]
	return []


func _refresh() -> void:
	if is_open or sources.is_empty():
		return
	for source in sources:
		if source == null or not source.call(&"is_active"):
			return
	is_open = true
	if not persistent_id.is_empty():
		GameState.set_flag(persistent_id)
	if wait_source == null or not wait_source.has_signal(wait_signal):
		_sink()
		return
	wait_source.connect(wait_signal, _sink, CONNECT_ONE_SHOT)
	get_tree().create_timer(wait_timeout).timeout.connect(_sink)
	unlock_started.emit()


## Chìm đúng một lần dù tín hiệu chờ và hết giờ cùng gọi
func _sink() -> void:
	if _sinking:
		return
	_sinking = true
	if open_trauma > 0.0:
		ScreenShake.add_trauma(open_trauma)
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(_visual, "position:y", _visual.position.y - sink_depth, open_time)
	tween.finished.connect(_finish_open.bind(false))
	if flash_light:
		var flash := create_tween()
		flash.tween_property(flash_light, "light_energy", flash_energy, 0.15)
		flash.tween_property(flash_light, "light_energy", 0.0, open_time)
	if dust:
		dust.restart()
	if open_sound and open_sound.stream:
		open_sound.play()
	# Mở lối ngay khi bắt đầu chìm: không bắt người chơi đứng chờ hết animation
	_collision.set_deferred(&"disabled", true)
	opened.emit()


func _finish_open(instant: bool) -> void:
	is_open = true
	_collision.set_deferred(&"disabled", true)
	if instant:
		_visual.position.y -= sink_depth
	_visual.visible = false
