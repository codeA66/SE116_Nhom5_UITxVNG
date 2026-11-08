class_name PlayerProgress
extends Resource
## Tiến trình của người chơi: vũ khí, kỹ năng đã mở, cờ trạng thái thế giới.
## Chỉ chứa dữ liệu. Mọi thay đổi phải đi qua GameState để phát signal; chỉ được ghi ra file khi chạm checkpoint.
## Thêm trường mới thì nhớ chép trong snapshot()

@export var weapon: WeaponData
## Danh sách đã nhặt; weapon phía trên chỉ là vũ khí đang chọn.
@export var weapons: Array[WeaponData] = []
@export var abilities: Array[AbilityData] = []
## Nguyên tố đang ghép vào từng ô vũ khí: WeaponData.Slot -> id nguyên tố. Không có khóa = chưa ghép
@export var fusions: Dictionary[int, StringName] = {}
## Cờ thế giới theo persistent_id, ví dụ "test_movement.sword_pickup" = vật đã nhặt
@export var flags: Dictionary[StringName, bool] = {}
## Tiền theo CurrencyData.id -> số đang có (không có khoá = 0). Đi theo bản chụp checkpoint như mọi tiến trình khác
@export var currencies: Dictionary[StringName, int] = {}
## Vật phẩm đếm theo số lượng: ItemData.id -> số đang có (vật liệu nâng cấp...). Chìa khóa theo cờ, không nằm đây
@export var items: Dictionary[StringName, int] = {}
## Cấp kỹ năng đã nâng: AbilityData.id -> cấp (không có khóa = cấp 1)
@export var ability_levels: Dictionary[StringName, int] = {}
## Bùa đã có và bùa đang đeo (theo CharmData.id)
@export var charms: Array[StringName] = []
@export var equipped_charms: Array[StringName] = []
## Số ô khắc để đeo bùa; -1 = chưa đặt (lấy theo NewGameData)
@export var charm_notches: int = -1
## Vật phẩm dùng nút đang chọn (ItemData.id, ví dụ TNT): phím use_item (T) dùng vật phẩm này. Rỗng = chưa chọn
@export var selected_item: StringName

@export_group("Checkpoint")
## Scene của khu chứa checkpoint gần nhất; rỗng = chưa có checkpoint
@export_file("*.tscn") var checkpoint_zone: String = ""
## Tên điểm xuất hiện của checkpoint trong khu đó
@export var checkpoint_spawn_id: StringName


## Bản chụp để chốt ở checkpoint / khôi phục khi chết. Mảng và từ điển được chép riêng (sửa bản này không đụng
## bản kia); WeaponData / AbilityData giữ nguyên tham chiếu vì là dữ liệu cố định dùng chung, và code so sánh
## vũ khí theo tham chiếu
func snapshot() -> PlayerProgress:
	var copy := PlayerProgress.new()
	copy.weapon = weapon
	copy.weapons = weapons.duplicate()
	copy.abilities = abilities.duplicate()
	copy.fusions = fusions.duplicate()
	copy.flags = flags.duplicate()
	copy.currencies = currencies.duplicate()
	copy.items = items.duplicate()
	copy.ability_levels = ability_levels.duplicate()
	copy.charms = charms.duplicate()
	copy.equipped_charms = equipped_charms.duplicate()
	copy.charm_notches = charm_notches
	copy.selected_item = selected_item
	copy.checkpoint_zone = checkpoint_zone
	copy.checkpoint_spawn_id = checkpoint_spawn_id
	return copy


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
