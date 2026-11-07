class_name DialogueCondition
extends Resource
## Điều kiện để một đoạn thoại được chọn. Lớp gốc luôn đúng.
## Điều kiện mới (đã trả tiền qua cổng, đủ đồ nâng cấp, đã mua bùa...) = lớp con mới, không sửa Npc / Dialogue.


func is_met(_npc: Npc) -> bool:
	return true
