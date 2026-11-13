extends Node3D
## Test Quỷ Xương Lửa (FireCaster) bằng hành vi thật: vật lý, va chạm, phím chém / phun lửa / thổi gió của player thật.
## 1. Nạp: model khối hiện, kháng lửa (hệ số 0), không bắt lửa.
## 2. Đuổi: ở xa thì đuổi tới tầm dừng rồi đứng lại; player áp sát không lùi; bị tường che thì đuổi tiếp.
## 3. Niệm rồi bắn: báo trước (đèn + cầu phình) đúng active_start; cầu trúng player: mất máu + player bắt lửa.
##    Cầu bay vào tường: nổ, về pool. Dash (bất tử) chặn: không mất máu, không bắt lửa.
## 4. Kháng lửa: phun lửa thật không mất máu, không cháy; chém thật mất máu.
## 5. Sợ gió: thổi gió lúc đang niệm: ngắt niệm, không bắn; bị đẩy xa hơn quái thường.
## 6. Cực đoan: tầm dừng 0 / 40 m, niệm 0 s, hồi chiêu 0,01 s (pool không phình).
## Không ghi save thật. Chạy: godot --headless --path . res://tests/fire/fire_caster/fire_caster_test.tscn
## (bỏ --headless, thêm -- --capture để chụp ảnh)

const CASTER_SCENE: PackedScene = preload("res://entities/enemies/volcano/fire_caster/fire_caster.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemies/_base/enemy.tscn")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const SWORD: WeaponData = preload("res://resources/combat/weapons/sword.tres")
const WIND_BLAST: AbilityData = preload("res://abilities/wind_blast/wind_blast.tres")
const FLAME_BREATH: AbilityData = preload("res://abilities/flame_breath/flame_breath.tres")
const DATA: FireCasterData = preload("res://resources/enemies/volcano/fire_caster/fire_caster.tres")

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
	GameState.unlock_ability(WIND_BLAST)
	GameState.unlock_ability(FLAME_BREATH)
	_player = PLAYER_SCENE.instantiate() as Player
	_player.position = PLAYER_HOME
	add_child(_player)
	await _frames(10)
	_player.health.max_health = 9999
	_player.health.heal_full()
	await _t_load()
	await _t_chase()
	await _t_cast_hit()
	await _t_wall_and_dash()
	await _t_fire_resist()
	await _t_wind()
	await _t_extreme()
	await _t_rotated_root()
	print("FIRE CASTER RESULT: %s" % ("OK (%d checks)" % _checks if _failed == 0 else "%d FAIL / %d" % [_failed, _checks]))
	get_tree().quit(1 if _failed > 0 else 0)


# ---------- Các mục ----------

func _t_load() -> void:
	_reset_player(PLAYER_HOME, Vector3.FORWARD)
	# Đứng yên (không niệm) để ảnh chụp đúng màu model, không bị lớp báo trước phủ
	var caster := await _spawn(Vector3(0, 0, 0), null, true)
	var model := caster.get_node("Model/Visual/FireCasterModel") as Node3D
	var burnable := caster.get_node("BurnableComponent") as BurnableComponent
	_check(model.is_visible_in_tree() and caster.data.display_name == "Quỷ Xương Lửa" and caster.health.max_health == 4, "nạp: model hiện, tên + máu 4")
	_check(is_zero_approx(caster.hurtbox.resistances.get(DamageInfo.Type.FIRE, 1.0)), "kháng lửa: hệ số sát thương lửa 0")
	var anim := caster.get_node("AnimationPlayer") as AnimationPlayer
	var clips: Array[StringName] = [&"Idle", &"Walk", &"Cast", &"Hurt", &"Death"]
	_check(caster.skeleton.get_bone_count() == 23 and clips.all(func(c: StringName) -> bool: return anim.has_animation(c)), "rig: Skeleton3D %d xương, đủ 5 clip" % caster.skeleton.get_bone_count())
	# Track của clip phải trỏ đúng xương trong cảnh (đường dẫn đã đổi theo root_node của AnimationPlayer)
	var cast_anim := anim.get_animation(&"Cast")
	var root := anim.get_node(anim.root_node)
	var bad_tracks := 0
	for t: int in range(cast_anim.get_track_count()):
		var path := cast_anim.track_get_path(t)
		var node := root.get_node_or_null(NodePath(path.get_concatenated_names()))
		if not (node is Skeleton3D and (node as Skeleton3D).find_bone(path.get_concatenated_subnames()) >= 0):
			bad_tracks += 1
	_check(bad_tracks == 0, "clip Cast: mọi track trỏ đúng xương (%d track sai)" % bad_tracks)
	burnable.ignite(_player)
	_check(not burnable.is_burning(), "không bắt lửa (ignite thẳng cũng không cháy)")
	await _capture("fire_caster_idle.png", caster.global_position)
	_cleanup()


