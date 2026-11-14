extends Node
## Sân thử thùng phá được: Foxy có kiếm + cung + Thổi Gió, năng lượng bắt đầu từ 0, vài thùng gỗ quanh sân.
## Chơi tay: chém thùng -> mỗi nhát nạp 1 ô năng lượng, 3 nhát thì vỡ, 5 giây sau mọc lại.
## Bắn tên / thổi gió vào thùng: trừ máu, làm vỡ, nhưng không nạp năng lượng.
## Tắt tự lưu và đổi thư mục lưu khi mở sân: không ghi vào save thật đang chơi dở.

const STORAGE := "user://test_breakables/"

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
	_empty_energy.call_deferred()


func _empty_energy() -> void:
	var player := get_parent().get_node_or_null(^"Player") as Player
	if player:
		player.energy.set_current(0)
