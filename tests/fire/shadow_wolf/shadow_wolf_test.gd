extends Node3D
## Test Sói Bóng Đêm (ShadowWolf) bằng hành vi thật: vật lý, va chạm, phím chém / phun lửa của player thật.
## 1. Nạp: rig 27 xương (4 đốt sống, 4 đốt đuôi), đủ 9 clip trỏ đúng xương, nhận lửa x1,5, mỗi con một bộ vật liệu mờ riêng.
## 2. Rình: ở xa thì chạy tới, rồi đi vòng quanh player đúng bán kính, tan vào bóng tối (fade = stalk_fade).
## 3. Vồ: gồng người báo trước (hiện rõ, đứng yên đúng crouch_time), lao trúng player mất máu;
##    player né: trượt, đứng sững recover_time (khoảng hở).
## 4. Cắn liên hoàn: áp sát thì cắn đủ bite_combo cú; bị chém thật giữa chuỗi thì ngắt.
## 5. Bầy 3 con (WolfPack): không lúc nào 2 con cùng vồ, nhiều con lần lượt được vồ.
## 6. Sợ lửa: phun lửa thật -> mất 2 máu (1 x 1,5 làm tròn), hiện rõ, bỏ chạy ra xa.
##    Player cầm đuốc cháy: sói không vồ / cắn, giữ khoảng cách.
## 7. Cực đoan: tầm vồ 0 / 20 m, độ mờ 0 / 1, bầy 1 / 6 con.
## Không ghi save thật. Chạy: godot --headless --path . res://tests/fire/shadow_wolf/shadow_wolf_test.tscn
## (bỏ --headless, thêm -- --capture để chụp ảnh)

const WOLF_SCENE: PackedScene = preload("res://entities/enemies/volcano/shadow_wolf/shadow_wolf.tscn")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const TORCH_SCENE: PackedScene = preload("res://objects/world/cellar/hand_torch/hand_torch.tscn")
const SWORD: WeaponData = preload("res://resources/combat/weapons/sword.tres")
const FLAME_BREATH: AbilityData = preload("res://abilities/flame_breath/flame_breath.tres")
const DATA: ShadowWolfData = preload("res://resources/enemies/volcano/shadow_wolf/shadow_wolf.tres")
const PLAYER_HOME := Vector3(0, 0, 8)

var _failed: int = 0
var _checks: int = 0
var _player: Player
var _spawned: Array[Node] = []


func _ready() -> void:
	if GameState.progress_changed.is_connected(SaveManager.save_game):
		GameState.progress_changed.disconnect(SaveManager.save_game)
	if GameState.progress_committed.is_connected(SaveManager.save_game):
		GameState.progress_committed.disconnect(SaveManager.save_game)
	_run.call_deferred()


func _run() -> void:
	_build_arena()
	GameState.replace_progress(PlayerProgress.new())
	GameState.set_weapon(SWORD)
	GameState.unlock_ability(FLAME_BREATH)
	_player = PLAYER_SCENE.instantiate() as Player
	_player.position = PLAYER_HOME
	add_child(_player)
	await _frames(10)
	_player.health.max_health = 9999
	_player.health.heal_full()
	await _t_load()
	await _t_stalk()
	await _t_pounce()
	await _t_bite()
	await _t_pack()
	await _t_fire()
	await _t_torch()
	await _t_extreme()
	print("SHADOW WOLF RESULT: %s" % ("OK (%d checks)" % _checks if _failed == 0 else "%d FAIL / %d" % [_failed, _checks]))
	get_tree().quit(1 if _failed > 0 else 0)


# ---------- Các mục ----------

