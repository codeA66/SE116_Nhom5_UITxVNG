class_name IgniteOnLastHitEffect
extends FusionEffect
## Kiếm Lửa: chỉ nhát CUỐI combo đặt một vùng lửa trước mặt theo hướng chém, làm cháy thứ dễ cháy trong đó.
## Các nhát trước chém thường. Không đổi sát thương (sát thương vẫn do hitbox của kiếm). Vùng lửa lấy từ object pool.

## Scene vùng lửa (FireTouch) dùng pool
@export var touch_scene: PackedScene
## Vùng lửa trước mặt: rộng x cao x sâu (m), tâm cách người chém `forward` m, cao `height` m
@export var area_size: Vector3 = Vector3(2.4, 1.6, 2.2)
@export var forward: float = 1.1
@export var height: float = 0.9
## Thời gian bật tối thiểu (s); nhát chém có khoảng bật ngắn hơn thì vẫn giữ chừng này để kịp dò
@export var min_time: float = 0.1
@export_range(1, 8) var pool_size: int = 2


## Tạo sẵn pool vùng lửa cho player lúc vào khu (không instantiate giữa trận)
func prepare_for_combat(user: Player) -> void:
	if touch_scene:
		user.get_fusion_pool(self, touch_scene, pool_size)


## Nhát chém vừa bật: chỉ nhát cuối combo mới đặt vùng lửa theo hướng chém
func on_melee_active(user: Player, _attack: AttackData, combo_index: int, combo_size: int, direction: Vector3, active_time: float) -> void:
	if touch_scene == null or combo_index < combo_size - 1:
		return
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.is_zero_approx():
		flat = user.get_facing_direction()
	flat = flat.normalized()
	var origin := user.global_position + Vector3.UP * height + flat * forward
	var touch := user.get_fusion_pool(self, touch_scene, pool_size).acquire() as FireTouch
	touch.sweep(Transform3D(Basis.looking_at(flat, Vector3.UP), origin), area_size, maxf(active_time, min_time), user)
