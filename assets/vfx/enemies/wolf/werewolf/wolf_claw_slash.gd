class_name WolfClawSlash
extends Node3D
## Ba vệt móng, gió mỏng và dư ảnh; mesh dựng sẵn, dùng lại theo pool.
signal finished
const ARC: Shader = preload("res://assets/vfx/enemies/wolf/werewolf/claw_arc.gdshader")
static var _horizontal: ArrayMesh
static var _vertical: ArrayMesh
var _materials: Array[ShaderMaterial] = []
var _flat: Array[MeshInstance3D] = []
var _down: Array[MeshInstance3D] = []
var _age: float = 0.0
var _sweep: float = 0.15

func _ready() -> void:
	set_as_top_level(true)
	if _horizontal==null: _horizontal=_build(false);_vertical=_build(true)
	for layer: int in 3:
		var mat: ShaderMaterial=ShaderMaterial.new();mat.shader=ARC;mat.set_shader_parameter(&"layer",layer)
		_materials.append(mat)
		_flat.append(_mesh(_horizontal,mat))
		for side: int in [-1,1]:
			var down: MeshInstance3D=_mesh(_vertical,mat);down.position.x=float(side)*.5
			_down.append(down)
	if get_parent() is ObjectPool:finished.connect((get_parent() as ObjectPool).release.bind(self))
	pool_released()

func play(at: Transform3D, combo: ClawComboSkillData, index: int, duration: float) -> void:
	global_transform=at
	_age=0.0;_sweep=maxf(duration,.02)
	var down: bool=index==3
	for mesh: MeshInstance3D in _flat:
		mesh.visible=not down
		mesh.scale=Vector3.ONE*combo.slash_radius
		mesh.position.y=combo.slash_height
		mesh.rotation.z=.10 if index%2==0 else -.10
	for mesh: MeshInstance3D in _down:
		mesh.visible=down;mesh.scale=Vector3.ONE*combo.slash_radius;mesh.position.y=.9
	for mat: ShaderMaterial in _materials:
		mat.set_shader_parameter(&"sweep_time",_sweep)
		mat.set_shader_parameter(&"arc_radians",deg_to_rad(combo.slash_arc_degrees))
		mat.set_shader_parameter(&"reverse",1.0 if index==1 else 0.0)
	visible=true;set_process(true);seek(0.0)

func seek(seconds: float) -> void:
	_age=seconds
	for mat: ShaderMaterial in _materials:mat.set_shader_parameter(&"age",_age)

func _process(delta: float) -> void:
	seek(_age+delta)
	if _age>=_sweep+.15:finished.emit()

func pool_released() -> void:
	visible=false;set_process(false)

func _mesh(mesh: ArrayMesh,material: Material) -> MeshInstance3D:
	var node: MeshInstance3D=MeshInstance3D.new();node.mesh=mesh;node.material_override=material
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node);return node

static func _build(down: bool) -> ArrayMesh:
	var verts: PackedVector3Array=PackedVector3Array()
	var uv: PackedVector2Array=PackedVector2Array()
	var colors: PackedColorArray=PackedColorArray()
	var indices: PackedInt32Array=PackedInt32Array()
	for claw: int in 3:
		var start: int=verts.size()
		for step: int in 81:
			var u: float=float(step)/80.0
			var angle: float=lerpf(1.2,-.35,u) if down else lerpf(-1.265,1.265,u)
			var radius: float=.82+float(claw)*.055
			var width: float=.075*pow(maxf(sin(u*PI),0.0),.65)
			for side: int in 2:
				var r: float=radius+(float(side)-.5)*width
				verts.append(Vector3(float(claw-1)*.045,sin(angle)*r*.8,cos(angle)*r) if down else Vector3(sin(angle)*r,float(claw-1)*.055,cos(angle)*r))
				uv.append(Vector2(u,float(side)))
				colors.append(Color(1.0 if down else 0.0,0,0,1))
			if step<80:
				var a: int=start+step*2;indices.append_array(PackedInt32Array([a,a+1,a+2,a+1,a+3,a+2]))
	var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=verts;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_INDEX]=indices
	arrays[Mesh.ARRAY_COLOR]=colors
	var mesh: ArrayMesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);return mesh
