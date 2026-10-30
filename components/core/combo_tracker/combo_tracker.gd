class_name ComboTracker
extends Node
## Nhớ nhát tiếp theo của combo sau khi đòn kết thúc (hết đòn hoặc bị hủy để chạy / dash).
## Bấm chém lại trong reset_time thì ra nhát kế, quá hạn thì về nhát đầu.
## Chỉ đếm giờ trong lúc chờ, còn lại tắt physics process.

## Thời gian nhớ combo sau khi rời đòn (s)
@export var reset_time: float = 0.3

var _next_index: int = 0
var _time_left: float = 0.0


func _ready() -> void:
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	_time_left -= delta
	if _time_left <= 0.0:
		reset()


## Nhát sẽ ra khi bắt đầu chém. Combo ngắn hơn chỉ số đang nhớ (vừa đổi vũ khí) thì về nhát đầu
func peek_index(combo_size: int) -> int:
	return _next_index if _next_index < combo_size else 0


## Gọi khi một nhát bắt đầu: nhớ nhát kế, nhát cuối thì vòng về đầu
func mark_started(index: int, combo_size: int) -> void:
	set_physics_process(false)
	_next_index = index + 1 if index + 1 < combo_size else 0


## Gọi khi rời đòn: bắt đầu đếm thời gian nhớ
func start_grace() -> void:
	if _next_index == 0:
		return
	_time_left = reset_time
	set_physics_process(true)


func reset() -> void:
	_next_index = 0
	set_physics_process(false)
