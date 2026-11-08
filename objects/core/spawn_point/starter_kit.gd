class_name StarterKit
extends Node
## Bộ đồ cấp sẵn khi player xuất hiện trong khu (vào từ cổng, hồi sinh ở checkpoint, chạy thử scene).
## Đặt làm con trực tiếp của ZoneRoot. Chỉ bù phần còn thiếu: vũ khí / kỹ năng đã có giữ nguyên,
## chỉ cầm held_weapon khi tay đang trống (không đè vũ khí người chơi đang cầm). Không dung hợp nguyên tố.

## Phát sau khi đã bù đồ (test / hiệu ứng nối vào)
signal applied(player: Player)

@export var weapons: Array[WeaponData] = []
@export var abilities: Array[AbilityData] = []
## Vũ khí cầm trên tay nếu chưa cầm gì; để trống = không cầm
@export var held_weapon: WeaponData


func _ready() -> void:
	var zone := get_parent() as ZoneRoot
	if zone == null:
		push_error("%s: StarterKit phải là con của ZoneRoot" % get_path())
		return
	# ZoneRoot._ready chạy sau con nên kịp nối trước khi player_spawned phát
	zone.player_spawned.connect(apply)


func apply(player: Player) -> void:
	for weapon: WeaponData in weapons:
		if weapon and GameState.get_weapon_in_slot(weapon.slot) == null:
			GameState.add_weapon(weapon)
	for ability: AbilityData in abilities:
		GameState.unlock_ability(ability)
	if held_weapon and GameState.get_weapon() == null:
		GameState.set_weapon(held_weapon)
	applied.emit(player)