func _t_load() -> void:
	_reset_player(PLAYER_HOME)
	var a := await _spawn(Vector3(-2, 0, -10), null, true)
	var b := await _spawn(Vector3(2, 0, -10), null, true)
	var anim := a.get_node("AnimationPlayer") as AnimationPlayer
	var clips: Array[StringName] = [&"Idle", &"Walk", &"Run", &"Stalk", &"Crouch", &"Pounce", &"Bite", &"Hurt", &"Death"]
	_check(a.skeleton.get_bone_count() == 27 and clips.all(func(c: StringName) -> bool: return anim.has_animation(c)), "rig %d xương, đủ 9 clip" % a.skeleton.get_bone_count())
	var root := anim.get_node(anim.root_node)
	var bad := 0
	for c: StringName in clips:
		var clip := anim.get_animation(c)
		for t: int in range(clip.get_track_count()):
			var path := clip.track_get_path(t)
			var sk := root.get_node_or_null(NodePath(path.get_concatenated_names())) as Skeleton3D
			if sk == null or sk.find_bone(path.get_concatenated_subnames()) < 0:
				bad += 1
	_check(bad == 0, "mọi track của 9 clip trỏ đúng xương (%d sai)" % bad)
	_check(is_equal_approx(a.hurtbox.resistances.get(DamageInfo.Type.FIRE, 1.0), 1.5), "sợ lửa: nhận sát thương lửa x1,5")
	a.fade_to(1.0, 0.0)
	var body_a := a.skeleton.get_node("ShadowWolfBody") as MeshInstance3D
	var body_b := b.skeleton.get_node("ShadowWolfBody") as MeshInstance3D
	var fa := _fur(body_a).get_shader_parameter(&"fade") as float
	var fb := _fur(body_b).get_shader_parameter(&"fade") as float
	_check(is_equal_approx(fa, 1.0) and is_zero_approx(fb), "mờ riêng từng con (con A %.1f, con B %.1f)" % [fa, fb])
	a.fade_to(0.0, 0.0)
	await _capture("wolf_idle.png", a.global_position)
	_cleanup()


func _t_stalk() -> void:
	var data := _data_copy()
	data.pounce_range_max = 0.0
	data.attack_range = 0.0
	data.bite_range = 0.0
	_reset_player(PLAYER_HOME)
	var w := await _spawn(PLAYER_HOME + Vector3(0, 0, -15), data)
	w.target = _player
	w.state_machine.transition_to(w.chase_state)
	var came := await _wait_until(func() -> bool: return _flat(w.global_position, _player.global_position) < data.stalk_radius + 1.0, 300)
	var a0 := _angle(w)
	var lo := 99.0
	var hi := 0.0
	var swept := 0.0
	var prev := a0
	for i: int in range(180):
		await get_tree().physics_frame
		var d := _flat(w.global_position, _player.global_position)
		lo = minf(lo, d)
		hi = maxf(hi, d)
		var a := _angle(w)
		swept += absf(wrapf(a - prev, -PI, PI))
		prev = a
	_check(came, "ở xa 15 m: chạy tới vòng rình")
	_check(lo > data.stalk_radius - 1.5 and hi < data.stalk_radius + 1.5 and rad_to_deg(swept) > 40.0, "đi vòng quanh player (cách %.1f–%.1f m, quét %.0f°)" % [lo, hi, rad_to_deg(swept)])
	_check(absf(w.fade - data.stalk_fade) < 0.02 and w.state_machine.current_state.name == &"WolfStalk", "lúc rình tan vào bóng tối (fade %.2f, state %s)" % [w.fade, w.state_machine.current_state.name])
	await _capture("wolf_stalk.png", w.global_position)
	_cleanup()


