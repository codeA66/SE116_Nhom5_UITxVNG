class_name KhamSinkingRoute
extends Node3D
## Đường chia ô sập, dùng cùng màu nóng/lạnh của CoolingPath.

const TILE_SCENE: PackedScene = preload("res://levels/zone_3_fire/level_3/rooms/tier_3/puzzles/kham_sinking_route/kham_sinking_tile.tscn")
const FLOOR_MODEL: PackedScene = preload("res://assets/models/map_fire/fire_kit/floor_cracked_4m.glb")
const DEFAULT_SETTINGS: KhamSinkData = preload("res://levels/zone_3_fire/level_3/rooms/tier_3/puzzles/kham_sinking_route/kham_sink_data.tres")

@export var cooling_path: CoolingPath
@export var floor_bodies: Array[StaticBody3D] = []

var _data: KhamSinkData
var _active: bool = false
var _tiles: Array[KhamSinkingTile] = []
var _surfaces: Array[Node3D] = []


func _ready() -> void:
	cooling_path.heat_changed.connect(_on_heat_changed)
	set_process(false)
	set_physics_process(false)


func configure(settings: KhamSinkData) -> void:
	_data = settings if settings else DEFAULT_SETTINGS
	if _data.crumble == null:
		_data.crumble = DEFAULT_SETTINGS.crumble
	if not _tiles.is_empty():
		return
	for body: StaticBody3D in floor_bodies:
		var collider: CollisionShape3D = body.get_node(^"Collision") as CollisionShape3D
		var box: BoxShape3D = collider.shape as BoxShape3D
		var surface: MeshInstance3D = body.get_node(^"Surface") as MeshInstance3D
		_surfaces.append(surface)
		body.collision_layer = 0
		_build_tiles(collider, box, surface.material_override)
	set_active(false)


func set_active(active: bool) -> void:
	_active = active
	if active:
		_on_heat_changed()
	else:
		for tile: KhamSinkingTile in _tiles:
			tile.set_enabled(false)
		for surface: Node3D in _surfaces:
			surface.hide()


func _on_heat_changed() -> void:
	if not _active:
		return
	var hot: bool = cooling_path.heat == CoolingPath.Heat.HOT
	for surface: Node3D in _surfaces:
		surface.visible = hot
	# Cảnh báo nóng không dựng lại những ô player đã làm sập.
	if cooling_path.heat == CoolingPath.Heat.WARNING:
		return
	for tile: KhamSinkingTile in _tiles:
		tile.set_enabled(not hot, cooling_path.heat == CoolingPath.Heat.SAFE)


func _build_tiles(collider: CollisionShape3D, box: BoxShape3D, material: Material) -> void:
	var columns: int = maxi(ceili(box.size.x / maxf(_data.tile_size.x, 0.25)), 1)
	var rows: int = maxi(ceili(box.size.z / maxf(_data.tile_size.y, 0.25)), 1)
	var limit: int = maxi(_data.max_tiles_per_body, 1)
	if columns * rows > limit:
		var ratio: float = sqrt(float(limit) / float(columns * rows))
		columns = clampi(floori(float(columns) * ratio), 1, limit)
		rows = maxi(mini(rows, floori(float(limit) / float(columns))), 1)
	var size: Vector3 = Vector3(box.size.x / columns, box.size.y, box.size.z / rows)
	var source_transform: Transform3D = global_transform.affine_inverse() * collider.global_transform
	for column: int in columns:
		for row: int in rows:
			var tile: KhamSinkingTile = TILE_SCENE.instantiate() as KhamSinkingTile
			tile.data = _data.crumble
			tile.size = size
			tile.trigger_on_exit = _data.trigger_on_exit
			var offset: Vector3 = Vector3(-box.size.x * 0.5 + (column + 0.5) * size.x, box.size.y * 0.5, -box.size.z * 0.5 + (row + 0.5) * size.z)
			tile.transform = source_transform * Transform3D(Basis.IDENTITY, offset)
			add_child(tile)
			(tile.visual.get_node(^"Mesh") as MeshInstance3D).hide()
			var model: Node3D = FLOOR_MODEL.instantiate() as Node3D
			model.position.y = -size.y
			model.scale = Vector3(maxf(size.x - tile.visual_gap, 0.05) / 4.0, size.y / 0.32, maxf(size.z - tile.visual_gap, 0.05) / 4.0)
			tile.visual.add_child(model)
			for mesh: Node in model.find_children("*", "MeshInstance3D", true, false):
				(mesh as MeshInstance3D).material_override = material
			_tiles.append(tile)
			tile.set_enabled(false)
