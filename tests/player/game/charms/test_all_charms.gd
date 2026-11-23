extends Node
## Test chung cho MỌI bùa trong catalog (resources/player/items/catalog.tres). Thêm bùa mới vào catalog là test tự kiểm,
## không phải viết thêm: dữ liệu hợp lệ, đeo / tháo sạch, kết hợp, đổi khu, lưu, luật đổi bùa ở checkpoint.
## Chạy: mở tests/player/game/charms/test_all_charms.tscn rồi F6. Tự ngắt tự lưu, không ghi save thật.
## Kết quả: từng dòng PASS / FAIL, cuối cùng "RESULT fails=N" (0 là đạt).
##
## ===== USE CASE =====
## UC1 Dữ liệu: id không trống, không trùng; có tên, mô tả; khấc 1–6; không effect null; mọi bùa đeo vừa số khấc tối đa.
## UC2 Đeo một bùa: chỉ số mà effect dữ liệu khai báo (StatMultiplierEffect / StatBonusEffect) đổi đúng giá trị.
## UC3 Tháo một bùa: mọi chỉ số, máu tối đa, năng lượng tối đa và số node con của player về đúng như trước khi đeo.
## UC4 Đeo trùng bùa đang đeo bị từ chối; đeo / tháo 20 lần liên tục vẫn về đúng ban đầu.
## UC5 Kết hợp: mọi tổ hợp vừa số khấc đeo được, tổng khấc đúng, chỉ số nhân / cộng dồn đúng; vượt khấc bị từ chối;
##     tháo theo thứ tự ngược hay xuôi đều về ban đầu.
## UC6 Đổi khu / chết hồi sinh (dựng lại scene): player mới có đúng tác dụng bùa đang đeo, không áp hai lần, không mất.
## UC7 Lưu / đọc: danh sách bùa có và bùa đang đeo giữ nguyên qua SaveManager.to_dict / from_dict.
## UC8 Luật đổi bùa: ngoài checkpoint không đeo / tháo được; đứng trong vùng chạm 1,4 m của checkpoint thì được;
##     ra khỏi vùng (cách 2,2 m) thì lại không được.
##
## Giới hạn: bùa có hành vi riêng (CharmEffect tự viết) chỉ được kiểm "tháo xong không sót gì";
## việc bùa đó làm đúng hay không phải có test riêng (ví dụ tests/player/game/charms/combat/test_combat_charms).

const COMBAT_SANDBOX := "res://tests/fire/sandbox/fire_sandbox.tscn"
const CHARM_SANDBOX := "res://tests/player/game/charms/charm_sandbox.tscn"
const MAX_HEALTH_STAT := &"max_health"
## Số lần đeo / tháo liên tục ở UC4
const SPAM_TIMES := 20
## Khoảng cách thử luật checkpoint (vùng chạm bán kính 1,4 m)
const INSIDE_DISTANCE := 0.6
const OUTSIDE_DISTANCE := 2.2

var _fails: int = 0
var _lv: Node
var _p: Player
var _charms: Array[CharmData] = []
## Mọi tên chỉ số mà bùa dữ liệu khai báo: so sánh chỉ số trước / sau theo danh sách này
var _stats: Array[StringName] = []


func _ready() -> void:
	# Không để test ghi đè save thật đang chơi dở
	if GameState.progress_changed.is_connected(SaveManager.save_game):
		GameState.progress_changed.disconnect(SaveManager.save_game)
	if GameState.progress_committed.is_connected(SaveManager.save_game):
		GameState.progress_committed.disconnect(SaveManager.save_game)
	_run.call_deferred()