func _t_pounce() -> void:
	_reset_player(PLAYER_HOME)
	var w := await _spawn(PLAYER_HOME + Vector3(0, 0, -5.5), null)
	var log := {"start": -1, "leap": -1, "land": -1, "hit": false, "fade_min": 1.0, "moved_crouch": 0.0}
	var tick := [0]
	w.pounce_started.connect(func() -> void: log["start"] = tick[0])
	w.pounce_landed.connect(func(hit: bool) -> void:
		log["land"] = tick[0]
		log["hit"] = hit)
	var hp := _player.health.current_health
	var crouch_pos := Vector3.ZERO
	w.target = _player
	w.state_machine.transition_to(w.chase_state)
	for i: int in range(240):
		tick[0] = i
		await get_tree().physics_frame
		var pounce := w.state_machine.current_state.name == &"WolfPounce"
		if pounce and (w.state_machine.current_state as Object).get(&"phase") == 0:
			if crouch_pos == Vector3.ZERO:
				crouch_pos = w.global_position
			log["moved_crouch"] = maxf(log["moved_crouch"], _flat(w.global_position, crouch_pos))
			log["fade_min"] = minf(log["fade_min"], w.fade)
		if pounce and (w.state_machine.current_state as Object).get(&"phase") == 1 and int(log["leap"]) < 0:
			log["leap"] = i
			await _capture("wolf_pounce.png", w.global_position)
		if int(log["land"]) >= 0:
			break
	var crouch: float = (int(log["leap"]) - int(log["start"])) / 60.0
	_check(int(log["start"]) >= 0 and absf(crouch - DATA.crouch_time) < 0.05, "vồ: gồng người báo trước %.2f s (đặt %.2f s)" % [crouch, DATA.crouch_time])
	_check(float(log["fade_min"]) < 0.05 and float(log["moved_crouch"]) < 0.15, "lúc gồng: hiện rõ, đứng yên (dời %.2f m)" % float(log["moved_crouch"]))
	_check(bool(log["hit"]) and _player.health.current_health < hp, "lao trúng player: mất máu (%d → %d)" % [hp, _player.health.current_health])
	_cleanup()
	# Né: lúc sói bắt đầu lao, player dịch ngang 4 m -> trượt, đứng sững recover_time
	await _frames(30)
	_reset_player(PLAYER_HOME)
	var w2 := await _spawn(PLAYER_HOME + Vector3(0, 0, -5.5), null)
	var res := {"hit": true, "landed": false}
	w2.pounce_landed.connect(func(hit: bool) -> void:
		res["hit"] = hit
		res["landed"] = true)
	w2.target = _player
	w2.state_machine.transition_to(w2.chase_state)
	await _wait_until(func() -> bool: return w2.state_machine.current_state.name == &"WolfPounce" and (w2.state_machine.current_state as Object).get(&"phase") == 1, 240)
	_player.teleport(_player.global_position + Vector3(4, 0.05, 0))
	await _wait_until(func() -> bool: return res["landed"], 120)
	var still_frames := 0
	for i: int in range(int(DATA.recover_time * 60.0) - 4):
		await get_tree().physics_frame
		if Vector2(w2.velocity.x, w2.velocity.z).length() < 0.5 and w2.state_machine.current_state.name == &"WolfPounce":
			still_frames += 1
	_check(res["landed"] and not res["hit"], "player né sang bên: cú vồ trượt")
	_check(still_frames >= int(DATA.recover_time * 60.0) - 8, "trượt xong đứng sững %.2f s (khoảng hở cho player)" % (still_frames / 60.0))
	_cleanup()


func _t_bite() -> void:
	var data := _data_copy()
	data.pounce_range_max = 0.0
	_reset_player(PLAYER_HOME)
	_player.get_node("HurtboxComponent").invulnerable = true
	var w := await _spawn(PLAYER_HOME + Vector3(0, 0, -1.4), data)
	var bites := [0]
	var bite_state := w.get_node("StateMachine/WolfBite")
	bite_state.bite.connect(func(_i: int) -> void: bites[0] += 1)
	# Player đứng sát: sói tự thấy và cắn ngay (không ép chuyển state, kẻo cắt ngang chuỗi cắn)
	await _wait_until(func() -> bool: return w.state_machine.current_state.name == &"WolfBite", 120)
	await _wait_until(func() -> bool: return w.state_machine.current_state.name != &"WolfBite", 180)
	_check(bites[0] == data.bite_combo, "áp sát: cắn liên hoàn đủ %d cú (%d)" % [data.bite_combo, bites[0]])
	await _capture("wolf_bite.png", w.global_position)
	# Chém thật giữa chuỗi: ngắt
	await _wait_until(func() -> bool: return w.state_machine.current_state.name == &"WolfBite", 120)
	bites[0] = 0
	await _wait_until(func() -> bool: return bites[0] >= 1, 60)
	_reset_player(w.global_position + w.get_facing_direction() * 1.3, -w.get_facing_direction())
	await _frames(2)
	_aim_mouse_at(w.global_position + Vector3.UP * 0.6)
	await _tap(&"attack")
	await _frames(70)
	_check(bites[0] < data.bite_combo, "bị chém giữa chuỗi: ngắt combo (cắn %d / %d cú)" % [bites[0], data.bite_combo])
	_player.get_node("HurtboxComponent").invulnerable = false
	_cleanup()


func _t_pack() -> void:
	_reset_player(PLAYER_HOME)
	_player.get_node("HurtboxComponent").invulnerable = true
	var pack := WolfPack.new()
	add_child(pack)
	_spawned.append(pack)
	var wolves: Array[ShadowWolf] = []
	for x: float in [-5.0, 0.0, 5.0]:
		var w := await _spawn(PLAYER_HOME + Vector3(x, 0, -7), _data_copy(), false, pack)
		w.target = _player
		w.state_machine.transition_to(w.chase_state)
		wolves.append(w)
	var max_together := 0
	var pouncers := {}
	for i: int in range(600):
		await get_tree().physics_frame
		var now := 0
		for w: ShadowWolf in wolves:
			if w.state_machine.current_state.name == &"WolfPounce":
				now += 1
				pouncers[w] = true
		max_together = maxi(max_together, now)
	_check(max_together == 1, "bầy 3 con trong 10 s: tối đa %d con vồ cùng lúc" % max_together)
	_check(pouncers.size() >= 2, "nhiều con lần lượt được vồ (%d con)" % pouncers.size())
	_player.get_node("HurtboxComponent").invulnerable = false
	_cleanup()


