class_name ZoneClearedUnlock
extends UnlockCondition
## Cần đã phá đảo các khu trong danh sách (khu trước mở khu sau; đủ 4 khu mở cửa đền).

@export var zones: Array[ZoneData] = []
@export var hint: String = "Phá đảo khu trước"


func is_met() -> bool:
	for zone in zones:
		if zone == null or not zone.is_cleared():
			return false
	return true


func get_hint() -> String:
	return hint
