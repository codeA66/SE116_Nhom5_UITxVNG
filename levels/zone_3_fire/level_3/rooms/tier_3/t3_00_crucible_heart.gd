class_name CrucibleHeart
extends Node3D
## NPC lò nghe các signal ở đây; thêm phòng chỉ cần thêm cờ và ký hiệu trong Inspector.

signal seal_released(seal_id: StringName)
signal seals_progressed(released: int, total: int)
signal all_seals_released

@export_group("Phong ấn")
@export var seal_ids: PackedStringArray = PackedStringArray()
@export var seal_flags: PackedStringArray = PackedStringArray()
@export var seal_symbols: Array[Node3D] = []
@export_group("Ký hiệu trên sàn")
@export var dormant_color: Color = Color(0.4, 0.2, 0.07)
@export var released_color: Color = Color(1.0, 0.65, 0.2)
@export_range(0.0, 8.0, 0.1) var released_emission: float = 1.5

var _states: PackedByteArray = PackedByteArray()
var _glyphs: Dictionary = {}
var _dormant_material: StandardMaterial3D
var _released_material: StandardMaterial3D
var _released_count: int = 0


func _ready() -> void:
	if seal_flags.size() != seal_ids.size() or seal_flags.size() != seal_symbols.size():
		push_error("%s: mỗi ấn cần một id, cờ và ký hiệu" % get_path())
		return
	_dormant_material = StandardMaterial3D.new()
	_dormant_material.albedo_color = dormant_color
	_dormant_material.metallic = 0.5
	_released_material = StandardMaterial3D.new()
	_released_material.albedo_color = released_color
	_released_material.emission_enabled = true
	_released_material.emission = released_color
	_released_material.emission_energy_multiplier = released_emission
	_states.resize(seal_flags.size())
	for index: int in range(seal_symbols.size()):
		var glyphs: Array[MeshInstance3D] = []
		for child: Node in seal_symbols[index].get_node(^"Hao").get_children():
			if child is MeshInstance3D:
				glyphs.append(child as MeshInstance3D)
		_glyphs[index] = glyphs
	GameState.progress_changed.connect(_refresh.bind(true))
	GameState.progress_replaced.connect(_refresh.bind(false))
	_refresh(false)


func released_count() -> int:
	return _released_count


func is_active() -> bool:
	return not seal_flags.is_empty() and _released_count == seal_flags.size()


func _refresh(announce: bool) -> void:
	var was_complete: bool = is_active()
	var previous_count: int = _released_count
	_released_count = 0
	for index: int in range(seal_flags.size()):
		var active: bool = GameState.has_flag(StringName(seal_flags[index]))
		var was_active: bool = _states[index] != 0
		_states[index] = int(active)
		_released_count += int(active)
		var material: Material = _released_material if active else _dormant_material
		var glyphs: Array[MeshInstance3D] = _glyphs[index]
		for glyph: MeshInstance3D in glyphs:
			glyph.material_override = material
		if announce and active and not was_active:
			seal_released.emit(StringName(seal_ids[index]))
	if previous_count != _released_count or not announce:
		seals_progressed.emit(_released_count, seal_flags.size())
	if announce and is_active() and not was_complete:
		all_seals_released.emit()
