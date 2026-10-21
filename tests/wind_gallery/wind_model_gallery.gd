extends Node3D
## Scene xem và đi thử model mới; mọi collider và override chỉ tồn tại trong scene này.

signal catalog_refreshed(count: int)
signal variant_loaded(asset_path: String, variant_name: String)

const CAMERA_SCRIPT: Script = preload("res://tests/wind_gallery/gallery_camera.gd")
const MODEL_DIRECTORY: String = "res://assets/generated/wind_ruins/gridmap"
const TITLES: Dictionary = {
	"F01": "Cờ chính", "F02": "Cờ rách", "F03": "Cờ đổ", "F04": "Cờ ngang",
	"T01": "Vách đá", "T02": "Góc vách", "T03": "Sàn", "T04": "Mép sạt", "T05": "Cầu thang",
	"A01": "Cột", "A02": "Dầm", "A03": "Tường thấp", "A04": "Mái", "A05": "Lan can",
	"I01": "Nhịp cầu", "I02": "Trụ cầu", "I03": "Máy buồm", "I04": "Trụ gió",
	"I05": "Bến", "I06": "Thuyền", "I07": "Cọc neo", "I08": "Cần hàng",
	"L01": "Cổng", "L02": "Giếng Gió", "L03": "Thư điện", "L04": "Vòng Gió", "L05": "Tháp",
	"D01": "Mảnh vòng", "D02": "Đá đổ", "D03": "Xe hàng", "D04": "Kho hàng", "D05": "Phù điêu",
	"N01": "Cây", "N02": "Cỏ và bụi", "N03": "Rễ", "P01": "Đèn", "P02": "Tường hồ",
	"P03": "Bệ sách", "P04": "Điểm lưu"
}

var asset_paths: PackedStringArray = PackedStringArray()
var variants: Array[Node3D] = []
var selected_bounds: AABB
var current_asset_path: String = ""
var _model_root: Node3D
var _asset_select: OptionButton
var _variant_select: OptionButton
var _view_select: OptionButton
var _material_select: OptionButton
var _details: Label
var _status: Label
var _walk: CheckButton
var _show_fox: CheckButton
var _grid: MeshInstance3D
var _panel: PanelContainer
var _clay: StandardMaterial3D
var _mesh_cache: Array[MeshInstance3D] = []
var _collision_cache: Array[StaticBody3D] = []
var _fox_spawn: Vector3 = Vector3.ZERO

@onready var _stage: Node3D = $ModelStage
@onready var _player: Player = $Player
@onready var _camera: CAMERA_SCRIPT = $InspectionCamera


func _ready() -> void:
	set_physics_process(false)
	_player.process_mode = Node.PROCESS_MODE_DISABLED
	(_player.get_node("HUD") as CanvasLayer).hide()
	(_player.get_node("AnimationPlayer") as AnimationPlayer).process_mode = Node.PROCESS_MODE_ALWAYS
	_camera.make_current()
	_clay = StandardMaterial3D.new()
	_clay.albedo_color = Color(0.45, 0.48, 0.52)
	_clay.roughness = 1.0
	_build_grid()
	_build_ui()
	get_viewport().size_changed.connect(_resize_ui)
	refresh_catalog()


func refresh_catalog() -> void:
	var previous: String = current_asset_path
	asset_paths.clear()
	_asset_select.clear()
	for folder: String in DirAccess.get_directories_at(MODEL_DIRECTORY):
		var directory: String = MODEL_DIRECTORY.path_join(folder)
		for file_name: String in DirAccess.get_files_at(directory):
			if file_name.get_extension().to_lower() == "glb":
				asset_paths.append(directory.path_join(file_name))
	asset_paths.sort()
	for path: String in asset_paths:
		var code: String = path.get_base_dir().get_file().to_upper()
		_asset_select.add_item("%s  %s" % [code, String(TITLES.get(code, "Model"))])
	catalog_refreshed.emit(asset_paths.size())
	if asset_paths.is_empty():
		_status.text = "Chưa có GLB trong thư mục model. Bấm Tải lại sau khi xuất model."
		return
	var selected: int = maxi(0, asset_paths.find(previous))
	if previous.is_empty():
		for i: int in asset_paths.size():
			if asset_paths[i].contains("/f01/"):
				selected = i
				break
	_asset_select.select(selected)
	load_asset(selected)


