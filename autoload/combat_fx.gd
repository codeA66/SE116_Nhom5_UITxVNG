extends Node
## Autoload "CombatFx": phát hiệu ứng chiến đấu dùng chung (trúng đòn, máu, quái chết) từ ObjectPool,
## nên bắn liên tục không instantiate() / queue_free() mỗi lần. Hiệu ứng tự nhả về pool khi xong.
## Vết máu trên sàn dùng một BloodStains số lượng cố định (vết cũ nhất bị tái dùng).

@export_group("Hit Spark")
@export var hit_spark_scene: PackedScene = preload("res://assets/vfx/combat/hit_spark.tscn")
@export var hit_spark_pool_size: int = 6
## Trần số hiệu ứng chạy cùng lúc; vượt thì tái dùng cái cũ nhất. Giữ chi phí GPU (vẽ chồng cộng sáng) có giới hạn khi đánh đông quái
@export var max_active_hits: int = 6

@export_group("Death Burst")
@export var death_burst_scene: PackedScene = preload("res://assets/vfx/combat/death_burst.tscn")
@export var death_burst_pool_size: int = 3
@export var max_active_deaths: int = 3

@export_group("Blood")
@export var blood_spray_scene: PackedScene = preload("res://assets/vfx/combat/blood_spray.tscn")
@export var blood_spray_pool_size: int = 4
@export var max_active_blood: int = 4
## Số vết máu tối đa trên sàn
@export var max_blood_stains: int = 24

var _hit_pool: ObjectPool
var _death_pool: ObjectPool
var _blood_pool: ObjectPool
var _stains: BloodStains


func _ready() -> void:
	_hit_pool = _make_pool(hit_spark_scene, hit_spark_pool_size, &"HitSparkPool")
	_death_pool = _make_pool(death_burst_scene, death_burst_pool_size, &"DeathBurstPool")
	_blood_pool = _make_pool(blood_spray_scene, blood_spray_pool_size, &"BloodSprayPool")
	_stains = BloodStains.new()
	_stains.name = &"BloodStains"
	_stains.max_stains = max_blood_stains
	add_child(_stains)


## position: điểm trúng; direction: hướng tia bay; color: màu tia lửa; power > 1: đòn mạnh / kết liễu
func spawn_hit(position: Vector3, direction: Vector3, color: Color = Color(1.0, 0.7, 0.25), effect_scale: float = 1.0, power: float = 1.0) -> void:
	var fx := _acquire_capped(_hit_pool, max_active_hits) as HitSpark
	fx.play(position, direction, color, effect_scale, power)


## position: chân quái
func spawn_death(position: Vector3, color: Color = Color(1.0, 0.5, 0.2), effect_scale: float = 1.0) -> void:
	var fx := _acquire_capped(_death_pool, max_active_deaths) as DeathBurst
	fx.play(position, color, effect_scale)


## Phun máu hình nón theo direction; floor_y: độ cao mặt sàn (để máu rơi xuống đó và để vết)
func spawn_blood(position: Vector3, direction: Vector3, color: Color, floor_y: float, power: float = 1.0, kill: bool = false) -> void:
	var fx := _acquire_capped(_blood_pool, max_active_blood) as BloodSpray
	fx.play(position, direction, color, floor_y, power, kill)


## Vết máu trên sàn tại world_position (y là mặt sàn); delay: chờ giọt rơi tới
func add_blood_stain(world_position: Vector3, size: float, color: Color, delay: float = 0.0, satellites: float = 3.0) -> void:
	_stains.add_stain(world_position, size, color, delay, satellites)


## Vũng máu lớn dưới xác
func spawn_puddle(feet_position: Vector3, size: float, color: Color) -> void:
	_stains.add_stain(feet_position, size, color, 0.0, 0.0)


func get_hit_pool() -> ObjectPool:
	return _hit_pool


func get_death_pool() -> ObjectPool:
	return _death_pool


func get_blood_pool() -> ObjectPool:
	return _blood_pool


func get_blood_stains() -> BloodStains:
	return _stains


func _acquire_capped(pool: ObjectPool, cap: int) -> Node:
	if cap > 0 and pool.get_active_count() >= cap:
		pool.release(pool.get_oldest_active())
	return pool.acquire()


func _make_pool(scene: PackedScene, size: int, pool_name: StringName) -> ObjectPool:
	var pool := ObjectPool.new()
	pool.name = pool_name
	pool.scene = scene
	pool.initial_size = size
	add_child(pool)
	return pool
