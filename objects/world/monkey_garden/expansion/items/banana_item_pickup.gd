class_name BananaItemPickup
extends Node3D
@export_enum("boots","healing") var kind: String = "boots"
var available: bool = false
var interaction: InteractableComponent
var _visual: Node3D
var _time: float = 0.0
var _beam: LootItemBeam

func _ready() -> void:
	_visual = BananaItemModels.boots_pair() if kind == "boots" else BananaItemModels.fruit(Color("4ce86e"))
	_beam = LootItemBeam.attach_to(self,Color("ffd447") if kind == "boots" else Color("4ce86e"))
	add_child(_visual)
	interaction = InteractableComponent.new(); interaction.collision_layer = 32; interaction.collision_mask = 0
	interaction.prompt_text = "Nhặt giày chuối" if kind == "boots" else "Nhặt chuối dinh dưỡng"
	interaction.prompt_offset = Vector3.UP*1.4; interaction.enabled = false
	var collider: CollisionShape3D = CollisionShape3D.new(); var sphere: SphereShape3D = SphereShape3D.new(); sphere.radius = 0.85; collider.shape = sphere; collider.position.y = 0.6
	interaction.add_child(collider); add_child(interaction); interaction.interacted.connect(_take)
	hide(); set_process(false)

func reveal() -> void:
	var landing: Vector3 = global_position; global_position += Vector3.UP*7; show()
	var tween: Tween = create_tween(); tween.tween_property(self,"global_position",landing,2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void: available = true; interaction.enabled = true; _beam.set_active(true); set_process(true))

func _process(delta: float) -> void:
	_time += delta; _visual.position.y = 0.65+sin(_time*2.4)*0.08; _visual.rotation.y += delta*0.5

func _take(actor: Node3D) -> void:
	if not available or not actor is Player: return
	interaction.enabled = false; BananaInventory.ensure(actor as Player).grant(StringName(kind)); queue_free()
