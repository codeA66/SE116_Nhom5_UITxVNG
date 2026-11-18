extends Node
## Sân thử hội Ếch Hoả Vương (boss cuối map Lửa): sàn vuông 20x20 không viền, 4 bệ ngoài sân (B/Đ/N/T) để boss nhảy ra,
## 3 ngai trên gờ phía bắc. Con giữa xuống đánh một mình, cúi chào về ngai thì 2 con hai bên cùng xuống.
## Foxy có kiếm + cung + Thổi Gió (E) + Phun Lửa (Q). Chơi tay: né Mưa Hoả Cầu, Dậm Dung Nham, loạt cầu lửa xoè quạt
## từ bệ ngoài; bay lên (50% máu) thì miễn sát thương; hạ 1 trong 2 con thì con còn lại cuồng loạn.
## Tắt tự lưu và đổi thư mục lưu khi mở sân: không ghi vào save thật đang chơi dở.

const STORAGE := "user://test_fire_toad/"

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
