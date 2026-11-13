class_name LightOnImpactEffect
extends FusionEffect
## Cung Lửa: mũi tên cắm đâu để lại đốm lửa còn sáng một lúc ở đó (soi đường trong phòng tối: bắn thành dải đèn).
## Ghép thêm vào FusionData, không đổi các hiệu ứng khác. Đốm lửa lấy từ object pool của player.

## Scene đốm lửa (EmberLight)
@export var ember_scene: PackedScene
## Sáng bao lâu (s), trong đó fade_time cuối là tắt dần
@export_range(0.1, 120.0, 0.1) var life: float = 15.0
@export_range(0.0, 30.0, 0.1) var fade_time: float = 3.0
@export var light_energy: float = 2.5
@export var light_range: float = 5.0
## Số đốm tạo sẵn; bắn nhiều hơn thì pool tạo thêm
@export_range(1, 32) var pool_size: int = 8


func prepare_for_combat(user: Player) -> void:
	if ember_scene:
		user.get_fusion_pool(self, ember_scene, pool_size)


func on_projectile_impact(user: Player, position: Vector3, _direction: Vector3) -> void:
	if ember_scene == null or not is_instance_valid(user):
		return
	var ember := user.get_fusion_pool(self, ember_scene, pool_size).acquire() as EmberLight
	ember.play(position, life, fade_time, light_energy, light_range)
