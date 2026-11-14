class_name BananaRicochetRange
extends Node3D
signal cleared
signal changed(ammo: int, score: int)
const BULLET: PackedScene = preload("res://objects/world/monkey_garden/ricochet_range/projectiles/ricochet_banana.tscn")
const WEAPON: Script = preload("res://objects/world/monkey_garden/ricochet_range/weapon/baka_weapon.gd")
const INTRO := preload("res://objects/world/monkey_garden/ricochet_range/weapon/range_monkey_intro.gd")
@export var magazine_size: int = 10
@export var experiment_reward_available: bool = true
@export var reward: OfferingBanana
@export var targets: Array[RicochetStar] = []
@export var offering_drop_point: Node3D
@export_range(0.0, 3.0, 0.1) var automatic_reset_delay: float = 0.7
var ammo: int = 10
var score: int = 0
var _pool: ObjectPool
var _weapon: BakaWeapon
var _player: Player
var completed: bool=false
var _reset_label: Label3D
var _automatic_reset: Timer
var _intro: INTRO
var _gun_available := false
var _gun_beam: LootItemBeam
var _gun_hold_basis: Basis
func is_cleared() -> bool: return completed
func begin(actor: Player) -> void:
	if is_instance_valid(_intro):
		_intro.begin.call_deferred(actor)
@onready var _pickup: InteractableComponent = $GunPickup/InteractableComponent
func _ready() -> void:
	_pool = ObjectPool.new(); _pool.scene = BULLET; _pool.initial_size = magazine_size; add_child(_pool)
	_automatic_reset = Timer.new(); _automatic_reset.one_shot = true
	_automatic_reset.timeout.connect(reset_range); add_child(_automatic_reset)
	_pickup.interacted.connect(_equip)
	_pickup.availability_check = func(actor: Node3D) -> bool: return actor is Player and _weapon == null and _gun_available
	$Reset/InteractableComponent.interacted.connect(func(_actor: Node3D) -> void: reset_range())
	$RoomBounds.body_entered.connect(_entered)
	$RoomBounds.body_exited.connect(_exited)
	for target: RicochetStar in targets: target.struck.connect(_struck)
	var model: Node3D = $GunPickup/Model
	model.position = Vector3.ZERO
	GardenRewards.fit(model)
	_gun_hold_basis = model.basis
	_gun_beam = LootItemBeam.attach_to($GunPickup, Color("ffd447"))
	$GunPickup.hide()
	_pickup.enabled = false
	_intro = INTRO.new()
	_intro.position = Vector3(0, 0, 6.85)
	add_child(_intro)
	_intro.gun_dropped.connect(_drop_gun)
	_intro.setup(model)
	reset_range()
	_reset_label=Label3D.new(); _reset_label.text="RESET"; _reset_label.font_size=42; _reset_label.pixel_size=0.012
	_reset_label.billboard=BaseMaterial3D.BILLBOARD_ENABLED; _reset_label.outline_size=6
	$Reset.add_child(_reset_label); _reset_label.position.y=1.6
	set_process(false); set_physics_process(false)
func _drop_gun(at: Vector3) -> void:
	$GunPickup.global_position = at
	var model: Node3D = $GunPickup/Model
	model.basis = Basis(Vector3.UP, PI * 0.22) * Basis(Vector3.BACK, -PI * 0.5) * _gun_hold_basis
	model.position = Vector3.ZERO
	var bounds := GardenRewards._bounds(model, Transform3D.IDENTITY)
	model.position = Vector3(-bounds.get_center().x, 0.22 - bounds.position.y, -bounds.get_center().z)
	$GunPickup.reset_physics_interpolation()
	$GunPickup.show()
	_gun_beam.set_active(true)
	_gun_available = true
	_pickup.enabled = true

func make_held_gun() -> Node3D:
	var model := $GunPickup/Model.duplicate(0) as Node3D
	model.basis = _gun_hold_basis
	return model

func _equip(actor: Node3D) -> void:
	if not _gun_available or _weapon != null or not actor is Player: return
	_player = actor as Player
	# Cài script trước khi vào cây, tham chiếu arena sẵn cho _ready.
	var node: Node = Node.new(); node.set_script(WEAPON); _weapon = node as BakaWeapon
	_weapon.name = "BakaWeapon"; _weapon.arena = self
	_player.add_child(_weapon)
	_pickup.enabled = false
	$GunPickup.hide()
	_gun_beam.set_active(false)
func _entered(body: Node3D) -> void:
	if not completed and body == _player and is_instance_valid(_weapon): _weapon.set_active(true)
func _exited(body: Node3D) -> void:
	if not completed and body == _player and is_instance_valid(_weapon): _weapon.set_active(false)
func fire(at: Vector3, direction: Vector3) -> bool:
	if completed or ammo <= 0: return false
	ammo -= 1
	var bullet: RicochetBanana = _pool.acquire() as RicochetBanana
	if not bullet.finished.is_connected(_bullet_finished): bullet.finished.connect(_bullet_finished)
	bullet.launch(at,direction)
	_update_display()
	return true
func reset_range() -> void:
	if completed: return
	_automatic_reset.stop()
	ammo = magazine_size; score = 0; _pool.release_all()
	for target: RicochetStar in targets: target.reset_target()
	if reward != null: reward.set_available(experiment_reward_available)
	_update_display()
func _bullet_finished(bullet: RicochetBanana) -> void:
	_pool.release(bullet)
	# Chờ viên cuối cùng bay/nảy xong, để phát bắn đạt điểm thứ năm vẫn được tính.
	if not completed and ammo == 0 and _pool.get_active_count() == 0:
		_automatic_reset.start(maxf(automatic_reset_delay,0.01))
func _struck(_target: RicochetStar) -> void:
	score += 1
	_update_display()
	if score == targets.size():
		completed=true
		_reset_label.hide()
		if _weapon: _weapon.finish()
		if reward != null:
			if offering_drop_point: reward.global_position=offering_drop_point.global_position
			GardenRewards.offering(reward)
		get_tree().create_timer(2.2).timeout.connect(func() -> void: cleared.emit())
func _update_display() -> void:
	changed.emit(ammo,score)
