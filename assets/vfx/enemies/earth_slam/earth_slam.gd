class_name EarthSlam
extends Node3D
## Đá khối, bụi, mảnh vụn và nứt đất; chạy xong trả về pool.
signal finished
const STONE: Shader=preload("res://assets/vfx/enemies/earth_slam/earth_stone.gdshader")
const DUST: Shader=preload("res://assets/vfx/enemies/earth_slam/earth_dust.gdshader")
const GROUND: Shader=preload("res://assets/vfx/enemies/earth_slam/earth_ground.gdshader")
const BASE_RADIUS: float=2.8
const ROCK_COUNT: int=52
var _materials: Array[ShaderMaterial]=[]
var age: float=-1.0

func _ready() -> void:
	set_as_top_level(true)
	var rng: RandomNumberGenerator=RandomNumberGenerator.new();rng.seed=7894
	var stone: ArrayMesh=_rock_mesh()
	var rocks: MultiMesh=_batch(stone,_material(STONE),ROCK_COUNT)
	# Cụm cao xen đá vừa và vụn sát đất, rải tự do thay vì hàng cọc tròn đều.
	for i: int in ROCK_COUNT:
		var a: float=rng.randf()*TAU
		var large: bool=i<14
		var rubble: bool=i>=32
		var r: float=rng.randf_range(1.15,2.15) if large else rng.randf_range(.65,2.5)
		var width: float=rng.randf_range(.26,.5) if large else rng.randf_range(.12,.38)
		var height: float=rng.randf_range(.7,1.5) if large else rng.randf_range(.18,.8)
		if rubble: height=rng.randf_range(.08,.3)
		var basis_value: Basis=Basis.from_euler(Vector3(rng.randf_range(-.5,.5),rng.randf()*TAU,rng.randf_range(-.4,.4)))
		basis_value=basis_value.scaled(Vector3(width,height,width*rng.randf_range(.65,1.35)))
		rocks.set_instance_transform(i,Transform3D(basis_value,Vector3(cos(a)*r,-.015,sin(a)*r)))
		rocks.set_instance_custom_data(i,Color(rng.randf(),rng.randf(),rng.randf(),1))
	var debris_mat: ShaderMaterial=_material(STONE);debris_mat.set_shader_parameter(&"debris",true)
	var debris: MultiMesh=_batch(stone,debris_mat,48)
	for i: int in 48:
		var a: float=rng.randf()*TAU
		var at: Vector3=Vector3(cos(a),.1,sin(a))*rng.randf_range(.3,1.3)
		var b: Basis=Basis.from_euler(Vector3(rng.randf(),rng.randf(),rng.randf())*TAU).scaled(Vector3.ONE*rng.randf_range(.08,.19))
		debris.set_instance_transform(i,Transform3D(b,at));debris.set_instance_custom_data(i,Color(a/TAU,rng.randf(),rng.randf(),1))
	var quad: QuadMesh=QuadMesh.new();quad.size=Vector2(1.7,1.5)
	var dust: MultiMesh=_batch(quad,_material(DUST),18)
	for i: int in 18:
		var a: float=float(i)*TAU/18.0;var r: float=rng.randf_range(1.0,2.3)
		dust.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3(cos(a)*r,.25,sin(a)*r)))
		dust.set_instance_custom_data(i,Color(a/TAU,rng.randf(),rng.randf(),1))
	var plane: PlaneMesh=PlaneMesh.new();plane.size=Vector2(BASE_RADIUS*2,BASE_RADIUS*2)
	var ground: MeshInstance3D=MeshInstance3D.new();ground.mesh=plane;ground.material_override=_material(GROUND)
	ground.position.y=.035;ground.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(ground)
	if get_parent() is ObjectPool:finished.connect((get_parent() as ObjectPool).release.bind(self))
	pool_released()

func play(at: Vector3,radius: float) -> void:
	global_position=at;global_rotation=Vector3(0.0,randf()*TAU,0.0)
	scale=Vector3(radius/BASE_RADIUS,1.0,radius/BASE_RADIUS)
	visible=true;set_process(true);seek(0.0)

func seek(seconds: float) -> void:
	age=seconds
	for mat: ShaderMaterial in _materials:mat.set_shader_parameter(&"age",age)

func _process(delta: float) -> void:
	seek(age+delta)
	if age>=1.15:finished.emit()

func pool_released() -> void:
	visible=false;set_process(false)

func _material(shader: Shader) -> ShaderMaterial:
	var mat: ShaderMaterial=ShaderMaterial.new();mat.shader=shader;_materials.append(mat);return mat

func _batch(mesh: Mesh,material: Material,count: int) -> MultiMesh:
	var mm: MultiMesh=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_custom_data=true;mm.mesh=mesh;mm.instance_count=count
	var node: MultiMeshInstance3D=MultiMeshInstance3D.new();node.multimesh=mm;node.material_override=material
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.custom_aabb=AABB(Vector3(-6,-1,-6),Vector3(12,7,12));add_child(node);return mm

func _rock_mesh() -> ArrayMesh:
	var vertices: PackedVector3Array=PackedVector3Array();var normals: PackedVector3Array=PackedVector3Array()
	for side: int in 5:
		var a: float=float(side)*TAU/5;var b: float=float(side+1)*TAU/5
		var low: Vector3=Vector3(cos(a)*.7,0,sin(a)*.7);var next: Vector3=Vector3(cos(b)*.7,0,sin(b)*.7)
		var mid: Vector3=Vector3(cos(a)*.65,.35,sin(a)*.65);var next_mid: Vector3=Vector3(cos(b)*.65,.35,sin(b)*.65)
		for tri: Array in [[low,mid,next_mid],[low,next_mid,next],[mid,Vector3(.25,1.25,-.12),next_mid]]:
			var p: Vector3=tri[0];var q: Vector3=tri[1];var r: Vector3=tri[2]
			var normal: Vector3=(q-p).cross(r-p).normalized()
			for point: Vector3 in tri:vertices.append(point);normals.append(normal)
	var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals
	var mesh: ArrayMesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);return mesh
