class_name RadialMagmaHazard
extends Node3D
## Quản lý 8 nhánh đá Magma tỏa tròn 360 độ từ tâm giậm đất của Boss.

signal finished

const MagmaHazardScript = preload("res://entities/bosses/boss_1/hazards/magma_spike/magma_hazard.gd")

@export var spoke_count: int = 8
@export var magma_hazard_scene: PackedScene

var _spikes: Array[Node3D] = []
var _active_count: int = 0

var _telegraph_container: Node3D = null
var _telegraph_pivots: Array[Node3D] = []
var _telegraph_fills: Array[MeshInstance3D] = []
var _telegraph_lines: Array[MeshInstance3D] = []
var _telegraph_timer: float = 0.0
var _telegraph_duration: float = 0.0
var _telegraph_active: bool = false


func _ready() -> void:
	set_as_top_level(true)
	set_process(false)
	_build_spokes()
	_build_telegraphs()


func _build_spokes() -> void:
	if magma_hazard_scene == null:
		return
	
	for i: int in spoke_count:
		var spike: Node3D = magma_hazard_scene.instantiate() as Node3D
		spike.name = "Spoke_%d" % i
		if spike.has_signal(&"finished"):
			spike.connect(&"finished", _on_spoke_finished)
		add_child(spike)
		_spikes.append(spike)


func _create_wedge_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var p0 := Vector3(-0.35, 0.02, 0.6)
	var p1 := Vector3( 0.35, 0.02, 0.6)
	var p2 := Vector3( 1.25, 0.02, 7.3)
	var p3 := Vector3(-1.25, 0.02, 7.3)
	
	st.set_uv(Vector2(0, 0)); st.add_vertex(p0)
	st.set_uv(Vector2(1, 0)); st.add_vertex(p1)
	st.set_uv(Vector2(1, 1)); st.add_vertex(p2)
	
	st.set_uv(Vector2(0, 0)); st.add_vertex(p0)
	st.set_uv(Vector2(1, 1)); st.add_vertex(p2)
	st.set_uv(Vector2(0, 1)); st.add_vertex(p3)
	
	return st.commit()


func _create_wedge_outline() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINE_STRIP)
	
	var p0 := Vector3(-0.35, 0.025, 0.6)
	var p1 := Vector3( 0.35, 0.025, 0.6)
	var p2 := Vector3( 1.25, 0.025, 7.3)
	var p3 := Vector3(-1.25, 0.025, 7.3)
	
	st.add_vertex(p0)
	st.add_vertex(p1)
	st.add_vertex(p2)
	st.add_vertex(p3)
	st.add_vertex(p0)
	
	return st.commit()


func _build_telegraphs() -> void:
	if _telegraph_container != null:
		return
	
	_telegraph_container = Node3D.new()
	_telegraph_container.name = "TelegraphContainer"
	_telegraph_container.visible = false
	add_child(_telegraph_container)
	
	var wedge_mesh := _create_wedge_mesh()
	var outline_mesh := _create_wedge_outline()
	
	for i: int in spoke_count:
		var angle: float = float(i) * (TAU / float(spoke_count))
		var facing: Vector3 = Vector3(cos(angle), 0.0, sin(angle)).normalized()
		
		var pivot := Node3D.new()
		pivot.name = "TelegraphPivot_%d" % i
		pivot.rotation.y = atan2(facing.x, facing.z)
		_telegraph_container.add_child(pivot)
		_telegraph_pivots.append(pivot)
		
		# Mặt sàn hình nan quạt bán trong suốt
		var fill := MeshInstance3D.new()
		fill.name = "WedgeFill"
		fill.mesh = wedge_mesh
		fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		
		var fill_mat := StandardMaterial3D.new()
		fill_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fill_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		fill_mat.albedo_color = Color(1.0, 0.28, 0.05, 0.35)
		fill.material_override = fill_mat
		pivot.add_child(fill)
		_telegraph_fills.append(fill)
		
		# Đường viền hình nan quạt sắc nét
		var line := MeshInstance3D.new()
		line.name = "WedgeLine"
		line.mesh = outline_mesh
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		
		var line_mat := StandardMaterial3D.new()
		line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		line_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		line_mat.albedo_color = Color(1.0, 0.15, 0.02, 0.85)
		line.material_override = line_mat
		pivot.add_child(line)
		_telegraph_lines.append(line)


func _find_floor(pos: Vector3) -> Vector3:
	var floor_pos := pos
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		pos + Vector3.UP * 2.0,
		pos + Vector3.DOWN * 10.0,
		1 # World / terrain collision mask
	)
	var hit: Dictionary = space_state.intersect_ray(query)
	if not hit.is_empty():
		floor_pos.y = (hit["position"] as Vector3).y
	return floor_pos


func show_telegraph(origin: Vector3, duration: float) -> void:
	if _telegraph_container == null:
		_build_telegraphs()
	
	var floor_pos := _find_floor(origin)
	global_position = floor_pos
	_telegraph_timer = 0.0
	_telegraph_duration = maxf(duration, 0.01)
	_telegraph_active = true
	_telegraph_container.visible = true
	set_process(true)
	_update_telegraph(0.0)


func hide_telegraph() -> void:
	_telegraph_active = false
	if _telegraph_container:
		_telegraph_container.visible = false
	set_process(false)


func _process(delta: float) -> void:
	if not _telegraph_active:
		set_process(false)
		return
	_telegraph_timer += delta
	var progress := clampf(_telegraph_timer / _telegraph_duration, 0.0, 1.0)
	_update_telegraph(progress)
	if _telegraph_timer >= _telegraph_duration:
		hide_telegraph()


func _update_telegraph(progress: float) -> void:
	# Quạt loe dần từ gốc ra xa và sáng rực dần theo progress
	var eased_p := ease(progress, 0.7)
	for pivot: Node3D in _telegraph_pivots:
		pivot.scale.z = maxf(eased_p, 0.01)
		pivot.scale.x = lerpf(0.4, 1.0, eased_p)
	
	for fill: MeshInstance3D in _telegraph_fills:
		var mat := fill.material_override as StandardMaterial3D
		if mat:
			mat.albedo_color.a = lerpf(0.2, 0.55, eased_p)
	
	for line: MeshInstance3D in _telegraph_lines:
		var mat := line.material_override as StandardMaterial3D
		if mat:
			mat.albedo_color.a = lerpf(0.5, 0.95, eased_p)


func launch(origin: Vector3, attack_data: AttackData) -> void:
	hide_telegraph()
	if _spikes.is_empty():
		_build_spokes()
	
	# Tìm cao độ sàn đấu bằng raycast
	var floor_pos := _find_floor(origin)
	global_position = floor_pos
	_active_count = _spikes.size()
	
	for i: int in _spikes.size():
		var angle: float = float(i) * (TAU / float(spoke_count))
		var facing: Vector3 = Vector3(cos(angle), 0.0, sin(angle)).normalized()
		if _spikes[i].has_method(&"start"):
			_spikes[i].call(&"start", attack_data, floor_pos, facing)


func cancel() -> void:
	hide_telegraph()
	for spike: Node3D in _spikes:
		if spike.has_method(&"cancel"):
			spike.call(&"cancel")
	_active_count = 0
	finished.emit()


func _on_spoke_finished() -> void:
	_active_count = maxi(_active_count - 1, 0)
	if _active_count == 0:
		finished.emit()