func load_asset(index: int) -> bool:
	if index < 0 or index >= asset_paths.size():
		return false
	set_walk_enabled(false)
	for child: Node in _stage.get_children():
		_stage.remove_child(child)
		child.queue_free()
	_stage.position = Vector3.ZERO
	_mesh_cache.clear()
	_collision_cache.clear()
	variants.clear()
	_variant_select.clear()
	current_asset_path = asset_paths[index]
	_asset_select.select(index)
	var document: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	var result: Error = document.append_from_file(current_asset_path, state)
	if result != OK:
		_status.text = "Không đọc được model: %s (lỗi %d)" % [current_asset_path, result]
		return false
	_model_root = document.generate_scene(state) as Node3D
	if _model_root == null:
		_status.text = "GLB không sinh được scene 3D."
		return false
	_stage.add_child(_model_root)
	for root_name: String in _gltf_root_names(current_asset_path):
		var candidate: Node3D = _model_root if String(_model_root.name) == root_name else _model_root.find_child(root_name, true, false) as Node3D
		if candidate != null:
			variants.append(candidate)
	if variants.is_empty():
		variants.append(_model_root)
	for variant: Node3D in variants:
		_variant_select.add_item(String(variant.name))
	_collect_meshes(_model_root, _mesh_cache)
	_prepare_vertex_materials()
	for mesh: MeshInstance3D in _mesh_cache:
		mesh.set_meta(&"gallery_material", {"override": mesh.material_override})
		# Collider tạm riêng cho chế độ đi thử, không ghi vào GLB hoặc scene cũ.
		var collider: StaticBody3D = StaticBody3D.new()
		collider.name = "GalleryCollision"
		collider.collision_layer = 0
		collider.collision_mask = 0
		var shape: CollisionShape3D = CollisionShape3D.new()
		shape.shape = mesh.mesh.create_trimesh_shape()
		collider.add_child(shape)
		mesh.add_child(collider)
		_collision_cache.append(collider)
	var preferred: int = 0
	for i: int in variants.size():
		var variant_name: String = String(variants[i].name).to_lower()
		if "intact" in variant_name or "_off_" in variant_name:
			preferred = i
			break
	_variant_select.select(preferred)
	select_variant(preferred)
	_status.text = "%d model • Chỉ thay đổi bản xem thử trong scene này" % asset_paths.size()
	return true


func select_variant(index: int) -> void:
	if index < 0 or index >= variants.size():
		return
	set_walk_enabled(false)
	_stage.position = Vector3.ZERO
	for i: int in variants.size():
		variants[i].visible = i == index
	var active_meshes: Array[MeshInstance3D] = []
	_collect_meshes(variants[index], active_meshes)
	if active_meshes.is_empty():
		return
	selected_bounds = active_meshes[0].global_transform * active_meshes[0].get_aabb()
	var triangles: int = 0
	for mesh: MeshInstance3D in active_meshes:
		selected_bounds = selected_bounds.merge(mesh.global_transform * mesh.get_aabb())
		triangles += int(mesh.mesh.get_faces().size() / 3)
	_stage.position = Vector3(-selected_bounds.get_center().x, -selected_bounds.position.y, -selected_bounds.get_center().z)
	selected_bounds.position += _stage.position
	_fox_spawn = Vector3(-selected_bounds.size.x * 0.5 - 1.5, 0.05, minf(2.0, selected_bounds.size.z * 0.5))
	_player.teleport(_fox_spawn, Vector3.BACK)
	_player.play_anim(Player.ANIM_IDLE)
	set_material_mode(_material_select.selected)
	set_view_mode(_view_select.selected)
	_details.text = "%s\n\nRộng × sâu × cao\n%.2f × %.2f × %.2f m\n\n%s tam giác • %d phần mesh\nCáo tham chiếu ~1,755 m\nModel giữ nguyên tỷ lệ 1:1" % [variants[index].name, selected_bounds.size.x, selected_bounds.size.z, selected_bounds.size.y, str(triangles), active_meshes.size()]
	variant_loaded.emit(current_asset_path, String(variants[index].name))


