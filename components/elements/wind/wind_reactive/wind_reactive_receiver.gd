class_name WindReactiveReceiver
extends WindReceiverComponent
## Vật trang trí chỉ nhận tín hiệu; không tích lũy vận tốc đẩy của vật động.

func push(impulse: Vector3) -> void:
	if enabled:
		pushed.emit(impulse)
