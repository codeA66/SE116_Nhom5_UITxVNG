class_name NpcState
extends State
## Lớp cơ sở cho state của NPC: giữ tham chiếu Npc (owner của scene).

var npc: Npc


func _ready() -> void:
	npc = owner as Npc
	if npc == null:
		push_error("%s: NpcState phải nằm trong scene có gốc là Npc" % get_path())
