class_name IgniteOnImpactEffect
extends FusionEffect
## Cung Lửa: tên trúng đâu (quái, vật, tường, sàn) thì bùng một vùng lửa tròn quanh chỗ trúng, làm cháy thứ dễ cháy
## trong đó. Không đổi sát thương của tên. Vùng lửa lấy từ object pool.

## Scene vùng lửa (FireTouch) dùng pool
@export var touch_scene: PackedScene
## Bán kính vùng bùng lửa quanh chỗ trúng (m)
@export var radius: float = 1.0
## Thời gian vùng bật (s)
@export var duration: float = 0.15
@export_range(1, 16) var pool_size: int = 4
## Vệt lửa bám theo tên lúc bay (FireArrowTrail); để trống thì tên bay như thường
@export var flight_scene: PackedScene
@export_range(1, 16) var flight_pool_size: int = 4


## Tạo sẵn pool vùng lửa và vệt lửa cho player lúc vào khu (không instantiate giữa trận)
func prepare_for_combat(user: Player) -> void:
	if touch_scene:
		user.get_fusion_pool(self, touch_scene, pool_size)
	if flight_scene:
		user.get_fusion_pool(self, flight_scene, flight_pool_size)


## Vừa bắn tên: gắn vệt lửa bám theo tên
func on_projectile_fired(user: Player, projectile: Node3D) -> void:
	if flight_scene == null or not is_instance_valid(projectile):
		return
	var trail := user.get_fusion_pool(self, flight_scene, flight_pool_size).acquire() as FireArrowTrail
	trail.start(projectile)


## Tên vừa trúng: bùng lửa quanh chỗ trúng
func on_projectile_impact(user: Player, position: Vector3, _direction: Vector3) -> void:
	if touch_scene == null or not is_instance_valid(user):
		return
	var touch := user.get_fusion_pool(self, touch_scene, pool_size).acquire() as FireTouch
	touch.burst(position, radius, duration, user)
