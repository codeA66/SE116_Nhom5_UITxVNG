class_name FireToadState
extends State
## Lớp cơ sở cho state của Ếch Hoả Vương. Skill chạy theo trình tự có await (nhảy, chờ báo trước...): mỗi lần vào
## state tăng _run_id, sau mỗi await kiểm tra still_running() để state đã bị thay (boss chết...) không chạy tiếp.

var toad: FireToad

var _run_id: int = 0


func _ready() -> void:
	toad = owner as FireToad


func enter(_previous: StringName) -> void:
	_run_id += 1
	toad.velocity = Vector3.ZERO
	_run(_run_id)


func exit() -> void:
	_run_id += 1


func physics_update(_delta: float) -> void:
	# Boss tự di chuyển bằng tween (nhảy, bay): giữ vận tốc 0 để move_and_slide không kéo lệch
	toad.velocity = Vector3.ZERO


## Trình tự của state; lớp con ghi đè. run_id dùng để kiểm tra still_running sau mỗi await
func _run(_id: int) -> void:
	pass


func still_running(id: int) -> bool:
	return id == _run_id and is_instance_valid(toad) and toad.is_inside_tree()


func wait(seconds: float) -> void:
	if seconds > 0.0:
		await toad.get_tree().create_timer(seconds, false, true).timeout


func finish(id: int) -> void:
	if still_running(id):
		state_machine.transition_to(&"Idle")
