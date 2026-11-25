extends CharmEffect

const CONTROLLER: String = "res://resources/player/items/effects/special/arrow_rend/arrow_rend.tscn"
const CHARM_ID: StringName = &"arrow_rend_charm"

@export_group("Tên ghim")
@export_range(0, 16) var maximum_arrows: int = 6
@export_range(0.0, 60.0, 0.1, "suffix:s") var mark_lifetime: float = 8.0
@export_group("Phân loại boss")
@export var boss_scene_paths: PackedStringArray = PackedStringArray()


func apply(player: Node) -> void:
	var actor: Player = player as Player
	if actor == null:
		return
	var rend: ArrowRend = actor.get_node_or_null(^"ArrowRend") as ArrowRend
	if rend == null:
		# Tiến trình nạp catalog trước Player nên chờ đến lúc đeo mới nạp scene.
		var scene: PackedScene = load(CONTROLLER) as PackedScene
		rend = scene.instantiate() as ArrowRend
		rend.configure(actor, maximum_arrows, mark_lifetime, boss_scene_paths)
		actor.add_child(rend)
	rend.set_equipped(true)


func remove(player: Node) -> void:
	# Đổi một bùa khác cũng áp lại cả bộ, nên giữ các mũi tên nếu vẫn đeo Đoạt Tiễn.
	if GameState.is_charm_equipped(CHARM_ID):
		return
	var rend: ArrowRend = player.get_node_or_null(^"ArrowRend") as ArrowRend
	if rend:
		rend.release()
