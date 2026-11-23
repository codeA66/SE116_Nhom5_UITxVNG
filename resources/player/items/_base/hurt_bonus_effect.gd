class_name HurtBonusEffect
extends CharmEffect
## Giữ tham chiếu yếu để Resource dùng chung không giữ sống player của khu cũ.

const CONTROLLER: PackedScene = preload("res://entities/player/charms/timed_hurt_bonus/timed_hurt_bonus.tscn")

@export_group("Buff sau khi mất máu")
@export var stat: StringName = &"weapon_damage_bonus"
@export_range(0.0, 100.0, 1.0, "or_greater") var bonus: float = 1.0
@export_range(0.0, 60.0, 0.1, "or_greater") var duration: float = 1.5

@export_group("Hình ảnh tùy chọn")
@export var visual_scene: PackedScene
@export var visual_style: Resource

@export_group("Chỉ báo hiệu lực")
@export var status_icon: Texture2D
@export var status_color: Color = Color("d6718a")

var _instances: Dictionary[int, WeakRef] = {}


func apply(player: Node) -> void:
	remove(player)
	if not player.is_inside_tree() or bonus <= 0.0 or duration <= 0.0 or stat.is_empty():
		return
	var controller: Node = CONTROLLER.instantiate()
	controller.call(&"configure", player, stat, StringName("hurt_effect_%d" % get_instance_id()), bonus, duration, status_icon, status_color)
	_instances[player.get_instance_id()] = weakref(controller)
	if visual_scene:
		# Là con trực tiếp của player nên không cần chép vị trí mỗi frame hay đi theo nhịp ẩn Model.
		var visual: Node = visual_scene.instantiate()
		visual.call(&"configure", visual_style, Callable(controller, &"get_time_left"))
		controller.connect(&"activated", Callable(visual, &"activate"))
		controller.connect(&"deactivated", Callable(visual, &"reset"))
		controller.tree_exiting.connect(Callable(visual, &"dispose"))
		player.add_child(visual)
	player.add_child(controller)


func remove(player: Node) -> void:
	var id: int = player.get_instance_id()
	var controller_ref: WeakRef = _instances.get(id)
	_instances.erase(id)
	if controller_ref == null:
		return
	var controller: Node = controller_ref.get_ref() as Node
	if is_instance_valid(controller) and controller.is_inside_tree():
		controller.call(&"release")
