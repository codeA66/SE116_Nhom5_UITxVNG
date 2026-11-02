class_name ArrowProjectile
extends Node3D
## Tên bay thẳng theo +Z. Quét cả đoạn đường mỗi physics frame để không xuyên vật mỏng.
## Kéo theo một vệt sáng (Trail) dài dần theo quãng đã bay. Trúng vật: dừng tại chỗ trúng, ẩn mũi tên,
## gọi hiệu ứng trúng, để vệt co về và mờ hết rồi mới coi là xong.
## Dùng với ObjectPool: hết việc thì phát finished để pool thu lại; không ai nghe (không có pool) thì tự xoá.

## Trúng vật hoặc hết thời gian bay, và vệt đã tắt
signal finished(arrow: ArrowProjectile)

## Tên trúng thứ gì đó (quái hoặc tường) tại position: buff nguyên tố của cung nghe signal này
signal impacted(position: Vector3, direction: Vector3)

@export_flags_3d_physics var collision_mask: int = 5 # world + enemy

@export_group("Hit")
## Độ "dày" của tên khi chạm quái (m): quét một khối cầu theo đường bay để lệch chuột một chút vẫn trúng
## (cách game top-down hay làm: phóng to vùng trúng thay vì bắt nhắm thật chuẩn). 0 = tia mỏng như cũ.
## Tường / vật cản vẫn dò bằng tia mỏng, để tên bay sát mép tường không bị dừng sớm.
@export_range(0.0, 2.0, 0.01, "or_greater") var hit_radius: float = 0.35
## Lớp được dò bằng khối cầu (chỉ phe bị bắn: quái); tường không thuộc lớp này
@export_flags_3d_physics var target_mask: int = 4 # enemy

@export_group("Trail")
## Chiều dài tối đa của vệt sau mũi tên (m); 0 = tắt vệt
@export_range(0.0, 20.0, 0.1, "or_greater") var trail_length: float = 2.5
## Thời gian vệt co về và mờ hết sau khi trúng / hết tầm (s)
@export_range(0.0, 2.0, 0.01, "or_greater") var trail_fade_time: float = 0.15
## Vệt bắt đầu lùi sau mũi tên bao nhiêu mét (để vệt không phủ lên model tên); 0 = ngay tại mũi
@export_range(0.0, 5.0, 0.01, "or_greater") var trail_head_offset: float = 0.0

@export_group("Flight FX")
## Hạt chỉ phát lúc tên đang bay (đốm sáng rơi theo đuôi...); tắt khi trúng / hết tầm / về pool
@export var flight_particles: Array[CPUParticles3D] = []

@export_group("Impact")
## Kích thước hiệu ứng trúng (CombatFx.spawn_arrow_impact); 0 = không phát
@export_range(0.0, 4.0, 0.05, "or_greater") var impact_scale: float = 1.0
## Hiệu ứng trúng riêng của loại tên này (gốc scene là ArrowImpact); để trống = hiệu ứng tên mặc định của CombatFx
@export var impact_scene: PackedScene

var _attack: AttackData
var _damage: int = 0
var _velocity: Vector3
var _remaining: float
var _source: Node3D
var _previous_position: Vector3
var _traveled: float = 0.0
## > 0: đã trúng / hết tầm, đang cho vệt tắt dần
var _fade_left: float = 0.0
var _fading: bool = false
var _trail_intensity: float = 1.0
## Truy vấn quét khối cầu tạo một lần, mỗi frame chỉ đổi vị trí / quãng (không cấp phát trong vòng lặp nóng)
var _sweep: PhysicsShapeQueryParameters3D
var _sweep_shape: SphereShape3D

@onready var _model: Node3D = $Model
@onready var _trail: MeshInstance3D = $Trail
@onready var _trail_material: ShaderMaterial = _trail.material_override as ShaderMaterial


func _ready() -> void:
	add_to_group(&"arrows")
	_trail_intensity = float(_trail_material.get_shader_parameter(&"intensity"))
	# Tạo pool hiệu ứng trúng ngay khi tên được tạo (lúc pool tên khởi tạo), tránh giật ở phát trúng đầu tiên
	if impact_scene:
		CombatFx.prepare_arrow_impact_scene(impact_scene)
	_sweep_shape = SphereShape3D.new()
	_sweep = PhysicsShapeQueryParameters3D.new()
	_sweep.shape = _sweep_shape
	_sweep.collide_with_areas = true
	_sweep.collide_with_bodies = true
	set_physics_process(false)


