class_name MonkeyBattleAura
extends Node3D
## Reused aura and expanding chestbeat rings; no particle nodes allocated per beat.
const FLAME: Shader = preload("res://assets/vfx/enemies/monkey/monkey_aura/monkey_battle_aura.gdshader")
var _buff: bool = false
var _chant: bool = false
var _age: float = 0.0
var _chant_age: float = 0.0
var _flames: Node3D
var _flame_material: ShaderMaterial
var _waves: Array[MeshInstance3D] = []

func _ready() -> void:
	_flames = Node3D.new(); add_child(_flames)
	_flame_material = ShaderMaterial.new(); _flame_material.shader = FLAME
	for i: int in 4:
		var card: MeshInstance3D = MeshInstance3D.new()
		var quad: QuadMesh = QuadMesh.new(); quad.size = Vector2(0.85, 1.65)
		card.mesh = quad; card.material_override = _flame_material
		card.rotation.y = float(i) * PI * 0.5
		card.position = Vector3(sin(card.rotation.y) * 0.28, 0.9, cos(card.rotation.y) * 0.28)
		card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_flames.add_child(card)
	var foot_ring: MeshInstance3D = MeshInstance3D.new()
	var foot_mesh: TorusMesh = TorusMesh.new()
	foot_mesh.inner_radius = 0.49; foot_mesh.outer_radius = 0.54; foot_mesh.rings = 32; foot_mesh.ring_segments = 6
	foot_ring.mesh = foot_mesh; foot_ring.position.y = 0.045
	var foot_material: StandardMaterial3D = StandardMaterial3D.new()
	foot_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	foot_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	foot_material.albedo_color = Color(1.0, 0.035, 0.01, 0.6)
	foot_material.emission_enabled = true; foot_material.emission = Color(1.4, 0.025, 0.005)
	foot_ring.material_override = foot_material
	foot_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flames.add_child(foot_ring)
	for i: int in 4:
		var ring: MeshInstance3D = MeshInstance3D.new()
		var torus: TorusMesh = TorusMesh.new()
		torus.inner_radius = 0.47; torus.outer_radius = 0.5; torus.rings = 36; torus.ring_segments = 6
		ring.mesh = torus; ring.position.y = 1.3
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(1.0, 0.32, 0.1, 0.0)
		material.emission_enabled = true; material.emission = Color(1.0, 0.09, 0.015)
		ring.material_override = material
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring); _waves.append(ring)
	_update_visuals()

func set_buff(active: bool) -> void:
	_buff = active
	set_process(_buff or _chant)
	if is_node_ready(): _update_visuals()

func set_chant(active: bool) -> void:
	if active and not _chant: _chant_age = 0.0
	_chant = active
	set_process(_buff or _chant)
	if is_node_ready(): _update_visuals()

func _process(delta: float) -> void:
	_age += delta
	if _chant: _chant_age += delta
	_update_visuals()

func _update_visuals() -> void:
	_flames.visible = _buff
	_flame_material.set_shader_parameter(&"age", _age)
	for i: int in _waves.size():
		var ring: MeshInstance3D = _waves[i]
		var time: float = _chant_age - 0.85 - float(i) * 0.18
		ring.visible = _chant and time >= 0.0
		if not ring.visible: continue
		var phase: float = fposmod(time, 0.9) / 0.9
		ring.scale = Vector3.ONE * lerpf(0.45, 6.0, phase)
		var mat: StandardMaterial3D = ring.material_override as StandardMaterial3D
		mat.albedo_color.a = (1.0 - phase) * 0.4
