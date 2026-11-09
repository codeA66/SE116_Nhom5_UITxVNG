class_name SkillShrineState
extends State
## Trạng thái của phòng học kỹ năng. Mỗi trạng thái tự nối / gỡ signal của phòng lúc vào / ra,
## nên thêm trạng thái mới không cần sửa trạng thái cũ.

var shrine: SkillShrine


func _ready() -> void:
	shrine = owner as SkillShrine


## Nối signal của phòng chỉ trong lúc trạng thái này đang chạy
func _listen(sig: Signal, handler: Callable) -> void:
	if not sig.is_connected(handler):
		sig.connect(handler)


func _unlisten(sig: Signal, handler: Callable) -> void:
	if sig.is_connected(handler):
		sig.disconnect(handler)
