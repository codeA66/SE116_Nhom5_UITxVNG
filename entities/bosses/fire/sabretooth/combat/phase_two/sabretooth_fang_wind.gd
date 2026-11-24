class_name SabretoothFangWind
extends WindReceiverComponent
## Bộ nhận gió cho projectile Blazing Fang Snap:
## Khi player dùng chiêu E gió thổi trúng, đẩy lùi đầu hổ lửa ra một đoạn xa mà không xóa nó (nếu bị đẩy đập tường mới nổ).

var combat: SabretoothP2Combat
var slot_index: int = 0


func push(impulse: Vector3) -> void:
	if enabled and combat:
		combat.apply_fang_wind(slot_index, impulse)


func push_from_blast(impulse: Vector3, _origin: Vector3, _half_width: float) -> void:
	if enabled and combat:
		combat.apply_fang_wind(slot_index, impulse)


func steer_push(target: Vector3, _rate: float, _delta: float) -> void:
	if enabled and combat:
		combat.apply_fang_wind(slot_index, target)
