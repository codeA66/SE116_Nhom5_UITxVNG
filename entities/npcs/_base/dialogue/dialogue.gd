class_name Dialogue
extends Resource
## Một đoạn thoại của NPC: nói lúc nào (context), khi nào được chọn (conditions), nói xong làm gì.
## NPC chọn đoạn hợp lệ có priority cao nhất trong cùng context. Thêm lời thoại = thêm .tres.

## Lúc dùng đoạn này: Npc.CONTEXT_GREETING (bấm nói chuyện), Npc.CONTEXT_FAREWELL (đóng màn dịch vụ), hoặc context riêng của service
@export var context: StringName = &"greeting"
## Nhiều đoạn cùng hợp lệ thì chọn đoạn số lớn hơn (ví dụ "lần đầu gặp" 10, "chào thường" 0)
@export var priority: int = 0
## Tất cả phải đúng thì đoạn mới được chọn
@export var conditions: Array[DialogueCondition] = []
@export var lines: Array[DialogueLine] = []
## Bật cờ này khi nói hết đoạn (không bật nếu người chơi bấm thoát giữa chừng)
@export var flag_on_finish: StringName
## Nói xong thì mở dịch vụ của NPC (nâng cấp, cửa hàng, thu tiền...). Tắt cho đoạn chào tạm biệt / chỉ nói chuyện.
@export var opens_service: bool = false


func is_available(npc: Npc) -> bool:
	for condition: DialogueCondition in conditions:
		if condition != null and not condition.is_met(npc):
			return false
	return true
