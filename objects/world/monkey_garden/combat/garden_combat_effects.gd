class_name GardenCombatEffects
extends RefCounted
const BANANA_BLAST: PackedScene = preload("res://assets/vfx/enemies/monkey/banana_blast/banana_blast.tscn")
static func explosion(parent: Node3D, at: Vector3, radius: float) -> void:
	var pool: ObjectPool = parent.get_node_or_null("BananaProjectileBlastPool") as ObjectPool
	if pool == null:
		pool = ObjectPool.new(); pool.name = "BananaProjectileBlastPool"; pool.scene = BANANA_BLAST; pool.initial_size = 2; parent.add_child(pool)
	var effect: Node3D = pool.acquire() as Node3D; effect.call("play",at,radius,true)
static func pulse(parent: Node, at: Vector3, radius: float, color: Color=Color(1,0.18,0.03)) -> void:
	var ring: MeshInstance3D=MeshInstance3D.new(); var mesh: TorusMesh=TorusMesh.new()
	mesh.inner_radius=0.85; mesh.outer_radius=1; mesh.rings=24; mesh.ring_segments=4
	var mat: StandardMaterial3D=StandardMaterial3D.new(); mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA; mat.albedo_color=color
	ring.mesh=mesh; ring.material_override=mat; ring.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(ring); ring.global_position=at; ring.scale=Vector3.ONE*0.05
	var tween: Tween=ring.create_tween().set_parallel(true); tween.tween_property(ring,"scale",Vector3.ONE*radius,0.35); tween.tween_property(mat,"albedo_color:a",0.0,0.35)
	tween.chain().tween_callback(ring.queue_free)
static func confetti(parent: Node3D, at: Vector3) -> void:
	var particles: CPUParticles3D=CPUParticles3D.new(); particles.amount=48; particles.one_shot=true; particles.explosiveness=1; particles.lifetime=1.3
	particles.direction=Vector3.UP; particles.spread=65; particles.gravity=Vector3.DOWN*6; particles.initial_velocity_min=2; particles.initial_velocity_max=5
	particles.scale_amount_min=0.025; particles.scale_amount_max=0.09
	var mesh: BoxMesh=BoxMesh.new(); mesh.size=Vector3(1,0.2,0.5); var mat: StandardMaterial3D=StandardMaterial3D.new(); mat.albedo_color=Color(1,0.55,0.02); mat.emission_enabled=true; mat.emission=mat.albedo_color; mesh.material=mat; particles.mesh=mesh
	parent.add_child(particles); particles.global_position=at; particles.restart(); parent.get_tree().create_timer(2).timeout.connect(particles.queue_free)
