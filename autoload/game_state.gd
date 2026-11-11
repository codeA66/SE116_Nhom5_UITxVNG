extends Node
## Autoload "GameState": giữ tiến trình người chơi suốt game, kể cả khi chuyển scene.
## Mọi thay đổi tiến trình đi qua đây và có hiệu lực ngay trong lượt chơi (cổng mở, trận đã thắng...).
## Checkpoint lưu tất cả: chạm checkpoint thì chốt bản chụp tiến trình và SaveManager ghi file (progress_committed);
## chết thì mọi thứ về đúng bản chụp đó (quái sống lại, chìa / đồ vừa nhặt mất, cổng vừa mở đóng lại).
## Chuyển khu qua cổng không chốt, không khôi phục.

## Tiến trình trong lượt chơi vừa đổi (HUD, cổng, trận nghe để phản ứng). Không ghi file
signal progress_changed
## Chạm checkpoint: tiến trình được chốt, SaveManager ghi file
signal progress_committed
signal ability_unlocked(ability: AbilityData)
signal weapon_changed(weapon: WeaponData)
signal checkpoint_changed(zone_path: String, spawn_id: StringName)
## Toàn bộ tiến trình bị thay (đọc save, chơi lại từ đầu)
signal progress_replaced
## Ghép / tháo / chuyển nguyên tố giữa các vũ khí
signal fusion_changed
## Tiền loại id vừa đổi (HUD, âm thanh nghe). Chết / nạp save thì nghe progress_replaced
signal currency_changed(id: StringName, total: int)
## Số lượng vật phẩm trong túi đổi (nhặt, NPC lấy đi khi nâng cấp)
signal items_changed
## Kỹ năng vừa được NPC nâng lên cấp level
signal ability_level_changed(ability: AbilityData, level: int)
## Đeo / tháo / có thêm bùa, đổi số ô khắc
signal charms_changed
## Vừa vào / ra khu đổi bùa (màn Tab bật / tắt việc đeo bùa)
signal charm_station_changed(inside: bool)
## Đổi vật phẩm đang chọn dùng bằng phím use_item (TNT...)
signal selected_item_changed
## Mở khóa bài hướng dẫn mới (Popup và Sổ Hướng Dẫn nghe)
signal tutorial_unlocked(tutorial: TutorialData)
## Danh sách bài hướng dẫn vừa đổi
signal tutorials_changed

const NEW_GAME: NewGameData = preload("res://resources/player/new_game.tres")
const FUSIONS: FusionTable = preload("res://resources/combat/fusion/fusion_table.tres")
const ITEMS: ItemCatalog = preload("res://resources/player/items/catalog.tres")
const TUTORIALS: TutorialCatalog = preload("res://resources/tutorials/catalog.tres")

var progress: PlayerProgress = PlayerProgress.new()

var _player_health: int = -1
var _player_energy: int = -1
## Bản chụp tiến trình ở lần chạm checkpoint gần nhất (hoặc lúc đọc save / bắt đầu game): chết thì quay về đây
var _committed: PlayerProgress
## Số khu đổi bùa player đang đứng trong (không lưu: rời khu / tải lại scene là về 0)
var _charm_stations: int = 0


func _ready() -> void:
	_grant_starting_abilities()
	_committed = progress.snapshot()
	# Player nào vào cây cũng được gắn QuickItemUser (dùng vật phẩm bằng phím use_item) mà không sửa player
	get_tree().node_added.connect(_on_node_added)


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


## Mọi kỹ năng đã mở khoá (không sao chép: chỉ đọc, đừng sửa mảng trả về)
func get_abilities() -> Array[AbilityData]:
	return progress.abilities


func unlock_ability(ability: AbilityData) -> void:
	if ability == null or has_ability(ability.id):
		return
	progress.abilities.append(ability)
	ability_unlocked.emit(ability)
	progress_changed.emit()
	unlock_tutorial(ability.id, false)


## Chọn vật phẩm dùng nút (QuickItemData, đã có trong túi) để phím use_item (T) dùng. id rỗng = bỏ chọn
func select_item(item_id: StringName) -> bool:
	if not item_id.is_empty():
		var item := ITEMS.get_item(item_id) as QuickItemData
		if item == null or get_item_count(item) <= 0:
			return false
	if progress.selected_item == item_id:
		return true
	progress.selected_item = item_id
	selected_item_changed.emit()
	progress_changed.emit()
	return true


## Vật phẩm đang chọn dùng; null nếu chưa chọn (hoặc không còn trong túi)
func get_selected_item() -> QuickItemData:
	if progress.selected_item.is_empty():
		return null
	var item := ITEMS.get_item(progress.selected_item) as QuickItemData
	return item if item and get_item_count(item) > 0 else null


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


