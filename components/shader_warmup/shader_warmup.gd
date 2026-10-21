class_name ShaderWarmup
extends Node
## Renderer Compatibility biên dịch shader vào lần đầu một vật liệu được vẽ, nên lần đầu chém trúng, thổi gió,
## quái chết... bị đứng hình 0.2–0.5 s. Renderer này không có precompile; tài liệu Godot khuyên cho mọi vật liệu
## hiện ít nhất một frame lúc nạp màn. Node này làm việc đó khi vào khu, lúc màn còn phủ đen.
## Tự quét mesh / multimesh / particle 3D và CanvasItem có material trong khu và autoload (pool hiệu ứng), cộng thêm
## node / scene / material do group SOURCE_GROUP đưa ra (quái chờ trận...) và data.extra_scenes.
## Hiệu ứng mới nằm sẵn trong khu hoặc pool thì không cần khai báo gì thêm.

signal finished

## Node trong group này có hàm get_shader_warmup_sources() -> Array gồm Node chưa nằm trong cây, PackedScene hoặc Material
const SOURCE_GROUP := &"shader_warmup_source"
## Lớp phủ đen nằm trên mọi UI trong lúc vẽ bản sao
const OVERLAY_LAYER := 128
## Kích thước ô vẽ material 2D (px)
const CANVAS_PROBE_SIZE := Vector2(16, 16)

@export var data: ShaderWarmupData

## Mỗi tổ hợp (kiểu vẽ + vật liệu) chỉ vẽ một bản: map lớn vẫn chỉ vài chục bản sao
var _seen: Dictionary[String, bool] = {}
var _temp_instances: Array[Node] = []
var _rig: Node3D
var _canvas: CanvasLayer
var _overlay: CanvasLayer
var _material_quad: QuadMesh


## Vẽ bản sao trong data.frames frame rồi dọn sạch. Gọi sau khi camera đã về đúng chỗ
func run(scene_root: Node, camera: Camera3D) -> void:
	if data == null or camera == null or (data.skip_when_headless and DisplayServer.get_name() == "headless"):
		finished.emit()
		return
	_build_layers(camera)
	_collect(scene_root)
	for node in get_tree().root.get_children():
		if node != scene_root:
			_collect(node)
	for source in get_tree().get_nodes_in_group(SOURCE_GROUP):
		if source.has_method(&"get_shader_warmup_sources"):
			for item: Variant in source.call(&"get_shader_warmup_sources"):
				_collect_item(item)
	for scene in data.extra_scenes:
		_collect_item(scene)
	for i in data.frames:
		await RenderingServer.frame_post_draw
	for instance in _temp_instances:
		instance.free()
	_temp_instances.clear()
	_rig.queue_free()
	_canvas.queue_free()
	_overlay.queue_free()
	finished.emit()


func _build_layers(camera: Camera3D) -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = OVERLAY_LAYER
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(black)
	add_child(_overlay)
	# Bản sao 2D vẽ dưới lớp phủ đen: vẫn được vẽ (nên được biên dịch) nhưng người chơi không thấy
	_canvas = CanvasLayer.new()
	_canvas.layer = OVERLAY_LAYER - 1
	add_child(_canvas)
	_rig = Node3D.new()
	add_child(_rig)
	_rig.global_transform = camera.global_transform.translated_local(Vector3(0.0, 0.0, -data.distance_from_camera))
	_rig.reset_physics_interpolation()


func _collect_item(item: Variant) -> void:
	if item is PackedScene:
		# Không đưa vào cây: script của scene không chạy _ready nên không có tác dụng phụ
		var instance := (item as PackedScene).instantiate()
		_temp_instances.append(instance)
		_collect(instance)
	elif item is Material:
		_add_material(item as Material)
	elif item is Node:
		_collect(item as Node)


func _collect(root: Node) -> void:
	if root == null or root == self or is_ancestor_of(root):
		return
	var nodes: Array[Node] = [root]
	nodes.append_array(root.find_children("*", "", true, false))
	for node in nodes:
		if node == self or is_ancestor_of(node):
			continue
		if node is GeometryInstance3D:
			_add_3d(node as GeometryInstance3D)
		elif node is CanvasItem:
			_add_2d(node as CanvasItem)


func _add_3d(node: GeometryInstance3D) -> void:
	var key := _key_3d(node)
	if key.is_empty() or _seen.has(key):
		return
	_seen[key] = true
	var copy := _copy_3d(node)
	copy.visible = true
	copy.cast_shadow = node.cast_shadow
	copy.transparency = node.transparency
	_rig.add_child(copy)
	if copy is GPUParticles3D:
		(copy as GPUParticles3D).restart()
	elif copy is CPUParticles3D:
		(copy as CPUParticles3D).restart()


