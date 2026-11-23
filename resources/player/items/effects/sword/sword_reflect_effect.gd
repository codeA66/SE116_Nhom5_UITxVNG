extends CharmEffect
## Mỗi Foxy giữ kết nối riêng vì dữ liệu bùa được chia sẻ.

const REFLECTION = preload("res://entities/player/charms/sword_reflection/sword_reflection.gd")

@export_group("Lực hất đạn")
@export_range(0.0, 30.0, 0.1, "or_greater") var push_speed: float = 12.0

var _instances: Dictionary[int, WeakRef] = {}


func apply(player: Node) -> void:
	remove(player)
	var user: Player = player as Player
	if user == null or not user.is_inside_tree() or push_speed <= 0.0:
		return
	var reflection: REFLECTION = REFLECTION.new()
	reflection.name = &"SwordReflection"
	reflection.configure(user, push_speed)
	_instances[user.get_instance_id()] = weakref(reflection)
	user.add_child(reflection)


func remove(player: Node) -> void:
	var player_key: int = player.get_instance_id()
	var reflection_ref: WeakRef = _instances.get(player_key)
	_instances.erase(player_key)
	if reflection_ref == null:
		return
	var reflection: REFLECTION = reflection_ref.get_ref() as REFLECTION
	if is_instance_valid(reflection) and reflection.is_inside_tree():
		reflection.release()
