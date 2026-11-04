class_name RealBakaWeapon
extends Node
var ammo: int = 0
var equipped: bool = false
var _cooldown: float = 0
var _player: Player
var _model: Node3D
var _hold: BananaGunHold
var _card: BananaWeaponCard
var _sword: Node3D
var _socket: Node3D

func _ready() -> void:
	_player = get_parent() as Player
	_sword = _player.model.find_child("Sword",true,false) as Node3D
	_socket = _player.get_node_or_null("WeaponSocket") as Node3D
	_model = GardenRewards.REAL_MODEL.instantiate(); GardenRewards.fit(_model)
	_hold = BananaGunHold.new(); _player.model.add_child(_hold); _hold.configure(_player,_model); _hold.set_held(false)
	var hud: CanvasLayer = CanvasLayer.new(); hud.layer = 20; add_child(hud)
	_card = BananaWeaponCard.new(); hud.add_child(_card); _refresh()
	GameState.weapon_changed.connect(_weapon_changed)
	_player.state_machine.state_changed.connect(_state_changed)

func add_ammo(amount: int) -> void:
	ammo += amount; _refresh()

func set_equipped(value: bool) -> void:
	if equipped == value: return
	equipped = value; _hold.set_held(value); _player.set_combat_locked(self,value)
	if is_instance_valid(_socket): _socket.visible = not value
	if is_instance_valid(_sword):
		_sword.visible = not value and _player.get_weapon() != null and _player.get_weapon().slot == WeaponData.Slot.SWORD
	_refresh()

func _refresh() -> void:
	if _card: _card.refresh(ammo,equipped)

func _weapon_changed(_weapon: WeaponData) -> void:
	if equipped: set_equipped(false)

func _state_changed(_from: StringName, to: StringName) -> void:
	if to == PlayerState.DEAD: set_equipped(false)

func _input(event: InputEvent) -> void:
	if not _player.controls_enabled or _player.health.is_dead() or event.is_echo(): return
	if event is InputEventKey and event.is_pressed() and (event as InputEventKey).physical_keycode == KEY_V:
		set_equipped(not equipped); get_viewport().set_input_as_handled(); return
	if not equipped: return
	if event.is_action_pressed("weapon_1") or event.is_action_pressed("skill"):
		set_equipped(false); GameState.select_weapon(WeaponData.Slot.SWORD); return
	if event.is_action_pressed("weapon_2") and _player.get_bow() != null:
		set_equipped(false); GameState.select_weapon(WeaponData.Slot.BOW); return
	if event.is_action_pressed("aim") and _player.get_bow() != null:
		set_equipped(false); return
	if not event.is_action_pressed("attack"): return
	var carry: CarryComponent = _player.get_node_or_null("CarryComponent") as CarryComponent
	if carry and carry.held_item:
		PlayerActionToast.show_for(_player,"Không dùng được, đang mang chuối thần!"); return
	if ammo <= 0:
		PlayerActionToast.show_for(_player,"Hết đạn chuối nổ!"); return
	if _cooldown > 0: return
	ammo -= 1; _cooldown = 1; _refresh()
	var toward: Vector3 = _player.get_mouse_aim_direction()
	if toward.is_zero_approx(): toward = _player.get_facing_direction()
	_player.face_instantly(toward)
	var bullet: ExplosiveBanana = ExplosiveBanana.new(); _player.get_parent().add_child(bullet)
	bullet.launch(_hold.muzzle.global_position,toward,_player)
	get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown-delta,0)
	if equipped and _player.controls_enabled:
		_player.face_direction(_player.get_mouse_aim_direction(),delta)
