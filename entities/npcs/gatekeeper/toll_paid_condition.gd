class_name TollPaidCondition
extends DialogueCondition
## Đúng khi cổng của chính NPC này đã / chưa được trả tiền (mỗi kẻ gác cổng tự xét cổng của mình).

@export var must_be_paid: bool = true


func is_met(npc: Npc) -> bool:
	for child in npc.get_children():
		var toll := child as TollService
		if toll:
			return toll.is_paid() == must_be_paid
	return not must_be_paid
