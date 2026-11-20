class_name SealGem
extends Node3D
## Giữ ngọc bên player trong lúc mang về ổ, kể cả sau khi nạp checkpoint.

@export var drop_offset: Vector3 = Vector3(0, -1.2, -1.4)
@export_range(0.05, 2.0, 0.05) var drop_time: float = 0.45
@export_group("Ngọc bay")
@export_range(0.1, 3.0, 0.05) var orbit_radius: float = 0.9
@export var orbit_height: float = 1.55
@export_range(0.1, 3.0, 0.05) var orbit_speed: float = 0.6
@export_range(1.0, 30.0, 0.5) var follow_speed: float = 12.0
@export_range(0.0, 0.5, 0.01) var bob_height: float = 0.12

var _shield: BeamReceiver
var _picked_flag: StringName
var _placed_flag: StringName
var _legacy_flag: StringName
var _carrier: Player
var _orbit_angle: float = 0.0
var _drop: Tween

@onready var _start: Vector3 = position
@onready var _interaction: InteractableComponent = $InteractableComponent


func _ready() -> void:
	_interaction.enabled = false
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_carrier):
		hide()
		set_physics_process(false)
		return
	_orbit_angle = fposmod(_orbit_angle + orbit_speed * TAU * delta, TAU)
	global_position = global_position.lerp(_orbit_position(), 1.0 - exp(-follow_speed * delta))


func configure(shield: BeamReceiver, picked_flag: StringName, placed_flag: StringName, legacy_flag: StringName) -> void:
	_shield = shield
	_picked_flag = picked_flag
	_placed_flag = placed_flag
	_legacy_flag = legacy_flag
	_interaction.interacted.connect(_on_interacted)
	_shield.completed.connect(_drop_gem)
	GameState.progress_changed.connect(_refresh_carried)
	GameState.progress_replaced.connect(_restore)
	_restore()


func set_carrier(player: Player) -> void:
	_carrier = player
	if _shield != null:
		_refresh_carried()
		if is_physics_processing():
			global_position = _orbit_position()
			reset_physics_interpolation()


func _restore() -> void:
	if _drop != null:
		_drop.kill()
	var broken: bool = _shield.is_completed()
	position = _start + drop_offset if broken else _start
	_interaction.enabled = broken
	show()
	set_physics_process(false)
	_refresh_carried()


func _refresh_carried() -> void:
	var placed: bool = GameState.has_flag(_placed_flag) or GameState.has_flag(_legacy_flag)
	var picked: bool = GameState.has_flag(_picked_flag)
	if not placed and not picked:
		return
	_interaction.enabled = false
	var carrying: bool = not placed and is_instance_valid(_carrier)
	visible = carrying
	if carrying and not is_physics_processing():
		global_position = _orbit_position()
		reset_physics_interpolation()
	set_physics_process(carrying)


func _orbit_position() -> Vector3:
	var horizontal: Vector3 = Vector3(cos(_orbit_angle), 0.0, sin(_orbit_angle)) * orbit_radius
	var height: float = orbit_height + sin(_orbit_angle * 2.0) * bob_height
	return _carrier.global_position + horizontal + Vector3.UP * height


func _drop_gem() -> void:
	if not visible:
		return
	_drop = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_drop.tween_property(self, "position", _start + drop_offset, drop_time)
	_drop.finished.connect(_enable_pickup)


func _enable_pickup() -> void:
	_interaction.enabled = true


func _on_interacted(actor: Node3D) -> void:
	var player: Player = actor as Player
	if player == null or not _interaction.enabled:
		return
	_carrier = player
	GameState.set_flag(_picked_flag)