func _gltf_root_names(path: String) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() < 20:
		return names
	file.seek(12)
	var length: int = file.get_32()
	file.get_32()
	var parsed: Variant = JSON.parse_string(file.get_buffer(length).get_string_from_utf8())
	if not parsed is Dictionary:
		return names
	var doc: Dictionary = parsed as Dictionary
	var scenes: Array = doc.get("scenes", [])
	var nodes: Array = doc.get("nodes", [])
	if scenes.is_empty():
		return names
	var scene_index: int = int(doc.get("scene", 0))
	for root_index: int in scenes[scene_index].get("nodes", []):
		names.append(String(nodes[root_index].get("name", "")))
	return names


func _collect_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		result.append(node as MeshInstance3D)
	for child: Node in node.get_children():
		_collect_meshes(child, result)


func _prepare_vertex_materials() -> void:
	# glTF runtime giữ COLOR_0 nhưng không tự bật màu đỉnh trên material.
	# Chỉ override bản sao tại scene test; không thay resource nhập hoặc GLB gốc.
	var copies: Dictionary = {}
	for mesh: MeshInstance3D in _mesh_cache:
		for surface: int in mesh.mesh.get_surface_count():
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			if not arrays[Mesh.ARRAY_COLOR] is PackedColorArray:
				continue
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] as PackedColorArray
			if colors.is_empty():
				continue
			var original: BaseMaterial3D = mesh.get_active_material(surface) as BaseMaterial3D
			if original == null:
				continue
			if not copies.has(original):
				var duplicate: BaseMaterial3D = original.duplicate() as BaseMaterial3D
				duplicate.vertex_color_use_as_albedo = true
				copies[original] = duplicate
			mesh.set_surface_override_material(surface, copies[original] as Material)


func set_view_mode(index: int) -> void:
	_view_select.select(index)
	if _walk != null and _walk.button_pressed:
		return
	if index == 1:
		_camera.game_view(_fox_spawn)
	else:
		var framed: AABB = selected_bounds.merge(AABB(_fox_spawn, Vector3(0.7, 1.8, 0.7)))
		_camera.frame_bounds(framed)
	_view_select.release_focus()


func set_walk_enabled(enabled: bool) -> void:
	if not is_instance_valid(_player):
		return
	if _walk != null:
		_walk.set_pressed_no_signal(enabled)
	_player.process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
	for collider: StaticBody3D in _collision_cache:
		var mesh: MeshInstance3D = collider.get_parent() as MeshInstance3D
		collider.collision_layer = 1 if enabled and mesh.is_visible_in_tree() else 0
	set_physics_process(enabled)
	if enabled:
		_player.show()
		_show_fox.set_pressed_no_signal(true)
		(_player.get_node("CameraRig/Camera3D") as Camera3D).make_current()
	elif _view_select != null:
		set_view_mode(_view_select.selected)
	if _walk != null:
		_walk.release_focus()


func _physics_process(_delta: float) -> void:
	if _player.position.y < -8.0:
		_player.velocity = Vector3.ZERO
		_player.teleport(_fox_spawn, Vector3.BACK)


func set_material_mode(index: int) -> void:
	_material_select.select(index)
	for mesh: MeshInstance3D in _mesh_cache:
		var original: Dictionary = mesh.get_meta(&"gallery_material") as Dictionary
		mesh.material_override = _clay if index == 1 else original.get("override") as Material
	_material_select.release_focus()


