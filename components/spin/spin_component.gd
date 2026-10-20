class_name SpinComponent
extends VisibleOnScreenNotifier3D
## Quay node cha quanh một trục cục bộ (cánh quạt, chong chóng...).
## Chỉ xử lý khi đang hiện trên màn hình: ra khỏi màn hình thì tắt _process.
## Bật Stutter cho máy hỏng: quay chậm, thỉnh thoảng khựng lại như bị kẹt.

## Trục quay trong toạ độ cục bộ của node cha
@export var axis: Vector3 = Vector3.FORWARD
## Tốc độ quay (độ/giây); âm = quay ngược
@export var speed_degrees: float = 45.0

@export_group("Stutter")
@export var stutter: bool = false
## Chu kỳ một nhịp quay rồi khựng (s)
@export_range(0.2, 10.0, 0.05) var stutter_period: float = 2.4
## Tỉ lệ thời gian bị khựng trong mỗi chu kỳ
@export_range(0.0, 0.95, 0.01) var stutter_hold_ratio: float = 0.45

var _target: Node3D
var _axis_normalized: Vector3
var _time: float = 0.0


func _ready() -> void:
	_target = get_parent() as Node3D
	if _target == null or axis.is_zero_approx():
		push_warning("%s: cần node cha là Node3D và trục khác 0" % get_path())
		set_process(false)
		return
	_axis_normalized = axis.normalized()
	# Signal thay cho kiểm tra mỗi frame: chỉ quay khi người chơi nhìn thấy
	screen_entered.connect(set_process.bind(true))
	screen_exited.connect(set_process.bind(false))
	set_process(is_on_screen())


func _process(delta: float) -> void:
	_time += delta
	var factor := 1.0
	if stutter:
		var cycle := fmod(_time, stutter_period) / stutter_period
		# Khựng ở cuối chu kỳ, quay bù nhanh hơn ở phần còn lại để tốc độ trung bình giữ nguyên
		factor = 0.0 if cycle > 1.0 - stutter_hold_ratio else 1.0 / maxf(1.0 - stutter_hold_ratio, 0.05)
	_target.rotate_object_local(_axis_normalized, deg_to_rad(speed_degrees) * factor * delta)
