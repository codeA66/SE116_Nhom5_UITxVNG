extends Node
## Autoload "GameState": giữ tiến trình người chơi suốt game, kể cả khi chuyển scene.
## Mọi thay đổi tiến trình đi qua đây; SaveManager nghe progress_changed để tự lưu.

signal progress_changed
signal ability_unlocked(ability: AbilityData)
signal weapon_changed(weapon: WeaponData)
signal checkpoint_changed(zone_path: String, spawn_id: StringName)
## Toàn bộ tiến trình bị thay (đọc save, chơi lại từ đầu)
signal progress_replaced
## Ghép / tháo / chuyển nguyên tố giữa các vũ khí
signal fusion_changed

const NEW_GAME: NewGameData = preload("res://resources/player/new_game.tres")
const FUSIONS: FusionTable = preload("res://resources/fusion/fusion_table.tres")

var progress: PlayerProgress = PlayerProgress.new()

var _player_health: int = -1
var _player_energy: int = -1
## Cờ chờ checkpoint (set_flag_on_checkpoint): chỉ ghi vào tiến trình khi chạm checkpoint mới;
## bị bỏ khi đổi khu, chết hay thoát game mà chưa chạm checkpoint
var _pending_flags: Dictionary[StringName, bool] = {}


func _ready() -> void:
	_grant_starting_abilities()


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


## Nguyên tố người chơi đang có (kỹ năng gốc đã mở khóa)
func get_owned_elements() -> Array[ElementData]:
	var owned: Array[ElementData] = []
	for element in FUSIONS.elements:
		if element.ability and has_ability(element.ability.id):
			owned.append(element)
	return owned


## Nguyên tố đang ghép ở ô vũ khí slot; null nếu chưa ghép
func get_fused_element(slot: WeaponData.Slot) -> ElementData:
	return FUSIONS.get_element(progress.fusions.get(slot, &""))


## Chiêu ghép của vũ khí đang cầm; null nếu vũ khí chưa ghép hoặc tổ hợp chưa có chiêu
func get_active_fusion() -> FusionData:
	var weapon := get_weapon()
	if weapon == null:
		return null
	var element := get_fused_element(weapon.slot)
	return FUSIONS.get_fusion(weapon.slot, element.id) if element else null


## Kỹ năng đang bị khóa vì nguyên tố của nó đang ghép vào vũ khí
func is_ability_fused(ability_id: StringName) -> bool:
	var element := FUSIONS.get_element_by_ability(ability_id)
	return element != null and progress.fusions.values().has(element.id)


## Ghép nguyên tố vào ô vũ khí. Nguyên tố đang ở vũ khí khác thì chuyển sang (mỗi nguyên tố chỉ ở một chỗ),
## vũ khí đích đang có nguyên tố khác thì nguyên tố cũ được tháo ra (mỗi vũ khí một nguyên tố)
func fuse(element_id: StringName, slot: WeaponData.Slot) -> bool:
	var element := FUSIONS.get_element(element_id)
	if element == null or not get_owned_elements().has(element) or get_weapon_in_slot(slot) == null:
		return false
	if progress.fusions.get(slot, &"") == element_id:
		return true
	for other: int in progress.fusions.keys():
		if progress.fusions[other] == element_id:
			progress.fusions.erase(other)
	progress.fusions[slot] = element_id
	fusion_changed.emit()
	progress_changed.emit()
	return true


func unfuse(slot: WeaponData.Slot) -> void:
	if not progress.fusions.has(slot):
		return
	progress.fusions.erase(slot)
	fusion_changed.emit()
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
	# Cung đã thành vũ khí phụ (phím aim): save cũ đang cầm cung thì về kiếm, chưa có kiếm thì tay không
	if progress.weapon is BowData:
		progress.weapon = progress.get_weapon_in_slot(WeaponData.Slot.SWORD)
	_grant_starting_abilities()
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
	_player_energy = -1


## Năng lượng giữ qua các lần chuyển khu như máu; không ghi ra file save. -1 = đầy
func get_player_energy() -> int:
	return _player_energy


func set_player_energy(value: int) -> void:
	_player_energy = value


## Kỹ năng khởi đầu luôn có, kể cả save cũ tạo trước khi thêm chúng. Không phát signal: không phải vừa nhặt
func _grant_starting_abilities() -> void:
	for ability in NEW_GAME.starting_abilities:
		if ability and not has_ability(ability.id):
			progress.abilities.append(ability)
