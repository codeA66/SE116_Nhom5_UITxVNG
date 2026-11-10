class_name BananaBombWarning
extends Node3D
@export var warning_color: Color = Color("ff3434")
@export var size_multiplier: float = 0.5
@export var pulse_speed: float = 7.0
@export var pulse_amount: float = 0.12
var _clock: float = 0.0

func _ready() -> void:
	var fill: StandardMaterial3D = StandardMaterial3D.new()
	fill.albedo_color = Color(warning_color,0.23)
	fill.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fill.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	# Billboard mặc định bỏ scale của cha; giữ scale để cả tam giác đập nhịp cùng dấu !.
	fill.billboard_keep_scale = true
	fill.cull_mode = BaseMaterial3D.CULL_DISABLED
	var border: StandardMaterial3D = fill.duplicate() as StandardMaterial3D
	border.albedo_color = Color(warning_color,0.85)
	border.emission_enabled = true; border.emission = warning_color*0.5
	var mesh: ImmediateMesh = ImmediateMesh.new()
	var corners: PackedVector3Array = PackedVector3Array([Vector3(-0.47,-0.32,0),Vector3(0.47,-0.32,0),Vector3(0,0.5,0)])
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES,fill)
	for vertex: Vector3 in corners: mesh.surface_add_vertex(vertex)
	mesh.surface_end()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES,border)
	for index: int in 3:
		var a: Vector3 = corners[index]; var b: Vector3 = corners[(index+1)%3]
		for vertex: Vector3 in [a,b,b*0.85,a,b*0.85,a*0.85]: mesh.surface_add_vertex(vertex)
	mesh.surface_end()
	var surface: MeshInstance3D = MeshInstance3D.new(); surface.mesh = mesh
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(surface)
	var label: Label3D = Label3D.new(); label.text = "!"; label.font_size = 64; label.pixel_size = 0.009
	label.outline_size = 6; label.modulate = Color(warning_color,0.95)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED; label.position.y = 0.03; add_child(label)
	var bomber: BananaBomber = get_parent() as BananaBomber
	bomber.armed.connect(_arm); bomber.died.connect(_stop); bomber.exploded.connect(_stop)
	scale = Vector3.ONE*size_multiplier
	hide(); set_process(false)

func _arm() -> void:
	_clock = 0.0; scale = Vector3.ONE*size_multiplier; show(); set_process(true)

func _stop(_enemy: Enemy = null) -> void:
	hide(); set_process(false)

func _process(delta: float) -> void:
	_clock += delta
	scale = Vector3.ONE*size_multiplier*(1.0+sin(_clock*pulse_speed)*pulse_amount)
