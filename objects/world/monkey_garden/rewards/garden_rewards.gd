class_name GardenRewards
extends RefCounted
const REAL_MODEL: PackedScene=preload("res://assets/models/enemies/items/banana_gun.glb")
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
static func loot(parent: Node3D, at: Vector3, gun: bool, amount: int, falling: bool=true) -> Node3D:
	# Đạn luôn nằm trên nền, kể cả quái chết khi đang bị hất tung hoặc reward khác đang bay.
	if not gun:
		var query: PhysicsRayQueryParameters3D=PhysicsRayQueryParameters3D.create(at+Vector3.UP*2,at-Vector3.UP*40,1)
		var hit: Dictionary=parent.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty(): at=hit.position
	var root: GardenFallingLoot=GardenFallingLoot.new(); root.name="RealBakaDrop" if gun else "BakaAmmoDrop"; parent.add_child(root); root.global_position=at
	root.set_meta("baka_ammo_amount",amount); root.set_meta("real_baka_gun",gun)
	var model: Node3D
	if gun:
		model=REAL_MODEL.instantiate(); fit(model)
	else:
		var mesh: MeshInstance3D=MeshInstance3D.new(); mesh.mesh=BananaGeometry.fruit(); var mat: StandardMaterial3D=StandardMaterial3D.new(); mat.albedo_color=Color(1,0.04,0.01); mesh.material_override=mat; model=mesh
	root.add_child(model); model.position.y=0.7
	for animator: AnimationPlayer in model.find_children("*","AnimationPlayer",true,false): animator.stop(); animator.active=false
	for body: RigidBody3D in model.find_children("*","RigidBody3D",true,false): body.freeze=true; body.collision_layer=0; body.collision_mask=0
	var interaction: InteractableComponent=InteractableComponent.new(); interaction.name="InteractableComponent"; interaction.collision_layer=32; interaction.collision_mask=0; interaction.enabled=false
	interaction.prompt_text="Nhặt real bAKa-47" if gun else "Nhặt %d đạn bAKa-47"%amount; interaction.prompt_offset=Vector3.UP*1.6
	var collision: CollisionShape3D=CollisionShape3D.new(); var sphere: SphereShape3D=SphereShape3D.new(); sphere.radius=0.9; collision.shape=sphere; collision.position.y=0.6; interaction.add_child(collision); root.add_child(interaction)
	interaction.interacted.connect(func(actor: Node3D) -> void:
		if not actor is Player: return
		var inventory: BananaInventory=BananaInventory.ensure(actor as Player)
		var weapon: RealBakaWeapon=actor.get_node_or_null("RealBakaWeapon") as RealBakaWeapon
		if gun and weapon==null:
			weapon=RealBakaWeapon.new(); weapon.name="RealBakaWeapon"; actor.add_child(weapon)
		if weapon==null: inventory.reserved_ammo+=amount
		else:
			weapon.add_ammo(amount+inventory.reserved_ammo); inventory.reserved_ammo=0
		inventory.announce(&"gun" if gun else &"ammo"); root.queue_free())
	var beam: LootItemBeam = LootItemBeam.attach_to(root,Color("ffd447") if gun else Color("ff352b"))
	root.landed.connect(beam.set_active.bind(true))
	if gun and falling: root.start(at,interaction)
	else: root.settle(at,interaction)
	return root
