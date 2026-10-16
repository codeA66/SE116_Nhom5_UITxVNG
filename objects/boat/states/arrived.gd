extends BoatState
## Đã tới bến cuối: đi một chiều nên không phản ứng với gió nữa. Chờ checkpoint mới để lưu vị trí.


func enter(previous: StringName) -> void:
	boat.speed = 0.0
	boat.lower_sail()
	# Vào thẳng Arrived khi tải khu (đã lưu) thì không cần ghi lại
	if not previous.is_empty():
		boat.mark_arrived()
