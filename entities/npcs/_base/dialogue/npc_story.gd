extends Node
## Gắn truyện vào NPC bằng component, kể cả khi room cũ đã lưu lời chào riêng.

@export var dialogues: Array[Dialogue] = []
@export var dialogue_box_scene: PackedScene


func _ready() -> void:
	var npc := get_parent() as Npc
	assert(npc != null)
	npc.dialogues = dialogues
	if dialogue_box_scene:
		npc.dialogue_box_scene = dialogue_box_scene
