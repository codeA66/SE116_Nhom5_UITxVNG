class_name ZoneRegistry
extends Resource
## Danh sách mọi khu của game: menu hồ sơ đọc tên nơi đang đứng và các khu đã phá từ đây.
## Thêm khu mới = thêm ZoneData vào .tres, không sửa code menu.

## Khu trung tâm (nơi bắt đầu, không có nguyên tố)
@export var hub: ZoneData
## 4 khu nguyên tố theo thứ tự mở: Gió, Lửa, Băng, Sét
@export var element_zones: Array[ZoneData] = []
## Chữ khi không xác định được nơi đang đứng (save cũ, khu đã đổi tên)
@export var unknown_name: String = "Nơi chưa rõ"


## Tên nơi tương ứng với scene checkpoint của hồ sơ
func get_location_name(scene_path: String) -> String:
	if scene_path.is_empty() and hub:
		return hub.display_name
	for zone in _all():
		if zone.scene_path == scene_path:
			return zone.display_name
	return unknown_name


func _all() -> Array[ZoneData]:
	var result: Array[ZoneData] = []
	if hub:
		result.append(hub)
	for zone in element_zones:
		if zone:
			result.append(zone)
	return result