## Material tạo lúc chạy (chưa gắn vào node nào): vẽ lên một ô vuông
func _add_material(material: Material) -> void:
	var key := "Material|%s" % _id(material)
	if _seen.has(key):
		return
	_seen[key] = true
	if _material_quad == null:
		_material_quad = QuadMesh.new()
	var quad := MeshInstance3D.new()
	quad.mesh = _material_quad
	quad.material_override = material
	_rig.add_child(quad)


func _add_2d(node: CanvasItem) -> void:
	var particles := node is GPUParticles2D or node is CPUParticles2D
	# Không có material riêng thì dùng shader canvas mặc định, giao diện đã biên dịch từ lúc mở game
	if node.material == null and not particles:
		return
	var key := "%s|%s" % [node.get_class() if particles else "Canvas", _id(node.material)]
	if node is GPUParticles2D:
		key += "|%s" % _id((node as GPUParticles2D).process_material)
	if _seen.has(key):
		return
	_seen[key] = true
	var copy: CanvasItem
	if particles:
		copy = node.duplicate(0) as CanvasItem
		for child in copy.get_children():
			child.free()
		(copy as Node2D).position = CANVAS_PROBE_SIZE
	else:
		var rect := ColorRect.new()
		rect.size = CANVAS_PROBE_SIZE
		rect.material = node.material
		copy = rect
	copy.visible = true
	_canvas.add_child(copy)
	if copy is GPUParticles2D:
		var gp := copy as GPUParticles2D
		gp.one_shot = false
		gp.restart()
	elif copy is CPUParticles2D:
		var cp := copy as CPUParticles2D
		cp.one_shot = false
		cp.restart()


## Khóa nhận dạng: cùng kiểu vẽ (thường / instancing) + cùng vật liệu + cùng chế độ bóng thì cùng một shader
func _key_3d(node: GeometryInstance3D) -> String:
	var parts := PackedStringArray([node.get_class(), str(node.cast_shadow), str(node.transparency > 0.0), _id(node.material_override), _id(node.material_overlay)])
	if node is MeshInstance3D:
		var mesh := (node as MeshInstance3D).mesh
		if mesh == null:
			return ""
		for i in mesh.get_surface_count():
			parts.append(_id((node as MeshInstance3D).get_active_material(i)))
	elif node is MultiMeshInstance3D:
		var multimesh := (node as MultiMeshInstance3D).multimesh
		if multimesh == null or multimesh.mesh == null:
			return ""
		parts.append_array([_id(multimesh.mesh), str(multimesh.transform_format), str(multimesh.use_colors), str(multimesh.use_custom_data)])
	elif node is GPUParticles3D:
		var gpu := node as GPUParticles3D
		parts.append(_id(gpu.process_material))
		for i in gpu.draw_passes:
			parts.append(_id(gpu.get_draw_pass_mesh(i)))
	elif node is CPUParticles3D:
		parts.append(_id((node as CPUParticles3D).mesh))
	return "|".join(parts)


func _copy_3d(node: GeometryInstance3D) -> GeometryInstance3D:
	if node is MeshInstance3D:
		# Tạo mới thay vì duplicate: không kéo theo skin / skeleton, vẽ tư thế gốc là đủ để biên dịch
		var source := node as MeshInstance3D
		var mesh_copy := MeshInstance3D.new()
		mesh_copy.mesh = source.mesh
		for i in source.mesh.get_surface_count():
			mesh_copy.set_surface_override_material(i, source.get_active_material(i))
		mesh_copy.material_overlay = source.material_overlay
		return mesh_copy
	if node is MultiMeshInstance3D:
		# Một instance là đủ; multimesh gốc có thể đang 0 instance (hiệu ứng chưa phát)
		var multimesh := (node as MultiMeshInstance3D).multimesh.duplicate() as MultiMesh
		multimesh.instance_count = 1
		multimesh.visible_instance_count = -1
		if multimesh.transform_format == MultiMesh.TRANSFORM_2D:
			multimesh.set_instance_transform_2d(0, Transform2D.IDENTITY)
		else:
			multimesh.set_instance_transform(0, Transform3D.IDENTITY)
		if multimesh.use_colors:
			multimesh.set_instance_color(0, Color.WHITE)
		if multimesh.use_custom_data:
			multimesh.set_instance_custom_data(0, Color(0.0, 0.0, 0.0, 0.0))
		var multi_copy := MultiMeshInstance3D.new()
		multi_copy.multimesh = multimesh
		multi_copy.material_override = node.material_override
		multi_copy.material_overlay = node.material_overlay
		return multi_copy
	# Particle, sprite, label...: bản sao không kèm script / signal / group, bỏ node con
	var copy := node.duplicate(0) as GeometryInstance3D
	for child in copy.get_children():
		child.free()
	copy.transform = Transform3D.IDENTITY
	if copy is GPUParticles3D:
		var gpu := copy as GPUParticles3D
		gpu.one_shot = false
		gpu.sub_emitter = NodePath()
	elif copy is CPUParticles3D:
		(copy as CPUParticles3D).one_shot = false
	return copy


func _id(resource: Resource) -> String:
	return str(resource.get_instance_id()) if resource else "-"
