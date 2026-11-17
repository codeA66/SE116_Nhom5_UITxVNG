extends Node3D
## Phát từng clip trên model đã import để kiểm tra dáng bằng camera game.

@export_group("Camera")
@export var camera_distance: float = 38.0
@export var camera_pitch_degrees: float = 50.0
@export var camera_yaw_degrees: float = 27.0
@export var camera_focus: Vector3 = Vector3(0.35, 0.65, 0.0)

@export_group("Sàn mẫu")
@export var floor_tile_scene: PackedScene
@export var floor_tile_size: float = 4.0
@export var floor_tile_top: float = 0.32
@export_range(0, 8, 1) var floor_tiles_each_side: int = 2

var _animator: AnimationPlayer

@onready var _model: Node3D = $FireToad
@onready var _floor: Node3D = $Floor
@onready var _camera: Camera3D = $Camera
@onready var _player_hud: CanvasLayer = $ComparisonPlayer/HUD
@onready var _picker: OptionButton = $Controls/Row/ClipPicker
@onready var _replay: Button = $Controls/Row/Replay


func _ready() -> void:
	_player_hud.hide()
	_place_floor()
	_place_camera()

	var players: Array[Node] = _model.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		push_error("Model Ếch Hoả Vương thiếu AnimationPlayer.")
		_picker.disabled = true
		_replay.disabled = true
		return

	_animator = players[0] as AnimationPlayer
	var initial_index: int = 0
	for clip: String in _animator.get_animation_list():
		if clip == "RESET":
			continue
		if clip == "Idle":
			initial_index = _picker.item_count
		_picker.add_item(clip)
	_picker.item_selected.connect(_play_clip)
	_replay.pressed.connect(_replay_clip)
	if _picker.item_count > 0:
		_picker.select(initial_index)
		_play_clip(initial_index)


func _place_camera() -> void:
	var pitch: float = deg_to_rad(camera_pitch_degrees)
	var yaw: float = deg_to_rad(camera_yaw_degrees)
	var distance_on_floor: float = camera_distance * cos(pitch)
	var offset: Vector3 = Vector3(
		distance_on_floor * sin(yaw),
		camera_distance * sin(pitch),
		-distance_on_floor * cos(yaw)
	)
	_camera.global_position = camera_focus + offset
	_camera.look_at(camera_focus)
	_camera.make_current()


func _place_floor() -> void:
	if floor_tile_scene == null:
		return
	for x: int in range(-floor_tiles_each_side, floor_tiles_each_side + 1):
		for z: int in range(-floor_tiles_each_side, floor_tiles_each_side + 1):
			var tile: Node3D = floor_tile_scene.instantiate() as Node3D
			_floor.add_child(tile)
			tile.position = Vector3(x * floor_tile_size, -floor_tile_top, z * floor_tile_size)


func _play_clip(index: int) -> void:
	var clip: StringName = StringName(_picker.get_item_text(index))
	_animator.stop()
	_animator.play(clip)


func _replay_clip() -> void:
	if _picker.selected >= 0:
		_play_clip(_picker.selected)
