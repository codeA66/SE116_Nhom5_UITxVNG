class_name RoomFocus
extends Node
## Nhìn phòng kiểu game sinh tồn góc trên xuống: phòng player đang đứng sáng bình thường, các phòng khác vẫn thấy nhưng
## tối đi (shade_alpha: thay vật liệu mesh phòng bằng bản tối, màu + phát sáng nhân 1 - shade_alpha).
## Không dùng lớp phủ trong suốt / decal: renderer Compatibility vẽ lớp phủ một lần mỗi đèn (tối gần đen) và không có decal. Quái chỉ hiện khi ở trong phòng đang đứng (ngoài mọi phòng thì luôn hiện).
## Tường phía camera của phòng đang đứng hạ xuống còn chân (wall_stub) để không che nhân vật; va chạm giữ nguyên.
## Mỗi phòng là một TierZone con (BoxShape3D; mask player + quái). Trên đường nối (ngoài mọi phòng) giữ phòng vừa rời.
## Chạy theo signal vào / ra vùng, không kiểm tra mỗi frame. Bản tối tạo một lần cho mỗi vật liệu gốc, dùng chung.

signal room_changed(zone: TierZone)

## Độ tối phủ lên phòng khác (0 = không tối, 1 = đen hẳn)
@export_range(0.0, 1.0, 0.01) var shade_alpha: float = 0.6
## Tắt thì bỏ hết lớp phủ (mọi phòng sáng), quái luôn hiện, không hạ tường
@export var enabled: bool = true:
	set(value):
		enabled = value
		if is_node_ready():
			_apply_shades()
			for enemy: Variant in _enemy_zones.keys():
				_update_enemy(enemy)
## Chiều cao chân tường còn lại khi hạ tường phía camera (m)
@export_range(0.0, 2.0, 0.05) var wall_stub: float = 0.3
## Tên nhóm tường trong cảnh phòng; phòng nằm cùng tên (bỏ hậu tố "Zone") trong rooms_root
@export var walls_group: StringName = &"Walls"
@export var rooms_root: Node

var current: TierZone

var _zones: Array[TierZone] = []
## Phòng -> các MeshInstance3D của phòng (lấy một lần lúc _ready)
var _meshes: Dictionary[TierZone, Array] = {}
## Quái -> số vùng phòng đang chứa nó (lặp không kiểu vì quái có thể bị giải phóng)
var _enemy_zones: Dictionary = {}
## Tường đang hạ -> scale y gốc
var _lowered: Dictionary = {}
## Vật liệu gốc -> bản tối (dùng chung giữa các mesh / phòng)
var _dark_of: Dictionary[Material, Material] = {}
## Mesh -> mảng vật liệu override gốc từng surface (khi đang tối)
var _original: Dictionary = {}

func _ready() -> void:
	for child: Node in get_children():
		var zone := child as TierZone
		if zone == null:
			continue
		_zones.append(zone)
		var room := get_room(zone)
		_meshes[zone] = room.find_children("*", "MeshInstance3D", true, false) if room else []
		_shade(zone, true)
		zone.player_entered.connect(focus.bind(zone))
		zone.body_entered.connect(_on_body_entered.bind(zone))
		zone.body_exited.connect(_on_body_exited.bind(zone))


## Chuyển sáng sang phòng zone (null = mọi phòng tối)
func focus(zone: TierZone) -> void:
	if zone == current:
		return
	_raise_walls()
	current = zone
	_apply_shades()
	_lower_walls(zone)
	for enemy: Variant in _enemy_zones.keys():
		_update_enemy(enemy)
	room_changed.emit(zone)


func set_shade_alpha(value: float) -> void:
	shade_alpha = clampf(value, 0.0, 1.0)
	for base: Material in _dark_of:
		_tint(base, _dark_of[base])


## Phòng đang tối
func is_shaded(zone: TierZone) -> bool:
	for mesh: Variant in _meshes.get(zone, []):
		if is_instance_valid(mesh) and _original.has(mesh):
			return true
	return false


func get_zones() -> Array[TierZone]:
	return _zones


func is_wall_lowered(wall: Node3D) -> bool:
	return _lowered.has(wall)


## Phòng (trong rooms_root) ứng với vùng
func get_room(zone: TierZone) -> Node3D:
	if rooms_root == null or zone == null:
		return null
	return rooms_root.get_node_or_null(NodePath(String(zone.name).trim_suffix("Zone"))) as Node3D


func _apply_shades() -> void:
	for z: TierZone in _zones:
		_shade(z, enabled and z != current)


