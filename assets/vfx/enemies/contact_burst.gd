extends Node3D
## Một vòng bụi và sáu nét ngắn tại điểm giẫm/trúng; tự tắt xử lý khi xong.
var _parts: Array[MeshInstance3D] = []
var _material: StandardMaterial3D
var _age: float = -1.0

func _ready() -> void:
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var ring: MeshInstance3D = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.32
	torus.outer_radius = 0.38
	torus.rings = 16
	torus.ring_segments = 6
	ring.mesh = torus
	add_child(ring)
	_parts.append(ring)
	for i: int in 6:
		var part: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(0.045, 0.05, 0.2)
		part.mesh = box
		part.rotation.y = float(i) * TAU / 6.0
		add_child(part)
		_parts.append(part)
	for part: MeshInstance3D in _parts:
		part.material_override = _material
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false
	set_process(false)

func play(color: Color) -> void:
	_material.albedo_color = color
	_material.emission_enabled = true
	_material.emission = color * 0.15
	_age = 0.0
	visible = true
	set_process(true)
	_process(0.0)

func _process(delta: float) -> void:
	_age += delta
	var progress: float = clampf(_age / 0.35, 0.0, 1.0)
	_parts[0].scale = Vector3.ONE * lerpf(0.35, 1.8, progress)
	for i: int in 6:
		var angle: float = float(i) * TAU / 6.0
		_parts[i + 1].position = Vector3(sin(angle), 0.0, cos(angle)) * (0.15 + progress * 0.6) + Vector3.UP * sin(progress * PI) * 0.15
	_material.albedo_color.a = 1.0 - progress
	if progress >= 1.0:
		visible = false
		set_process(false)