func _t_chase() -> void:
	var data := _data_copy()
	data.attack_cooldown = 999.0
	_reset_player(PLAYER_HOME, Vector3.FORWARD)
	var caster := await _spawn(PLAYER_HOME + Vector3(0, 0, -13), data)
	caster.target = _player
	caster.state_machine.transition_to(caster.chase_state)
	var reached := await _wait_until(func() -> bool: return _flat(caster.global_position, _player.global_position) <= data.stop_distance + 0.3, 360)
	await _frames(60)
	var d := _flat(caster.global_position, _player.global_position)
	_check(reached and d >= data.stop_distance - 0.6, "ở xa 13 m: đuổi tới tầm %.0f m rồi đứng lại (%.2f m)" % [data.stop_distance, d])
	# Player áp sát 2 m: không lùi
	_reset_player(caster.global_position + Vector3(0, 0, 2.0), Vector3.FORWARD)
	await _frames(5)
	var start := _flat(caster.global_position, _player.global_position)
	await _frames(90)
	var after := _flat(caster.global_position, _player.global_position)
	_check(after <= start + 0.3, "player áp sát (%.1f m): không lùi (%.1f m sau 1,5 s)" % [start, after])
	_cleanup()
	# Bị tường che trong tầm: đuổi tiếp vòng qua cho tới khi thấy player
	_reset_player(PLAYER_HOME, Vector3.FORWARD)
	var wall := _box(PLAYER_HOME + Vector3(0, 1.5, -2.5), Vector3(3, 3, 0.4), Color(0.25, 0.22, 0.2))
	var c2 := await _spawn(PLAYER_HOME + Vector3(0, 0, -5), data)
	c2.target = _player
	c2.state_machine.transition_to(c2.chase_state)
	var p0 := c2.global_position
	await _frames(120)
	_check(c2.global_position.distance_to(p0) > 1.0, "trong tầm nhưng bị tường che: vẫn đuổi tiếp (đi %.2f m)" % c2.global_position.distance_to(p0))
	wall.queue_free()
	_cleanup()


func _t_cast_hit() -> void:
	_reset_player(PLAYER_HOME, Vector3.FORWARD)
	# Sinh ngoài tầm phát hiện (12 m > 9 m), nối signal xong mới đưa player lại gần 6 m
	var caster := await _spawn(PLAYER_HOME + Vector3(0, 0, -12))
	var log := {"start": -1, "fire": -1, "light": false}
	var tick := [0]
	caster.cast_started.connect(func() -> void: log["start"] = tick[0])
	caster.bolt_fired.connect(func(_b: FireBolt) -> void: log["fire"] = tick[0])
	_reset_player(caster.global_position + Vector3(0, 0, 6), Vector3.FORWARD)
	var hp := _player.health.current_health
	var burn := _player.get_node("BurnableComponent") as BurnableComponent
	var landed := false
	var arm_bone := caster.skeleton.find_bone("Forearm_R")
	var arm_rest := caster.skeleton.get_bone_pose_rotation(arm_bone)
	var arm_moved := [0.0]
	# Vị trí cầu trên tay so với thân quái (hệ toạ độ của Model, không phụ thuộc quái xoay / đi)
	var model := caster.get_node("Model") as Node3D
	var hand_rest := model.to_local(caster.get_hand_position())
	var spawn := {"shift": -1.0}
	caster.bolt_fired.connect(func(_b: FireBolt) -> void:
		spawn["shift"] = model.to_local(caster.get_hand_position()).distance_to(hand_rest), CONNECT_ONE_SHOT)
	for i: int in range(300):
		tick[0] = i
		await get_tree().physics_frame
		if caster.is_charging() and (caster.get_node("Model/Visual/FireCasterModel/FireCasterModel/Rig/Skeleton3D/Orb/CastLight") as Node3D).visible:
			log["light"] = true
		arm_moved[0] = maxf(arm_moved[0], caster.skeleton.get_bone_pose_rotation(arm_bone).angle_to(arm_rest))
		if i == int(log["start"]) + 30:
			await _capture("fire_caster_cast.png", caster.global_position)
		if _player.health.current_health < hp:
			landed = true
			break
	var gap: float = (int(log["fire"]) - int(log["start"])) / 60.0
	_check(int(log["start"]) >= 0 and bool(log["light"]), "thấy player: niệm, đèn báo trước sáng (bắt đầu tick %d, đèn %s)" % [log["start"], log["light"]])
	_check(absf(gap - DATA.attack.active_start) < 0.05, "bắn đúng mốc active_start %.2f s (đo %.2f s)" % [DATA.attack.active_start, gap])
	_check(rad_to_deg(arm_moved[0]) > 45.0, "lúc niệm: xương cẳng tay phải xoay thật (tối đa %.0f°)" % rad_to_deg(arm_moved[0]))
	_check(float(spawn["shift"]) > 0.25, "cầu trên tay đi theo xương: lúc bắn đã dời %.2f m so với dáng nghỉ (cầu bay ra từ chỗ đó)" % float(spawn["shift"]))
	_check(landed and burn.is_burning(), "cầu trúng player: mất máu (%d → %d) và bắt lửa" % [hp, _player.health.current_health])
	burn.extinguish()
	_cleanup()