## Số tiền đang có của loại id (CurrencyData.id); loại chưa từng có = 0
func get_currency(id: StringName) -> int:
	return progress.currencies.get(id, 0)


## Đủ tiền để trả amount không (hỏi trước khi hiện nút / mở cổng); không đổi tiền
func can_afford(id: StringName, amount: int) -> bool:
	return amount >= 0 and get_currency(id) >= amount


## Cộng tiền. Không phát progress_changed: nhặt tiền liên tục không cần cổng / trận kiểm tra lại
func add_currency(id: StringName, amount: int) -> void:
	if not _is_valid_currency_call(id, amount) or amount == 0:
		return
	progress.currencies[id] = get_currency(id) + amount
	currency_changed.emit(id, progress.currencies[id])


## Trừ tiền nếu đủ (người gác cổng, cửa hàng). Thiếu thì không trừ, không phát signal, trả về false
func spend_currency(id: StringName, amount: int) -> bool:
	if not _is_valid_currency_call(id, amount) or not can_afford(id, amount):
		return false
	if amount == 0:
		return true
	progress.currencies[id] = get_currency(id) - amount
	currency_changed.emit(id, progress.currencies[id])
	return true


## Số đang có của một vật phẩm (theo số lượng, hoặc theo cờ với chìa khóa)
func get_item_count(item: ItemData) -> int:
	return item.count_in(progress) if item else 0


## Cộng vật phẩm đếm theo số lượng (nhặt được, phần thưởng). Vật phẩm theo cờ thì dùng set_flag
func add_item(item: ItemData, amount: int = 1) -> void:
	if item == null or amount <= 0 or not item.owned_flag.is_empty():
		return
	progress.items[item.id] = progress.items.get(item.id, 0) + amount
	items_changed.emit()
	progress_changed.emit()


## Cấp hiện tại của kỹ năng; 0 nếu chưa có kỹ năng
func get_ability_level(ability: AbilityData) -> int:
	if ability == null or not has_ability(ability.id):
		return 0
	return clampi(progress.ability_levels.get(ability.id, 1), 1, ability.get_max_level())


## Đủ điều kiện nâng lên cấp tiếp theo (đã có kỹ năng, chưa tối đa, đủ vật phẩm). Không đổi gì
func can_upgrade_ability(ability: AbilityData) -> bool:
	var level := get_ability_level(ability)
	var step := ability.get_upgrade(level) if level > 0 else null
	return step != null and step.is_affordable(progress)


## NPC nâng cấp kỹ năng: lấy đi vật phẩm yêu cầu rồi tăng một cấp. Thiếu thì không đổi gì, trả về false
func upgrade_ability(ability: AbilityData) -> bool:
	if not can_upgrade_ability(ability):
		return false
	var level := get_ability_level(ability)
	for cost: ItemCost in ability.get_upgrade(level).requirements:
		progress.items[cost.item.id] = progress.items.get(cost.item.id, 0) - cost.count
		if progress.items[cost.item.id] <= 0:
			progress.items.erase(cost.item.id)
	progress.ability_levels[ability.id] = level + 1
	items_changed.emit()
	ability_level_changed.emit(ability, level + 1)
	progress_changed.emit()
	return true


func owns_charm(id: StringName) -> bool:
	return progress.charms.has(id)


func add_charm(charm: CharmData) -> void:
	if charm == null or owns_charm(charm.id):
		return
	progress.charms.append(charm.id)
	charms_changed.emit()
	progress_changed.emit()


func is_charm_equipped(id: StringName) -> bool:
	return progress.equipped_charms.has(id)


func get_charm_notches() -> int:
	return progress.charm_notches if progress.charm_notches >= 0 else NEW_GAME.charm_notches


## Số ô khắc đang bị bùa đeo chiếm
func get_used_notches() -> int:
	var used := 0
	for id: StringName in progress.equipped_charms:
		var charm := ITEMS.get_charm(id)
		used += charm.notch_cost if charm else 0
	return used


## Chỉ đổi bùa được khi đứng trong khu đổi bùa
func can_change_charms() -> bool:
	return _charm_stations > 0


## Đeo bùa: cần đang ở khu đổi bùa, đã có bùa và còn đủ ô khắc
func equip_charm(id: StringName) -> bool:
	var charm := ITEMS.get_charm(id)
	if charm == null or not can_change_charms() or not owns_charm(id) or is_charm_equipped(id):
		return false
	if get_used_notches() + charm.notch_cost > get_charm_notches():
		return false
	progress.equipped_charms.append(id)
	charms_changed.emit()
	progress_changed.emit()
	return true


