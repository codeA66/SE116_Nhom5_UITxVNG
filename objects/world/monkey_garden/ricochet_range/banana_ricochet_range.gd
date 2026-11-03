class_name BananaRicochetRange
extends Node3D
signal cleared
signal changed(ammo: int, score: int)
const BULLET: PackedScene = preload("res://objects/world/monkey_garden/ricochet_range/projectiles/ricochet_banana.tscn")
const WEAPON: Script = preload("res://objects/world/monkey_garden/ricochet_range/weapon/baka_weapon.gd")
@export var magazine_size: int = 7
@export var experiment_reward_available: bool = true
@export var reward: OfferingBanana
@export var targets: Array[RicochetStar] = []
@export var offering_drop_point: Node3D
@export var gun_drop_point: Node3D
var ammo: int = 7
var score: int = 0
var _pool: ObjectPool
var _weapon: BakaWeapon
var _player: Player
var completed: bool=false
var _reset_label: Label3D
func is_cleared() -> bool: return completed
func begin(_actor: Player) -> void: pass
@onready var _display: Label3D = $Score
@onready var _pickup: InteractableComponent = $GunPickup/InteractableComponent
func _ready() -> void:
	_pool = ObjectPool.new(); _pool.scene = BULLET; _pool.initial_size = 7; add_child(_pool)
	_pickup.interacted.connect(_equip)
	_pickup.availability_check = func(actor: Node3D) -> bool: return actor is Player and _weapon == null
	$Reset/InteractableComponent.interacted.connect(func(_actor: Node3D) -> void: reset_range())
	$RoomBounds.body_entered.connect(_entered)
	$RoomBounds.body_exited.connect(_exited)
	for target: RicochetStar in targets: target.struck.connect(_struck)
	reset_range()
	$Score.hide()
	_reset_label=Label3D.new(); _reset_label.text="RESET"; _reset_label.font_size=42; _reset_label.pixel_size=0.012
	_reset_label.billboard=BaseMaterial3D.BILLBOARD_ENABLED; _reset_label.outline_size=6
	$Reset.add_child(_reset_label); _reset_label.position.y=1.6
	set_process(false); set_physics_process(false)
func _equip(actor: Node3D) -> void:
	if _weapon != null or not actor is Player: return
	_player = actor as Player
	# Cài script trước khi vào cây, tham chiếu arena sẵn cho _ready.
	var node: Node = Node.new(); node.set_script(WEAPON); _weapon = node as BakaWeapon
	_weapon.name = "BakaWeapon"; _weapon.arena = self
	_player.add_child(_weapon)
	_pickup.enabled = false; $GunPickup/Model.hide()
func _entered(body: Node3D) -> void:
	if not completed and body == _player and is_instance_valid(_weapon): _weapon.set_active(true)
func _exited(body: Node3D) -> void:
	if not completed and body == _player and is_instance_valid(_weapon): _weapon.set_active(false)
func fire(at: Vector3, direction: Vector3) -> bool:
	if completed or ammo <= 0: return false
	ammo -= 1
	var bullet: RicochetBanana = _pool.acquire() as RicochetBanana
	if not bullet.finished.is_connected(_pool.release): bullet.finished.connect(_pool.release)
	bullet.launch(at,direction)
	_update_display()
	return true
func reset_range() -> void:
	if completed: return
	ammo = magazine_size; score = 0; _pool.release_all()
	for target: RicochetStar in targets: target.reset_target()
	if reward != null: reward.set_available(experiment_reward_available)
	_update_display()
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
			GardenRewards.loot(get_parent() as Node3D,gun_drop_point.global_position if gun_drop_point else reward.global_position+Vector3.RIGHT*2,true,5)
		get_tree().create_timer(2.2).timeout.connect(func() -> void: cleared.emit())
func _update_display() -> void:
	_display.text = "%d / %d    •    %d / %d" % [score,targets.size(),ammo,magazine_size]
	changed.emit(ammo,score)
