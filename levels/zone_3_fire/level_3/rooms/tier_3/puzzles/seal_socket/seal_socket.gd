class_name SealSocket
extends Node3D
## Hiện ngọc và chạy vệt sáng khi người chơi đặt đúng ấn.

signal activated
signal deactivated

@export var picked_flag: StringName
@export var placed_flag: StringName
@export var legacy_placed_flag: StringName
@export var light_path: MeshInstance3D
@export_range(0.05, 5.0, 0.05) var light_time: float = 1.1

var _lighting: Tween
var _path_material: ShaderMaterial
var _placed: bool = false

@onready var _gem: Node3D = $Gem
@onready var _interaction: InteractableComponent = $InteractableComponent


func _ready() -> void:
	_interaction.interacted.connect(_on_interacted)
	_interaction.availability_check = _can_place
	if light_path != null:
		_path_material = light_path.material_override as ShaderMaterial
	GameState.progress_replaced.connect(_restore)
	_restore()


func is_active() -> bool:
	return GameState.has_flag(placed_flag) or GameState.has_flag(legacy_placed_flag)


func _can_place(actor: Node3D) -> bool:
	return actor is Player and GameState.has_flag(picked_flag) and not is_active()


func _on_interacted(actor: Node3D) -> void:
	if not _can_place(actor):
		return
	_gem.show()
	if light_path != null:
		light_path.show()
		_lighting = create_tween()
		_lighting.tween_method(_set_progress, 0.0, 1.0, light_time)
	_placed = true
	GameState.set_flag(placed_flag)
	activated.emit()


func _restore() -> void:
	if _lighting != null:
		_lighting.kill()
	var was_placed: bool = _placed
	_placed = is_active()
	_gem.visible = _placed
	if light_path != null:
		light_path.visible = _placed
		_set_progress(1.0 if _placed else 0.0)
	if _placed and not was_placed:
		activated.emit()
	elif was_placed and not _placed:
		deactivated.emit()


func _set_progress(value: float) -> void:
	if _path_material != null:
		_path_material.set_shader_parameter(&"progress", value)
