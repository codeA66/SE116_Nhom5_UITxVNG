class_name UnlockCondition
extends Resource
## Một điều kiện để mở cổng / cửa. Loại mới (cần kỹ năng, cần tiền...) = lớp con mới, không sửa cổng.

## Bật: điều kiện không giữ cổng đóng, chỉ chặn lúc bước vào (ví dụ mật khẩu). Cổng vẫn mở + chiếu lễ thức khi các
## điều kiện thường thỏa, để người chơi biết đi đâu tiếp; hỏi điều kiện này khi tới cửa
@export var check_on_entry: bool = false


## Lớp con ghi đè: điều kiện đã thỏa chưa
func is_met() -> bool:
	return true


## Lớp con ghi đè: chữ gợi ý hiện trên cổng khi chưa thỏa
func get_hint() -> String:
	return ""


## Đúng khi mọi điều kiện đều thỏa (mảng rỗng = luôn mở)
static func all_met(conditions: Array[UnlockCondition]) -> bool:
	for condition in conditions:
		if condition and not condition.is_met():
			return false
	return true


## Đúng khi mọi điều kiện cùng loại (check_on_entry = on_entry) đều thỏa
static func all_met_of(conditions: Array[UnlockCondition], on_entry: bool) -> bool:
	for condition in conditions:
		if condition and condition.check_on_entry == on_entry and not condition.is_met():
			return false
	return true


## Gợi ý của điều kiện đầu tiên chưa thỏa
static func first_hint(conditions: Array[UnlockCondition]) -> String:
	for condition in conditions:
		if condition and not condition.is_met():
			return condition.get_hint()
	return ""
