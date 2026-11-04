class_name RicochetBanana
extends Node3D
signal finished(bullet: RicochetBanana)
signal bounced(normal: Vector3, incoming: Vector3, outgoing: Vector3)
@export var speed: float = 10.0
@export var lifetime: float = 7.0
@export var maximum_bounces: int = 2
var direction: Vector3
var _age: float = 0.0
var _bounces: int = 0
var _sweep: ShapeCast3D
var _visual: MeshInstance3D
var _sparkles: CPUParticles3D
func _ready() -> void:
	top_level = true
	_visual = MeshInstance3D.new(); _visual.mesh = BananaGeometry.fruit(); _visual.scale = Vector3.ONE*1.2
	var mat: StandardMaterial3D = StandardMaterial3D.new(); mat.albedo_color = Color(1,0.025,0.01); mat.emission_enabled=true; mat.emission=Color(1,0.025,0.01); mat.emission_energy_multiplier=0.5; mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_visual.material_override = mat; add_child(_visual)
	_sparkles=CPUParticles3D.new(); _sparkles.amount=12; _sparkles.lifetime=0.35; _sparkles.local_coords=false; _sparkles.gravity=Vector3.ZERO; _sparkles.initial_velocity_min=0.1; _sparkles.initial_velocity_max=0.6
	var spark: SphereMesh=SphereMesh.new(); spark.radius=0.025; spark.height=0.05; spark.radial_segments=4; spark.rings=1; var light: StandardMaterial3D=StandardMaterial3D.new(); light.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; light.albedo_color=Color(1,0.7,0.35); spark.material=light; _sparkles.mesh=spark; add_child(_sparkles)
	_sweep = ShapeCast3D.new(); var sphere: SphereShape3D = SphereShape3D.new(); sphere.radius = 0.12
	sphere.radius=0.4
	_sweep.shape = sphere; _sweep.collision_mask = 2049; _sweep.collide_with_areas = true; _sweep.collide_with_bodies = true
	_sweep.enabled = false; add_child(_sweep)
	pool_released()
func launch(at: Vector3, toward: Vector3) -> void:
	global_transform = Transform3D(Basis.IDENTITY,at)
	direction = Vector3(toward.x,0,toward.z).normalized()
	_age = 0; _bounces = 0; visible = true; set_physics_process(true); reset_physics_interpolation()
	_sparkles.emitting=true
func pool_released() -> void:
	visible = false; set_physics_process(false)
	if _sparkles: _sparkles.emitting=false
func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime: finished.emit(self); return
	_visual.rotate_z(delta*14.0)
	var remaining: float = speed*delta
	for iteration: int in 4:
		_sweep.target_position = direction*remaining
		_sweep.force_shapecast_update()
		if not _sweep.is_colliding(): global_position += direction*remaining; break
		var fraction: float = _sweep.get_closest_collision_safe_fraction()
		global_position += direction * remaining * fraction
		var collider: Node = _sweep.get_collider(0) as Node
		if collider is RicochetStar:
			GardenCombatEffects.pulse(get_parent(),global_position,0.7); (collider as RicochetStar).hit(); finished.emit(self); return
		var normal: Vector3 = _sweep.get_collision_normal(0); normal.y = 0; normal = normal.normalized()
		if normal.is_zero_approx(): finished.emit(self); return
		if _bounces >= maximum_bounces:
			GardenCombatEffects.pulse(get_parent(),global_position,0.65); finished.emit(self); return
		var incoming: Vector3 = direction
		direction = direction.bounce(normal).normalized()
		bounced.emit(normal,incoming,direction)
		GardenCombatEffects.pulse(get_parent(),global_position,0.65)
		global_position += normal*0.015
		remaining *= 1.0-fraction
		_bounces += 1
		if remaining < 0.001: break
