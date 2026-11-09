class_name Gatekeeper
extends Npc
## Kẻ gác cổng: đứng cạnh hàng rào thu tiền. Trả rồi thì bước sang bên (StepAside) và hàng rào mở.
## Vào map mà cổng đã trả từ trước: đứng sẵn bên cạnh, hàng rào mở sẵn, không phát lại hoạt ảnh.

## Hàng rào của RIÊNG con này (nối bằng tham chiếu, nhiều cổng một map không đụng nhau)
@export var barrier: TollBarrier
## Hoạt ảnh lặp (clip từ .glb nhập vào mặc định không lặp)
@export var looping_animations: Array[StringName] = [&"Idle", &"Talk", &"IdleAside"]
## Quãng bước sang bên trong clip StepAside (hệ trục của NPC). Clip bước sang TRÁI của model = +X khi mặt hướng +Z:
## đặt kẻ gác cổng ở phía +X của rào để bước ra xa lối đi
@export var aside_offset: Vector3 = Vector3(1.5, 0.0, 0.0)
## Thời gian quay về hướng ban đầu trước khi bước (giây)
@export var face_reset_time: float = 0.2

var _passage_open: bool = false
var _toll: TollService
var _rest_yaw: float = 0.0

@onready var _shadow: Node3D = $Shadow


func _ready() -> void:
	super()
	_rest_yaw = visual.rotation.y
	_set_loops()
	for child in get_children():
		if child is TollService:
			_toll = child
	if barrier == null:
		push_warning("%s: kẻ gác cổng chưa nối hàng rào" % get_path())
	if _toll and _toll.is_paid():
		open_passage(false)
	else:
		play_animation(idle_animation)


## Mở lối: animated = bước sang bên rồi mới mở rào; false = đặt ngay trạng thái đã mở (nạp save)
func open_passage(animated: bool) -> void:
	if _passage_open:
		return
	_passage_open = true
	if _toll:
		idle_animation = _toll.data.idle_aside_animation
	var shadow_target := _shadow.position + aside_offset
	if animated and _toll:
		# Lúc nói chuyện đã quay theo cáo: quay về hướng gốc để bước đúng phía (ra xa lối đi)
		var turn := create_tween()
		turn.tween_property(visual, "rotation:y", _rest_yaw, maxf(face_reset_time, 0.01))
		await turn.finished
		# Rào nhấc lên cùng lúc kẻ gác cổng bước sang; bóng trượt theo chân
		if barrier:
			barrier.set_open(true, true)
		var step := _step_duration()
		create_tween().tween_property(_shadow, "position", shadow_target, step).set_trans(Tween.TRANS_SINE)
		await play_one_shot(_toll.data.step_aside_animation)
	else:
		visual.rotation.y = _rest_yaw
		_shadow.position = shadow_target
		if barrier:
			barrier.set_open(true, false)
	play_animation(idle_animation)


func is_passage_open() -> bool:
	return _passage_open


## Chạy một clip không lặp và chờ hết (hoặc trả ngay nếu clip không có)
func play_one_shot(animation: StringName) -> void:
	if animation_player == null or animation.is_empty() or not animation_player.has_animation(animation):
		return
	animation_player.play(animation)
	await animation_player.animation_finished


## Đã đứng sang bên: không quay theo cáo nữa (gốc model lệch khỏi tâm, quay sẽ văng vòng)
func turn_toward(point: Vector3, delta: float) -> bool:
	if _passage_open:
		return true
	return super(point, delta)


func _step_duration() -> float:
	var clip := _toll.data.step_aside_animation if _toll else &""
	if animation_player and animation_player.has_animation(clip):
		return animation_player.get_animation(clip).length
	return 0.01


func _set_loops() -> void:
	if animation_player == null:
		return
	for animation_name: StringName in looping_animations:
		if animation_player.has_animation(animation_name):
			animation_player.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR
