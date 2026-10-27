class_name EnemyHazard
extends Node3D
## Hiệu ứng và hitbox dùng chung đồng hồ; vị trí thế giới cố định sau khi triệu hồi.
signal finished

@export var active_start: float = 1.0
@export var active_end: float = 1.4
@export var lifetime: float = 3.2
@export var growing_ice: bool = false
@export var ice_length: float = 4.9
@export var ice_growth_time: float = 1.0
@export var knock_up: float = 0.0
var age: float = 0.0
var running: bool = false
var _activated: bool = false
var _skill: EnemySkillData
@onready var hitbox: HitboxComponent = $Hitbox
@onready var visual: Node3D = $Visual
@onready var _shape: CollisionShape3D = $Hitbox/CollisionShape3D

func _ready() -> void:
	set_as_top_level(true)
	visual.set(&"manual_clock", true)
	visual.set_process(false)
	hitbox.hit.connect(_on_hit)
	pool_released()

func start(skill: EnemySkillData, at: Vector3, facing: Vector3) -> void:
	_skill = skill
	global_position = at
	global_rotation = Vector3(0.0, atan2(facing.x, facing.z), 0.0)
	age = 0.0
	_activated = false
	running = true
	visible = true
	visual.call(&"seek", 0.0)
	set_physics_process(true)

func pool_acquired() -> void:
	visible = true

func pool_released() -> void:
	running = false
	visible = false
	set_physics_process(false)
	hitbox.deactivate()
	visual.call(&"seek", -1.0)
	_skill = null

func cancel() -> void:
	if not running: return
	running = false
	hitbox.deactivate()
	finished.emit()

func _physics_process(delta: float) -> void:
	if not running: return
	age += delta
	visual.call(&"seek", age)
	if growing_ice:
		var box: BoxShape3D = _shape.shape as BoxShape3D
		var depth: float = maxf(0.1, ice_length * clampf(age / ice_growth_time, 0.0, 1.0))
		box.size.z = depth
		_shape.position.z = depth * 0.5
	if age >= active_start and not _activated:
		_activated = true
		hitbox.activate(_skill, active_end - active_start)
	if age >= active_end and hitbox.is_active(): hitbox.deactivate()
	if age >= lifetime: cancel()

func _on_hit(hurtbox: HurtboxComponent) -> void:
	if knock_up <= 0.0: return
	var body: CharacterBody3D = hurtbox.owner as CharacterBody3D
	if body != null: body.velocity.y = maxf(body.velocity.y, knock_up)
