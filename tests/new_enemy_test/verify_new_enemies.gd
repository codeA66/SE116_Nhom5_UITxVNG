extends Node3D
## Kiểm thử tích hợp: chạy physics thật, nhận sát thương qua hurtbox, không gọi giả hit.
const BEAR: PackedScene = preload("res://entities/enemies/armored_polar_bear/armored_polar_bear.tscn")
const CHIEF: PackedScene = preload("res://entities/enemies/monkey_chieftain/monkey_chieftain.tscn")
const GRUNT: PackedScene = preload("res://entities/enemies/monkey_grunt/monkey_grunt.tscn")
var _failures: int = 0
var _checks: int = 0
var _dummy: CharacterBody3D
var _health: HealthComponent
var _hurt: HurtboxComponent
var _arena: Node3D
var _last_finish: int = -1
var _next_start: int = -1
var _latest_hazard: EnemyHazard
var _hazard_id: StringName

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	_arena = Node3D.new(); add_child(_arena)
	var floor_body: StaticBody3D = StaticBody3D.new()
	var floor_shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new(); box.size = Vector3(100, 1, 100)
	floor_shape.shape = box; floor_body.add_child(floor_shape)
	floor_body.position.y = -0.5; _arena.add_child(floor_body)
	_create_target()
	await _libraries_and_patrol()
	await _monkey_combat()
	await _chief_display_and_root()
	await _bear_skills()
	await _hazard_collisions()
	await _revised_ranges_and_windup()
	await _crowd_collisions()
	await _tuning_and_interruptions()
	await _playable_squad()
	print("NEW_ENEMY_TEST_RESULT checks=%d failures=%d" % [_checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)

func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition: print("PASS: ", label)
	else: _failures += 1; push_error("FAIL: " + label)

func _frames(count: int) -> void:
	for i: int in count: await get_tree().physics_frame

func _seconds(duration: float) -> void:
	await _frames(ceili(duration * Engine.physics_ticks_per_second))

func _create_target() -> void:
	_dummy = CharacterBody3D.new(); _dummy.name = "PlayerProbe"
	_dummy.collision_layer = 2; _dummy.collision_mask = 1
	var body_shape: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new(); capsule.radius = 0.3; capsule.height = 1.6
	body_shape.shape = capsule; body_shape.position.y = .8; _dummy.add_child(body_shape)
	_health = HealthComponent.new(); _health.max_health = 10000; _dummy.add_child(_health)
	_hurt = HurtboxComponent.new(); _hurt.health = _health; _hurt.collision_layer = 2; _hurt.collision_mask = 0
	var hurt_shape: CollisionShape3D = CollisionShape3D.new()
	hurt_shape.shape = capsule; hurt_shape.position.y = .8; _hurt.add_child(hurt_shape); _dummy.add_child(_hurt)
	_dummy.position = Vector3(40, 0, 40)
	_arena.add_child(_dummy); body_shape.owner = _dummy; _health.owner = _dummy; _hurt.owner = _dummy; hurt_shape.owner = _dummy

func _spawn(scene: PackedScene) -> WildEnemy:
	var actor: WildEnemy = scene.instantiate() as WildEnemy
	actor.data = actor.data.duplicate(true) as WildEnemyData
	_arena.add_child(actor)
	return actor

func _dispose(actor: WildEnemy) -> void:
	actor.queue_free(); _dummy.position = Vector3(40, 0, 40)
	await _frames(3)

func _wait_state(actor: WildEnemy, state: StringName, limit: int = 600) -> bool:
	for i: int in limit:
		if actor.state_machine.current_state.name == state: return true
		await get_tree().physics_frame
	return false

func _libraries_and_patrol() -> void:
	var scenes: Array[PackedScene] = [BEAR, CHIEF, GRUNT]
	var counts: Array[int] = [35, 8, 7]
	for i: int in scenes.size():
		var actor: WildEnemy = _spawn(scenes[i]); await _frames(5)
		var anim: AnimationPlayer = actor.animation_player()
		_check(anim.get_animation_list().size() == counts[i], "%s full animation library (%d)" % [actor.name, counts[i]])
		var valid_paths: bool = true
		for clip_name: StringName in anim.get_animation_list():
			var clip: Animation = anim.get_animation(clip_name)
			for track: int in clip.get_track_count():
				var path: NodePath = clip.track_get_path(track)
				if actor.model.get_node_or_null(NodePath(path.get_concatenated_names())) == null: valid_paths = false
		_check(valid_paths, "%s animation tracks resolve to model" % actor.name)
		_check(anim.current_animation == actor.wildlife.idle_animation, "%s idle without player" % actor.name)
		await _seconds(5.0)
		_check(actor.distance_from_home() <= actor.data.patrol_radius + .4, "%s patrol stays near spawn" % actor.name)
		_check(not actor.has_target(), "%s ignores distant player" % actor.name)
		await _dispose(actor)

func _monkey_combat() -> void:
	var actor: WildEnemy = _spawn(GRUNT); await _frames(3)
	_dummy.position = Vector3(0, 0, 5)
	_check(await _wait_state(actor, &"WildChase", 30), "grunt sensor enters chase")
	await _frames(10)
	_check(actor.animation_player().current_animation == actor.wildlife.run_animation and actor.velocity.length() > .1, "grunt runs toward player")
	_check(await _wait_state(actor, &"SkillAttack"), "grunt starts lunge in melee range")
	actor.skill_finished.connect(_on_finished)
	actor.skill_started.connect(_on_started)
	_check(await _wait_state(actor, &"Watch"), "grunt enters cooldown after completed attack")
	var at: Vector3 = actor.position
	_dummy.position = at + Vector3(3, 0, 1)
	await _seconds(1.0)
	_check(actor.position.distance_to(at) > .4, "grunt walks closer during cooldown")
	_check(actor.get_facing_direction().dot(actor.direction_to_target()) > .98, "grunt faces moving player during cooldown")
	_check(actor.animation_player().current_animation == actor.wildlife.walk_animation, "grunt uses walk while recovering nearby")
	_dummy.position = actor.position + Vector3(0, 0, 1)
	_check(await _wait_state(actor, &"SkillAttack", 400), "grunt attacks again after cooldown")
	_check(_next_start - _last_finish >= 119 and _next_start - _last_finish <= 124, "grunt waits two seconds after attack end")
	_check(_health.current_health < _health.max_health, "monkey melee applies real hurtbox damage")
	_check(actor.movement.max_speed == 6.0, "grunt run matches player speed without exceeding it")
	_dummy.position = actor.position + Vector3(0, 0, 9)
	await _wait_state(actor, &"Watch")
	await _seconds(.25)
	_check(actor.animation_player().current_animation == actor.wildlife.run_animation and actor.velocity.length() <= 6.01, "grunt runs during cooldown when player is far")
	# Chọn ngẫu nhiên hai đòn hợp lệ, không cấp phát danh sách mỗi frame.
	actor.set_physics_process(false)
	actor.state_machine.transition_to(&"Idle")
	_dummy.position = actor.position + Vector3(0, 0, 1)
	actor.set(&"_attack_cooldown_left", 0.0)
	var ready_slashes: Dictionary[StringName, float] = {&"slash_01": 0.0, &"slash_02": 0.0}
	actor.set(&"_cooldowns", ready_slashes)
	var seen: Dictionary[StringName, bool] = {}
	for i: int in 100:
		var choice: EnemySkillData = actor.choose_skill()
		if choice != null: seen[choice.skill_id] = true
	_check(seen.size() == 2, "grunt randomly selects both slash animations")
	await _dispose(actor)

func _on_finished(_skill: EnemySkillData, completed: bool) -> void:
	if completed: _last_finish = Engine.get_physics_frames()

func _on_started(_skill: EnemySkillData) -> void:
	_next_start = Engine.get_physics_frames()

func _chief_display_and_root() -> void:
	var actor: WildEnemy = _spawn(CHIEF); await _frames(3)
	_dummy.position = Vector3(0, 0, 5)
	_check(await _wait_state(actor, &"Display", 30), "chief chest-beats on detection")
	_check(actor.animation_player().current_animation == &"Gorilla_ChestBeat_Roar", "chief plays original chestbeat roar")
	await _seconds(4.7)
	_check(not actor.alert_pending(), "chief roars once per engagement")
	actor.set_physics_process(false)
	actor.state_machine.transition_to(&"Idle")
	actor.position = Vector3.ZERO; actor.velocity = Vector3.ZERO; actor.home_position = Vector3.ZERO
	_dummy.position = Vector3(0, 0, 8); actor.target = _dummy
	var skill: EnemySkillData = actor.wildlife.skills[0]
	_check(absf(actor.root_offset(skill, skill.duration) - 1.344) < .02, "chief baked root curve matches authored 3.2m at model scale")
	# Tường chặn chuyển động vật lý của đòn vồ.
	var wall: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new(); box.size = Vector3(5, 4, .2)
	shape.shape = box; wall.add_child(shape); wall.position = Vector3(0, 2, 1.0); _arena.add_child(wall)
	actor.begin_skill(skill); actor.set_physics_process(true)
	await _seconds(skill.duration + .1)
	_check(actor.position.z < .55, "chief lunge cannot pass through wall")
	wall.queue_free(); await _frames(3)
	actor.set_physics_process(false); actor.state_machine.transition_to(&"Idle")
	actor.position = Vector3.ZERO; actor.velocity = Vector3.ZERO
	_dummy.position = Vector3(0, 0, 5); _dummy.velocity = Vector3(6, 0, 0)
	actor.begin_skill(skill); actor.set_physics_process(true)
	await _seconds(.4)
	var leap: Node = actor.state_machine.current_state
	var anticipated: Vector3 = leap.call(&"landing_position") as Vector3
	_check(anticipated.x > 2.0, "chief aims ahead along player movement during windup")
	_check(actor.get_facing_direction().x > .3, "chief turns toward predicted position while winding up")
	await _seconds(.5)
	var locked_landing: Vector3 = leap.call(&"landing_position") as Vector3
	_dummy.velocity = Vector3(-6, 0, 0); _dummy.position = Vector3(-3, 0, 5)
	await _seconds(.2)
	_check((leap.call(&"landing_position") as Vector3).distance_to(locked_landing) < .001, "chief locks destination after launch")
	for frame: int in 60:
		if actor.hitbox.is_active(): break
		await _frames(1)
	_check(actor.hitbox.is_active() and actor.position.distance_to(locked_landing) < .08, "chief reaches landing point exactly when claw hitbox activates")
	_check(actor.position.length() > 4.0, "chief leaps several meters rather than original short root step")
	await _wait_state(actor, &"Watch")
	_check(actor.attack_cooldown_remaining() > 1.9, "chief attack starts two-second recovery")
	_dummy.velocity = Vector3.ZERO
	_dummy.position = Vector3(40, 0, 40)
	await _seconds(4)
	_check(not actor.has_target(), "chief releases distant player")
	await _dispose(actor)

func _on_hazard(hazard: EnemyHazard, skill: EnemySkillData) -> void:
	_latest_hazard = hazard; _hazard_id = skill.skill_id

func _bear_skills() -> void:
	var actor: WildEnemy = _spawn(BEAR); await _frames(3)
	actor.emitter.hazard_spawned.connect(_on_hazard)
	_dummy.position = Vector3(0, 0, 8)
	_check(await _wait_state(actor, &"SkillAttack", 30), "bear detects player at ranged distance")
	_check(actor.pending_skill.skill_id == &"wind", "bear opens with wind on distant player")
	_check(is_instance_valid(_latest_hazard) and _hazard_id == &"wind", "wind hazard created at cast start")
	var wind_at: Vector3 = _latest_hazard.global_position
	_check(wind_at.distance_to(_dummy.position) < .05, "wind warning centered under player feet")
	_dummy.position.x = 3
	await _seconds(.4)
	_check(_latest_hazard.global_position.distance_to(wind_at) < .01, "wind warning stays fixed after target moves")
	await _seconds(3.2)
	_check(actor.skill_cooldown(&"wind") > 4.7 and actor.skill_cooldown(&"ice") == 0.0, "bear spells have independent five-second cooldowns")
	# Ép vị trí gần để kiểm tra ice tracking và hướng khóa sau windup.
	actor.set_physics_process(false); actor.state_machine.transition_to(&"Idle")
	_dummy.position = actor.position + Vector3(0, 0, 3)
	actor.begin_skill(actor.wildlife.skills[0]); actor.set_physics_process(true)
	await _seconds(.3)
	_dummy.position = actor.position + Vector3(3, 0, 1)
	await _seconds(.75)
	_check(_hazard_id == &"ice", "ice appears at end of windup")
	var locked: Vector3 = actor.get_facing_direction()
	_check(locked.x > .7, "ice tracks target direction during windup")
	_dummy.position = actor.position + Vector3(-3, 0, 0)
	await _seconds(.3)
	_check(actor.get_facing_direction().distance_to(locked) < .001, "ice direction locks after windup")
	_check(_latest_hazard.global_basis.z.dot(locked) > .99, "ice VFX and hitbox share locked forward axis")
	await _seconds(2.2)
	actor.set_physics_process(false); actor.state_machine.transition_to(&"Idle")
	var cooling_spells: Dictionary[StringName, float] = {&"wind": 4.0, &"ice": 4.0, &"claw": 0.0}
	actor.set(&"_cooldowns", cooling_spells)
	_dummy.position = actor.position + Vector3(0, 0, 5)
	actor.state_machine.transition_to(&"WildChase"); actor.set_physics_process(true)
	await _frames(20)
	_check(actor.animation_player().current_animation == actor.wildlife.run_animation, "bear runs closer while spells cool down")
	_check(await _wait_state(actor, &"SkillAttack", 150), "bear reaches fallback melee range")
	_check(actor.pending_skill.skill_id == &"claw", "bear uses physical claw when spells unavailable")
	await _seconds(1.6)
	_check(_hazard_id == &"claw" and _latest_hazard.age < .15, "delayed magic warning starts after physical claw finishes")
	actor.health.take_damage(actor.health.max_health)
	await _frames(2)
	var active: int = 0
	for pool: ObjectPool in actor.emitter.pools.values(): active += pool.get_active_count()
	_check(active == 0, "enemy death releases every pooled hazard")
	await _dispose(actor)

func _hazard_collisions() -> void:
	var actor: WildEnemy = _spawn(BEAR); await _frames(3)
	actor.set_physics_process(false); actor.sensor.monitoring = false
	_dummy.position = Vector3(0, 0, 4); actor.target = _dummy
	var skill: EnemySkillData = actor.wildlife.skills[2]
	var hazard: EnemyHazard = actor.emitter.emit_skill(skill, Vector3.BACK)
	var at: Vector3 = hazard.global_position
	var health_before: int = _health.current_health
	await _seconds(.9)
	_check(_health.current_health == health_before and not hazard.hitbox.is_active(), "delayed claw cannot damage during one-second warning")
	actor.position.x += 4
	_check(hazard.global_position.distance_to(at) < .01, "pooled warning keeps world position when caster moves")
	await _seconds(.25)
	_check(_health.current_health == health_before - skill.damage, "delayed claw deals damage after one second")
	await _seconds(.25)
	_check(_health.current_health == health_before - skill.damage, "one damage application per magic claw cast")
	await _seconds(1.0)
	var pool: ObjectPool = actor.emitter.pools[skill.effect_scene]
	_check(pool.get_active_count() == 0 and pool.get_total_created() == 2, "hazard returns to prewarmed pool")
	_dummy.position = Vector3(0, 0, 4)
	hazard = actor.emitter.emit_skill(skill, Vector3.BACK)
	health_before = _health.current_health
	await _seconds(.5); _dummy.position.x += 5
	await _seconds(2.2)
	_check(_health.current_health == health_before, "moving out of warning avoids magic claw")
	actor.emitter.cancel_all(); await _frames(2)
	_check(not hazard.hitbox.is_active() and not hazard.is_physics_processing(), "released hazard has no active collision or clock")
	# Phe enemy (layer 4) không bị hitbox chỉ mask player (layer 2) đánh trúng.
	_dummy.position = Vector3(0, 0, 4); _hurt.collision_layer = 4
	hazard = actor.emitter.emit_skill(skill, Vector3.BACK)
	await _seconds(2.3)
	_check(_health.current_health == health_before, "enemy spell does not damage friendly hurtboxes")
	_hurt.collision_layer = 2; actor.emitter.cancel_all()
	# Đo collision wind/ice thật ngoài việc kiểm tra hình ảnh và thời gian state.
	_dummy.position = Vector3(0, 0, 4)
	health_before = _health.current_health
	var wind: EnemySkillData = actor.wildlife.skills[1]
	hazard = actor.emitter.emit_skill(wind, Vector3.BACK)
	await _seconds(.8)
	_check(_health.current_health == health_before, "wind warning has no early damage")
	await _seconds(.7)
	_check(_health.current_health == health_before - wind.damage and _dummy.velocity.y >= 7.0, "wind burst damages and launches player once")
	actor.emitter.cancel_all(); await _frames(2)
	actor.position = Vector3.ZERO; _dummy.position = Vector3(0, 0, 4)
	health_before = _health.current_health
	var ice: EnemySkillData = actor.wildlife.skills[0]
	hazard = actor.emitter.emit_skill(ice, Vector3.BACK)
	await _seconds(.2)
	_check(_health.current_health == health_before, "ice hitbox does not reach ahead of growing crystals")
	await _seconds(1.0)
	_check(_health.current_health == health_before - ice.damage, "growing ice collision reaches player along locked path")
	actor.emitter.cancel_all()
	await _dispose(actor)

func _playable_squad() -> void:
	var packed: PackedScene = load("res://tests/new_enemy_test/new_enemy_test.tscn") as PackedScene
	var arena: Node3D = packed.instantiate() as Node3D
	add_child(arena); await _frames(5)
	var player: FoxyPlayer = arena.get_node("Player") as FoxyPlayer
	player.controls_enabled = false
	var chief: MonkeyChieftain = arena.get_node("MonkeySquad/Chieftain") as MonkeyChieftain
	var squad: Array[MonkeyGrunt] = []
	for child: Node in arena.get_node("MonkeySquad").get_children():
		if child is MonkeyGrunt:
			var grunt: MonkeyGrunt = child as MonkeyGrunt
			grunt.sensor.monitoring = false; squad.append(grunt)
	_check(squad.size() == 3 and arena.get_node("ArmoredPolarBear") is ArmoredPolarBear, "playable arena contains one bear, one chief, three grunts")
	player.teleport(chief.global_position + Vector3(0, 0, 3))
	_check(await _wait_state(chief, &"Display", 60), "real Foxy player triggers chief detection")
	var rallied: bool = true
	for grunt: MonkeyGrunt in squad: rallied = rallied and grunt.target == player
	_check(rallied, "chief rallies all three nearby grunts without their sensors")
	await _seconds(8.0)
	_check((arena.get("_hits") as int) > 0, "playable encounter damages real player through existing combat components")
	_check(player.health.current_health == player.health.max_health, "training toggle heals real player without saving progression")
	var bear: WildEnemy = arena.get_node("ArmoredPolarBear") as WildEnemy
	bear.set_physics_process(false); bear.sensor.monitoring = false
	bear.target = player
	var effect: EnemyHazard = bear.emitter.emit_skill(bear.wildlife.skills[2], Vector3.BACK)
	effect.set_physics_process(false)
	effect.visual.call(&"seek", 1.12)
	var overlay: ClawScreenOverlay = effect.visual.get("overlay") as ClawScreenOverlay
	var first_rect: Rect2 = overlay.screen_rect()
	_check(overlay.overlay_visible() and first_rect.size.x > 20.0, "magic claw appears on screen overlay at world warning position")
	var camera: Camera3D = arena.get_node("OverviewCamera") as Camera3D
	camera.position = player.position + Vector3(12, 8, 0); camera.look_at(player.position); camera.make_current()
	await _frames(2)
	_check(overlay.overlay_visible() and overlay.screen_rect().size.x > 20.0, "claw overlay remains visible from side camera")
	bear.emitter.cancel_all(); await _frames(2)
	_check(not overlay.overlay_visible(), "pool release hides canvas overlay as well as world VFX")
	arena.queue_free(); await _frames(3)

func _revised_ranges_and_windup() -> void:
	var actor: WildEnemy = _spawn(BEAR); await _frames(3)
	actor.sensor.monitoring = false; actor.set_physics_process(false)
	_dummy.position = Vector3(0, 0, 1.5); actor.target = _dummy
	var health_before: int = _health.current_health
	actor.begin_skill(actor.wildlife.skills[2]); actor.set_physics_process(true)
	await _seconds(.6)
	_check(not actor.hitbox.is_active() and _health.current_health == health_before, "bear claw has readable 0.7-second windup without early damage")
	_check(actor.animation_player().current_animation == &"BearActions/Claw_Windup", "bear uses new pull-in anticipation clip")
	await _seconds(.25)
	_check(_health.current_health < health_before, "bear physical claw hits after longer windup")
	actor.set_physics_process(false); actor.state_machine.transition_to(&"Idle"); actor.emitter.cancel_all()
	actor.position = Vector3.ZERO
	_dummy.position = Vector3(0, 0, 4)
	health_before = _health.current_health
	var hazard: EnemyHazard = actor.emitter.emit_skill(actor.wildlife.skills[1], Vector3.BACK)
	await _seconds(.2); _dummy.position.x = 2.6
	await _seconds(1.0)
	_check(_health.current_health < health_before, "double-radius wind hits beyond former 1.45m radius")
	actor.emitter.cancel_all(); await _frames(2)
	_dummy.position = Vector3(0, 0, 4)
	health_before = _health.current_health
	hazard = actor.emitter.emit_skill(actor.wildlife.skills[2], Vector3.BACK)
	await _seconds(.2); _dummy.position.x = 1.9
	await _seconds(.95)
	_check(_health.current_health < health_before, "expanded magic claw hits beyond old radius after 1s")
	actor.emitter.cancel_all(); await _frames(2)
	_dummy.position = Vector3(1.2, 0, 7)
	health_before = _health.current_health
	hazard = actor.emitter.emit_skill(actor.wildlife.skills[0], Vector3.BACK)
	await _seconds(.8)
	_check(_health.current_health < health_before, "faster wider ice reaches lateral player 7m away before old peak time")
	actor.emitter.cancel_all(); await _dispose(actor)

func _crowd_collisions() -> void:
	var actors: Array[Enemy] = []
	var starts: Array[Vector3] = [Vector3(-2, 0, -3), Vector3(0, 0, -3.8), Vector3(2, 0, -3), Vector3(-3.5, 0, -5.5), Vector3(3.5, 0, -5.5)]
	var scenes: Array[PackedScene] = [CHIEF, GRUNT, GRUNT, BEAR, load("res://entities/enemies/enemy_1/enemy_1.tscn") as PackedScene]
	for i: int in scenes.size():
		var actor: Enemy = scenes[i].instantiate() as Enemy
		actor.position = starts[i]
		_arena.add_child(actor); actors.append(actor)
		if actor is WildEnemy: actor.set(&"_alert_done", true)
	await _frames(5)
	_dummy.position = Vector3(0, 0, 4)
	var clearance: float = INF
	var all_masks: bool = true
	for actor: Enemy in actors: all_masks = all_masks and actor.get_collision_mask_value(3)
	for frame: int in 480:
		await _frames(1)
		for i: int in actors.size():
			for j: int in range(i + 1, actors.size()):
				var a: Enemy = actors[i]; var b: Enemy = actors[j]
				var radius_a: float = ((a.get_node("CollisionShape3D") as CollisionShape3D).shape as CapsuleShape3D).radius
				var radius_b: float = ((b.get_node("CollisionShape3D") as CollisionShape3D).shape as CapsuleShape3D).radius
				var offset: Vector3 = a.position - b.position; offset.y = 0.0
				clearance = minf(clearance, offset.length() - radius_a - radius_b)
	_check(all_masks, "new and existing enemies all collide with enemy body layer")
	_check(clearance >= -.035, "mixed crowd bodies never overlap while running and attacking (clearance %.3f)" % clearance)
	var progressed: bool = true
	for i: int in actors.size(): progressed = progressed and actors[i].position.distance_to(starts[i]) > 1.0
	_check(progressed, "all five enemies make progress while avoiding their neighbors")
	for actor: Enemy in actors: actor.queue_free()
	_dummy.position = Vector3(40, 0, 40); await _frames(3)

func _tuning_and_interruptions() -> void:
	for radius: float in [0.0, 0.15, 4.0]:
		var actor: WildEnemy = _spawn(GRUNT); await _frames(3)
		actor.data.patrol_radius = radius
		actor.data.patrol_wait_min = .1; actor.data.patrol_wait_max = .1
		actor.state_machine.transition_to(&"Idle")
		await _seconds(5)
		_check(actor.position.is_finite() and actor.distance_from_home() <= radius + .4, "patrol radius %.2f remains finite and bounded" % radius)
		await _dispose(actor)
	var actor: WildEnemy = _spawn(GRUNT); await _frames(3)
	_dummy.position = Vector3(0, 0, 1); actor.target = _dummy
	actor.begin_skill(actor.wildlife.skills[0]); await _seconds(.4)
	var damage: DamageInfo = DamageInfo.new(1, DamageInfo.Type.PHYSICAL, Vector3.ZERO, _dummy)
	actor.hurtbox.receive_hit(damage); await _frames(2)
	_check(actor.state_machine.current_state.name == &"Hurt" and not actor.hitbox.is_active(), "hurt interrupts grunt windup and disables its hitbox")
	_check(actor.attack_cooldown_remaining() > 1.8, "interrupted grunt attack still starts recovery cooldown")
	await _dispose(actor)
	actor = _spawn(CHIEF); await _frames(3); actor.set_physics_process(false)
	_dummy.position = Vector3(0, 0, 8); _dummy.velocity = Vector3(40, 0, 0); actor.target = _dummy
	var leap: LeapSkillData = actor.wildlife.skills[0] as LeapSkillData
	for limit: float in [0.0, 0.2, 12.0]:
		leap.maximum_leap_distance = limit
		actor.begin_skill(leap)
		var destination: Vector3 = actor.state_machine.current_state.call(&"landing_position") as Vector3
		_check(destination.is_finite() and destination.distance_to(actor.position) <= limit + .001, "predicted leap limit %.1f clamps fast moving target safely" % limit)
		actor.state_machine.transition_to(&"Idle")
	_dummy.velocity = Vector3.ZERO; await _dispose(actor)
	var first: WildEnemy = _spawn(GRUNT)
	var second: WildEnemy = _spawn(GRUNT)
	await _frames(3)
	first.spacing.separation_radius = .15; second.spacing.separation_radius = 3.0
	var first_radius: float = ((first.spacing.get_node("CollisionShape3D") as CollisionShape3D).shape as SphereShape3D).radius
	var second_radius: float = ((second.spacing.get_node("CollisionShape3D") as CollisionShape3D).shape as SphereShape3D).radius
	_check(absf(first_radius - .15) < .001 and absf(second_radius - 3.0) < .001, "spacing radius small/large updates independent per-enemy shapes")
	await _dispose(first); await _dispose(second)