func _t_wall_and_dash() -> void:
	_reset_player(PLAYER_HOME, Vector3.FORWARD)
	var caster := await _spawn(Vector3(0, 0, -10), null, true)
	await _frames(5)
	# Cầu bay vào tường bắc (z -18)
	var bolt := caster.fire_bolt(Vector3.FORWARD)
	var done := [false]
	bolt.finished.connect(func(_b: FireBolt) -> void: done[0] = true, CONNECT_ONE_SHOT)
	var ok := await _wait_until(func() -> bool: return done[0], 120)
	_check(ok and bolt.global_position.z > -18.6 and caster.pool.get_active_count() == 0, "cầu vào tường: nổ ở tường (z %.2f), về pool" % bolt.global_position.z)
	# Dash: bất tử chặn đòn, không bắt lửa
	_reset_player(caster.global_position + Vector3(0, 0, 4), Vector3.FORWARD)
	await _frames(5)
	var hurtbox := _player.get_node("HurtboxComponent") as HurtboxComponent
	hurtbox.set_invincible(1.0)
	var hp := _player.health.current_health
	var b2 := caster.fire_bolt((_player.global_position + Vector3.UP - caster.get_hand_position()).normalized())
	var res := {"landed": true}
	b2.hit.connect(func(_h: HurtboxComponent, landed: bool) -> void: res["landed"] = landed, CONNECT_ONE_SHOT)
	await _frames(40)
	var burn := _player.get_node("BurnableComponent") as BurnableComponent
	_check(not bool(res["landed"]) and _player.health.current_health == hp and not burn.is_burning(), "player đang bất tử (dash): cầu nổ, không mất máu, không bắt lửa")
	_cleanup()


func _t_fire_resist() -> void:
	var data := _data_copy()
	data.attack_cooldown = 999.0
	_reset_player(PLAYER_HOME, Vector3.FORWARD)
	var caster := await _spawn(PLAYER_HOME + Vector3(0, 0, -2.4), data, true)
	await _frames(10)
	var hp := caster.health.current_health
	_player.energy.set_current(_player.energy.get_max())
	_aim_mouse_at(caster.global_position + Vector3.UP)
	Input.action_press(&"skill_fire")
	await _frames(90)
	Input.action_release(&"skill_fire")
	await _frames(20)
	var burnable := caster.get_node("BurnableComponent") as BurnableComponent
	_check(caster.health.current_health == hp and not burnable.is_burning(), "phun lửa thật 1,5 s: không mất máu, không cháy (%d → %d)" % [hp, caster.health.current_health])
	await _frames(30)
	_reset_player(caster.global_position + Vector3(0, 0, 1.3), Vector3.FORWARD)
	await _frames(10)
	_aim_mouse_at(caster.global_position + Vector3.UP)
	await _tap(&"attack")
	await _frames(40)
	_check(caster.health.current_health < hp, "chém kiếm thật: mất máu (%d → %d)" % [hp, caster.health.current_health])
	_cleanup()


