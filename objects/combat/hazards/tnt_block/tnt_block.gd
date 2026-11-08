class_name TntBlock
extends StaticBody3D
## Khối TNT do player đặt (kỹ năng TNT). Nằm yên, đứng lên được; chỉ nổ khi chạm lửa: BurnableComponent bị
## nguồn lửa đốt (phun lửa, vết lửa, dung nham...) thì châm ngòi fuse_time giây rồi nổ.
## Nổ: một lần dò hình cầu bán kính radius, mọi hurtbox trong vùng (quái, boss, cả player) nhận đòn attack,
## bị đẩy ra xa tâm nổ. Chủ hurtbox có hàm on_explosion_hit(source) (boss có khiên...) được báo trước khi nhận đòn. Người gây đòn tính là người đặt (quái quay sang đuổi người đặt, không đuổi khối TNT).
## Dùng lại được: place() đưa khối về trạng thái chờ ở chỗ mới, không tạo node mới.
## Hiệu năng: không có _process; ngòi là Timer, dò vùng nổ đúng một lần lúc nổ.

signal placed
## Bắt lửa, ngòi bắt đầu cháy
signal fuse_lit
signal exploded(at: Vector3)

enum Phase { HIDDEN, ARMED, FUSE, SPENT }

## Lớp hurtbox bị nổ trúng: player (2) + enemy (3)
const HURTBOX_MASK := 0b110

@export var attack: AttackData
## Bán kính vùng nổ (m)
@export_range(0.5, 12.0, 0.1) var radius: float = 3.0
## Thời gian từ lúc bắt lửa tới lúc nổ (s)
@export_range(0.0, 5.0, 0.05) var fuse_time: float = 0.6
@export_group("Feedback")
@export_range(0.0, 1.0) var shake_trauma: float = 0.6
@export var burst_color: Color = Color(1.0, 0.55, 0.15)
@export_range(0.1, 6.0, 0.1) var burst_scale: float = 2.6

var phase: Phase = Phase.HIDDEN

var _placer: Node3D

@onready var _visual: Node3D = $Visual
@onready var _shape: CollisionShape3D = $CollisionShape3D
@onready var _burnable: BurnableComponent = $BurnableComponent
@onready var _fuse: Timer = $Fuse
@onready var _spark: OmniLight3D = $Visual/Spark


func _ready() -> void:
	_burnable.ignited.connect(_on_ignited)
	_fuse.one_shot = true
	_fuse.timeout.connect(explode)
	_set_present(false)


## Đặt khối ở at (mặt sàn), quay yaw; khối đang cháy ngòi thì dập và dời đi
func place(at: Vector3, yaw: float, placer: Node3D = null) -> void:
	_fuse.stop()
	_burnable.extinguish()
	_placer = placer
	global_position = at
	rotation = Vector3(0.0, yaw, 0.0)
	phase = Phase.ARMED
	_set_present(true)
	_spark.visible = false
	placed.emit()


func is_armed() -> bool:
	return phase == Phase.ARMED or phase == Phase.FUSE


## Châm ngòi (gọi thẳng được, ví dụ TNT khác nổ cạnh); ngòi 0 s thì nổ ngay
func light_fuse() -> void:
	if phase != Phase.ARMED:
		return
	phase = Phase.FUSE
	_spark.visible = true
	fuse_lit.emit()
	if fuse_time <= 0.0:
		explode()
	else:
		_fuse.start(fuse_time)


func explode() -> void:
	if not is_armed():
		return
	phase = Phase.SPENT
	_fuse.stop()
	var center := global_position + Vector3.UP * 0.4
	_damage_in_radius(center)
	CombatFx.spawn_death(center, burst_color, burst_scale)
	ScreenShake.add_trauma(shake_trauma)
	_set_present(false)
	exploded.emit(center)


func _on_ignited() -> void:
	light_fuse()


## Dò một lần mọi hurtbox trong hình cầu rồi gây đòn; đẩy theo hướng từ tâm nổ ra
func _damage_in_radius(center: Vector3) -> void:
	if attack == null:
		return
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, center)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = HURTBOX_MASK
	var source: Node = _placer if is_instance_valid(_placer) else self
	for result: Dictionary in get_world_3d().direct_space_state.intersect_shape(query, 64):
		var hurtbox := result.collider as HurtboxComponent
		if hurtbox == null:
			continue
		var direction := hurtbox.global_position - center
		direction.y = 0.0
		direction = direction.normalized() if direction.length_squared() > 0.0001 else Vector3.FORWARD
		# Báo vụ nổ trước (boss vỡ khiên) để đòn ngay sau đó tính sát thương được
		var target: Node = hurtbox.owner
		if target and target.has_method(&"on_explosion_hit"):
			target.call(&"on_explosion_hit", self)
		var info := DamageInfo.new(attack.damage, attack.damage_type, direction * attack.knockback, source)
		info.direction = direction
		info.attack = attack
		hurtbox.receive_hit(info)


## Hiện / ẩn cả hình, va chạm và khả năng bắt lửa
func _set_present(present: bool) -> void:
	_visual.visible = present
	_shape.set_deferred(&"disabled", not present)
	_burnable.set_enabled(present)
