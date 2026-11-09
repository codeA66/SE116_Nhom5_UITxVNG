extends Node3D
## Scene duyệt các bộ model map Lửa: mỗi trang một bộ xếp lưới, trang cuối là phòng mẫu ghép từ fire_kit.
## Trái / phải để đổi trang. Chạy với "-- --capture" để chụp mọi trang vào capture_dir rồi thoát.

const KIT_DIRS: Array[String] = [
	"res://assets/models/map_fire/fire_kit/",
	"res://assets/models/map_fire/inferno_kit/",
	"res://assets/models/map_fire/lavaplant_kit/",
]
const FIRE_KIT: String = "res://assets/models/map_fire/fire_kit/"
const PLAYER_HEIGHT: float = 1.8
const PLAYER_RADIUS: float = 0.35

@export_group("Lưới model")
## Số model mỗi hàng
@export var columns: int = 6
## Khoảng cách tối thiểu giữa các ô (m); model lớn hơn ô sẽ tự giãn hàng/cột
@export var cell_size: float = 7.0
@export_group("Camera")
@export var camera_pitch_degrees: float = -50.0
@export var camera_yaw_degrees: float = 35.0
@export var camera_distance: float = 80.0
@export_group("Chụp ảnh")
@export_dir var capture_dir: String = "res://output/fire_kit/qa/"
## Số frame chờ trước khi chụp để shader và bóng kịp ổn định
@export var capture_wait_frames: int = 20

var _page: int = 0
var _display: Node3D

@onready var _camera: Camera3D = $Camera3D
@onready var _title: Label = $UI/Title


func _ready() -> void:
	_show_page(0)
	if "--capture" in OS.get_cmdline_user_args():
		_capture_all.call_deferred()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_right"):
		_show_page((_page + 1) % _page_count())
	elif event.is_action_pressed(&"ui_left"):
		_show_page((_page + _page_count() - 1) % _page_count())


func _page_count() -> int:
	return KIT_DIRS.size() + 1


func _show_page(index: int) -> void:
	_page = index
	if is_instance_valid(_display):
		remove_child(_display)
		_display.queue_free()
	_display = Node3D.new()
	add_child(_display)
	var bounds: AABB
	if index < KIT_DIRS.size():
		bounds = _build_grid(KIT_DIRS[index])
		_title.text = "%s  (%d/%d)" % [KIT_DIRS[index].trim_suffix("/").get_file(), index + 1, _page_count()]
	else:
		bounds = _build_sample_room()
		_title.text = "Phòng mẫu fire_kit  (%d/%d)" % [index + 1, _page_count()]
	_add_player_marker(bounds.position + Vector3(-1.5, 0.0, -1.5))
	_frame_camera(bounds)


func _list_models(dir_path: String) -> PackedStringArray:
	var names: PackedStringArray = []
	for file: String in DirAccess.get_files_at(dir_path):
		if file.get_extension() == "glb":
			names.append(file)
	names.sort()
	return names


func _build_grid(dir_path: String) -> AABB:
	var models: Array[Node3D] = []
	var sizes: Array[Vector3] = []
	for file: String in _list_models(dir_path):
		var packed: PackedScene = load(dir_path + file) as PackedScene
		if packed == null:
			push_error("Không tải được model: " + dir_path + file)
			continue
		var model: Node3D = packed.instantiate() as Node3D
		# Godot tự đổi tên node trùng khi thêm vào cây, nên lưu tên file để làm nhãn
		model.set_meta(&"model_name", file.get_basename())
		models.append(model)
		sizes.append(_model_aabb(model).size)
	# Cột và hàng giãn theo model lớn nhất trong đó để vách đá lớn không đè lên nhau
	var col_width: Array[float] = []
	col_width.resize(columns)
	col_width.fill(cell_size)
	var row_count: int = ceili(float(models.size()) / float(columns))
	var row_depth: Array[float] = []
	row_depth.resize(row_count)
	row_depth.fill(cell_size)
	for i: int in range(models.size()):
		col_width[i % columns] = maxf(col_width[i % columns], sizes[i].x + 1.5)
		row_depth[i / columns] = maxf(row_depth[i / columns], sizes[i].z + 2.5)
	var bounds: AABB = AABB()
	for i: int in range(models.size()):
		var x: float = 0.0
		for c: int in range(i % columns):
			x += col_width[c]
		var z: float = 0.0
		for r: int in range(i / columns):
			z += row_depth[r]
		var model: Node3D = models[i]
		model.position = Vector3(x + col_width[i % columns] * 0.5, 0.0, z + row_depth[i / columns] * 0.5)
		_display.add_child(model)
		var label: Label3D = Label3D.new()
		label.text = String(model.get_meta(&"model_name"))
		label.font_size = 48
		label.pixel_size = 0.012
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = model.position + Vector3(0.0, sizes[i].y + 0.6, 0.0)
		_display.add_child(label)
		var cell: AABB = AABB(model.position - sizes[i] * Vector3(0.5, 0.0, 0.5), sizes[i])
		bounds = cell if i == 0 else bounds.merge(cell)
	return bounds