func _t_fire() -> void:
	var data := _data_copy()
	data.pounce_range_max = 0.0
	data.bite_range = 0.0
	_reset_player(PLAYER_HOME)
	var w := await _spawn(PLAYER_HOME + Vector3(0, 0, -2.4), data, true)
	w.fade_to(0.8, 0.0)
	await _frames(5)
	var hp := w.health.current_health
	_player.energy.set_current(_player.energy.get_max())
	await _frames(2)
	_aim_mouse_at(w.global_position + Vector3.UP * 0.6)
	Input.action_press(&"skill_fire")
	var fled := await _wait_until(func() -> bool: return w.state_machine.current_state.name == &"WolfFlee", 60)
	Input.action_release(&"skill_fire")
	var lost := hp - w.health.current_health
	var d0 := _flat(w.global_position, _player.global_position)
	await _frames(50)
	var d1 := _flat(w.global_position, _player.global_position)
	_check(lost == 2, "phun lửa thật: mất %d máu (1 x 1,5 làm tròn = 2)" % lost)
	_check(fled and is_zero_approx(w.fade) and d1 > d0 + 1.0, "trúng lửa: hiện rõ, bỏ chạy (%.1f → %.1f m)" % [d0, d1])
	_cleanup()


func _t_torch() -> void:
	_reset_player(PLAYER_HOME)
	var torch := HandTorch.give_to(_player, TORCH_SCENE)
	torch.light_up()
	var w := await _spawn(PLAYER_HOME + Vector3(0, 0, -5), null)
	w.target = _player
	w.state_machine.transition_to(w.chase_state)
	var attacked := false
	var closest := 99.0
	for i: int in range(240):
		await get_tree().physics_frame
		var s := w.state_machine.current_state.name
		attacked = attacked or s == &"WolfPounce" or s == &"WolfBite"
		if i > 120:
			closest = minf(closest, _flat(w.global_position, _player.global_position))
	_check(not attacked and closest > DATA.light_fear_radius - 1.5, "player cầm đuốc cháy: sói không vồ / cắn, giữ cách %.1f m" % closest)
	torch.queue_free()
	_cleanup()


func _t_extreme() -> void:
	# Tầm vồ 0: không bao giờ vồ
	var none := _data_copy()
	none.pounce_range_min = 0.0
	none.pounce_range_max = 0.0
	none.bite_range = 0.0
	_reset_player(PLAYER_HOME)
	var w0 := await _spawn(PLAYER_HOME + Vector3(0, 0, -6), none)
	w0.target = _player
	w0.state_machine.transition_to(w0.chase_state)
	var pounced := false
	for i: int in range(180):
		await get_tree().physics_frame
		pounced = pounced or w0.state_machine.current_state.name == &"WolfPounce"
	_check(not pounced, "tầm vồ 0: không vồ")
	_cleanup()
	# Tầm vồ 20 m: vồ từ xa ngay
	var far := _data_copy()
	far.pounce_range_max = 20.0
	far.stalk_radius = 14.0
	_reset_player(PLAYER_HOME)
	_player.get_node("HurtboxComponent").invulnerable = true
	var w1 := await _spawn(PLAYER_HOME + Vector3(0, 0, -13), far)
	w1.target = _player
	w1.state_machine.transition_to(w1.chase_state)
	var ok := await _wait_until(func() -> bool: return w1.state_machine.current_state.name == &"WolfPounce", 60)
	_check(ok and _flat(w1.global_position, _player.global_position) > 10.0, "tầm vồ 20 m: vồ từ xa 13 m")
	_cleanup()
	# Độ mờ rình 0 và 1
	for value: float in [0.0, 1.0]:
		var d := _data_copy()
		d.stalk_fade = value
		d.pounce_range_max = 0.0
		d.bite_range = 0.0
		var w := await _spawn(PLAYER_HOME + Vector3(0, 0, -6), d)
		w.target = _player
		w.state_machine.transition_to(w.chase_state)
		await _frames(150)
		_check(absf(w.fade - value) < 0.02, "độ mờ rình %.0f: fade %.2f" % [value, w.fade])
		_cleanup()
	# Bầy 1 và 6 con
	for count: int in [1, 6]:
		var pack := WolfPack.new()
		add_child(pack)
		_spawned.append(pack)
		var wolves: Array[ShadowWolf] = []
		for k: int in range(count):
			var ang := TAU * k / count
			var w := await _spawn(PLAYER_HOME + Vector3(sin(ang) * 6.0, 0, cos(ang) * 6.0), _data_copy(), false, pack)
			w.target = _player
			w.state_machine.transition_to(w.chase_state)
			wolves.append(w)
		var max_together := 0
		var any := false
		for i: int in range(300):
			await get_tree().physics_frame
			var now := 0
			for w: ShadowWolf in wolves:
				if w.state_machine.current_state.name == &"WolfPounce":
					now += 1
			max_together = maxi(max_together, now)
			any = any or now > 0
		_check(any and max_together == 1, "bầy %d con: có vồ, tối đa %d con cùng lúc" % [count, max_together])
		_cleanup()
	_player.get_node("HurtboxComponent").invulnerable = false