func _t_wind() -> void:
	_reset_player(PLAYER_HOME, Vector3.FORWARD)
	var caster := await _spawn(PLAYER_HOME + Vector3(0, 0, -3), null)
	var log := {"cancel": 0, "fired": 0}
	caster.cast_cancelled.connect(func() -> void: log["cancel"] += 1)
	caster.bolt_fired.connect(func(_b: FireBolt) -> void: log["fired"] += 1)
	var started := await _wait_until(func() -> bool: return caster.is_charging(), 240)
	await _frames(10)
	var p0 := caster.global_position
	_aim_mouse_at(caster.global_position + Vector3.UP)
	await _tap(&"skill")
	await _frames(60)
	var pushed := _flat(caster.global_position, p0)
	_check(started and int(log["cancel"]) == 1 and int(log["fired"]) == 0, "thổi gió lúc đang niệm: ngắt niệm, không bắn (huỷ %d, bắn %d)" % [log["cancel"], log["fired"]])
	_cleanup()
	# So với quái thường cùng khoảng cách
	_reset_player(PLAYER_HOME, Vector3.FORWARD)
	await _frames(70)
	var dummy := ENEMY_SCENE.instantiate() as Enemy
	dummy.position = PLAYER_HOME + Vector3(0, 0, -3)
	add_child(dummy)
	_spawned.append(dummy)
	await _frames(10)
	var d0 := dummy.global_position
	_aim_mouse_at(dummy.global_position + Vector3.UP)
	await _tap(&"skill")
	await _frames(60)
	var dummy_pushed := _flat(dummy.global_position, d0)
	_check(pushed > dummy_pushed * 1.3, "bị đẩy xa hơn quái thường (%.2f m so với %.2f m)" % [pushed, dummy_pushed])
	_cleanup()


func _t_extreme() -> void:
	# Tầm dừng 0: đuổi sát player, không lỗi
	var zero := _data_copy()
	zero.stop_distance = 0.0
	zero.attack_cooldown = 999.0
	_reset_player(PLAYER_HOME, Vector3.FORWARD)
	var c0 := await _spawn(PLAYER_HOME + Vector3(0, 0, -6), zero)
	c0.target = _player
	c0.state_machine.transition_to(c0.chase_state)
	await _frames(150)
	_check(_flat(c0.global_position, _player.global_position) < 2.5, "tầm dừng 0: đuổi sát player (%.2f m), không lỗi" % _flat(c0.global_position, _player.global_position))
	_cleanup()
	# Tầm dừng 40 m: player trong tầm từ đầu nên đứng yên
	var far := _data_copy()
	far.stop_distance = 40.0
	far.attack_cooldown = 999.0
	_reset_player(PLAYER_HOME, Vector3.FORWARD)
	var c1 := await _spawn(PLAYER_HOME + Vector3(0, 0, -6), far)
	var home := c1.global_position
	c1.target = _player
	c1.state_machine.transition_to(c1.chase_state)
	await _frames(120)
	_check(c1.global_position.distance_to(home) < 0.4, "tầm dừng 40 m: đứng yên tại chỗ (dời %.2f m)" % c1.global_position.distance_to(home))
	_cleanup()
	# Niệm 0 s + hồi chiêu 0,01 s: bắn liên tục, pool không phình quá vài quả
	var rapid := _data_copy()
	var atk := rapid.attack.duplicate() as AttackData
	atk.active_start = 0.0
	atk.active_end = 0.01
	atk.duration = 0.05
	rapid.attack = atk
	rapid.attack_cooldown = 0.01
	_reset_player(PLAYER_HOME, Vector3.FORWARD)
	_player.get_node("HurtboxComponent").invulnerable = true
	var c2 := await _spawn(PLAYER_HOME + Vector3(0, 0, -6), rapid)
	var shots := [0]
	c2.bolt_fired.connect(func(_b: FireBolt) -> void: shots[0] += 1)
	await _frames(180)
	var created_mid := c2.pool.get_total_created()
	var shots_mid: int = shots[0]
	await _frames(180)
	_check(shots[0] - shots_mid >= 10 and c2.pool.get_total_created() == created_mid, "niệm 0 s, hồi chiêu 0,01 s: 3 s sau bắn thêm %d quả, pool không tạo thêm node (%d → %d)" % [shots[0] - shots_mid, created_mid, c2.pool.get_total_created()])
	_player.get_node("HurtboxComponent").invulnerable = false
	_cleanup()