## damage < 0 = dùng attack.damage
func launch(attack: AttackData, speed: float, lifetime: float, direction: Vector3, source: Node3D, origin: Vector3, damage: int = -1) -> void:
	_attack = attack
	_damage = attack.damage if damage < 0 else damage
	_velocity = direction.normalized() * speed
	_remaining = lifetime
	_source = source
	_previous_position = origin
	_traveled = 0.0
	_fading = false
	_model.visible = true
	_trail_material.set_shader_parameter(&"intensity", _trail_intensity)
	_set_trail_length(0.0)
	_sweep_shape.radius = maxf(hit_radius, 0.001)
	_sweep.collision_mask = target_mask
	_sweep.exclude = [(source as CollisionObject3D).get_rid()] if source is CollisionObject3D else []
	look_at(global_position + direction, Vector3.UP, true)
	reset_physics_interpolation()
	for particles in flight_particles:
		particles.restart()
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if _fading:
		_update_fade(delta)
		return
	var next := global_position + _velocity * minf(delta, _remaining)
	var query := PhysicsRayQueryParameters3D.create(_previous_position, next, collision_mask)
	query.collide_with_areas = true
	query.hit_from_inside = true
	if is_instance_valid(_source) and _source is CollisionObject3D:
		query.exclude = [(_source as CollisionObject3D).get_rid()]
	var space := get_world_3d().direct_space_state
	var result := space.intersect_ray(query)
	# Quái chạm khối cầu trước khi tia mỏng chạm thứ gì (kể cả tường) thì tính trúng quái
	var motion := next - _previous_position
	var target := _sweep_targets(space, motion)
	if not target.is_empty():
		var ray_fraction := 2.0
		if not result.is_empty():
			ray_fraction = _previous_position.distance_to(result["position"]) / maxf(motion.length(), 0.0001)
		if float(target["fraction"]) <= ray_fraction:
			result = target
	if not result.is_empty():
		var collider := result["collider"] as Node
		var hurtbox := collider as HurtboxComponent
		if hurtbox == null and collider:
			hurtbox = collider.get_node_or_null(^"HurtboxComponent") as HurtboxComponent
		if hurtbox:
			var source: Node = _source if is_instance_valid(_source) else null
			hurtbox.receive_hit(DamageInfo.new(_damage, _attack.damage_type, _velocity.normalized() * _attack.knockback, source))
		var hit_position: Vector3 = result["position"]
		# Lùi một chút khỏi điểm trúng để vật nở ra (hố hút) không lọt vào trong tường
		impacted.emit(hit_position - _velocity.normalized() * 0.3, _velocity.normalized())
		_traveled += global_position.distance_to(hit_position)
		global_position = hit_position
		if impact_scale > 0.0:
			if impact_scene:
				CombatFx.spawn_arrow_impact_scene(impact_scene, hit_position, _velocity, impact_scale)
			else:
				CombatFx.spawn_arrow_impact(hit_position, _velocity, impact_scale)
		_start_fade()
		return
	_traveled += global_position.distance_to(next)
	global_position = next
	_previous_position = next
	_remaining -= delta
	_set_trail_length(_traveled)
	if _remaining <= 0.0:
		_start_fade()


## Quét khối cầu bán kính hit_radius theo quãng bay frame này, chỉ trên target_mask.
## Trả về {collider, position, fraction} của mục tiêu có hurtbox chạm sớm nhất; rỗng nếu không chạm / hit_radius = 0
func _sweep_targets(space: PhysicsDirectSpaceState3D, motion: Vector3) -> Dictionary:
	if hit_radius <= 0.0 or motion.is_zero_approx():
		return {}
	_sweep.transform = Transform3D(Basis.IDENTITY, _previous_position)
	_sweep.motion = motion
	# [an toàn, chạm]: 1.0 = đi hết quãng không chạm gì
	var fractions := space.cast_motion(_sweep)
	if fractions.size() < 2 or fractions[1] >= 1.0:
		return {}
	var at := _previous_position + motion * fractions[1]
	_sweep.transform = Transform3D(Basis.IDENTITY, at)
	_sweep.motion = Vector3.ZERO
	for hit: Dictionary in space.intersect_shape(_sweep, 4):
		var collider := hit["collider"] as Node
		if collider is HurtboxComponent or (collider and collider.get_node_or_null(^"HurtboxComponent")):
			return {"collider": collider, "position": at, "fraction": fractions[1]}
	return {}


## ObjectPool gọi khi nhả về
func pool_released() -> void:
	set_physics_process(false)
	_stop_flight_particles()


func _start_fade() -> void:
	_model.visible = false
	_stop_flight_particles()
	_fading = true
	_fade_left = trail_fade_time
	_update_fade(0.0)


## Vệt co về chỗ trúng và mờ dần; hết thì báo xong
func _update_fade(delta: float) -> void:
	_fade_left -= delta
	var t := clampf(_fade_left / trail_fade_time, 0.0, 1.0) if trail_fade_time > 0.0 else 0.0
	_set_trail_length(minf(_traveled, trail_length) * t)
	_trail_material.set_shader_parameter(&"intensity", _trail_intensity * t)
	if t <= 0.0:
		_finish()


## Vệt nằm sau đầu tên (gốc node), dài length nhưng không quá trail_length.
## Shader streak lấy trục và độ dài từ trục Y của node: Y hướng theo +Z (hướng bay)
func _set_trail_length(length: float) -> void:
	var l := minf(length, trail_length)
	_trail.visible = l > 0.001
	if not _trail.visible:
		return
	_trail.transform = Transform3D(Basis(Vector3.RIGHT, Vector3.BACK * l, Vector3.DOWN), Vector3(0.0, 0.0, -trail_head_offset - l * 0.5))


## Ngừng phát hạt mới; hạt đã phát (toạ độ thế giới) tự tàn hết
func _stop_flight_particles() -> void:
	for particles in flight_particles:
		particles.emitting = false


func _finish() -> void:
	set_physics_process(false)
	_fading = false
	_trail.visible = false
	if finished.get_connections().is_empty():
		queue_free()
	else:
		finished.emit(self)
