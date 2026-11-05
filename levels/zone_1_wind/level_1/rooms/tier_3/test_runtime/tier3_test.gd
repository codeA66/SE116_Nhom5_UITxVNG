extends ZoneRoot
## Tiến trình bàn tế, camera, chuối phần thưởng và hiển thị khu boss của scene thử Tier 3.

const CARRY := preload("res://components/core/interaction/carry/carry_component.gd")
const SWORD := preload("res://resources/combat/weapons/sword.tres")

@export var overview_camera: Camera3D
@export var offering_pedestals: Array[OfferingPedestal] = []
@export var boss_gate: StoneGate
@export var boss_veil: Node3D
@export var boss_decoration: Node3D
@export var room_cutaways: Array[RoomCutaway] = []
@export var standalone_test: bool = true
@export var main_hud_position: Vector2 = Vector2(24,245)
@export var main_hud_line_gap: float = 28.0

var _player: Player
var _player_camera: Camera3D
var _overview: bool = false

@onready var _counter: Label = $TestSetup/Interface/Counter
@onready var _carry_hint: Label = $TestSetup/Interface/CarryHint

func _enter_tree() -> void:
	var ancestor: Node = get_parent()
	while ancestor != null:
		if ancestor is ZoneRoot:
			standalone_test = false
			break
		ancestor = ancestor.get_parent()

func _ready() -> void:
	if standalone_test:
		player_spawned.connect(_configure_player)
		GameState.set_weapon(SWORD)
		GameState.add_weapon(preload("res://resources/combat/weapons/bow.tres"))
		GameState.unlock_ability(preload("res://abilities/wind_blast/wind_blast.tres"))
	else:
		var zone: Node = get_parent()
		while zone != null and not zone is ZoneRoot: zone = zone.get_parent()
		if zone is ZoneRoot:
			(zone as ZoneRoot).player_spawned.connect(_configure_player)
			(zone as ZoneRoot).combat_ready.connect(_parent_combat_ready,CONNECT_ONE_SHOT)
		$TestSetup/Lighting.queue_free()
		$TestSetup/SafetyNet.queue_free()
		$TestSetup/Interface/PreviewHint.queue_free()
		_counter.position = main_hud_position
		_carry_hint.position = main_hud_position+Vector2(0,main_hud_line_gap)
	for pedestal: OfferingPedestal in offering_pedestals:
		pedestal.activated.connect(_update_counter)
	boss_gate.opened.connect(_reveal_boss_room)
	boss_gate.unlock_started.connect(_begin_reveal)
	boss_veil.show()
	boss_decoration.show()
	if standalone_test: await super._ready()
	_player_camera = get_viewport().get_camera_3d()
	_update_counter()

func _parent_combat_ready() -> void:
	_combat_ready = true; combat_ready.emit()


func _configure_player(player: Player) -> void:
	_player = player
	var carry: CarryComponent = player.get_node_or_null("CarryComponent") as CarryComponent
	if carry == null:
		carry = CarryComponent.new(); carry.name = "CarryComponent"; player.add_child(carry)
	(carry as CarryComponent).holding_changed.connect(_holding_changed)
	var compass: OfferingCompass = OfferingCompass.new(); compass.name = "OfferingCompass"
	for banana: Node in $Bananas.get_children():
		if banana is OfferingBanana: compass.targets.append(banana)
	player.add_child(compass)
	var inventory: BananaInventory = BananaInventory.ensure(player)
	var toast: PlayerActionToast = PlayerActionToast.new(); toast.name = "PlayerActionToast"; toast.cooldown = inventory.settings.toast_cooldown; player.add_child(toast)
	_player_camera = get_viewport().get_camera_3d()


func _input(event: InputEvent) -> void:
	if not standalone_test: return
	if not event is InputEventKey or not event.is_pressed() or event.is_echo():
		return
	if (event as InputEventKey).physical_keycode != KEY_F2 or _player_camera == null:
		return
	_overview = not _overview
	if _overview:
		overview_camera.make_current()
	else:
		_player_camera.make_current()
	_player.set_controls_enabled(not _overview)
	for cutaway: RoomCutaway in room_cutaways:
		cutaway.set_overview(_overview)
	for activity: Node in get_tree().get_nodes_in_group(&"tier3_room_activity"):
		(activity as GardenRoomActivity).set_overview(_overview)
	get_viewport().set_input_as_handled()


func _holding_changed(item: Node3D) -> void:
	_carry_hint.text = "Đang mang chuối — di chuyển tới bục; F để đặt hoặc thả" if item else ""


func _update_counter() -> void:
	var count := 0
	for pedestal: OfferingPedestal in offering_pedestals:
		if pedestal.is_active():
			count += 1
	_counter.text = "Chuối trên bục: %d / %d" % [count, offering_pedestals.size()]


func _reveal_boss_room() -> void:
	boss_veil.hide()
	boss_decoration.show()
	_counter.text = "Đủ 5 chuối — cổng khu thủ lĩnh đã mở"


func _begin_reveal() -> void:
	var materials: Array[ShaderMaterial] = []
	for mesh: MeshInstance3D in boss_veil.find_children("*","MeshInstance3D",true,false):
		var material: ShaderMaterial = mesh.material_override.duplicate() as ShaderMaterial
		mesh.material_override = material; materials.append(material)
	var tween: Tween = create_tween()
	tween.tween_method(_set_veil_opacity.bind(materials),1.0,0.0,boss_gate.open_time*0.8)
	tween.tween_callback(boss_veil.hide)


func _set_veil_opacity(value: float, materials: Array[ShaderMaterial]) -> void:
	for material: ShaderMaterial in materials: material.set_shader_parameter("opacity",value)
