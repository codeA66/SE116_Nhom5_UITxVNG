extends Node3D
## Nạp hiệu ứng sẵn, bám hai xương bàn tay; nổ đất cùng signal hitbox khi đáp.
const SLAM: PackedScene=preload("res://assets/vfx/enemies/earth_slam/earth_slam.tscn")
const CHARGE: Shader=preload("res://assets/vfx/enemies/earth_slam/hand_charge.gdshader")
var pool: ObjectPool
var _actor: WildEnemy
var _skeleton: Skeleton3D
var _hands: Array[int]=[]
var _charges: Array[MeshInstance3D]=[]
var _material: ShaderMaterial
var _time: float=0.0
var _radius: float=2.8

func _ready() -> void:
	_actor=get_parent() as WildEnemy
	_skeleton=_actor.get_node("Model/Visual/Rig").find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
	var hitbox: HitboxComponent=_actor.get_node("Model/Hitbox") as HitboxComponent
	_radius=((hitbox.get_node("CollisionShape3D") as CollisionShape3D).shape as CylinderShape3D).radius
	_material=ShaderMaterial.new();_material.shader=CHARGE
	for bone_name: String in ["CATRigLArmPalm","CATRigRArmPalm001"]:
		var bone: int=_skeleton.find_bone(bone_name);assert(bone>=0);_hands.append(bone)
		var orb: MeshInstance3D=MeshInstance3D.new();var sphere: SphereMesh=SphereMesh.new()
		sphere.radius=.36;sphere.height=.72;sphere.radial_segments=16;sphere.rings=8
		orb.mesh=sphere;orb.material_override=_material;orb.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		orb.visible=false;add_child(orb);_charges.append(orb)
	pool=ObjectPool.new();pool.scene=SLAM;pool.initial_size=2;add_child(pool)
	_actor.skill_started.connect(_begin);_actor.skill_finished.connect(_finish);hitbox.activated.connect(_impact)
	set_process(false)

func _begin(skill: EnemySkillData) -> void:
	if skill.skill_id!=&"leap_claw":return
	_time=0.0
	for orb: MeshInstance3D in _charges:orb.visible=true
	set_process(true);_process(0.0)

func _finish(_skill: EnemySkillData,completed: bool) -> void:
	for orb: MeshInstance3D in _charges:orb.visible=false
	set_process(false)
	if not completed:pool.release_all()

func _impact(_attack: AttackData) -> void:
	for orb: MeshInstance3D in _charges:orb.visible=false
	set_process(false)
	# Chạy sau move_and_slide của actor để tâm hiệu ứng đúng vị trí đã đáp.
	_spawn_impact.call_deferred()

func _spawn_impact() -> void:
	if not is_instance_valid(_actor) or _actor.is_dead():return
	var at: Vector3=_actor.global_position
	var query: PhysicsRayQueryParameters3D=PhysicsRayQueryParameters3D.create(at+Vector3.UP*3.0,at+Vector3.DOWN*8.0,257)
	var floor_hit: Dictionary=_actor.get_world_3d().direct_space_state.intersect_ray(query)
	if not floor_hit.is_empty():at.y=(floor_hit["position"] as Vector3).y
	var effect: EarthSlam=pool.acquire() as EarthSlam;effect.play(at,_radius)
	ScreenShake.add_trauma(.14)

func _process(delta: float) -> void:
	_time+=delta;_material.set_shader_parameter(&"age",_time)
	for i: int in _hands.size():
		_charges[i].global_position=_skeleton.global_transform*_skeleton.get_bone_global_pose(_hands[i]).origin
