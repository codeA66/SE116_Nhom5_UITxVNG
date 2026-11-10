class_name BananaPeelResponse
extends Node
## Điểm mở rộng cho giày/boss: nhận vỏ chuối trước khi áp dụng trạng thái trượt.
const META_KEY: StringName = &"banana_peel_response"

static func find_on(actor: Node) -> BananaPeelResponse:
	if not is_instance_valid(actor) or not actor.has_meta(META_KEY): return null
	return actor.get_meta(META_KEY) as BananaPeelResponse

func _enter_tree() -> void:
	get_parent().set_meta(META_KEY,self)
func _exit_tree() -> void:
	var actor: Node = get_parent()
	if find_on(actor) == self: actor.remove_meta(META_KEY)
func step_on_peel() -> bool:
	return false
