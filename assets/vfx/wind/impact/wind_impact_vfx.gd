class_name WindImpactVfx
extends WindBurstVfx
## Bụi gió tại vật bị thổi trúng. Là một WindBurstVfx dùng style nhỏ, do WindImpactPool quản lý.


## Đặt tại vị trí vật, quay theo hướng bị đẩy rồi phát
func play_at(world_position: Vector3, direction: Vector3) -> void:
	global_position = world_position
	var flat := Vector3(direction.x, 0.0, direction.z)
	if not flat.is_zero_approx():
		global_basis = Basis.looking_at(-flat.normalized(), Vector3.UP)
	play(false)
