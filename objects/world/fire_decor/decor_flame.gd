class_name DecorFlame
extends Node3D
## Vật lửa trang trí (đuốc đứng, hố lửa, cột lửa): model + hệ lửa FlameFeedback + đèn, cháy sẵn từ đầu.
## Thêm loại vật lửa mới = tạo scene mới (model + FlameFeedback + Light + Notifier) gắn script này, không sửa code.
## Hiệu năng: không có việc gì mỗi frame ngoài chập chờn của FlameFeedback; chập chờn tắt khi vùng ảnh hưởng
## của đèn nằm ngoài màn hình (signal của Notifier), đèn mờ dần khi ở xa.

## Năng lượng đèn lúc cháy bình thường (FlameFeedback chập chờn quanh mức này)
@export_range(0.0, 8.0, 0.05) var light_energy: float = 2.0
@export_group("Ở xa")
## Từ khoảng cách này (m) đèn bắt đầu mờ đi
@export_range(5.0, 200.0, 1.0) var fade_begin: float = 30.0
## Đèn tắt hẳn sau thêm bấy nhiêu m
@export_range(1.0, 100.0, 1.0) var fade_length: float = 10.0

# Ngọn lửa là node con tên bắt đầu bằng "Flame" trong model (glTF có thể thêm hậu tố)
@onready var _flame: Node3D = $Model.find_child("Flame*", true, false) as Node3D
@onready var _light: OmniLight3D = $Light
@onready var _feedback: FlameFeedback = $FlameFeedback
@onready var _notifier: VisibleOnScreenNotifier3D = $Notifier


func _ready() -> void:
	_light.distance_fade_enabled = true
	_light.distance_fade_begin = fade_begin
	_light.distance_fade_length = fade_length
	_feedback.setup(_flame, _light, light_energy)
	_feedback.start_quiet()
	# Đèn ảnh hưởng tới vật ngoài khung hình thì vẫn phải chập chờn; chỉ tắt khi cả vùng sáng đã ra khỏi màn hình
	_notifier.screen_entered.connect(_set_flicker.bind(true))
	_notifier.screen_exited.connect(_set_flicker.bind(false))


func _set_flicker(on: bool) -> void:
	_feedback.set_process(on)
