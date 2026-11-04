class_name BananaItemModels
extends RefCounted

static func material(color: Color) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new(); mat.albedo_color = color; mat.roughness = 0.85
	return mat

static func fruit(color: Color) -> MeshInstance3D:
	var model: MeshInstance3D = MeshInstance3D.new(); model.mesh = BananaGeometry.fruit(); model.material_override = material(color)
	model.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; return model

static func shoe() -> Node3D:
	var root: Node3D = Node3D.new()
	var body: MeshInstance3D = MeshInstance3D.new(); body.mesh = _boot_mesh()
	var gold: StandardMaterial3D = material(Color("f7ce26")); gold.emission_enabled = true
	gold.emission = Color(0.32,0.21,0.015); gold.emission_energy_multiplier = 0.15
	body.material_override = gold; root.add_child(body)
	var cuff: MeshInstance3D = MeshInstance3D.new(); var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = 0.086; mesh.bottom_radius = 0.098; mesh.height = 0.085; mesh.radial_segments = 8
	cuff.mesh = mesh; cuff.material_override = gold; cuff.position = Vector3(0,0.16,-0.045); root.add_child(cuff)
	var strap: MeshInstance3D = MeshInstance3D.new(); var band: BoxMesh = BoxMesh.new(); band.size = Vector3(0.19,0.018,0.18)
	strap.mesh = band; strap.material_override = material(Color("856b23")); strap.position = Vector3(0,0.15,-0.04); root.add_child(strap)
	return root

static func _boot_mesh() -> ArrayMesh:
	var surface: SurfaceTool = SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Mũi cong và thu nhọn như quả chuối, cổ ôm chân; tránh hình hộp phủ kín hai bàn chân.
	var sections: Array[Vector4] = [Vector4(-0.13,0.08,0.0,0.14),Vector4(-0.02,0.098,0.0,0.15),Vector4(0.11,0.09,0.005,0.10),Vector4(0.24,0.055,0.035,0.095),Vector4(0.30,0.008,0.07,0.115)]
	var rings: Array[PackedVector3Array] = []
	for section: Vector4 in sections:
		var width: float = section.y; var bottom: float = section.z; var top: float = section.w
		rings.append(PackedVector3Array([Vector3(-width,bottom,section.x),Vector3(-width,bottom+0.04,section.x),Vector3(-width*0.7,top,section.x),Vector3(0,top+0.01,section.x),Vector3(width*0.7,top,section.x),Vector3(width,bottom+0.04,section.x),Vector3(width,bottom,section.x),Vector3(0,bottom-0.01,section.x)]))
	for segment: int in rings.size()-1:
		for side: int in 8:
			var next: int = (side+1)%8
			for vertex: Vector3 in [rings[segment][side],rings[segment+1][side],rings[segment+1][next],rings[segment][side],rings[segment+1][next],rings[segment][next]]: surface.add_vertex(vertex)
	for end: int in [0,rings.size()-1]:
		var center: Vector3 = Vector3(0,0.07,sections[end].x)
		for side: int in 8:
			var a: Vector3 = rings[end][side]; var b: Vector3 = rings[end][(side+1)%8]
			for vertex: Vector3 in ([center,a,b] if end==0 else [center,b,a]): surface.add_vertex(vertex)
	surface.generate_normals(); return surface.commit()

static func boots_pair() -> Node3D:
	var root: Node3D = Node3D.new()
	for side: float in [-1.0,1.0]:
		var boot: Node3D = shoe(); root.add_child(boot); boot.position.x = side*0.13; boot.scale = Vector3.ONE*1.65
	return root