func _run() -> void:
	_collect()
	_uc1_data()
	await _open(COMBAT_SANDBOX)
	await _uc2_uc3_single()
	await _uc4_repeat()
	await _uc5_combos()
	await _uc6_rebuild()
	_uc7_save()
	_close()
	await _uc8_checkpoint()
	print("RESULT fails=%d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _collect() -> void:
	for charm in GameState.ITEMS.charms:
		_charms.append(charm)
		if charm == null:
			continue
		for effect in charm.effects:
			var stat := _effect_stat(effect)
			if not stat.is_empty() and not _stats.has(stat):
				_stats.append(stat)
	print("INFO %d bùa trong catalog, chỉ số khai báo: %s" % [_charms.size(), _stats])


# ===== UC1 =====
func _uc1_data() -> void:
	_check(not _charms.is_empty(), "UC1 catalog có bùa")
	var ids: Array[StringName] = []
	var max_notches := GameState.NEW_GAME.charm_notches
	for i in _charms.size():
		var charm := _charms[i]
		var label := "UC1 bùa #%d" % i
		_check(charm != null, label + " không null")
		if charm == null:
			continue
		label = "UC1 [%s]" % charm.id
		_check(not String(charm.id).is_empty(), label + " có id")
		_check(not ids.has(charm.id), label + " id không trùng")
		ids.append(charm.id)
		_check(not charm.display_name.strip_edges().is_empty(), label + " có tên hiển thị")
		_check(not charm.description.strip_edges().is_empty(), label + " có mô tả")
		_check(charm.notch_cost >= 1 and charm.notch_cost <= 6, label + " khấc trong 1–6 (đang %d)" % charm.notch_cost)
		_check(charm.notch_cost <= max_notches, label + " đeo vừa số khấc tối đa %d" % max_notches)
		_check(not charm.effects.is_empty(), label + " có ít nhất một effect")
		for e in charm.effects:
			_check(e != null, label + " không có effect null")
			var stat := _effect_stat(e)
			if e is StatMultiplierEffect or e is StatBonusEffect:
				_check(not stat.is_empty(), label + " effect chỉ số có tên chỉ số")
			if e is StatMultiplierEffect:
				_check((e as StatMultiplierEffect).multiplier > 0.0, label + " hệ số nhân > 0")


# ===== UC2 + UC3 =====
func _uc2_uc3_single() -> void:
	var base := _snapshot()
	for charm in _charms:
		if charm == null:
			continue
		var label := "[%s]" % charm.id
		_give(charm)
		_check(GameState.equip_charm(charm.id), "UC2 %s đeo được" % label)
		await _f(2)
		_check(GameState.is_charm_equipped(charm.id), "UC2 %s đang đeo" % label)
		var expected := _expected(base, [charm])
		_expect_stats(expected, "UC2 %s chỉ số khi đeo" % label)
		_check(GameState.unequip_charm(charm.id), "UC3 %s tháo được" % label)
		await _f(2)
		_expect_same(base, _snapshot(), "UC3 %s tháo xong về đúng ban đầu" % label)


# ===== UC4 =====
func _uc4_repeat() -> void:
	var base := _snapshot()
	for charm in _charms:
		if charm == null:
			continue
		var label := "[%s]" % charm.id
		_give(charm)
		GameState.equip_charm(charm.id)
		_check(not GameState.equip_charm(charm.id), "UC4 %s đeo trùng bị từ chối" % label)
		_check(GameState.get_used_notches() == charm.notch_cost, "UC4 %s đeo trùng không tốn thêm khấc" % label)
		for i in SPAM_TIMES:
			GameState.unequip_charm(charm.id)
			GameState.equip_charm(charm.id)
		GameState.unequip_charm(charm.id)
		await _f(2)
		_expect_same(base, _snapshot(), "UC4 %s đeo / tháo %d lần vẫn về ban đầu" % [label, SPAM_TIMES])


# ===== UC5 =====
func _uc5_combos() -> void:
	var base := _snapshot()
	var valid: Array[CharmData] = []
	for c in _charms:
		if c:
			valid.append(c)
	for c in valid:
		_give(c)
	var limit := GameState.get_charm_notches()
	var count := valid.size()
	# Duyệt mọi tổ hợp (2^n); catalog nhỏ nên rẻ. Quá 12 bùa thì chỉ thử tổ hợp tới 3 bùa để test không chạy quá lâu
	var tried := 0
	for mask in range(1, 1 << count):
		var combo: Array[CharmData] = []
		for i in count:
			if mask & (1 << i):
				combo.append(valid[i])
		if count > 12 and combo.size() > 3:
			continue
		var cost := 0
		for c in combo:
			cost += c.notch_cost
		var label := "UC5 tổ hợp %s" % [combo.map(func(c: CharmData) -> StringName: return c.id)]
		var accepted := true
		for c in combo:
			accepted = GameState.equip_charm(c.id) and accepted
		await _f(1)
		if cost <= limit:
			_check(accepted, label + " (%d/%d khấc) đeo được hết" % [cost, limit])
			_check(GameState.get_used_notches() == cost, label + " tổng khấc đúng")
			_expect_stats(_expected(base, combo), label + " chỉ số cộng dồn đúng")
		else:
			_check(not accepted and GameState.get_used_notches() <= limit, label + " (%d/%d khấc) vượt khấc bị từ chối" % [cost, limit])
		# Tháo xen kẽ: lần chẵn tháo ngược, lần lẻ tháo xuôi
		var order := GameState.progress.equipped_charms.duplicate()
		if mask % 2 == 0:
			order.reverse()
		for id: StringName in order:
			GameState.unequip_charm(id)
		await _f(1)
		_expect_same(base, _snapshot(), label + " tháo hết về ban đầu")
		tried += 1
	print("INFO UC5 đã thử %d tổ hợp, giới hạn %d khấc" % [tried, limit])


# ===== UC6 =====
func _uc6_rebuild() -> void:
	# Đeo tối đa số bùa vừa khấc, ghi lại trạng thái, dựng lại scene (như đổi khu / hồi sinh) rồi so
	var limit := GameState.get_charm_notches()
	var used := 0
	var worn: Array[CharmData] = []
	for c in _charms:
		if c and used + c.notch_cost <= limit and GameState.equip_charm(c.id):
			used += c.notch_cost
			worn.append(c)
	await _f(2)
	var before := _snapshot()
	_check(not worn.is_empty(), "UC6 có bùa để thử đổi khu")
	_close()
	await _open(COMBAT_SANDBOX)
	_expect_same(before, _snapshot(), "UC6 dựng lại scene: tác dụng bùa đúng một lần, không mất")
	_close()
	await _open(COMBAT_SANDBOX)
	_expect_same(before, _snapshot(), "UC6 dựng lại lần hai vẫn đúng (không cộng dồn qua các lần)")
	for c in worn:
		GameState.unequip_charm(c.id)


# ===== UC7 =====
func _uc7_save() -> void:
	var limit := GameState.get_charm_notches()
	var used := 0
	for c in _charms:
		if c and used + c.notch_cost <= limit and GameState.equip_charm(c.id):
			used += c.notch_cost
	var owned := GameState.progress.charms.duplicate()
	var equipped := GameState.progress.equipped_charms.duplicate()
	var loaded: PlayerProgress = SaveManager.from_dict(SaveManager.to_dict(GameState.progress))
	_check(loaded.charms == owned, "UC7 bùa đã có giữ nguyên qua lưu / đọc")
	_check(loaded.equipped_charms == equipped, "UC7 bùa đang đeo giữ nguyên qua lưu / đọc")
	for id: StringName in equipped:
		GameState.unequip_charm(id)


# ===== UC8 =====
func _uc8_checkpoint() -> void:
	# Trả quyền đổi bùa đã mượn ở các UC trên để thử đúng luật checkpoint
	GameState.exit_charm_station()
	_check(not GameState.can_change_charms(), "UC8 trước khi vào sân: không có quyền đổi bùa")
	GameState.replace_progress(PlayerProgress.new())
	_lv = (load(CHARM_SANDBOX) as PackedScene).instantiate()
	get_tree().root.add_child(_lv)
	await _wait(1.0)
	_p = _lv.get_node("Player") as Player
	var checkpoint := _lv.get_node_or_null("CharmCheckpoint") as Checkpoint
	_check(checkpoint != null, "UC8 sân thử bùa có checkpoint")
	if checkpoint == null:
		return
	var charm: CharmData = null
	for c in _charms:
		if c:
			charm = c
			break
	_give(charm)
	await _stand(checkpoint.global_position + Vector3(OUTSIDE_DISTANCE, 0.2, 0))
	_check(not GameState.can_change_charms(), "UC8 cách checkpoint %.1f m: không được đổi bùa" % OUTSIDE_DISTANCE)
	_check(not GameState.equip_charm(charm.id), "UC8 ngoài checkpoint: đeo bị từ chối")
	await _stand(checkpoint.global_position + Vector3(INSIDE_DISTANCE, 0.2, 0))
	_check(GameState.can_change_charms(), "UC8 trong vùng chạm checkpoint: được đổi bùa")
	_check(GameState.equip_charm(charm.id), "UC8 trong checkpoint: đeo được")
	await _stand(checkpoint.global_position + Vector3(OUTSIDE_DISTANCE, 0.2, 0))
	_check(not GameState.can_change_charms(), "UC8 bước ra khỏi vùng: mất quyền đổi bùa")
	_check(not GameState.unequip_charm(charm.id), "UC8 ngoài checkpoint: tháo bị từ chối")
	_check(GameState.is_charm_equipped(charm.id), "UC8 bùa vẫn đang đeo sau khi bị từ chối tháo")
	await _stand(checkpoint.global_position + Vector3(INSIDE_DISTANCE, 0.2, 0))
	_check(GameState.unequip_charm(charm.id), "UC8 quay lại checkpoint: tháo được")
	_close()
	await _f(2)
	_check(not GameState.can_change_charms(), "UC8 gỡ sân khi player còn trong vùng: không kẹt quyền đổi bùa")


# ===== Trạng thái so sánh =====
## Mọi thứ bùa có thể đổi mà nhìn được từ ngoài: chỉ số khai báo, máu / năng lượng tối đa, số node con của player
func _snapshot() -> Dictionary:
	var snap := {}
	for stat in _stats:
		snap["mult:" + String(stat)] = _p.stats.get_multiplier(stat)
		snap["bonus:" + String(stat)] = _p.stats.get_bonus(stat)
	snap["max_health"] = _p.health.max_health
	snap["max_energy"] = _p.energy.get_max()
	snap["nodes"] = _p.find_children("*", "", true, false).size()
	return snap


## Chỉ số mong đợi khi đeo combo, tính từ base theo dữ liệu effect (nhân dồn / cộng dồn)
func _expected(base: Dictionary, combo: Array) -> Dictionary:
	var result := {}
	for stat in _stats:
		result["mult:" + String(stat)] = base["mult:" + String(stat)]
		result["bonus:" + String(stat)] = base["bonus:" + String(stat)]
	# Máu tối đa là chỉ số player tự đọc (cộng bonus max_health): kiểm cả kết quả cuối, không chỉ số cộng
	result["max_health"] = base["max_health"]
	for charm: CharmData in combo:
		for e in charm.effects:
			if e is StatMultiplierEffect:
				var m := e as StatMultiplierEffect
				result["mult:" + String(m.stat)] *= m.multiplier
			elif e is StatBonusEffect:
				var b := e as StatBonusEffect
				result["bonus:" + String(b.stat)] += b.bonus
				if b.stat == MAX_HEALTH_STAT:
					result["max_health"] += roundi(b.bonus)
	return result


func _expect_stats(expected: Dictionary, label: String) -> void:
	var now := _snapshot()
	var wrong: Array[String] = []
	for key: String in expected:
		if not is_equal_approx(float(now[key]), float(expected[key])):
			wrong.append("%s=%s (mong %s)" % [key, now[key], expected[key]])
	_check(wrong.is_empty(), label + ("" if wrong.is_empty() else " SAI: " + ", ".join(wrong)))


func _expect_same(a: Dictionary, b: Dictionary, label: String) -> void:
	var wrong: Array[String] = []
	for key: String in a:
		if not b.has(key) or not is_equal_approx(float(a[key]), float(b[key])):
			wrong.append("%s: %s -> %s" % [key, a[key], b.get(key)])
	_check(wrong.is_empty(), label + ("" if wrong.is_empty() else " SAI: " + ", ".join(wrong)))


func _effect_stat(effect: CharmEffect) -> StringName:
	if effect is StatMultiplierEffect:
		return (effect as StatMultiplierEffect).stat
	if effect is StatBonusEffect:
		return (effect as StatBonusEffect).stat
	return &""


# ===== Tiện ích =====
## Mở sân, player bất tử; mượn quyền đổi bùa (không phụ thuộc vị trí checkpoint) cho UC2–UC7
func _open(path: String) -> void:
	if not GameState.can_change_charms():
		GameState.enter_charm_station()
	_lv = (load(path) as PackedScene).instantiate()
	get_tree().root.add_child(_lv)
	await _wait(1.0)
	_p = _lv.get_node("Player") as Player
	_p.get_node("HurtboxComponent").set_invincible(9999.0)


func _close() -> void:
	if is_instance_valid(_lv):
		_lv.get_parent().remove_child(_lv)
		_lv.queue_free()
	_lv = null
	_p = null


func _give(charm: CharmData) -> void:
	if charm and not GameState.owns_charm(charm.id):
		GameState.add_charm(charm)


func _stand(where: Vector3) -> void:
	_p.teleport(where, Vector3.FORWARD)
	await _f(10)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, true).timeout


func _f(frames: int) -> void:
	for i: int in frames:
		await get_tree().physics_frame


func _check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		_fails += 1
