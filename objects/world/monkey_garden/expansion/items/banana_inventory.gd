class_name BananaInventory
extends Node
@export var settings: BananaItemSettings = preload("res://resources/world/monkey_garden/banana_item_settings.tres")
var has_boots: bool = false
var has_healing: bool = false
var healing_uses: int = 0
var reserved_ammo: int = 0
var popup: ItemDiscoveryPopup
var _player: Player
var _boost_left: float = 0.0
var _base_speed: float
var _trail: CPUParticles3D
var _card: BananaHealingCard

static func ensure(player: Player) -> BananaInventory:
	var inventory: BananaInventory = player.get_node_or_null("BananaInventory") as BananaInventory
	if inventory == null:
		inventory = BananaInventory.new(); inventory.name = "BananaInventory"; player.add_child(inventory)
	return inventory

func _ready() -> void:
	_player = get_parent() as Player
	_player.movement = _player.movement.duplicate(true) as MovementStats
	_base_speed = _player.movement.max_speed
	_trail = BananaItemEffects.particles(true); _player.add_child(_trail); _trail.position.y = 0.08
	popup = ItemDiscoveryPopup.new(); add_child(popup)
	var layer: CanvasLayer = CanvasLayer.new(); layer.layer = 20; add_child(layer)
	_card = BananaHealingCard.new(); layer.add_child(_card); _card.refresh(0,settings.healing_uses)
	set_physics_process(false)

func grant(kind: StringName) -> void:
	if kind == &"boots" and not has_boots:
		has_boots = true; _attach_boots()
	elif kind == &"healing":
		has_healing = true; refill_healing(); _card.show()
	popup.present.call_deferred(_player,kind)

func announce(kind: StringName) -> void:
	if kind == &"ammo":
		if GameState.has_flag(&"tier3.ammo_instruction_seen"): return
		GameState.set_flag(&"tier3.ammo_instruction_seen")
	popup.present.call_deferred(_player,kind)

func refill_healing() -> void:
	if not has_healing: return
	healing_uses = settings.healing_uses; _card.refresh(healing_uses,settings.healing_uses)

func step_on_peel() -> bool:
	if not has_boots or not _player.is_on_floor() or _player.health.is_dead(): return false
	if _boost_left <= 0: _base_speed = _player.movement.max_speed
	_boost_left = settings.boost_duration; _player.movement.max_speed = _base_speed*settings.boost_multiplier
	_trail.emitting = true; set_physics_process(true); return true

func _physics_process(delta: float) -> void:
	_boost_left = maxf(_boost_left-delta,0)
	if _boost_left <= 0:
		_player.movement.max_speed = _base_speed; _trail.emitting = false; set_physics_process(false)

func _input(event: InputEvent) -> void:
	if not _player.controls_enabled or event.is_echo() or not event.is_action_pressed("banana_heal"): return
	if not has_healing or healing_uses <= 0 or _player.health.is_dead() or _player.health.current_health >= _player.health.max_health: return
	healing_uses -= 1; _player.health.set_current_health(_player.health.current_health+settings.healing_amount)
	_card.refresh(healing_uses,settings.healing_uses); BananaItemEffects.heal(_player); get_viewport().set_input_as_handled()

func _attach_boots() -> void:
	var skeleton: Skeleton3D = _player.model.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
	for bone_name: String in ["foot.L","foot.R"]:
		var index: int = skeleton.find_bone(bone_name)
		if index < 0: continue
		var attachment: BoneAttachment3D = BoneAttachment3D.new(); attachment.bone_name = bone_name; skeleton.add_child(attachment)
		var shoe: Node3D = BananaItemModels.shoe(); attachment.add_child(shoe)
		var basis: Basis = skeleton.get_bone_global_rest(index).basis.orthonormalized().inverse()
		shoe.transform = Transform3D(basis,basis*Vector3(0,-0.03,0.08)); shoe.name = "BananaBoot"
