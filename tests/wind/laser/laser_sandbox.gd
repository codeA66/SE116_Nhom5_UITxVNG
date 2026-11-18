extends Node
## Sân thử tượng bắn laser: hành lang có 3 tượng gắn tường tây bắn sang tường đông, lệch nhịp nhau 1 giây.
## Chơi tay: đi xuyên hành lang về phía bắc. Chạm tia đỏ đang bật mất 1 máu; tia mờ nhấp nháy là báo sắp bật (chưa đau);
## lộn (Shift) xuyên qua tia không mất máu. Tia dừng ở tường đông.
## Tắt tự lưu và đổi thư mục lưu khi mở sân: không ghi vào save thật đang chơi dở.

const STORAGE := "user://test_laser/"

@export var weapons: Array[Resource] = []


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