## Đặt quái xoay sẵn 180° ở node gốc (như khi level designer cho quay mặt): gốc về thẳng, góc chuyển sang Model,
## đi về phía player với thân nghiêng về trước, cầu lửa sinh ra phía player; giữ tỉ lệ phóng to của gốc
func _t_rotated_root() -> void:
	_reset_player(PLAYER_HOME, Vector3.FORWARD)
	var caster := CASTER_SCENE.instantiate() as FireCaster
	caster.data = _data_copy()
	caster.transform = Transform3D(Basis(Vector3.UP, PI).scaled(Vector3.ONE * 1.4), PLAYER_HOME + Vector3(0, 0, -11))
	add_child(caster)
	_spawned.append(caster)
	await _frames(3)
	_check(caster.basis.orthonormalized().is_equal_approx(Basis.IDENTITY) and caster.basis.get_scale().is_equal_approx(Vector3.ONE * 1.4), "gốc xoay 180° ×1,4: gốc về thẳng, giữ tỉ lệ (%s)" % caster.basis.get_scale())
	var bolt_ahead := [-99.0]
	caster.bolt_fired.connect(func(b: FireBolt) -> void: bolt_ahead[0] = (b.global_position - caster.global_position).dot(caster.direction_to_target()), CONNECT_ONE_SHOT)
	var sk := caster.skeleton
	var lean := -99.0
	for i: int in range(200):
		await get_tree().physics_frame
		if caster.state_machine.current_state.name == &"FireChase" and caster.velocity.length() > 1.0:
			var head := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Head")).origin
			lean = (head - caster.global_position).dot(caster.direction_to_target())
		if bolt_ahead[0] > -99.0:
			break
	_check(lean > 0.05, "gốc xoay 180°: đi về phía player, thân nghiêng về trước (đầu lệch %.2f m về phía player)" % lean)
	_check(bolt_ahead[0] > 0.5, "gốc xoay 180°: cầu lửa sinh ra phía player (%.2f m)" % bolt_ahead[0])
	_cleanup()


# ---------- Tiện ích ----------

func _spawn(pos: Vector3, data: FireCasterData = null, freeze_ai: bool = false) -> FireCaster:
	var caster := CASTER_SCENE.instantiate() as FireCaster
	# Luôn dùng bản sao: các mục sửa dữ liệu không lan sang mục khác
	caster.data = data if data else _data_copy()
	caster.position = pos
	add_child(caster)
	_spawned.append(caster)
	await _frames(3)
	if freeze_ai:
		caster.data.detect_range = 0.0
		caster.sensor.radius = 0.0
		caster.forget_target()
		caster.state_machine.transition_to(&"Idle")
	return caster


func _data_copy() -> FireCasterData:
	var d := DATA.duplicate() as FireCasterData
	return d


func _cleanup() -> void:
	for node: Node in _spawned:
		if is_instance_valid(node):
			node.queue_free()
	_spawned.clear()
	for a: StringName in [&"attack", &"skill", &"skill_fire"]:
		Input.action_release(a)


func _reset_player(pos: Vector3, facing: Vector3) -> void:
	_player.teleport(pos + Vector3.UP * 0.05, facing)
	_player.health.heal_full()


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _build_arena() -> void:
	_box(Vector3(0, -0.5, 0), Vector3(60, 1, 60), Color(0.35, 0.18, 0.12))
	# Tường bắc z -18 cho cầu nổ
	_box(Vector3(0, 2, -18.5), Vector3(20, 4, 1), Color(0.25, 0.22, 0.2))
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


## Có cửa sổ + "--capture": camera nhìn chéo vào quái rồi chụp
func _capture(file: String, focus: Vector3) -> void:
	if not "--capture" in OS.get_cmdline_user_args():
		return
	var cam := Camera3D.new()
	add_child(cam)
	cam.global_position = focus + Vector3(3.2, 3.0, 3.2)
	cam.look_at(focus + Vector3.UP * 1.1)
	cam.fov = 45.0
	cam.make_current()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://output/fire_caster/" + file)
	cam.queue_free()
	var player_cam := _player.get_node("CameraRig/Camera3D") as Camera3D
	player_cam.make_current()