func unequip_charm(id: StringName) -> bool:
	if not can_change_charms() or not is_charm_equipped(id):
		return false
	progress.equipped_charms.erase(id)
	charms_changed.emit()
	progress_changed.emit()
	return true


## CharmStation gọi khi player bước vào / ra khu đổi bùa
func enter_charm_station() -> void:
	_charm_stations += 1
	if _charm_stations == 1:
		charm_station_changed.emit(true)


func exit_charm_station() -> void:
	if _charm_stations <= 0:
		return
	_charm_stations -= 1
	if _charm_stations == 0:
		charm_station_changed.emit(false)


## Kiểm tra bài hướng dẫn đã mở khóa chưa
func has_tutorial(id: StringName) -> bool:
	return progress.unlocked_tutorials.has(id)


## Lấy danh sách các TutorialData đã mở khóa theo đúng thứ tự
func get_unlocked_tutorials() -> Array[TutorialData]:
	var result: Array[TutorialData] = []
	for id: StringName in progress.unlocked_tutorials:
		var tut := TUTORIALS.get_tutorial(id)
		if tut:
			result.append(tut)
	return result


## Mở khóa hướng dẫn: nếu chưa có thì thêm vào danh sách, set cờ và phát signal (popup = false để lưu âm thầm)
func unlock_tutorial(tutorial_or_id: Variant, popup: bool = true) -> bool:
	var tutorial: TutorialData = null
	var id: StringName = &""
	if tutorial_or_id is TutorialData:
		tutorial = tutorial_or_id as TutorialData
		id = tutorial.id
	elif tutorial_or_id is StringName or tutorial_or_id is String:
		id = StringName(tutorial_or_id)
		tutorial = TUTORIALS.get_tutorial(id)
	
	if id.is_empty() or has_tutorial(id):
		return false
	
	progress.unlocked_tutorials.append(id)
	set_flag(StringName("tut_" + String(id)))
	tutorials_changed.emit()
	progress_changed.emit()
	if tutorial and popup:
		tutorial_unlocked.emit(tutorial)
	return true


func has_flag(id: StringName) -> bool:
	return progress.flags.has(id)


func set_flag(id: StringName) -> void:
	if id.is_empty() or has_flag(id):
		return
	progress.flags[id] = true
	progress_changed.emit()


## Giữ cho code cũ: giờ mọi cờ đều chỉ được ghi file khi chạm checkpoint, nên giống hệt set_flag
func set_flag_on_checkpoint(id: StringName) -> void:
	set_flag(id)


## Không còn cờ chờ riêng (mọi thứ chờ checkpoint). Giữ hàm rỗng để test cũ (test_boat_integration) còn biên dịch
func discard_pending_flags() -> void:
	pass


## Chết: mọi thứ về bản chụp ở lần chạm checkpoint gần nhất. SceneManager gọi lúc màn đã tối, trước khi tải lại khu
func restore_checkpoint() -> void:
	var old_tutorials := progress.unlocked_tutorials.duplicate()
	progress = _committed.snapshot()
	for tut_id: StringName in old_tutorials:
		if not progress.unlocked_tutorials.has(tut_id):
			progress.unlocked_tutorials.append(tut_id)
			progress.flags[StringName("tut_" + String(tut_id))] = true
	reset_player_health()
	progress_replaced.emit()
	tutorials_changed.emit()


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
	# Vừa đọc save / bắt đầu mới: đây là mốc để chết thì quay về
	_committed = progress.snapshot()
	reset_player_health()
	progress_replaced.emit()
	tutorials_changed.emit()


func has_checkpoint() -> bool:
	return progress.has_checkpoint()


## Chạm checkpoint (kể cả chạm lại đúng checkpoint cũ): chốt toàn bộ tiến trình hiện tại và ghi file
func set_checkpoint(zone_path: String, spawn_id: StringName) -> void:
	var moved := progress.checkpoint_zone != zone_path or progress.checkpoint_spawn_id != spawn_id
	progress.checkpoint_zone = zone_path
	progress.checkpoint_spawn_id = spawn_id
	_committed = progress.snapshot()
	if moved:
		checkpoint_changed.emit(zone_path, spawn_id)
		progress_changed.emit()
	progress_committed.emit()


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


## Lời gọi tiền hợp lệ: id không rỗng, số không âm. Sai thì cảnh báo (lỗi code gọi), không đổi tiền
func _is_valid_currency_call(id: StringName, amount: int) -> bool:
	if id.is_empty():
		push_warning("GameState: gọi tiền với id rỗng")
		return false
	if amount < 0:
		push_warning("GameState: số tiền âm (%d) cho '%s', dùng spend_currency để trừ" % [amount, id])
		return false
	return true


func _on_node_added(node: Node) -> void:
	if node is Player:
		QuickItemUser.ensure.call_deferred(node as Player)
