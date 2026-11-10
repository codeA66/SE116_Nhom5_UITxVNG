class_name AreaData
extends Resource
## Một nơi có tên trên đảo: cả khu (ZoneData kế thừa) hoặc một vùng con trong khu (tầng, sân...).
## Chữ giới thiệu khu vực đọc tên từ đây: thêm vùng mới = thêm .tres, không sửa code.

## Tiền tố cờ "đã tới nơi này" trong GameState (lần đầu hiện bản đầy đủ, các lần sau bản ngắn)
const SEEN_FLAG_FORMAT := "area.%s.seen"

@export var id: StringName
@export var display_name: String = ""
## Dòng phụ dưới tên, chỉ hiện ở lần đầu tới; để trống = không có
@export var subtitle: String = ""


func get_seen_flag() -> StringName:
	return StringName(SEEN_FLAG_FORMAT % id)


func is_seen() -> bool:
	return not id.is_empty() and GameState.has_flag(get_seen_flag())
