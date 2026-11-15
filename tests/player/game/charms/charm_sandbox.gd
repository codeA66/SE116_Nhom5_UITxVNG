extends Node
## Sân thử bùa: nhặt -> ghép -> buff. Foxy có kiếm; Bùa Phong Kiếm và Bùa Tâm Cáo nằm trên đất; khu đổi bùa có vạch vàng;
## vài thùng gỗ để chém, bẫy gai để thử mất máu.
## Chơi tay: F nhặt bùa -> đứng trong vạch vàng, Tab -> trang Bùa, đeo:
## - Phong Kiếm: chém nhanh hơn 25% (so nhịp chém thùng trước / sau).
## - Tâm Cáo: thanh máu 4 -> 6 ô, hai ô mới đầy luôn; dẫm bẫy gai thấy trừ đúng; tháo thì về 4.
## Mỗi bùa tốn 1 ô khắc, có 3 ô: đeo được cả hai bùa cùng lúc.
## Tắt tự lưu và đổi thư mục lưu khi mở sân: không ghi vào save thật đang chơi dở.

const STORAGE := "user://test_charms/"

@export var weapons: Array[Resource] = []
@export var abilities: Array[Resource] = []


func _enter_tree() -> void:
	SaveManager.use_storage_dir(STORAGE)
	for progress_signal: Signal in [GameState.progress_changed, GameState.progress_committed]:
		if progress_signal.is_connected(SaveManager.save_game):
			progress_signal.disconnect(SaveManager.save_game)


func _ready() -> void:
	for weapon in weapons:
		GameState.add_weapon(weapon as WeaponData)
	if not weapons.is_empty():
		GameState.set_weapon(weapons[0] as WeaponData)
	for ability in abilities:
		GameState.unlock_ability(ability as AbilityData)
	# Sân luôn bắt đầu chưa có bùa nào, bùa trên đất chưa bị nhặt
	GameState.progress.charms.clear()
	GameState.progress.equipped_charms.clear()
	GameState.progress.flags.clear()
	GameState.charms_changed.emit()
