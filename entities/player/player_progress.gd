class_name PlayerProgress
extends Resource
## Tiến trình của người chơi: vũ khí, kỹ năng đã mở, cờ trạng thái thế giới.
## Chỉ chứa dữ liệu. Mọi thay đổi phải đi qua GameState để phát signal và tự lưu.

@export var weapon: WeaponData
@export var abilities: Array[AbilityData] = []
## Cờ thế giới theo persistent_id, ví dụ "test_movement.sword_pickup" = vật đã nhặt
@export var flags: Dictionary[StringName, bool] = {}


func get_ability(id: StringName) -> AbilityData:
	for ability in abilities:
		if ability.id == id:
			return ability
	return null
