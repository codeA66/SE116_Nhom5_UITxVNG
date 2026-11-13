extends Node
## Sân thử nhặt Ấn Gió: Foxy có kiếm + Thổi Gió cấp 1, một Ấn Gió nằm trên sân.
## Chơi tay: đi tới Ấn Gió, nhấn F -> màn giới thiệu Lốc xoáy (như lúc học sách Gió) -> E thả lốc vào hình nộm / quái.
## Tắt tự lưu và đổi thư mục lưu khi mở sân: không ghi vào save thật đang chơi dở.

const STORAGE := "user://test_wind_upgrade/"

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
		# Sân luôn bắt đầu ở cấp 1, chưa có Ấn nào, Ấn trên sân chưa bị nhặt
		GameState.progress.ability_levels.erase((ability as AbilityData).id)
	GameState.progress.items.clear()
	GameState.progress.flags.clear()
