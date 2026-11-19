extends WindReceiverComponent
## Mép luồng gió chỉ hất nhẹ lông vàng; lông trắng chạm luồng sẽ mất sát thương.

func push(impulse: Vector3) -> void:
	if enabled:
		(get_parent() as PyralonFeather).on_blast(impulse)


func push_from_blast(impulse: Vector3, origin: Vector3, half_width: float) -> void:
	if not enabled:
		return
	var forward := impulse.normalized()
	var lateral := (global_position - origin).slide(Vector3.UP).slide(forward)
	var edge := smoothstep(0.22, 1.0, lateral.length() / maxf(half_width, 0.05))
	var direction := (forward + lateral.normalized() * edge * 0.9).normalized()
	push(direction * impulse.length() * lerpf(1.0, 0.32, edge))
