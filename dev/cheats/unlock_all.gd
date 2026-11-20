extends DevCheat
## Mở hết: mọi kỹ năng, vũ khí, bùa có trong project (quét file .tres). Dùng hàm public của GameState nên HUD,
## túi đồ và hướng dẫn cập nhật như khi nhặt thật. Mỗi ô vũ khí chỉ giữ một món nên vũ khí cùng ô lấy món cuối.

const SCAN := {
	"res://abilities/": "ability",
	"res://resources/combat/weapons/": "weapon",
	"res://resources/player/items/charms/": "charm",
}


func _init() -> void:
	title = "Mở hết kỹ năng, vũ khí, bùa"
	group = "3. Tiến trình"
	kind = Kind.ACTION
	order = 0


func run(_console: DevConsole) -> void:
	var abilities: Array[AbilityData] = []
	var weapons := 0
	var charms := 0
	for root: String in SCAN:
		for path in _find_resources(root):
			var resource := load(path)
			if resource is AbilityData:
				abilities.append(resource as AbilityData)
			elif resource is WeaponData:
				GameState.add_weapon(resource as WeaponData)
				weapons += 1
			elif resource is CharmData:
				GameState.add_charm(resource as CharmData)
				charms += 1
	# Dạng tiến hoá (Lốc xoáy của Thổi Gió) cũng là file kỹ năng riêng: không mở thẳng, chỉ có qua nâng cấp kỹ năng gốc
	var evolved: Array[AbilityData] = []
	for ability in abilities:
		for step in ability.upgrades:
			if step and step.evolves_into:
				evolved.append(step.evolves_into)
	var opened := 0
	for ability in abilities:
		if evolved.has(ability):
			continue
		GameState.unlock_ability(ability)
		_upgrade_to_max(ability)
		opened += 1
	print("DevConsole: mở %d kỹ năng (cấp tối đa), %d vũ khí, %d bùa" % [opened, weapons, charms])


## Nâng kỹ năng lên cấp cao nhất (Thổi Gió -> lốc xoáy...) qua đúng đường của NPC: đưa vật phẩm mỗi bậc yêu cầu
## rồi upgrade_ability, nên túi đồ, HUD, tab kỹ năng cập nhật như nâng thật. Vật phẩm bị trừ lại ngay khi nâng
func _upgrade_to_max(ability: AbilityData) -> void:
	var level := GameState.get_ability_level(ability)
	while level > 0 and level < ability.get_max_level():
		var step := ability.get_upgrade(level)
		if step == null:
			return
		for cost: ItemCost in step.requirements:
			var missing := cost.count - GameState.get_item_count(cost.item)
			if missing > 0:
				GameState.add_item(cost.item, missing)
		if not GameState.upgrade_ability(ability):
			push_warning("DevConsole: không nâng được %s lên cấp %d" % [ability.id, level + 1])
			return
		level = GameState.get_ability_level(ability)


func _find_resources(root: String) -> PackedStringArray:
	var result := PackedStringArray()
	var dir := DirAccess.open(root)
	if dir == null:
		return result
	for file in dir.get_files():
		var name := file.trim_suffix(".remap")
		if name.ends_with(".tres") or name.ends_with(".res"):
			result.append(root.path_join(name))
	for sub in dir.get_directories():
		result.append_array(_find_resources(root.path_join(sub)))
	return result
