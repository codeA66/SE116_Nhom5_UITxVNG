extends Node
## Tách tiến trình sân thử để nhặt bùa và chạm checkpoint không thay đổi hồ sơ thật.

const STORAGE: String = "user://test_combat_charms/"
const PROJECT_THEME: Theme = preload("res://ui/theme/menu_theme.tres")

@export_group("Trang bị thử")
@export var weapons: Array[Resource] = []
@export var abilities: Array[Resource] = []
@export_range(1, 12) var notch_count: int = 4


func _enter_tree() -> void:
	SaveManager.use_storage_dir(STORAGE)
	for event: Signal in [GameState.progress_changed, GameState.progress_committed, GameState.tutorials_changed]:
		if event.is_connected(SaveManager.save_game):
			event.disconnect(SaveManager.save_game)
	var progress: PlayerProgress = PlayerProgress.new()
	progress.charm_notches = notch_count
	GameState.replace_progress(progress)


func _ready() -> void:
	set_process(false)
	for weapon: Resource in weapons:
		GameState.add_weapon(weapon as WeaponData)
	if not weapons.is_empty():
		GameState.set_weapon(weapons[0] as WeaponData)
	for ability: Resource in abilities:
		GameState.unlock_ability(ability as AbilityData)
	for node: Node in get_parent().find_children("*", "Label3D", true, false):
		(node as Label3D).font = PROJECT_THEME.default_font
	var zone: ZoneRoot = get_parent() as ZoneRoot
	if not zone.is_combat_ready():
		await zone.combat_ready
	for name: String in ["DummySword", "DummyBow", "DummySkill"]:
		var dummy: Node = zone.get_node(NodePath(name))
		var hurtbox: HurtboxComponent = dummy.get_node(^"HurtboxComponent") as HurtboxComponent
		hurtbox.hurt.connect(_on_target_hurt.bind(name))
	print("COMBAT_CHARMS_SANDBOX: F nhặt bùa; đứng cạnh checkpoint, Tab → Bùa để đeo/tháo; ô đỏ gây 1 sát thương.")


func _on_target_hurt(_info: DamageInfo, amount: int, target: String) -> void:
	print("CHARM_HIT target=%s damage=%d time_ms=%d" % [target, amount, Time.get_ticks_msec()])
