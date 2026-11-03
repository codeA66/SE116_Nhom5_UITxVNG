extends ZoneRoot
## Phòng thử độc lập: cấp đồ cho lượt thử, không chốt checkpoint hoặc ghi save.

const TEST_WIND: AbilityData = preload("res://abilities/wind_blast/wind_blast.tres")
const TEST_SWORD: WeaponData = preload("res://resources/combat/weapons/sword.tres")

@export var overview_camera: Camera3D

var _player_camera: Camera3D
var _preview_player: Player
var _overview: bool = false


func _ready() -> void:
	GameState.unlock_ability(TEST_WIND)
	GameState.set_weapon(TEST_SWORD)
	await super._ready()
	_preview_player = get_node(^"Player") as Player
	_player_camera = get_viewport().get_camera_3d()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.is_pressed() or event.is_echo():
		return
	if (event as InputEventKey).physical_keycode != KEY_F2 or overview_camera == null or _player_camera == null:
		return
	_overview = not _overview
	if _overview:
		overview_camera.make_current()
	else:
		_player_camera.make_current()
	_preview_player.set_controls_enabled(not _overview)
	get_viewport().set_input_as_handled()
