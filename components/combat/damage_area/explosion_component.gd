class_name ExplosionComponent
extends Node3D
## Vụ nổ dùng chung (quái tự nổ, sau này bẫy / thùng nổ): gọi explode() thì dò hình cầu đúng một lần, mọi
## hurtbox trong radius (lọc bằng hurtbox_mask) nhận đòn attack và bị đẩy ra xa tâm; có thể làm mục tiêu
## bắt lửa. Hurtbox của chính chủ (owner) được bỏ qua. Chủ hurtbox có on_explosion_hit(source) (boss có khiên)
## được báo trước khi nhận đòn, giống TNT.
## Hiệu năng: không có _process; shape / query tạo một lần và dùng lại.

signal exploded(center: Vector3, hit_count: int)

@export var attack: AttackData
## Bán kính nổ (m)
@export_range(0.1, 12.0, 0.1) var radius: float = 2.5
## Lớp hurtbox bị nổ trúng: mặc định player (2) + enemy (3), nên nổ cả quái đứng gần
@export_flags_3d_physics var hurtbox_mask: int = 0b110
@export_group("Burn")
## Làm mục tiêu bắt lửa (BurnableComponent) khi trúng
@export var ignite_targets: bool = true
## Đường dẫn BurnableComponent tính từ chủ hurtbox
@export var burnable_node: NodePath = ^"BurnableComponent"
@export_group("Feedback")
@export_range(0.0, 1.0) var shake_trauma: float = 0.5
## Rung đủ mức khi camera nhìn trong bán kính này (m); xa dần yếu dần, ngoài shake_max_radius thì không rung
@export_range(0.0, 100.0, 0.5) var shake_full_radius: float = 8.0
@export_range(0.0, 200.0, 0.5) var shake_max_radius: float = 20.0
@export var burst_color: Color = Color(1.0, 0.45, 0.1)
@export_range(0.1, 6.0, 0.1) var burst_scale: float = 2.2

var _sphere := SphereShape3D.new()
var _query := PhysicsShapeQueryParameters3D.new()


func _ready() -> void:
	_query.shape = _sphere
	_query.collide_with_areas = true
	_query.collide_with_bodies = false


## Nổ tại vị trí node này; source là người gây đòn (quái tự nổ, người đặt bẫy...). Trả về số hurtbox trúng
func explode(source: Node = null) -> int:
	var center := global_position
	var hits := 0
	if attack != null:
		hits = _damage_in_radius(center, source if source else owner)
	CombatFx.spawn_death(center, burst_color, burst_scale)
	ScreenShake.add_trauma_at(shake_trauma, center, shake_full_radius, shake_max_radius)
	exploded.emit(center, hits)
	return hits


func _damage_in_radius(center: Vector3, source: Node) -> int:
	_sphere.radius = radius
	_query.transform = Transform3D(Basis.IDENTITY, center)
	_query.collision_mask = hurtbox_mask
	var hits := 0
	for result: Dictionary in get_world_3d().direct_space_state.intersect_shape(_query, 64):
		var hurtbox := result.collider as HurtboxComponent
		if hurtbox == null or (owner != null and hurtbox.owner == owner):
			continue
		var direction := hurtbox.global_position - center
		direction.y = 0.0
		direction = direction.normalized() if direction.length_squared() > 0.0001 else Vector3.FORWARD
		var target: Node = hurtbox.owner
		if target and target.has_method(&"on_explosion_hit"):
			target.call(&"on_explosion_hit", self)
		var info := DamageInfo.new(attack.damage, attack.damage_type, direction * attack.knockback, source)
		info.direction = direction
		info.attack = attack
		if hurtbox.receive_hit(info):
			hits += 1
		if ignite_targets and target:
			var burnable := target.get_node_or_null(burnable_node) as BurnableComponent
			if burnable:
				burnable.ignite(source)
	return hits
