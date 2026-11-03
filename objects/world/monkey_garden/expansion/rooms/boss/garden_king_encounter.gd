class_name GardenKingEncounter
extends Area3D
signal cleared
@export var guards: Array[Enemy] = []
@export var encounter_flag: StringName = &"level_1.monkey_king_defeated"
@export_multiline var instructions: String = "Hãy dùng tất cả những gì bạn có để chiến đấu và tiêu diệt Vua Khỉ cùng thuộc hạ của hắn!"
var started: bool = false
var _alive: int = 0
var _player: Player

func _ready() -> void:
	_setup.call_deferred()
	body_entered.connect(_entered)

func _setup() -> void:
	for guard: Enemy in guards:
		guard.set_dormant(true); guard.process_mode = Node.PROCESS_MODE_DISABLED
		guard.died.connect(_died); _alive += 1

func _entered(body: Node3D) -> void:
	if started or not body is Player: return
	started = true; _player = body as Player; set_deferred("monitoring",false)
	var popup: ItemDiscoveryPopup = BananaInventory.ensure(_player).popup
	popup.dismissed.connect(_fight,CONNECT_ONE_SHOT)
	popup.present_text.call_deferred(_player,"VUA KHỈ",instructions)

func _fight() -> void:
	for guard: Enemy in guards:
		if is_instance_valid(guard) and not guard.is_dead():
			guard.process_mode = Node.PROCESS_MODE_INHERIT
			guard.set_dormant(false)
			if guard is WildEnemy: (guard as WildEnemy).receive_rally(_player)
			else: guard.target = _player

func _died(_enemy: Enemy) -> void:
	_alive -= 1
	if _alive<=0:
		GameState.set_flag(encounter_flag); cleared.emit()
