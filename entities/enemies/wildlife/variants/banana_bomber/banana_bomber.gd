class_name BananaBomber
extends MonkeyGrunt
## Một lần bắt mục tiêu, một đồng hồ không reset; chết trước ngòi nổ thì hủy hoàn toàn.
signal armed
signal exploded
const BLAST: PackedScene = preload("res://assets/vfx/enemies/monkey/banana_blast/banana_blast.tscn")
@export var fuse_time: float = 5.0
@export var blast_radius: float = 3.2
@export var blast_push: float = 9.0
@export var ammo_drop_amount: int = 3
var is_armed: bool = false
var fuse_elapsed: float = 0.0
var _exploding: bool = false
var detonated: bool = false
var _blink_phase: float = 0.0
var _banana: MeshInstance3D
var _bomb_material: StandardMaterial3D
var _skeleton: Skeleton3D
var _hands: Vector2i
var _pool: ObjectPool

func _ready() -> void:
	super()
	_skeleton = get_node("Model/Visual/Rig").find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_hands = Vector2i(_skeleton.find_bone("CATRigLArmPalm"),_skeleton.find_bone("CATRigRArmPalm001"))
	for knife: MeshInstance3D in model.find_children("*knife*", "MeshInstance3D", true, false): knife.hide()
	_banana = MeshInstance3D.new()
	_banana.name = "GiantBananaBomb"
	_banana.mesh = BananaGeometry.fruit()
	_banana.scale = Vector3.ONE * 1.5
	_bomb_material = StandardMaterial3D.new()
	_bomb_material.vertex_color_use_as_albedo = true
	_bomb_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_bomb_material.roughness = 0.8
	_banana.material_override = _bomb_material
	add_child(_banana)
	var world: Node = self
	while world.get_parent() != get_tree().root and world.get_parent() != null: world = world.get_parent()
	_pool = world.get_node_or_null("BananaBlastPool") as ObjectPool
	if _pool == null:
		_pool = ObjectPool.new(); _pool.name = "BananaBlastPool"; _pool.scene = BLAST; _pool.initial_size = 2
		world.add_child.call_deferred(_pool)

func choose_skill() -> EnemySkillData:
	return null

func alert_pending() -> bool:
	return false

func arm() -> void:
	if is_armed or is_dead(): return
	is_armed = true
	fuse_elapsed = 0.0
	armed.emit()

func receive_rally(player: Node3D) -> void:
	super(player)
	if has_target(): arm()

func _on_target_entered(body: Node3D) -> void:
	super(body)
	if has_target(): arm()

func _pre_state_update(delta: float) -> void:
	super(delta)
	if not is_armed or is_dead() or _exploding: return
	fuse_elapsed += delta
	if fuse_elapsed >= maxf(fuse_time, 0.1):
		_exploding = true
		_detonate.call_deferred()

func _process(delta: float) -> void:
	if _banana == null or _skeleton == null: return
	_banana.global_position = _skeleton.global_transform * ((_skeleton.get_bone_global_pose(_hands.x).origin + _skeleton.get_bone_global_pose(_hands.y).origin) * 0.5)
	_banana.global_rotation = Vector3(0, model.rotation.y, 0)
	if not is_armed or is_dead(): return
	var progress: float = clampf(fuse_elapsed / maxf(fuse_time,0.1),0,1)
	_blink_phase += delta * lerpf(2.0,20.0,progress*progress) * TAU
	var amount: float = smoothstep(-0.2,0.2,sin(_blink_phase))
	_bomb_material.vertex_color_use_as_albedo = false
	_bomb_material.albedo_color = Color(1,0.72,0.015).lerp(Color.WHITE,amount)
	_bomb_material.emission_enabled = true
	_bomb_material.emission = _bomb_material.albedo_color
	_bomb_material.emission_energy_multiplier = 0.35 + progress*0.65

func _on_died() -> void:
	if ammo_drop_amount > 0:
		# Tạo Area tương tác sau bước physics; đạn chết thường không dùng hiệu ứng rơi thưởng phòng.
		GardenRewards.loot.call_deferred(get_parent(),global_position,false,ammo_drop_amount,false)
	is_armed = false
	if _banana: _banana.hide()
	set_process(false)
	super()

func _detonate() -> void:
	if is_dead(): return
	detonated=true
	var effect: Node3D = _pool.acquire() as Node3D
	effect.call("play",global_position,blast_radius)
	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = blast_radius; shape.height = 3.5
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = shape; query.transform = Transform3D(Basis.IDENTITY,global_position + Vector3.UP)
	query.collision_mask = 6; query.collide_with_areas = true; query.collide_with_bodies = false
	for result: Dictionary in get_world_3d().direct_space_state.intersect_shape(query,64):
		var box: HurtboxComponent = result.collider as HurtboxComponent
		if box == null or box == hurtbox or not box.is_alive(): continue
		var actor: CharacterBody3D = box.get_parent() as CharacterBody3D
		if actor == null: continue
		var direction: Vector3 = actor.global_position-global_position; direction.y = 0
		if direction.is_zero_approx(): direction = Vector3.RIGHT
		direction = direction.normalized()
		box.receive_hit(DamageInfo.new(1,DamageInfo.Type.PHYSICAL,Vector3.ZERO,self))
		ForcedImpulse.push(actor,direction*blast_push)
	exploded.emit()
	health.take_damage(health.current_health)
