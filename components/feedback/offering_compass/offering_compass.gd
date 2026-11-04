class_name OfferingCompass
extends Node3D
## Một chỉ báo cho mỗi phần thưởng đã đáp đất; các hướng giống nhau được phép chồng lên nhau.
@export var targets: Array[OfferingBanana] = []
@export var pulse_speed: float = 7.0
@export var pulse_distance: float = 0.07
var _arrows: Array[Node3D] = []
var _clock: float = 0.0
var _player: Node3D

func _ready() -> void:
	_player = get_parent() as Node3D
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var gold: StandardMaterial3D = _material(Color("ffe92a"))
	var black: StandardMaterial3D = _material(Color("14140e"))
	var halo: StandardMaterial3D = _material(Color(1,0.86,0.05,0.14)); halo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var inside: ArrayMesh = _chevrons(0.024)
	var outline: ArrayMesh = _chevrons(0.038)
	var glow: ArrayMesh = _chevrons(0.067)
	for index: int in targets.size():
		var arrow: Node3D = Node3D.new(); arrow.name = "To_"+targets[index].name; add_child(arrow)
		for layer: int in 3:
			var visual: MeshInstance3D = MeshInstance3D.new(); visual.mesh = [glow,outline,inside][layer]
			visual.material_override = [halo,black,gold][layer]
			visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			visual.position.y = 0.034+index*0.004+layer*0.001
			arrow.add_child(visual)
		_arrows.append(arrow); targets[index].navigation_changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	var any: bool = false
	for index: int in targets.size():
		var item: OfferingBanana = targets[index]
		var active: bool = is_instance_valid(item) and item.was_rewarded and item.available and item.location == OfferingBanana.Location.WORLD
		_arrows[index].visible = active; any = any or active
	set_process(any)

func _process(delta: float) -> void:
	_clock += delta
	global_position = _player.get_global_transform_interpolated().origin
	for index: int in _arrows.size():
		var arrow: Node3D = _arrows[index]
		if not arrow.visible: continue
		var offset: Vector3 = targets[index].global_position-global_position; offset.y = 0
		var direction: Vector3 = offset.normalized()
		arrow.rotation.y = atan2(direction.x,direction.z)
		arrow.position = direction*sin(_clock*pulse_speed)*pulse_distance

static func _material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new(); material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if color.r>0.5:
		material.emission_enabled = true; material.emission = Color(color.r,color.g,color.b); material.emission_energy_multiplier = 0.25
	return material

static func _chevrons(thickness: float) -> ArrayMesh:
	var surface: SurfaceTool = SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for line: int in 3:
		var width: float = 0.32-float(line)*0.055
		var base: float = 0.45+float(line)*0.23
		for segment: int in 16:
			var u: float = -1.0+float(segment)/8.0
			var v: float = u+0.125
			var a: Vector3 = Vector3(u*width,0,base+0.26*(1-absf(u)))
			var b: Vector3 = Vector3(v*width,0,base+0.26*(1-absf(v)))
			var normal: Vector3 = Vector3(-(b.z-a.z),0,b.x-a.x).normalized()*thickness
			for vertex: Vector3 in [a-normal,b-normal,b+normal,a-normal,b+normal,a+normal]: surface.add_vertex(vertex*1.16)
	surface.generate_normals(); return surface.commit()
