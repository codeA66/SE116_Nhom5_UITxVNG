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

# Rung theo vị trí trong cùng một frame không cộng dồn (nhiều búa đập cùng lúc chỉ tính mức mạnh nhất)
var _positional_frame: int = -1
var _positional_added: float = 0.0


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


## Rung do một nguồn có vị trí (búa, nổ, thủy triều...): trong full_radius (m, mặt phẳng XZ) thì rung đủ amount,
## xa dần yếu dần, ngoài max_radius thì không rung, nên vật ở phòng khác / ngoài màn hình không làm rung khi đứng yên.
## Khoảng cách đo tới điểm camera đang nhìn trên mặt sàn ngang với nguồn.
func add_trauma_at(amount: float, world_pos: Vector3, full_radius: float, max_radius: float) -> void:
	if amount <= 0.0:
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	var focus: Vector3 = _camera_focus(camera, world_pos.y)
	var dist: float = Vector2(world_pos.x - focus.x, world_pos.z - focus.z).length()
	var scaled: float = amount
	if dist > full_radius:
		var span: float = maxf(max_radius - full_radius, 0.001)
		scaled = amount * clampf(1.0 - (dist - full_radius) / span, 0.0, 1.0)
	var frame: int = Engine.get_process_frames()
	if frame != _positional_frame:
		_positional_frame = frame
		_positional_added = 0.0
	var extra: float = scaled - _positional_added
	if extra <= 0.0:
		return
	_positional_added = scaled
	add_trauma(extra)


## Giao điểm tia nhìn giữa camera với mặt phẳng ngang y = height (camera nhìn chéo xuống nên luôn cắt)
func _camera_focus(camera: Camera3D, height: float) -> Vector3:
	var origin: Vector3 = camera.global_position
	var forward: Vector3 = -camera.global_basis.z
	if absf(forward.y) < 0.01:
		return origin
	var t: float = (height - origin.y) / forward.y
	return origin + forward * maxf(t, 0.0)
