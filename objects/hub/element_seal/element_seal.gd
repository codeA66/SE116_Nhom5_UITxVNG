class_name ElementSeal
extends MeshInstance3D
## Dấu nguyên tố trên cửa đền: tối khi khu chưa phá, sáng màu nguyên tố khi đã phá.

@export var zone: ZoneData
@export var dim_color: Color = Color(0.22, 0.22, 0.24)
@export_range(0.0, 8.0, 0.1) var lit_energy: float = 2.5

var _material: StandardMaterial3D

@onready var _watcher: ProgressWatcher = $ProgressWatcher


func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Mỗi dấu một màu riêng nên cần material riêng, tạo một lần
	_watcher.changed.connect(_refresh)
	_material = StandardMaterial3D.new()
	material_override = _material
	_refresh()


func is_lit() -> bool:
	return zone != null and zone.is_cleared()


func _refresh() -> void:
	var lit := is_lit()
	_material.albedo_color = zone.color if lit and zone else dim_color
	_material.emission_enabled = lit
	if lit and zone:
		_material.emission = zone.color
		_material.emission_energy_multiplier = lit_energy
