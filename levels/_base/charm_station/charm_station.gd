class_name CharmStation
extends Area3D
## Khu đổi bùa: player đứng trong vùng này mới được đeo / tháo bùa ở màn Tab.
## Kéo scene vào khu, chỉnh hình vùng (Shape). Nhiều khu đổi bùa trong một map vẫn đếm đúng.
## Chạy theo signal vào / ra, không kiểm tra mỗi frame.

var _inside: bool = false


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _exit_tree() -> void:
	# Khu bị gỡ (đổi scene) khi player còn đứng trong: trả lại bộ đếm để không kẹt quyền đổi bùa
	if _inside:
		_inside = false
		GameState.exit_charm_station()


func _on_body_entered(body: Node3D) -> void:
	if body is Player and not _inside:
		_inside = true
		GameState.enter_charm_station()


func _on_body_exited(body: Node3D) -> void:
	if body is Player and _inside:
		_inside = false
		GameState.exit_charm_station()
