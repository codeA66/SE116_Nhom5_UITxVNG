class_name FusionEffect
extends Resource
## Một hiệu ứng buff mà nguyên tố ghép thêm vào đòn thường của vũ khí. Player gọi các hàm dưới đây
## đúng lúc; hiệu ứng nào chỉ cần một vài thời điểm thì chỉ ghi đè hàm đó.
## Thêm buff mới (Lửa cháy, Nước làm chậm...) = thêm script kế thừa + file .tres, không sửa code cũ.

@export var warmup_scenes: Array[PackedScene] = []


func _init() -> void:
	# Owner khởi tạo trước GameState để Resource nạp sẵn không phải giữ registry static.
	SharedResources.register_weak(&"fusion.effects", self)


static func _registered_effects() -> Array[Resource]:
	return SharedResources.get_registered(&"fusion.effects")


static func prepare_loaded_effects(user: Player) -> void:
	for effect in _registered_effects():
		effect.call(&"prepare_for_combat", user)


static func collect_shader_warmup_sources() -> Array[Node]:
	var sources: Array[Node] = []
	for effect in _registered_effects():
		sources.append_array(effect.call(&"get_shader_warmup_sources"))
	return sources


## Chuẩn bị riêng cho từng player/khu; không lưu Node sống trong Resource dùng chung.
func prepare_for_combat(_user: Player) -> void:
	pass


## Hitbox của một nhát cận chiến vừa bật. combo_index đếm từ 0; direction là hướng ngang của nhát
func on_melee_active(_user: Player, _attack: AttackData, _combo_index: int, _combo_size: int, _direction: Vector3, _active_time: float) -> void:
	pass


## Vũ khí vừa tạo đạn; hiệu ứng hình ảnh có thể bám đạn mà không sửa lớp đạn.
func on_projectile_fired(_user: Player, _projectile: Node3D) -> void:
	pass


## Hình học/material sinh động: hệ warmup có sẵn sẽ vẽ trước lúc mở màn.
func get_shader_warmup_sources() -> Array[Node]:
	var sources: Array[Node] = []
	for scene in warmup_scenes:
		if scene:
			sources.append(scene.instantiate())
	return sources


## Đạn của vũ khí vừa trúng mục tiêu.
func on_projectile_impact(_user: Player, _position: Vector3, _direction: Vector3) -> void:
	pass
