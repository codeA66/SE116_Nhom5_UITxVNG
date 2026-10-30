class_name SquashStretchComponent
extends Node
## Co giãn phần hình của nhân vật cho có lực và trọng lượng: kéo dài khi bật lên khỏi đất
## (nhảy, bị cột gió nâng), co dẹt khi tiếp đất, rơi càng nhanh co càng nhiều.
## Chỉ co giãn target (phần hình), không đụng hitbox / vùng va chạm nên không ảnh hưởng gameplay.
## Tự theo dõi body, không cần nhân vật gọi; gắn vào quái, boss là dùng được ngay.

@export var body: CharacterBody3D
## Node chỉ chứa hình (ví dụ Model/FoxRig), gốc ở chân để co giãn quanh mặt đất
@export var target: Node3D

@export_group("Stretch")
## Chiều cao khi bật lên (bề ngang tự co lại để giữ thể tích)
@export var stretch_scale: float = 1.2
@export var stretch_time: float = 0.12
## Rời đất với vận tốc đi lên ít nhất bấy nhiêu (m/s) mới tính là bật lên; bước hụt mép không kéo dài
@export var min_launch_speed: float = 1.0

@export_group("Squash")
## Chiều cao khi tiếp đất nhẹ / mạnh nhất
@export var light_squash_scale: float = 0.85
@export var hard_squash_scale: float = 0.7
## Vận tốc rơi (m/s): dưới ngưỡng đầu không co, từ ngưỡng sau trở lên co mạnh nhất
@export var min_impact_speed: float = 3.0
@export var hard_impact_speed: float = 15.0
@export var squash_time: float = 0.05
## Thời gian nảy về hình dạng bình thường
@export var recover_time: float = 0.15

var _was_on_floor: bool = true
var _previous_vertical_speed: float = 0.0
var _base_scale: Vector3 = Vector3.ONE
var _tween: Tween


func _ready() -> void:
	if body == null:
		body = owner as CharacterBody3D
	if body == null or target == null:
		push_error("%s cần body (CharacterBody3D) và target (phần hình)" % get_path())
		set_physics_process(false)
		return
	_base_scale = target.scale
	_was_on_floor = body.is_on_floor()


## Chạy sau move_and_slide của body (node con xử lý sau node cha): trạng thái chạm đất đã cập nhật
func _physics_process(_delta: float) -> void:
	var on_floor := body.is_on_floor()
	if _was_on_floor and not on_floor and body.velocity.y >= min_launch_speed:
		stretch()
	elif not _was_on_floor and on_floor and -_previous_vertical_speed >= min_impact_speed:
		squash(-_previous_vertical_speed)
	_was_on_floor = on_floor
	_previous_vertical_speed = body.velocity.y


func stretch() -> void:
	_start_tween()
	_tween.tween_property(target, "scale", _shape(stretch_scale), stretch_time * 0.35)
	_tween.tween_property(target, "scale", _base_scale, stretch_time * 0.65)


## impact_speed: vận tốc rơi lúc chạm đất (m/s)
func squash(impact_speed: float) -> void:
	var t := clampf(inverse_lerp(min_impact_speed, hard_impact_speed, impact_speed), 0.0, 1.0)
	var height := lerpf(light_squash_scale, hard_squash_scale, t)
	_start_tween()
	_tween.tween_property(target, "scale", _shape(height), squash_time)
	# Nảy nhẹ quá mức rồi về bình thường, như vật đàn hồi
	_tween.tween_property(target, "scale", _base_scale, recover_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _start_tween() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()


## Giữ thể tích: cao h lần thì bề ngang 1/sqrt(h) lần
func _shape(height: float) -> Vector3:
	var width := 1.0 / sqrt(maxf(height, 0.01))
	return Vector3(_base_scale.x * width, _base_scale.y * height, _base_scale.z * width)
