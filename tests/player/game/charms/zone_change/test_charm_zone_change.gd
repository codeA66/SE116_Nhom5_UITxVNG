extends Node
## Đổi khu khi đang đeo bùa thêm máu không được mất máu (lỗi 28/11/2026: đeo Bùa Tâm Cáo +2 máu, vào đấu trường hổ
## tự nhiên còn 4/6). Đổi khu thật qua SceneManager, save riêng của test.
##
## ===== USE CASE =====
## UC1  Đeo bùa thêm máu, đổi sang khu khác -> máu hiện tại và máu tối đa giữ nguyên như trước khi đổi.
## UC2  Đang thiếu máu rồi đổi khu -> giữ đúng máu đang có (không đầy lại, không kẹp về mức gốc).
## UC3  Tháo bùa khi đang chơi (ở checkpoint) vẫn kẹp về mức gốc như cũ.
## Không ghi cứng số máu: mức gốc đọc từ player, phần cộng thêm đọc từ dữ liệu bùa, nên đổi máu gốc / bùa
## (7, 8 máu...) test không phải sửa.
##
## ===== TEST CASE =====
## TC1 (UC1) Khu A -> khu B: (máu, máu tối đa) của player khu B == player khu A ngay trước khi đổi, và
##           máu tối đa == mức gốc + phần cộng của bùa.
## TC2 (UC2) Trừ 1 máu -> đổi khu -> khu mới giữ đúng (máu, máu tối đa) trước khi đổi.
## TC3 (UC3) Tháo bùa -> máu tối đa về mức gốc, máu bị kẹp không vượt mức gốc.

const ZONE := "res://levels/zone_3_fire/tier_1/tiger_arena/tiger_arena.tscn"
const SPAWN := &"tiger_arena_entry"
const HEART := "res://resources/player/items/charms/heart_charm.tres"

var _fails: int = 0


func _ready() -> void:
	if GameState.progress_changed.is_connected(SaveManager.save_game):
		GameState.progress_changed.disconnect(SaveManager.save_game)
	if GameState.progress_committed.is_connected(SaveManager.save_game):
		GameState.progress_committed.disconnect(SaveManager.save_game)
	_run.call_deferred()


func _run() -> void:
	# Node rỗng làm current_scene để test không bị giải phóng khi SceneManager đổi khu
	var stand_in := Node.new()
	get_tree().root.add_child.call_deferred(stand_in)
	await get_tree().process_frame
	get_tree().current_scene = stand_in
	reparent(get_tree().root)
	GameState.replace_progress(PlayerProgress.new())
	GameState.reset_player_health()
	GameState.add_charm(load(HEART) as CharmData)
	GameState.enter_charm_station()
	GameState.equip_charm(&"heart_charm")
	GameState.exit_charm_station()
	var player := await _change_zone()
	var bonus := _heart_bonus()
	var base := player.health.max_health - bonus if player else 0
	_check(player != null and bonus > 0 and player.health.current_health == player.health.max_health, "TC1: khu A đầy máu, bùa cộng +%d (%s)" % [bonus, _hp(player)])
	var before := _state(player)
	player = await _change_zone()
	_check(_state(player) == before, "TC1: sang khu B giữ nguyên máu %s -> %s" % [before, _state(player)])
	_check(player != null and player.health.max_health == base + bonus, "TC1: máu tối đa = gốc %d + bùa %d (%s)" % [base, bonus, _hp(player)])
	player.health.take_damage(1)
	await get_tree().process_frame
	before = _state(player)
	player = await _change_zone()
	_check(_state(player) == before, "TC2: thiếu máu đổi khu vẫn giữ %s -> %s" % [before, _state(player)])
	GameState.enter_charm_station()
	GameState.unequip_charm(&"heart_charm")
	GameState.exit_charm_station()
	await get_tree().process_frame
	_check(player.health.max_health == base and player.health.current_health <= base, "TC3: tháo bùa -> máu tối đa về gốc %d (%s)" % [base, _hp(player)])
	print("RESULT fails=%d" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _change_zone() -> Player:
	SceneManager.change_zone(ZONE, SPAWN)
	var t := 0.0
	while SceneManager.is_busy() and t < 20.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	for i in 20:
		await get_tree().physics_frame
	var zone := get_tree().current_scene
	return zone.get_node_or_null("Player") as Player if zone else null


## Phần máu tối đa Bùa Tâm Cáo cộng thêm, đọc từ dữ liệu bùa (không ghi cứng)
func _heart_bonus() -> int:
	var total := 0
	for effect in (load(HEART) as CharmData).effects:
		if effect is StatBonusEffect and (effect as StatBonusEffect).stat == &"max_health":
			total += roundi((effect as StatBonusEffect).bonus)
	return total


func _state(player: Player) -> Vector2i:
	return Vector2i(-99, -99) if player == null else Vector2i(player.health.current_health, player.health.max_health)


func _hp(player: Player) -> String:
	return "null" if player == null else "%d/%d" % [player.health.current_health, player.health.max_health]


func _check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		_fails += 1
