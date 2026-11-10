extends Node
## Cài profile trước _ready của quái để socket/pool đạn dùng đúng Resource của đòn ném.
const AggroData = preload("res://resources/world/monkey_garden/boss_aggro/garden_boss_aggro_data.gd")
@export var encounter: GardenKingEncounter
@export var settings: AggroData = preload("res://resources/world/monkey_garden/boss_aggro/garden_boss_aggro.tres")
var _profiles: Dictionary[WildEnemyData, WildEnemyData] = {}
var _configured: Dictionary[int, bool] = {}

func _enter_tree() -> void:
	encounter.guard_registered.connect(_configure)
	for guard: Enemy in encounter.guards: _configure(guard)
	set_process(false); set_physics_process(false)

func _exit_tree() -> void:
	if is_instance_valid(encounter) and encounter.guard_registered.is_connected(_configure):
		encounter.guard_registered.disconnect(_configure)

func _configure(guard: Enemy) -> void:
	if not is_instance_valid(guard) or not guard is MonkeyGrunt: return
	var id: int = guard.get_instance_id()
	if _configured.has(id): return
	_configured[id] = true
	var original: WildEnemyData = guard.data as WildEnemyData
	if not _profiles.has(original): _profiles[original] = _make_profile(original,guard is RoofBananaGrunt)
	var profile: WildEnemyData = _profiles[original]
	guard.data = profile
	if guard.is_node_ready():
		(guard as WildEnemy).wildlife = profile
		guard.sensor.radius = profile.detect_range

func _make_profile(original: WildEnemyData, roof: bool) -> WildEnemyData:
	# Resource gốc vẫn được khỉ ở phòng bẫy, phòng thử giày và các wave dùng chung.
	var profile: WildEnemyData = original.duplicate() as WildEnemyData
	if roof:
		var multiplier: float = maxf(settings.roof_range_multiplier,0.1)
		profile.detect_range *= multiplier; profile.lose_range *= multiplier
		var skills: Array[EnemySkillData] = []
		for skill: EnemySkillData in original.skills:
			if skill is ProjectileSkillData:
				var ranged: ProjectileSkillData = skill.duplicate() as ProjectileSkillData
				ranged.maximum_range *= multiplier
				skills.append(ranged)
			else: skills.append(skill)
		profile.skills = skills
	else:
		profile.detect_range = settings.ground_detect_range
		profile.lose_range = maxf(profile.detect_range,settings.ground_lose_range)
		profile.leash_range = settings.ground_leash_range
	return profile
