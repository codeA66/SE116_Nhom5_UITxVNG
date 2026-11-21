class_name Tier3Altar
extends Node3D
## Bệ chung nhận ấn và dẫn sáng từ khe về biểu tượng phòng.

signal gem_placed

const ROUTE_VERSION: StringName = &"level_3.t3_walkthrough_altar_v2"
const LEGACY_LY: StringName = &"level_3.t3_walkthrough_ly"

@export var earned_flags: Array[StringName] = []
@export var placed_flags: Array[StringName] = []
@export var flames: Array[Node3D] = []
@export_range(0.1, 5.0, 0.05) var light_time: float = 1.35

var _lighting: Tween

@onready var _gems: Array[Node3D] = [$Gems/Ly, $Gems/Kham, $Gems/Ton, $Gems/Chan]
@onready var _paths: Array[MeshInstance3D] = [$Paths/South, $Paths/North, $Paths/West, $Paths/East]
@onready var _interaction: InteractableComponent = $InteractableComponent


func _ready() -> void:
	for index: int in range(_gems.size()):
		_paths[index].material_override = _paths[index].material_override.duplicate() as ShaderMaterial
	_interaction.availability_check = _can_place
	_interaction.interacted.connect(_on_interacted)
	GameState.progress_replaced.connect(_restore)
	_restore()


func is_complete() -> bool:
	if _lighting != null or placed_flags.is_empty():
		return false
	for flag: StringName in placed_flags:
		if not GameState.has_flag(flag):
			return false
	return true


func _can_place(actor: Node3D) -> bool:
	return actor is Player and _lighting == null and _available_slot() >= 0


func _available_slot() -> int:
	for index: int in range(placed_flags.size()):
		if GameState.has_flag(earned_flags[index]) and not GameState.has_flag(placed_flags[index]):
			return index
	return -1


func _on_interacted(_actor: Node3D) -> void:
	var index: int = _available_slot()
	if index < 0:
		return
	_gems[index].show()
	_lighting = create_tween()
	_lighting.tween_method(_set_path_progress.bind(index), 0.0, 1.0, light_time)
	_lighting.finished.connect(_finish_light.bind(index))
	GameState.set_flag(placed_flags[index])


func _finish_light(index: int) -> void:
	_lighting = null
	flames[index].show()
	gem_placed.emit()


func _restore() -> void:
	if _lighting != null:
		_lighting.kill()
		_lighting = null
	var legacy: bool = not GameState.has_flag(ROUTE_VERSION)
	if legacy and GameState.has_flag(LEGACY_LY):
		GameState.set_flag(placed_flags[0])
	for index: int in range(_gems.size()):
		# Bản cũ mở cửa ngay khi giải xong Khảm, Tốn hoặc Chấn.
		if legacy and index > 0 and GameState.has_flag(earned_flags[index]):
			GameState.set_flag(placed_flags[index])
		var placed: bool = GameState.has_flag(placed_flags[index])
		_gems[index].visible = placed
		_set_path_progress(1.0 if placed else 0.0, index)
		flames[index].visible = placed
	if legacy:
		GameState.set_flag(ROUTE_VERSION)


func _set_path_progress(progress: float, index: int) -> void:
	var material: ShaderMaterial = _paths[index].material_override as ShaderMaterial
	material.set_shader_parameter(&"progress", progress)
