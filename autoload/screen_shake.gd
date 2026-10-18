extends Node
## Autoload "ScreenShake": giữ trauma (0..1) của rung màn hình. Ai muốn rung gọi add_trauma();
## CameraShake (con của Camera3D) đọc trauma để rung. Trauma tự giảm; về 0 thì tắt process.
## Rung theo thời gian thật nên vẫn mượt trong hitstop / slow motion.

## Phát khi có thêm trauma: CameraShake bật process lại
signal trauma_added(amount: float)

const MAX_TRAUMA := 1.0
## Chặn chia cho time_scale quá nhỏ
const MIN_REAL_DELTA_SCALE := 0.001

## Trauma giảm bao nhiêu mỗi giây
@export var decay: float = 1.6

var trauma: float = 0.0


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	# delta bị Engine.time_scale co lại; chia ngược để decay theo giây thật
	var real_delta := delta / maxf(Engine.time_scale, MIN_REAL_DELTA_SCALE)
	trauma = maxf(trauma - decay * real_delta, 0.0)
	if trauma <= 0.0:
		set_process(false)


## Cộng dồn nhưng kẹp ≤ 1 để nhiều đòn liên tiếp không rung quá tay
func add_trauma(amount: float) -> void:
	if amount <= 0.0:
		return
	trauma = minf(trauma + amount, MAX_TRAUMA)
	set_process(true)
	trauma_added.emit(amount)
