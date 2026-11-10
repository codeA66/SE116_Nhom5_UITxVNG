extends Node3D
## Một MultiMesh cho mỗi NPC, cấp phát lúc vào map; không ánh sáng, bóng hay va chạm.

@export_range(1, 24) var particle_count: int = 10
@export var particle_color: Color = Color(1.0, 0.7, 0.3, 0.65)
@export var fade_time: float = 0.4

var strength: float = 0.0
var _clock: float = 0.0
var _instances: MultiMeshInstance3D
var _mesh: MultiMesh
var _tween: Tween


func _ready() -> void:
	var npc := get_parent() as Npc
	assert(npc != null)
	npc.conversation_started.connect(_begin)
	npc.conversation_ended.connect(_end)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = false
	var shape := SphereMesh.new()
	shape.radius = 0.5
	shape.height = 1.0
	shape.radial_segments = 8
	shape.rings = 4
	shape.material = material
	_mesh = MultiMesh.new()
	_mesh.transform_format = MultiMesh.TRANSFORM_3D
	_mesh.use_colors = true
	_mesh.mesh = shape
	_mesh.instance_count = clampi(particle_count, 1, 24)
	_mesh.custom_aabb = AABB(Vector3(-4, -2, -4), Vector3(8, 8, 8))
	_instances = MultiMeshInstance3D.new()
	# Vệt được tính theo frame hiển thị; không nội suy lại theo physics.
	_instances.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_instances.multimesh = _mesh
	_instances.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_instances)
	_instances.hide()
	set_process(false)


func _process(delta: float) -> void:
	_clock += delta
	for index in _mesh.instance_count:
		_mesh.set_instance_transform(index, particle_transform(index, _clock))
		var color := particle_color
		color.a *= strength * (0.55 + 0.45 * sin(_clock * 1.7 + float(index) * 2.3))
		_mesh.set_instance_color(index, color)


func particle_transform(_index: int, _time: float) -> Transform3D:
	return Transform3D.IDENTITY


func _begin(_player: Player) -> void:
	_kill_tween()
	# Điền transform trước khi hiện để không lóe mesh kích thước mặc định.
	_process(0.0)
	_instances.show()
	set_process(true)
	_tween = create_tween()
	_tween.tween_property(self, "strength", 1.0, maxf(fade_time, 0.01))


func _end(_player: Player) -> void:
	_kill_tween()
	if not is_inside_tree():
		return
	_tween = create_tween()
	_tween.tween_property(self, "strength", 0.0, maxf(fade_time, 0.01))
	_tween.tween_callback(_sleep)


func _sleep() -> void:
	_instances.hide()
	set_process(false)


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()


func _exit_tree() -> void:
	_kill_tween()
