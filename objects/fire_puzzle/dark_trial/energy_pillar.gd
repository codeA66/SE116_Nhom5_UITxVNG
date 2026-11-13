class_name EnergyPillar
extends Node3D
## Trụ năng lượng: lồng sinh quái (SpawnerCage) khi player vào phòng; phá lồng và hạ hết quái thì hiện lò lửa
## (IgnitableBrazier) ở chân trụ; thắp lò là xong trụ, phát lit. Không lưu cờ: thử thách tạo trụ mới mỗi lượt.
## Gọi setup() trước khi add_child. Hiệu năng: chỉ nghe signal cleared / activated.

signal lit

@export var cage_scene: PackedScene = preload("res://objects/combat/spawner_cage/spawner_cage.tscn")
@export var brazier_scene: PackedScene = preload("res://objects/world/cellar/ignitable_brazier/ignitable_brazier.tscn")

var data: DarkTrialPillarData
var _cage: SpawnerCage
var _brazier: IgnitableBrazier


func setup(pillar_data: DarkTrialPillarData) -> void:
	data = pillar_data
	name = String(data.name)
	position = data.position


func _ready() -> void:
	if data == null:
		push_error("%s: chưa gọi setup()" % get_path())
		return
	_cage = cage_scene.instantiate() as SpawnerCage
	_cage.name = "Cage"
	_cage.enemy_scene = data.enemy_scene
	_cage.spawn_interval = data.spawn_interval
	_cage.max_alive = data.max_alive
	_cage.active_area_size = data.active_area_size
	_cage.active_area_offset = data.active_area_offset
	add_child(_cage)
	_cage.cleared.connect(_on_cage_cleared, CONNECT_ONE_SHOT)


func get_cage() -> SpawnerCage:
	return _cage


## Lò lửa (chỉ có sau khi dọn xong lồng)
func get_brazier() -> IgnitableBrazier:
	return _brazier


func is_lit() -> bool:
	return _brazier != null and _brazier.is_active()


func _on_cage_cleared() -> void:
	_brazier = brazier_scene.instantiate() as IgnitableBrazier
	_brazier.name = "Brazier"
	add_child(_brazier)
	_brazier.activated.connect(lit.emit, CONNECT_ONE_SHOT)
