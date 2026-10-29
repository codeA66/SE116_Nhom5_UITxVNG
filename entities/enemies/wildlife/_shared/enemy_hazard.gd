class_name EnemyHazard
extends Node3D
## Hiệu ứng và hitbox dùng chung đồng hồ; vị trí thế giới cố định sau khi triệu hồi.
signal finished

@export var active_start: float = 1.0
@export var active_end: float = 1.4
@export var lifetime: float = 3.2
@export var knock_up: float = 0.0
@export var follow_duration: float = 0.0
var follow_target: Node3D
var age: float = 0.0
var running: bool = false
var _activated: bool = false
var _skill: EnemySkillData
@onready var hitbox: HitboxComponent = $Hitbox
@onready var visual: Node3D = $Visual
# Lớp con (IceHazard) dùng _shape; Godot chỉ xét trong lớp này nên báo "không dùng"
@warning_ignore("unused_private_class_variable")
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
	_update_hitbox()
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
	follow_target = null

func cancel() -> void:
	if not running: return
	running = false
	hitbox.deactivate()
	finished.emit()

func _physics_process(delta: float) -> void:
	if not running: return
	age += delta
	if age <= follow_duration and is_instance_valid(follow_target):
		global_position.x = follow_target.global_position.x
		global_position.z = follow_target.global_position.z
	visual.call(&"seek", age)
	_update_hitbox()
	if age >= active_start and not _activated:
		_activated = true
		hitbox.activate(_skill, active_end - active_start)
	if age >= active_end and hitbox.is_active(): hitbox.deactivate()
	if age >= lifetime: cancel()

func _update_hitbox() -> void:
	pass

func _on_hit(hurtbox: HurtboxComponent) -> void:
	if knock_up <= 0.0: return
	var body: CharacterBody3D = hurtbox.owner as CharacterBody3D
	if body != null: body.velocity.y = maxf(body.velocity.y, knock_up)
