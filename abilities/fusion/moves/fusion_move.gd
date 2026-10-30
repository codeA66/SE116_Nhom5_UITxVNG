class_name FusionMove
extends Node3D
## Gốc của các vật mà buff nguyên tố tạo ra trong thế giới (lưỡi liềm gió, hố hút...).
## FusionEffect tạo scene rồi gọi perform(); vật tự dọn mình khi xong.


## user: người gây ra (để bỏ qua chính mình); attack: sát thương / đẩy lùi (có thể null nếu vật không gây sát thương);
## direction: hướng ngang đã chuẩn hóa
func perform(_user: Character, _attack: AttackData, _direction: Vector3) -> void:
	queue_free()