## Phòng 12 x 12 m trên nền đỡ giữa biển dung nham, giống ảnh duyệt trong Blender
func _build_sample_room() -> AABB:
	for i: int in range(-3, 6):
		for j: int in range(-3, 6):
			_place("lava_plane_4m", Vector3(i * 4.0, -4.0, j * 4.0))
	for i: int in range(3):
		for j: int in range(3):
			var edge: bool = i != 1 or j != 1
			_place("foundation_edge_4m" if edge else "foundation_4m", Vector3(i * 4.0, -4.0, j * 4.0))
			var floor_name: String = "floor_4m"
			if i == 1 and j == 1:
				floor_name = "floor_lava_grate_4m"
			elif i == 2 and j == 2:
				floor_name = "floor_cracked_4m"
			_place(floor_name, Vector3(i * 4.0, 0.0, j * 4.0))
	var wall_y: float = 0.32
	# Tường sau (phía -Z) có cửa ở giữa
	for i: int in range(3):
		_place("wall_doorway_4m" if i == 1 else "wall_4m", Vector3(i * 4.0, wall_y, -2.4))
	_place("wall_pillar", Vector3(-2.4, wall_y, -2.4))
	# Tường trái, có một đoạn đổ
	_place("wall_4m", Vector3(-2.4, wall_y, 0.0), 90.0)
	_place("wall_broken_4m", Vector3(-2.4, wall_y, 4.0), 90.0)
	# Lan can thấp phía trước
	_place("wall_low_4m", Vector3(0.0, wall_y, 10.4))
	_place("wall_low_4m", Vector3(8.0, wall_y, 10.4))
	# Bên phải: cổng sắt rồi cầu ra ngoài
	_place("wall_4m", Vector3(10.4, wall_y, 0.0), 90.0)
	_place("gate_frame_4m", Vector3(10.4, wall_y, 4.0), 90.0)
	_place("gate_door_4m", Vector3(10.4, wall_y, 4.0), 90.0)
	_place("wall_4m", Vector3(10.4, wall_y, 8.0), 90.0)
	_place("bridge_4m", Vector3(13.5, 0.0, 4.0), 90.0)
	_place("bridge_broken_4m", Vector3(17.5, 0.0, 4.0), 90.0)
	_place("lavafall_4m", Vector3(-4.0, -4.0, 8.0), 90.0)
	_place("portal_frame", Vector3(4.0, wall_y, 2.0))
	return AABB(Vector3(-2.4, -4.0, -2.4), Vector3(22.0, 9.0, 14.8))


func _place(model_name: String, pos: Vector3, yaw_degrees: float = 0.0) -> Node3D:
	var packed: PackedScene = load(FIRE_KIT + model_name + ".glb") as PackedScene
	if packed == null:
		push_error("Không tải được model: " + model_name)
		return null
	var model: Node3D = packed.instantiate() as Node3D
	model.position = pos
	model.rotation_degrees.y = yaw_degrees
	_display.add_child(model)
	return model


## Capsule đúng kích thước va chạm của nhân vật để so tỉ lệ
func _add_player_marker(pos: Vector3) -> void:
	var mesh: CapsuleMesh = CapsuleMesh.new()
	mesh.height = PLAYER_HEIGHT
	mesh.radius = PLAYER_RADIUS
	var marker: MeshInstance3D = MeshInstance3D.new()
	marker.mesh = mesh
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color("3fa9ff")
	marker.material_override = material
	marker.position = pos + Vector3(0.0, PLAYER_HEIGHT * 0.5, 0.0)
	_display.add_child(marker)


func _model_aabb(root: Node3D) -> AABB:
	var result: AABB = AABB()
	var first: bool = true
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var instance: MeshInstance3D = node as MeshInstance3D
		# Model chưa vào cây nên tự cộng dồn transform từ instance lên root
		var xform: Transform3D = Transform3D.IDENTITY
		var walker: Node = instance
		while walker != root and walker is Node3D:
			xform = (walker as Node3D).transform * xform
			walker = walker.get_parent()
		var box: AABB = xform * instance.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result


func _frame_camera(bounds: AABB) -> void:
	var center: Vector3 = bounds.get_center()
	var basis: Basis = Basis.from_euler(Vector3(deg_to_rad(camera_pitch_degrees), deg_to_rad(camera_yaw_degrees), 0.0))
	_camera.size = maxf(bounds.size.x, bounds.size.z) * 0.95 + 4.0
	_camera.global_transform = Transform3D(basis, center + basis.z * camera_distance)


func _capture_all() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(capture_dir))
	for index: int in range(_page_count()):
		_show_page(index)
		for _frame: int in range(capture_wait_frames):
			await get_tree().process_frame
		var image: Image = get_viewport().get_texture().get_image()
		var path: String = capture_dir.path_join("fire_gallery_page_%d.png" % index)
		var error: Error = image.save_png(path)
		if error != OK:
			push_error("Không lưu được ảnh: " + path)
		else:
			print("Đã chụp: ", ProjectSettings.globalize_path(path))
	get_tree().quit()