func _shade(zone: TierZone, dark: bool) -> void:
	for item: Variant in _meshes.get(zone, []):
		if not is_instance_valid(item):
			continue
		var mesh := item as MeshInstance3D
		if dark == _original.has(mesh) or mesh.mesh == null:
			continue
		var count: int = mesh.get_surface_override_material_count()
		if dark:
			var saved: Array[Material] = []
			for i: int in range(count):
				saved.append(mesh.get_surface_override_material(i))
				var base: Material = mesh.get_active_material(i)
				if base:
					mesh.set_surface_override_material(i, _darkened(base))
			_original[mesh] = saved
		else:
			var saved: Array[Material] = _original[mesh]
			for i: int in range(mini(count, saved.size())):
				mesh.set_surface_override_material(i, saved[i])
			_original.erase(mesh)


## Bản tối của vật liệu (tạo một lần). ShaderMaterial (dung nham...) giữ nguyên vì không biết tham số màu
func _darkened(base: Material) -> Material:
	if _dark_of.has(base):
		return _dark_of[base]
	var dark: Material = base
	if base is BaseMaterial3D:
		dark = base.duplicate()
		_tint(base, dark)
	_dark_of[base] = dark
	return dark


func _tint(base: Material, dark: Material) -> void:
	var b := base as BaseMaterial3D
	var d := dark as BaseMaterial3D
	if b == null or d == null or b == d:
		return
	var f: float = 1.0 - shade_alpha
	d.albedo_color = Color(b.albedo_color.r * f, b.albedo_color.g * f, b.albedo_color.b * f, b.albedo_color.a)
	d.emission_energy_multiplier = b.emission_energy_multiplier * f


func _on_body_entered(body: Node3D, zone: TierZone) -> void:
	if body is Enemy:
		_set_enemy_zone(body, zone, true)


func _on_body_exited(body: Node3D, zone: TierZone) -> void:
	if body is Enemy and _enemy_zones.has(body):
		_set_enemy_zone(body, zone, false)


## Quái giữ danh sách vùng đang chứa nó (vào / ra có thể chồng nhau ở cửa)
func _set_enemy_zone(enemy: Node3D, zone: TierZone, inside: bool) -> void:
	var zones: Array = enemy.get_meta(&"room_focus_zones", [])
	if inside and not zones.has(zone):
		zones.append(zone)
	elif not inside:
		zones.erase(zone)
	enemy.set_meta(&"room_focus_zones", zones)
	_enemy_zones[enemy] = zones.size()
	_update_enemy(enemy)


func _update_enemy(enemy: Variant) -> void:
	if not is_instance_valid(enemy):
		_enemy_zones.erase(enemy)
		return
	var node := enemy as Node3D
	var zones: Array = node.get_meta(&"room_focus_zones", [])
	# Ngoài mọi phòng (đường nối): luôn hiện; chưa vào phòng nào (current null): hiện
	node.visible = not enabled or zones.is_empty() or current == null or zones.has(current)


## Hạ các tường nằm giữa phòng và camera (tường có tâm lệch về phía camera so với tâm phòng)
func _lower_walls(zone: TierZone) -> void:
	var room := get_room(zone)
	var camera := get_viewport().get_camera_3d()
	if room == null or camera == null:
		return
	var walls := room.get_node_or_null(NodePath(walls_group))
	if walls == null:
		return
	var to_camera: Vector3 = camera.global_position - room.global_position
	to_camera.y = 0.0
	to_camera = to_camera.normalized()
	for child: Node in walls.get_children():
		var wall := child as Node3D
		if wall == null:
			continue
		var offset: Vector3 = wall.global_position - room.global_position
		offset.y = 0.0
		if offset.dot(to_camera) <= 1.0:
			continue
		var height: float = _wall_height(wall)
		if height <= wall_stub:
			continue
		_lowered[wall] = wall.scale.y
		wall.scale.y = wall.scale.y * wall_stub / height if wall_stub > 0.0 else 0.001


func _raise_walls() -> void:
	for wall: Variant in _lowered.keys():
		if is_instance_valid(wall):
			(wall as Node3D).scale.y = _lowered[wall]
	_lowered.clear()


## Chiều cao hình tường (m) theo AABB các mesh con, tính một lần rồi nhớ trong meta
func _wall_height(wall: Node3D) -> float:
	if wall.has_meta(&"room_focus_height"):
		return wall.get_meta(&"room_focus_height")
	var top: float = 0.0
	for mesh: Node in wall.find_children("*", "MeshInstance3D", true, false):
		var m := mesh as MeshInstance3D
		var aabb: AABB = m.global_transform * m.get_aabb()
		top = maxf(top, aabb.end.y - wall.global_position.y)
	wall.set_meta(&"room_focus_height", top)
	return top
