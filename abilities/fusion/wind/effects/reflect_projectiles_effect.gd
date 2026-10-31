class_name ReflectProjectilesEffect
extends FusionEffect
## Nhát chém đánh bật đạn của quái (quả cầu hồn...) như cú thổi gió: trong lúc hitbox bật, đạn nào nằm trong
## vùng trước mặt thì bị đẩy theo hướng chém, đạn tự đổi phe. Chỉ tác động vật có is_reflected() (đạn phản được),
## không đẩy đá / thuyền / quái. Vùng dò là Area3D tạm, tự xoá khi hết khoảng bật.

## Vùng dò trước mặt: rộng x cao x sâu (m), tâm cách người chém `forward` m
@export var area_size: Vector3 = Vector3(2.4, 1.6, 2.2)
@export var forward: float = 1.1
@export var height: float = 0.9
## Lực đẩy truyền cho đạn (chỉ cần khác 0 để đạn đổi hướng; đạn tự tính tốc độ bay ngược)
@export var push_speed: float = 12.0
## Lớp vùng nhận gió (đạn nhận cú đẩy qua WindReceiverComponent)
@export_flags_3d_physics var receiver_mask: int = 128


func on_melee_active(user: Player, _attack: AttackData, _index: int, _combo_size: int, direction: Vector3, active_time: float) -> void:
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = receiver_mask
	area.monitorable = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = area_size
	shape.shape = box
	area.add_child(shape)
	user.get_parent().add_child(area)
	area.global_transform = Transform3D(Basis.looking_at(direction, Vector3.UP), user.global_position + Vector3.UP * height + direction * forward)
	area.area_entered.connect(func(other: Area3D) -> void:
		var receiver := other as WindReceiverComponent
		if receiver and receiver.get_parent() and receiver.get_parent().has_method(&"is_reflected"):
			receiver.push(direction * push_speed))
	# Hết khoảng bật của nhát chém thì bỏ vùng dò (tối thiểu vài frame để kịp dò đạn đang nằm sẵn trong vùng)
	user.get_tree().create_timer(maxf(active_time, 0.08), false, true).timeout.connect(area.queue_free)
