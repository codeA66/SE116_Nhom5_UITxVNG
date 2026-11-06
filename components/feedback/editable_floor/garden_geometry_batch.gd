@tool
class_name GardenGeometryBatch
extends MultiMeshInstance3D
## Lưu mesh và buffer, dựng MultiMesh mới khi reload; không đổi format của MultiMesh còn instance.
@export var source_mesh: Mesh:
	set(value):
		source_mesh = value
		_rebuild()
@export var instance_data: PackedFloat32Array:
	set(value):
		instance_data = value
		_rebuild()

func _ready() -> void:
	if multimesh==null: _rebuild()
	set_process(false); set_physics_process(false)

func _validate_property(property: Dictionary) -> void:
	if property.name == "multimesh": property.usage = int(property.usage) & ~PROPERTY_USAGE_STORAGE

func _rebuild() -> void:
	if source_mesh == null or instance_data.is_empty(): return
	var batch: MultiMesh = MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = source_mesh
	batch.instance_count = floori(instance_data.size() / 12.0)
	batch.buffer = instance_data
	multimesh = batch
