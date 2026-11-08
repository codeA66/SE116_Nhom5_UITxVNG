class_name GardenRewards
extends RefCounted
const GUN_MODEL: PackedScene=preload("res://assets/models/enemies/items/banana_gun.glb")
static func fit(model: Node3D) -> void:
	var bounds: AABB=_bounds(model,Transform3D.IDENTITY)
	var length: float=maxf(bounds.size.x,maxf(bounds.size.y,bounds.size.z))
	model.scale*=1.25/maxf(length,0.01)
	if bounds.size.x>bounds.size.z: model.rotation.y=-PI/2
	# Giữ gốc model tại đáy/tâm thật, không dùng pivot lệch từ file GLB.
	var normalized: AABB=_bounds(model,Transform3D.IDENTITY)
	var offset: Vector3=model.transform.basis.inverse()*Vector3(normalized.get_center().x,normalized.position.y,normalized.get_center().z)
	for child: Node in model.get_children():
		if child is Node3D: child.position-=offset
	for animator: AnimationPlayer in model.find_children("*","AnimationPlayer",true,false): animator.stop(); animator.active=false
static func _bounds(node: Node3D, parent: Transform3D) -> AABB:
	var transform: Transform3D=parent*node.transform
	var box: AABB=transform*(node as MeshInstance3D).mesh.get_aabb() if node is MeshInstance3D and (node as MeshInstance3D).mesh else AABB()
	for child: Node in node.get_children():
		if child is Node3D:
			var other: AABB=_bounds(child,transform)
			if other.size!=Vector3.ZERO: box=other if box.size==Vector3.ZERO else box.merge(other)
	return box
static func offering(item: OfferingBanana) -> void:
	item.was_rewarded=true
	var landing: Vector3=item.global_position; item.set_available(false); item.show(); item.global_position=landing+Vector3.UP*9
	var tween: Tween=item.create_tween(); tween.tween_property(item,"global_position",landing,2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(item.set_available.bind(true))
