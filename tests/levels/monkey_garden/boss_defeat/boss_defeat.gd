extends Node
## Boss gục phải kết thúc cả quân đặt sẵn lẫn quân triệu hồi, không ảnh hưởng phòng khác.

const TEST_MAP: String = "res://levels/zone_1_wind/level_1/rooms/tier_3/tier3_test.tscn"
const MAIN_MAP: String = "res://levels/zone_1_wind/level_1/level_1.tscn"
var _checks: int = 0
var _failures: PackedStringArray = []

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	if GameState.progress_committed.is_connected(SaveManager.save_game): GameState.progress_committed.disconnect(SaveManager.save_game)
	await _case(TEST_MAP,false)
	await _case(TEST_MAP,true)
	await _case(MAIN_MAP,true)
	print("BOSS_DEFEAT_RESULT ",_checks-_failures.size(),"/",_checks," failures=",_failures)
	get_tree().quit(0 if _failures.is_empty() else 1)

func _case(path: String, with_summons: bool) -> void:
	var progress: PlayerProgress = GameState.progress.snapshot()
	progress.flags.erase(&"level_1.monkey_king_defeated")
	GameState.replace_progress(progress)
	var world: ZoneRoot = load(path).instantiate() as ZoneRoot
	world.shader_warmup = null; get_tree().root.add_child(world)
	if not world.is_combat_ready(): await world.combat_ready
	await _frames(8)
	var tier: Node3D = world if path==TEST_MAP else world.get_node("Rooms/Tier3")
	var king: GardenKingEncounter = tier.get_node("Rooms/BossRoom/KingEncounter")
	var player: Player = world.get_node("Player")
	player.health.damaged.connect(func(_amount: int) -> void: player.health.heal_full())
	player.teleport(king.global_position+Vector3(0,0.1,2),Vector3.FORWARD)
	for frame: int in 650:
		if king.fighting: break
		await _frames(1)
	_check(king.fighting,"boss fight begins "+path.get_file())
	var followers: Array[Enemy] = []
	var outside: Enemy = tier.get_node("Rooms/RootGarden/BananaBootsTrial/TrainingRoofGuard_1")
	var outside_hp: int = outside.health.current_health
	var count: Array[int] = [0]
	king.cleared.connect(func() -> void: count[0]+=1)
	var summoned: Array[MonkeyGrunt] = []
	if with_summons:
		king.leader.summoner.summoned.connect(func(monkeys: Array[MonkeyGrunt]) -> void: summoned.append_array(monkeys))
		king.leader.summoner.summon(); await _frames(3)
		_check(summoned.size()==4,"boss creates four real summons")
		var bombers: int = 0
		for monkey: MonkeyGrunt in summoned:
			if monkey is BananaBomber: bombers+=1
			_check(monkey in king.guards,"summon joins encounter death tracking")
		_check(bombers>=1 and bombers<=2,"summoned bombers are included")
	for guard: Enemy in king.guards:
		if guard != king.leader and not guard.is_dead(): followers.append(guard)
	var first: Enemy = followers.pop_front()
	first.on_lethal_zone_entered()
	_check(not GameState.has_flag(king.encounter_flag) and count[0]==0,"killing a guard does not clear living boss")
	var emitter: EnemyProjectileEmitter = followers[0].get_node("ProjectileEmitter") as EnemyProjectileEmitter
	var roof: WildEnemy = followers[0] as WildEnemy
	var skill: ProjectileSkillData = roof.wildlife.skills[-1] as ProjectileSkillData
	var projectile: EnemyProjectile = emitter.launch(skill,Vector3.RIGHT)
	projectile.set_physics_process(false)
	var deaths: Array[int] = [0]
	for guard: Enemy in followers:
		guard.died.connect(func(_enemy: Enemy) -> void: deaths[0]+=1)
	king.leader.on_lethal_zone_entered(); await _frames(3)
	_check(king.leader.is_dead() and not king.fighting,"leader defeat ends fighting")
	_check(deaths[0]==followers.size(),"every remaining follower dies through normal health/FSM")
	for guard: Enemy in followers:
		_check(guard.is_dead() and guard.state_machine.current_state.name==&"Dead","follower enters Dead state")
		if guard is BananaBomber: _check(not guard.is_armed and not guard.detonated,"boss defeat cancels bomber fuse")
	_check(GameState.has_flag(king.encounter_flag) and count[0]==1,"boss completion emits exactly once")
	_check(not projectile.visible,"retinue bananas are cancelled at victory")
	_check(is_instance_valid(outside) and outside.health.current_health==outside_hp,"other room monkeys survive")
	king.leader.on_lethal_zone_entered(); await _frames(5)
	_check(count[0]==1,"duplicate death cannot repeat completion")
	world.process_mode = Node.PROCESS_MODE_DISABLED
	for area: Node in world.find_children("*","Area3D",true,false): area.set_deferred("monitoring",false)
	await _frames(3); world.queue_free(); await _frames(3)

func _frames(count: int) -> void:
	for frame: int in count: await get_tree().physics_frame

func _check(value: bool, message: String) -> void:
	_checks+=1; print("PASS " if value else "FAIL ",message)
	if not value: _failures.append(message)
