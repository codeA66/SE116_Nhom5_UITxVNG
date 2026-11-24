extends CharmEffect

const CONTROLLER_PATH: String = "res://resources/player/items/effects/special/cast/charm_ultimate.tscn"
const CHARM_ID: StringName = &"skystrike_charm"

@export var data: SkystrikeData


func apply(player: Node) -> void:
	var actor: Player = player as Player
	if not is_instance_valid(actor) or data == null:
		return
	var controller: CharmUltimate = actor.get_node_or_null(^"CharmUltimate") as CharmUltimate
	if controller == null:
		# Catalog được nạp sớm hơn cây player nên lấy scene tại thời điểm đeo.
		var scene: PackedScene = load(CONTROLLER_PATH) as PackedScene
		controller = scene.instantiate() as CharmUltimate
		controller.configure(actor, data)
		actor.add_child(controller)
	controller.set_equipped(true)


func remove(player: Node) -> void:
	# CharmHolder áp lại cả bộ khi đổi bùa khác. Chỉ xả điểm khi thật sự tháo Thiên Kích.
	if GameState.is_charm_equipped(CHARM_ID):
		return
	var controller: CharmUltimate = player.get_node_or_null(^"CharmUltimate") as CharmUltimate
	if controller:
		controller.set_equipped(false)
