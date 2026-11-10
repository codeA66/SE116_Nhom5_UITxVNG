class_name FlagCondition
extends DialogueCondition
## Đúng khi cờ tiến trình đang bật (hoặc đang tắt nếu must_be_set = false).
## Dùng cho "lần đầu gặp", "đã trả tiền", "đã nghe lời dặn"...

@export var flag: StringName
@export var must_be_set: bool = true


func is_met(_npc: Npc) -> bool:
	return GameState.has_flag(flag) == must_be_set
