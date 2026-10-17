extends Node
## Autoload "GameState": giữ tiến trình người chơi suốt game, kể cả khi chuyển scene.
## Mọi thay đổi tiến trình đi qua đây; SaveManager nghe progress_changed để tự lưu.

signal progress_changed
signal ability_unlocked(ability: AbilityData)
signal weapon_changed(weapon: WeaponData)
signal checkpoint_changed(zone_path: String, spawn_id: StringName)
## Toàn bộ tiến trình bị thay (đọc save, chơi lại từ đầu)
signal progress_replaced

var progress: PlayerProgress = PlayerProgress.new()

var _player_health: int = -1
## Cờ chờ checkpoint (set_flag_on_checkpoint): chỉ ghi vào tiến trình khi chạm checkpoint mới;
## bị bỏ khi đổi khu, chết hay thoát game mà chưa chạm checkpoint
var _pending_flags: Dictionary[StringName, bool] = {}


func get_weapon() -> WeaponData:
	return progress.weapon


func set_weapon(weapon: WeaponData) -> void:
	# Giữ API cũ: cấp vũ khí rồi chọn, không làm mất vũ khí ở ô còn lại.
	if weapon:
		_store_weapon(weapon)
	if progress.weapon == weapon:
		return
	progress.weapon = weapon
	weapon_changed.emit(weapon)
	progress_changed.emit()


func add_weapon(weapon: WeaponData) -> void:
	if weapon == null or progress.get_weapon_in_slot(weapon.slot) == weapon:
		return
	_store_weapon(weapon)
	progress_changed.emit()


func get_weapon_in_slot(slot: WeaponData.Slot) -> WeaponData:
	return progress.get_weapon_in_slot(slot)


func select_weapon(slot: WeaponData.Slot) -> bool:
	var owned := get_weapon_in_slot(slot)
	if owned == null:
		return false
	set_weapon(owned)
	return true


func _store_weapon(weapon: WeaponData) -> void:
	for index in progress.weapons.size():
		if progress.weapons[index].slot == weapon.slot:
			progress.weapons[index] = weapon
			return
	progress.weapons.append(weapon)


func has_ability(id: StringName) -> bool:
	return progress.get_ability(id) != null


func get_ability(id: StringName) -> AbilityData:
	return progress.get_ability(id)


func unlock_ability(ability: AbilityData) -> void:
	if ability == null or has_ability(ability.id):
		return
	progress.abilities.append(ability)
	ability_unlocked.emit(ability)
	progress_changed.emit()


func has_flag(id: StringName) -> bool:
	return progress.flags.has(id)


func set_flag(id: StringName) -> void:
	if id.is_empty() or has_flag(id):
		return
	progress.flags[id] = true
	progress_changed.emit()


## Cờ chỉ được lưu khi người chơi chạm một checkpoint MỚI sau đó (thuyền đã tới bến, công tắc đã bật...).
## Chết, đổi khu hay thoát game trước khi chạm checkpoint thì vật trở về trạng thái cũ
func set_flag_on_checkpoint(id: StringName) -> void:
	if id.is_empty() or has_flag(id):
		return
	_pending_flags[id] = true


## SceneManager gọi khi đổi khu (kể cả hồi sinh): bỏ các cờ chưa kịp lưu
func discard_pending_flags() -> void:
	_pending_flags.clear()


## Thay toàn bộ tiến trình. Không phát progress_changed để không ghi đè file save ngay khi vừa đọc
func replace_progress(new_progress: PlayerProgress) -> void:
	progress = new_progress
	# Tương thích tiến trình cũ chỉ có một weapon.
	if progress.weapon:
		_store_weapon(progress.weapon)
	_pending_flags.clear()
	reset_player_health()
	progress_replaced.emit()


func has_checkpoint() -> bool:
	return progress.has_checkpoint()


func set_checkpoint(zone_path: String, spawn_id: StringName) -> void:
	if progress.checkpoint_zone == zone_path and progress.checkpoint_spawn_id == spawn_id:
		return
	progress.checkpoint_zone = zone_path
	progress.checkpoint_spawn_id = spawn_id
	# Checkpoint mới: các cờ đang chờ được ghi luôn trong lần lưu này
	for id in _pending_flags:
		progress.flags[id] = true
	_pending_flags.clear()
	checkpoint_changed.emit(zone_path, spawn_id)
	progress_changed.emit()


func get_checkpoint_zone() -> String:
	return progress.checkpoint_zone


func get_checkpoint_spawn_id() -> StringName:
	return progress.checkpoint_spawn_id


## Máu player giữ qua các lần chuyển khu (player là object mới mỗi khu). Không ghi ra file save:
## mở lại game hay hồi sinh đều đầy máu. -1 = đầy
func get_player_health() -> int:
	return _player_health


func set_player_health(value: int) -> void:
	_player_health = value


func reset_player_health() -> void:
	_player_health = -1
