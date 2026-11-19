class_name FireBossStrike
extends EnemySkillData
## Vùng trúng và nhịp đánh thứ hai cho các clip có nhiều lần tiếp xúc.

@export var hitbox_center: Vector3
@export var hitbox_size: Vector3 = Vector3.ONE
@export var second_hit: Vector2
@export var automatic: bool = true


func hit_window_at(time: float) -> Vector2:
	if time >= active_start and time < active_end:
		return Vector2(active_start, active_end)
	if time >= second_hit.x and time < second_hit.y:
		return second_hit
	return Vector2.ZERO


func update_hitbox(hitbox: HitboxComponent, time: float, speed: float) -> void:
	var bounds := hit_window_at(time)
	if bounds == Vector2.ZERO:
		if hitbox.is_active():
			hitbox.deactivate()
		return
	if hitbox.is_active():
		return
	var collision := hitbox.get_node("CollisionShape3D") as CollisionShape3D
	collision.position = hitbox_center
	(collision.shape as BoxShape3D).size = hitbox_size
	hitbox.activate(self, (bounds.y - bounds.x) / speed)
