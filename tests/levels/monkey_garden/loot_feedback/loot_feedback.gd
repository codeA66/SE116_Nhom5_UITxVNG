extends Node
const MAP: PackedScene = preload("res://levels/zone_1_wind/level_1/rooms/tier_3/tier3_test.tscn")
var _world: ZoneRoot
var _player: Player
var _clock: float = 0.0
var _checks: int = 0
var _failures: PackedStringArray = []

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func _physics_process(delta: float) -> void:
	_clock+=delta

func _run() -> void:
	if GameState.progress_committed.is_connected(SaveManager.save_game): GameState.progress_committed.disconnect(SaveManager.save_game)
	_world=MAP.instantiate(); _world.shader_warmup=null
	get_tree().root.add_child(_world)
	if not _world.is_combat_ready(): await _world.combat_ready
	await _frames(10); _player=_world.get_node("Player")
	for guard: Node in _world.find_children("*","Enemy",true,false):
		(guard as Enemy).set_dormant(true); guard.process_mode=Node.PROCESS_MODE_DISABLED
	_player.teleport(Vector3(0,0.1,26),Vector3.FORWARD)
	await _frames(6)
	await _drops()
	await _warning()
	await _cooldown(false,3.5)
	await _cooldown(true,4.0)
	var gate: GardenOfferingGate=_world.get_node("OfferingPuzzle/FiveBananaGate")
	gate.call("_sink")
	_check(not gate.get_node("Visual/OldGardenDoor/Interactive_Cyan_Lock").visible and not gate.get_node("Visual/OldGardenDoor/LockBase").visible,"central lock disappears at start of opening")
	var room: Node3D=_world.get_node("Rooms/RootGarden")
	var fruit: OfferingBanana=_world.get_node("Bananas/Banana_5")
	var entrance: GardenLiftGate=(room.get_node("DoorTrial") as RoomGateTrial).gates[0]
	_check(fruit.global_position.distance_to(entrance.global_position)<3,"offering reward lands beside actual entrance")
	_world.process_mode=Node.PROCESS_MODE_DISABLED
	for area: Node in _world.find_children("*","Area3D",true,false): area.set_deferred("monitoring",false)
	await _frames(3); _world.queue_free(); await _frames(3)
	print("LOOT_FEEDBACK_RESULT ",_checks-_failures.size(),"/",_checks," failures=",_failures)
	get_tree().quit(0 if _failures.is_empty() else 1)

func _drops() -> void:
	var banana: OfferingBanana=_world.get_node("Bananas/Banana_4")
	GardenRewards.offering(banana)
	_check(not banana.get_node("LootBeam").visible,"offering beam waits for landing")
	await _frames(150)
	_check(banana.available and banana.get_node("LootBeam").visible,"landed offering shows beam")
	var carry: CarryComponent=_player.get_node("CarryComponent")
	_player.state_machine.transition_to(&"Idle")
	_check(carry.take(banana) and not banana.get_node("LootBeam").visible,"carrying offering hides beam")
	carry.drop(); await _frames(2)
	_check(banana.get_node("LootBeam").visible,"dropping offering restores beam")

func _warning() -> void:
	var bomber: BananaBomber=_spawn("res://entities/enemies/wildlife/variants/banana_bomber/banana_bomber.tscn",Vector3(4,0.1,27)) as BananaBomber
	bomber.set_dormant(true); bomber.set_physics_process(false)
	var warning: BananaBombWarning=bomber.get_node("WarningIndicator")
	_check(not warning.visible,"unaware bomber has no warning")
	bomber.receive_rally(_player); await _frames(2)
	_check(warning.visible,"detection arms bomber and reveals triangle")
	var scale_before: Vector3=warning.scale
	await _frames(12)
	_check(warning.scale.distance_to(scale_before)>0.02,"warning pulses in size")
	bomber.health.take_damage(999); await _frames(3)
	_check(not warning.visible,"death hides warning immediately")

func _cooldown(roof: bool, expected: float) -> void:
	var file: String="res://entities/enemies/wildlife/variants/roof_banana_grunt/roof_banana_grunt.tscn" if roof else "res://entities/enemies/wildlife/monkey_grunt/monkey_grunt.tscn"
	_player.teleport(Vector3(0,0.1,20),Vector3.FORWARD)
	(_player.get_node("HurtboxComponent") as HurtboxComponent).set_invincible(30)
	var enemy: WildEnemy=_spawn(file,Vector3(0,4 if roof else 0.1,28)) as WildEnemy
	enemy.movement.max_speed=0.0
	var fired: Array[float]=[]
	(enemy.get_node("ProjectileEmitter") as EnemyProjectileEmitter).projectile_fired.connect(func(projectile: EnemyProjectile) -> void:
		fired.append(_clock); projectile.cancel.call_deferred())
	enemy.receive_rally(_player)
	for index: int in 900:
		await _frames(1)
		if fired.size()>=2: break
	_check(fired.size()>=2,"AI throws two bananas: "+file.get_file()+str(roof))
	if fired.size()>=2: _check(fired[1]-fired[0]>=expected-0.05,"throw cannot bypass cooldown "+str(expected))
	var skill: ProjectileSkillData=enemy.wildlife.skills[-1] as ProjectileSkillData
	_check(is_equal_approx(skill.cooldown,expected),"configured release cooldown "+str(expected))
	enemy.process_mode=Node.PROCESS_MODE_DISABLED; enemy.set_dormant(true)
	enemy.queue_free(); await _frames(3)

func _spawn(file: String, at: Vector3) -> Enemy:
	var enemy: Enemy=load(file).instantiate(); enemy.position=at; _world.add_child(enemy); return enemy

func _frames(count: int) -> void:
	for index: int in count: await get_tree().physics_frame

func _check(value: bool, message: String) -> void:
	_checks+=1; print("PASS " if value else "FAIL ",message)
	if not value: _failures.append(message)
