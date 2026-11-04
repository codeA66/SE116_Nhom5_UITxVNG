class_name BananaWindReceiver
extends WindReceiverComponent
## Chỉ cú thổi E phản đạn; gió nền không tự đổi hướng quả chuối.
func push(impulse: Vector3) -> void:
	if enabled:
		(get_parent() as EnemyProjectile).reflect(impulse)
