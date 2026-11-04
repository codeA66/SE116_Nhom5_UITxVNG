class_name EditableFloor
extends Node3D
## Các ô là node riêng trong editor; lúc chơi dùng chung mesh/material và gom một lần.

@export var batch_when_playing: bool = true

func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	if not batch_when_playing: return
	var groups: Dictionary[String, Array] = {}
	for tile: Node in get_children():
		for child: Node in tile.get_children():
			var mesh: MeshInstance3D = child as MeshInstance3D
			if mesh == null or mesh.mesh == null or not mesh.visible: continue
			var key: String = str(mesh.mesh.get_instance_id()) + ":" + str(mesh.material_override.get_instance_id() if mesh.material_override else 0)
			if not groups.has(key): groups[key] = []
			groups[key].append(mesh)
	for entries: Array in groups.values():
		var source: MeshInstance3D = entries[0]
		var batch: MultiMesh = MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.mesh = source.mesh
		batch.instance_count = entries.size()
		var bounds: AABB
		for index: int in entries.size():
			var mesh: MeshInstance3D = entries[index]
			var pose: Transform3D = global_transform.affine_inverse() * mesh.global_transform
			batch.set_instance_transform(index, pose)
			bounds = pose * mesh.mesh.get_aabb() if index == 0 else bounds.merge(pose * mesh.mesh.get_aabb())
			mesh.hide()
		var visual: MultiMeshInstance3D = MultiMeshInstance3D.new()
		visual.name = "RuntimeFloorBatch"
		visual.multimesh = batch
		visual.material_override = source.material_override
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		visual.custom_aabb = bounds
		add_child(visual)