func _build_grid() -> void:
	var lines: PackedVector3Array = PackedVector3Array()
	for i: int in range(-50, 51):
		lines.append_array(PackedVector3Array([Vector3(i, 0.008, -50), Vector3(i, 0.008, 50), Vector3(-50, 0.008, i), Vector3(50, 0.008, i)]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = lines
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.23, 0.26, 0.29)
	_grid = MeshInstance3D.new()
	_grid.name = "MeterGrid"
	_grid.mesh = mesh
	_grid.material_override = material
	_grid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_grid)


func _build_ui() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "GalleryUI"
	add_child(layer)
	_panel = PanelContainer.new()
	_panel.position = Vector2(16, 16)
	_panel.custom_minimum_size = Vector2(316, 0)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.07, 0.095, 0.96)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	_panel.add_theme_stylebox_override("panel", style)
	layer.add_child(_panel)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 6)
	scroll.add_child(column)
	_label(column, "PHÒNG TEST MODEL GIÓ", 19)
	_label(column, "Scene riêng • Lưới 1 mét", 12)
	_asset_select = _option(column, [], _on_asset_selected)
	_variant_select = _option(column, [], _on_variant_selected)
	_view_select = _option(column, ["Camera xoay tự do", "Camera game 50° · FOV 30°"], set_view_mode)
	_material_select = _option(column, ["Màu vật liệu gốc", "Clay kiểm tra hình khối"], set_material_mode)
	_walk = CheckButton.new()
	_walk.text = "Đi thử bằng cáo"
	_walk.toggled.connect(set_walk_enabled)
	column.add_child(_walk)
	_show_fox = CheckButton.new()
	_show_fox.text = "Hiện cáo so tỷ lệ"
	_show_fox.set_pressed_no_signal(true)
	_show_fox.toggled.connect(_on_fox_toggled)
	column.add_child(_show_fox)
	var grid_toggle: CheckButton = CheckButton.new()
	grid_toggle.text = "Hiện lưới 1 m"
	grid_toggle.set_pressed_no_signal(true)
	grid_toggle.toggled.connect(_on_grid_toggled)
	column.add_child(grid_toggle)
	var reset: Button = Button.new()
	reset.text = "Đặt lại cáo và camera"
	reset.pressed.connect(_reset_view)
	column.add_child(reset)
	var reload_button: Button = Button.new()
	reload_button.text = "Tải lại danh sách model"
	reload_button.pressed.connect(refresh_catalog)
	column.add_child(reload_button)
	_details = _label(column, "", 13)
	_details.custom_minimum_size.x = 280.0
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(column, "Giữ chuột phải: xoay\nLăn chuột: zoom\nĐi thử: WASD · Space nhảy", 12)
	_status = _label(column, "Đang đọc model…", 12)
	_status.custom_minimum_size.x = 280.0
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_resize_ui()


func _resize_ui() -> void:
	_panel.size = Vector2(316, maxf(300.0, get_viewport().get_visible_rect().size.y - 32.0))


func _label(parent: Node, text: String, size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)
	return label


func _option(parent: Node, items: Array, action: Callable) -> OptionButton:
	var option: OptionButton = OptionButton.new()
	option.clip_text = true
	option.custom_minimum_size = Vector2(280, 34)
	for text: String in items:
		option.add_item(text)
	option.item_selected.connect(action)
	parent.add_child(option)
	return option


func _on_asset_selected(index: int) -> void:
	load_asset(index)
	_asset_select.release_focus()


func _on_variant_selected(index: int) -> void:
	select_variant(index)
	_variant_select.release_focus()


func _on_fox_toggled(visible_now: bool) -> void:
	if not visible_now:
		set_walk_enabled(false)
	_player.visible = visible_now
	_show_fox.release_focus()


func _on_grid_toggled(visible_now: bool) -> void:
	_grid.visible = visible_now


func _reset_view() -> void:
	set_walk_enabled(false)
	_player.velocity = Vector3.ZERO
	_player.teleport(_fox_spawn, Vector3.BACK)
	_player.play_anim(Player.ANIM_IDLE)
	set_view_mode(_view_select.selected)

