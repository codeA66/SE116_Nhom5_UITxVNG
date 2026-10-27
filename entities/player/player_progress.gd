class_name PlayerProgress
extends Resource
## Tiến trình của người chơi: vũ khí, kỹ năng đã mở, cờ trạng thái thế giới.
## Chỉ chứa dữ liệu. Mọi thay đổi phải đi qua GameState để phát signal và tự lưu.

@export var weapon: WeaponData
## Danh sách đã nhặt; weapon phía trên chỉ là vũ khí đang chọn.
@export var weapons: Array[WeaponData] = []
@export var abilities: Array[AbilityData] = []
## Nguyên tố đang ghép vào từng ô vũ khí: WeaponData.Slot -> id nguyên tố. Không có khóa = chưa ghép
@export var fusions: Dictionary[int, StringName] = {}
## Cờ thế giới theo persistent_id, ví dụ "test_movement.sword_pickup" = vật đã nhặt
@export var flags: Dictionary[StringName, bool] = {}

@export_group("Checkpoint")
## Scene của khu chứa checkpoint gần nhất; rỗng = chưa có checkpoint
@export_file("*.tscn") var checkpoint_zone: String = ""
## Tên điểm xuất hiện của checkpoint trong khu đó
@export var checkpoint_spawn_id: StringName


func get_ability(id: StringName) -> AbilityData:
	for ability in abilities:
		if ability.id == id:
			return ability
	return null


func has_checkpoint() -> bool:
	return not checkpoint_zone.is_empty()


func get_weapon_in_slot(slot: WeaponData.Slot) -> WeaponData:
	for owned in weapons:
		if owned.slot == slot:
			return owned
	return null
