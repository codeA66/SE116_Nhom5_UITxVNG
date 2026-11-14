extends Node
## Autoload "HitStop": dừng hình ngắn khi trúng đòn.
## Dùng Engine.time_scale nên tác động toàn game. Cutscene có ưu tiên hơn hitstop ngắn.

@export var slow_time_scale: float = 0.05

var _request_id: int = 0
var _cinematic: Node


func stop(duration: float) -> void:
	if duration <= 0.0 or is_instance_valid(_cinematic):
		return
	_request_id += 1
	var request := _request_id
	Engine.time_scale = slow_time_scale
	# ignore_time_scale = true: timer chạy theo thời gian thật, không bị chính hitstop làm chậm
	await get_tree().create_timer(duration, true, false, true).timeout
	if request == _request_id:
		Engine.time_scale = 1.0


## Làm chậm thời gian có chủ đích (cảnh thắng trận...). Dùng chung request_id với stop():
## lần gọi sau ghi đè lần trước, hết giờ thì trả time_scale về 1
func slow_motion(duration: float, time_scale: float) -> void:
	if duration <= 0.0 or is_instance_valid(_cinematic):
		return
	_request_id += 1
	var request := _request_id
	Engine.time_scale = time_scale
	await get_tree().create_timer(duration, true, false, true).timeout
	if request == _request_id:
		Engine.time_scale = 1.0


func begin_cinematic(cinematic: Node, time_scale: float) -> void:
	_request_id += 1
	_cinematic = cinematic
	Engine.time_scale = time_scale
	cinematic.tree_exiting.connect(end_cinematic.bind(cinematic), CONNECT_ONE_SHOT)


func end_cinematic(cinematic: Node) -> void:
	if _cinematic != cinematic:
		return
	_cinematic = null
	Engine.time_scale = 1.0
