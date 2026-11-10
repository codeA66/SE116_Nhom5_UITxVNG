extends Node
## Unit test nhánh truyện, phí thuyền và hình học VFX; không cần nạp bản đồ hay renderer.

var _fails: int = 0
var _checks: int = 0

func _ready() -> void:
	for save_signal: Signal in [GameState.progress_changed, GameState.progress_committed]:
		if save_signal.is_connected(SaveManager.save_game):
			save_signal.disconnect(SaveManager.save_game)
	var saved := GameState.progress
	_test_story()
	_test_fare()
	_test_particles()
	GameState.replace_progress(saved)
	print("UNIT RESULT checks=%d fails=%d" % [_checks, _fails])
	get_tree().quit(_fails)

func _test_story() -> void:
	GameState.replace_progress(PlayerProgress.new())
	var ferry := Npc.new()
	for id: String in ["first", "lantern", "repeat"]:
		ferry.dialogues.append(load("res://resources/world/npcs/ferry/%s.tres" % id) as Dialogue)
	_check(ferry.pick_dialogue(&"greeting").resource_path.ends_with("first.tres"), "UT01 ferry first visit")
	GameState.set_flag(&"level_1.story.ferry_met")
	_check(ferry.pick_dialogue(&"greeting").resource_path.ends_with("lantern.tres"), "UT02 ferry second fragment")
	GameState.set_flag(&"level_1.story.ferry_lantern")
	_check(ferry.pick_dialogue(&"greeting").resource_path.ends_with("repeat.tres"), "UT03 ferry short repeat")
	var serialized := SaveManager.to_dict(GameState.progress)
	GameState.replace_progress(SaveManager.from_dict(serialized))
	_check(ferry.pick_dialogue(&"greeting").resource_path.ends_with("repeat.tres"), "UT04 story flags survive save roundtrip")
	GameState.set_checkpoint("res://levels/zone_1_wind/level_1/level_1.tscn", &"start")
	GameState.set_flag(&"test.story.after_checkpoint")
	GameState.restore_checkpoint()
	_check(GameState.has_flag(&"level_1.story.ferry_lantern"), "UT17 checkpoint retains heard story")
	_check(not GameState.has_flag(&"test.story.after_checkpoint"), "UT18 death discards uncommitted story")
	var gate := Npc.new()
	var toll := TollService.new()
	toll.paid_flag = &"test.unit.toll"
	gate.add_child(toll)
	for id: String in ["first", "unpaid", "knocking", "paid"]:
		gate.dialogues.append(load("res://resources/world/npcs/gate/%s.tres" % id) as Dialogue)
	_check(gate.pick_dialogue(&"greeting").resource_path.ends_with("first.tres"), "UT05 gate first visit")
	GameState.set_flag(&"level_1.story.gate_met")
	_check(gate.pick_dialogue(&"greeting").resource_path.ends_with("unpaid.tres"), "UT06 unpaid repeat still opens service")
	_check(gate.pick_dialogue(&"greeting").opens_service, "UT07 unpaid dialogue opens toll")
	GameState.set_flag(toll.paid_flag)
	_check(gate.pick_dialogue(&"greeting").resource_path.ends_with("knocking.tres"), "UT08 paid gate reveals legend")
	_check(not gate.pick_dialogue(&"greeting").opens_service, "UT09 paid lore does not reopen toll")
	GameState.set_flag(&"level_1.story.gate_knocking")
	_check(gate.pick_dialogue(&"greeting").resource_path.ends_with("paid.tres"), "UT10 paid gate short repeat")
	ferry.free()
	gate.free()

func _test_fare() -> void:
	for entry: Array in [[3, 2, false], [3, 3, true], [0, 0, true], [999999, 7, false]]:
		GameState.replace_progress(PlayerProgress.new())
		GameState.add_currency(&"soul_jade", entry[1])
		var service := FerryFareService.new()
		service.price = entry[0]
		var result := service.try_pay_fare()
		var expected: int = FerryFareService.FareResult.PAID if entry[2] else FerryFareService.FareResult.INSUFFICIENT
		_check(result == expected, "UT11 fare price=%d funds=%d result" % [entry[0], entry[1]])
		var remaining: int = entry[1] - entry[0] if entry[2] else entry[1]
		_check(GameState.get_currency(&"soul_jade") == remaining, "UT12 fare balance")
		if entry[2]:
			_check(service.try_pay_fare() == FerryFareService.FareResult.ALREADY_CALLED and GameState.get_currency(&"soul_jade") == remaining, "UT13 no double charge")
		service.free()
	var invalid := FerryFareService.new()
	invalid.currency = null
	_check(invalid.try_pay_fare() == FerryFareService.FareResult.INVALID, "UT14 missing currency")
	invalid.currency = load("res://resources/player/currency/soul_jade.tres") as CurrencyData
	invalid.price = -1
	_check(invalid.try_pay_fare() == FerryFareService.FareResult.INVALID, "UT15 negative fare")
	invalid.free()

func _test_particles() -> void:
	for path: String in ["lantern_motes", "gate_wind"]:
		var particle: Node3D = load("res://components/feedback/conversation/%s.gd" % path).new()
		var valid := true
		for index in 24:
			for sample: float in [0.0, 0.016, 3.7, 1000000.0]:
				var pose: Transform3D = particle.particle_transform(index, sample)
				valid = valid and pose.origin.is_finite() and pose.basis.is_finite() and pose.origin.length() < 4.0
		_check(valid, "UT16 bounded finite geometry " + path)
		particle.free()

func _check(passed: bool, message: String) -> void:
	_checks += 1
	print("PASS " if passed else "FAIL ", message)
	if not passed:
		_fails += 1