# ---------- Tiện ích ----------

func _spawn(pos: Vector3, data: ShadowWolfData = null, freeze_ai: bool = false, pack: WolfPack = null) -> ShadowWolf:
	var w := WOLF_SCENE.instantiate() as ShadowWolf
	w.data = data if data else _data_copy()
	w.pack = pack
	w.position = pos
	add_child(w)
	_spawned.append(w)
	await _frames(3)
	if freeze_ai:
		w.sensor.radius = 0.0
		w.forget_target()
		w.state_machine.transition_to(&"Idle")
	return w


## Vật liệu lông (ShaderMaterial) đầu tiên của thân; mắt / răng / móng dùng vật liệu sáng thường
func _fur(body: MeshInstance3D) -> ShaderMaterial:
	for i: int in range(body.mesh.get_surface_count()):
		var mat := body.get_active_material(i) as ShaderMaterial
		if mat:
			return mat
	return null


func _data_copy() -> ShadowWolfData:
	return DATA.duplicate() as ShadowWolfData


func _angle(w: Node3D) -> float:
	var d := w.global_position - _player.global_position
	return atan2(d.x, d.z)


func _cleanup() -> void:
	for node: Node in _spawned:
		if is_instance_valid(node):
			node.queue_free()
	_spawned.clear()
	for a: StringName in [&"attack", &"skill", &"skill_fire"]:
		Input.action_release(a)
	await _frames(2)


func _reset_player(pos: Vector3, facing: Vector3 = Vector3.FORWARD) -> void:
	_player.teleport(pos + Vector3.UP * 0.05, facing)
	# Camera theo player có độ trễ: kéo tới ngay để chuột ngắm (có cửa sổ) đúng chỗ
	(_player.get_node("CameraRig") as CameraRig).snap()
	_player.health.heal_full()


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _build_arena() -> void:
	_box(Vector3(0, -0.5, 0), Vector3(70, 1, 70), Color(0.32, 0.17, 0.12))
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, 30, 0)
	add_child(light)


func _box(at: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	bm.material = mat
	mesh.mesh = bm
	body.add_child(mesh)
	add_child(body)
	return body


## Có cửa sổ: player ngắm theo chuột thật, nên đưa chuột vào mục tiêu trước khi bấm (headless dùng hướng mặt)
func _aim_mouse_at(world: Vector3) -> void:
	if DisplayServer.get_name() == "headless":
		return
	Input.warp_mouse(get_viewport().get_camera_3d().unproject_position(world))


func _tap(action: StringName) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)
	await _frames(1)


func _wait_until(pred: Callable, max_frames: int) -> bool:
	for i: int in range(max_frames):
		if pred.call():
			return true
		await get_tree().physics_frame
	return pred.call()


func _frames(n: int) -> void:
	for _i: int in range(n):
		await get_tree().physics_frame


func _check(ok: bool, label: String) -> void:
	_checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		_failed += 1


## Có cửa sổ + "--capture": camera nhìn chéo vào sói rồi chụp
func _capture(file: String, focus: Vector3) -> void:
	if not "--capture" in OS.get_cmdline_user_args():
		return
	var cam := Camera3D.new()
	add_child(cam)
	cam.global_position = focus + Vector3(3.0, 2.4, 3.0)
	cam.look_at(focus + Vector3.UP * 0.6)
	cam.fov = 45.0
	cam.make_current()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://output/shadow_wolf/" + file)
	cam.queue_free()
	(_player.get_node("CameraRig/Camera3D") as Camera3D).make_current()
