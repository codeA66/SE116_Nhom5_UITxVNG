class_name WebBolt
extends Area3D
## Đạn tơ của nhện lửa. Bay thẳng; trúng player thì tạo tấm tơ dính luôn vào người (không sát thương), chạm tường / sàn
## hoặc hết tuổi thọ thì rớt thành tấm tơ trên sàn tại chỗ đó. Player đang dash (bất tử) thì đạn xuyên qua, không dính.
## Dùng với ObjectPool: không queue_free, xong việc phát finished để pool thu lại.
## Theo dõi va chạm bằng signal; chỉ chạy _physics_process khi đang bay.

## Hết việc (đã rớt thành tấm tơ hoặc bị hủy): pool nghe để thu lại
signal finished(bolt: WebBolt)
## Đã tạo tấm tơ (dính người hoặc trên sàn)
signal landed(patch: WebPatch, on_player: bool)

## Scene tấm tơ rớt ra
@export var patch_scene: PackedScene
## Lớp chặn đạn (world); player được nhận biết riêng qua hurtbox
@export_flags_3d_physics var floor_mask: int = 1

var _data: WebData
var _velocity: Vector3
var _remaining: float = 0.0
var _spent: bool = true
var _floor_query: PhysicsRayQueryParameters3D

@onready var _shape: CollisionShape3D = $CollisionShape3D
@onready var _visual: Node3D = $Visual


func _ready() -> void:
	# Đạn không bay theo quái cha
	top_level = true
	_floor_query = PhysicsRayQueryParameters3D.new()
	_floor_query.collision_mask = floor_mask
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	set_physics_process(false)


func launch(data: WebData, origin: Vector3, direction: Vector3) -> void:
	_data = data
	_spent = false
	_remaining = data.bolt_lifetime
	_velocity = direction.normalized() * data.bolt_speed
	# Shape là local_to_scene nên đổi bán kính không ảnh hưởng quả khác
	(_shape.shape as SphereShape3D).radius = data.bolt_radius
	global_position = origin
	reset_physics_interpolation()
	set_physics_process(true)


## Tan ngay không tạo tơ (quái bắn đã chết)
func dissipate() -> void:
	if _spent:
		return
	_spent = true
	set_physics_process(false)
	finished.emit(self)


func is_flying() -> bool:
	return not _spent


func pool_acquired() -> void:
	set_deferred(&"monitoring", true)


func pool_released() -> void:
	_spent = true
	set_physics_process(false)
	set_deferred(&"monitoring", false)


func _physics_process(delta: float) -> void:
	global_position += _velocity * delta
	_remaining -= delta
	if _remaining <= 0.0:
		_land_on_floor(global_position)


func _on_area_entered(area: Area3D) -> void:
	var hurtbox: HurtboxComponent = area as HurtboxComponent
	if _spent or hurtbox == null:
		return
	var player: Player = hurtbox.owner as Player
	# Dash xuyên qua đạn
	if player == null or hurtbox.is_invincible():
		return
	_land(player.global_position, player)


func _on_body_entered(body: Node3D) -> void:
	# Player do hurtbox lo (để tôn trọng bất tử khi dash); body còn lại là tường / sàn
	if _spent or body is Player:
		return
	_land_on_floor(global_position)


## Tìm sàn ngay dưới điểm rơi để tấm tơ nằm sát đất
func _land_on_floor(point: Vector3) -> void:
	if _spent:
		return
	_floor_query.from = point + Vector3.UP * 1.0
	_floor_query.to = point + Vector3.DOWN * 4.0
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(_floor_query)
	_land(hit.position if not hit.is_empty() else point, null)


func _land(point: Vector3, player: Player) -> void:
	_spent = true
	set_physics_process(false)
	# Có thể đang trong callback vật lý: không được thêm vùng va chạm ngay lúc này
	_spawn_patch.call_deferred(point, player)


func _spawn_patch(point: Vector3, player: Player) -> void:
	var patch: WebPatch = patch_scene.instantiate() as WebPatch
	patch.data = _data
	get_tree().current_scene.add_child(patch)
	patch.global_position = point
	if player != null:
		patch.entangle(player)
	landed.emit(patch, player != null)
	finished.emit(self)
