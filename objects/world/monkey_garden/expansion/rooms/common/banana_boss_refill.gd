class_name BananaBossRefill
extends Area3D

func _ready() -> void:
	body_entered.connect(_entered)

func _entered(body: Node3D) -> void:
	if not body is Player: return
	var inventory: BananaInventory = body.get_node_or_null("BananaInventory") as BananaInventory
	if inventory: inventory.refill_healing()
