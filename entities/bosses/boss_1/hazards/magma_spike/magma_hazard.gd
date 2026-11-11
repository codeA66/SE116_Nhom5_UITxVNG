class_name MagmaHazard
extends Node3D
## Nhánh đá Magma trồi lên từ sàn theo nhịp shader và gây sát thương/hất tung mục tiêu.

signal finished

const SECTION_COUNT: int = 11

## Bật tùy chọn này để tự do chỉnh tay các CollisionShape3D trong scene (Hitbox/CollisionShape3D...)
## Code sẽ tôn trọng vị trí/kích thước do bạn chỉnh trong editor, không tự động tính toán đè lên.
@export var manual_hitbox: bool = true

@export var collision_padding: float = 0.15
@export var active_start: float = 0.05
@export var active_end: float = 3.0
@export var lifetime: float = 3.2
@export var knock_up: float = 4.0
## Tỉ lệ thu nhỏ hitbox so với model trực quan (0.82 = nhỏ hơn 18% để né đòn công bằng)
@export_range(0.5, 1.0) var hitbox_shrink_ratio: float = 0.82
## Hệ số thu hẹp đỉnh chóp gai (tạo hình nêm lăng trụ tam giác nhọn dần lên đỉnh)
@export_range(0.1, 0.8) var tip_taper_ratio: float = 0.4

var age: float = 0.0
var running: bool = false
var _activated: bool = false
var _attack_data: AttackData

var _sections: Array[CollisionShape3D] = []
var _bounds: Array[AABB] = []
var _births: Array[float] = []
var _deaths: Array[float] = []
var _settled: Array[bool] = []
var _growth_time: float = 0.5

@onready var hitbox: HitboxComponent = $Hitbox
@onready var visual: Node3D = $Visual
@onready var _shape: CollisionShape3D = $Hitbox/CollisionShape3D
@onready var wind_receiver: WindReceiverComponent = get_node_or_null(^"WindReceiver")


func _ready() -> void:
	set_as_top_level(true)
	visual.set(&"manual_clock", true)
	visual.set_process(false)
	hitbox.hit.connect(_on_hit)
	if wind_receiver:
		wind_receiver.pushed.connect(_on_wind_pushed)
	_build_sections()
	pool_released()


func start(attack_data: AttackData, at: Vector3, facing: Vector3) -> void:
	_attack_data = attack_data
	global_position = at
	global_rotation = Vector3(0.0, atan2(facing.x, facing.z), 0.0)
	age = 0.0
	_activated = false
	running = true
	visible = true
	_settled.fill(false)
	for section: CollisionShape3D in _sections:
		section.disabled = true
	if wind_receiver:
		wind_receiver.enabled = true
		wind_receiver.monitorable = true
	visual.call(&"seek", 0.0)
	_update_hitbox()
	set_physics_process(true)


func pool_acquired() -> void:
	visible = true


func pool_released() -> void:
	running = false
	visible = false
	set_physics_process(false)
	if hitbox:
		hitbox.deactivate()
	if wind_receiver:
		wind_receiver.enabled = false
		wind_receiver.monitorable = false
	visual.call(&"seek", -1.0)
	_settled.fill(false)
	for section: CollisionShape3D in _sections:
		section.set_deferred(&"disabled", true)
	_attack_data = null


func cancel() -> void:
	if not running:
		return
	running = false
	if hitbox:
		hitbox.deactivate()
	if wind_receiver:
		wind_receiver.enabled = false
		wind_receiver.monitorable = false
	visible = false
	visual.call(&"seek", -1.0)
	_settled.fill(false)
	for section: CollisionShape3D in _sections:
		section.set_deferred(&"disabled", true)
	set_physics_process(false)
	finished.emit()


func _physics_process(delta: float) -> void:
	if not running:
		return
	age += delta
	visual.call(&"seek", age)
	_update_hitbox()
	
	if age >= active_start and not _activated:
		_activated = true
		hitbox.activate(_attack_data, active_end - active_start)
	
	if age >= active_end and hitbox.is_active():
		hitbox.deactivate()
	
	if age >= lifetime:
		cancel()


func _build_sections() -> void:
	if manual_hitbox:
		_sections.clear()
		for child in hitbox.get_children():
			if child is CollisionShape3D:
				child.disabled = true
				_sections.append(child)
		return
	
	var config: Resource = visual.get(&"style") as Resource
	if config == null:
		return
	_growth_time = maxf(float(config.get(&"growth_time")), 0.001)
	var path_length: float = float(config.get(&"path_length")) * absf(visual.scale.x)
	var shatter_time: float = float(config.get(&"shatter_time"))
	var batches: Dictionary = visual.get(&"batch_data") as Dictionary
	var mesh: ArrayMesh = visual.get(&"crystal_mesh") as ArrayMesh
	var crystal_bounds: AABB = mesh.get_aabb()
	
	_bounds.resize(SECTION_COUNT)
	_births.resize(SECTION_COUNT)
	_deaths.resize(SECTION_COUNT)
	_settled.resize(SECTION_COUNT)
	_settled.fill(false)
	
	var populated: Array[bool] = []
	populated.resize(SECTION_COUNT)
	populated.fill(false)
	_births.fill(INF)
	
	for layer: String in ["CrystalCore", "SecondaryShards"]:
		if not batches.has(layer):
			continue
		var instances: Array = batches[layer]
		for entry: Dictionary in instances:
			var u: float = (entry["data"] as Color).b
			var index: int = clampi(roundi(u * (SECTION_COUNT - 1)), 0, SECTION_COUNT - 1)
			var transform_value: Transform3D = visual.transform * (entry["transform"] as Transform3D)
			var box: AABB = transform_value * crystal_bounds
			_bounds[index] = _bounds[index].merge(box) if populated[index] else box
			populated[index] = true
			_births[index] = minf(_births[index], u * _growth_time)
			_deaths[index] = maxf(_deaths[index], shatter_time + u * 0.12 + 0.16)
	
	for index: int in SECTION_COUNT:
		if not populated[index]:
			continue
		var box: AABB = _bounds[index].grow(maxf(collision_padding, 0.0))
		var near_z: float = minf(box.position.z, maxf(0.0, (float(index) - 0.5) / (SECTION_COUNT - 1) * path_length))
		var far_z: float = maxf(box.end.z, (float(index) + 0.5) / (SECTION_COUNT - 1) * path_length)
		box = AABB(Vector3(box.position.x, 0.0, near_z), Vector3(box.size.x, maxf(box.end.y, 0.2), far_z - near_z))
		_bounds[index] = box
		var section: CollisionShape3D = _shape if index == 0 else CollisionShape3D.new()
		var poly := ConvexPolygonShape3D.new()
		section.shape = poly
		section.disabled = true
		if index > 0:
			hitbox.add_child(section)
		_sections.append(section)
	
	active_end = _deaths.max()


func _update_hitbox() -> void:
	if manual_hitbox:
		var should_enable: bool = (age >= active_start and age < active_end)
		for section: CollisionShape3D in _sections:
			if section.disabled == should_enable:
				section.disabled = not should_enable
		return
	
	for index: int in _sections.size():
		var section: CollisionShape3D = _sections[index]
		if age >= _deaths[index] or age <= _births[index]:
			if not section.disabled:
				section.disabled = true
			continue
		if _settled[index]:
			continue
		var growth: float = smoothstep(_births[index], _births[index] + 0.15, age)
		section.disabled = growth <= 0.02 or age >= _deaths[index]
		if section.disabled:
			continue
		var box: AABB = _bounds[index]
		var current_growth := growth
		
		# Kích thước co gọn theo hitbox_shrink_ratio (nhỏ hơn model ~18%) và lớn dần theo growth
		var half_w: float = maxf((box.size.x * hitbox_shrink_ratio * 0.5) * pow(current_growth, 0.6), 0.05)
		var half_d: float = maxf((box.size.z * hitbox_shrink_ratio * 0.5) * pow(current_growth, 0.6), 0.05)
		var height: float = maxf((box.size.y * hitbox_shrink_ratio) * current_growth, 0.05)
		var center_x: float = box.get_center().x
		var center_z: float = box.get_center().z
		
		var taper: float = tip_taper_ratio
		
		# 6 đỉnh lăng trụ đứng đáy tam giác (nêm chóp gai):
		# Đáy sàn (y = 0): tam giác hướng mũi nhọn về phía trước +Z
		# Đáy trên (y = height): tam giác thu nhỏ nhọn hơn nữa về phía đỉnh
		var points := PackedVector3Array([
			# Đáy sàn (y = 0)
			Vector3(-half_w, 0.0, -half_d),
			Vector3( half_w, 0.0, -half_d),
			Vector3(    0.0, 0.0,  half_d),
			# Đáy trên (y = height)
			Vector3(-half_w * taper, height, -half_d * taper),
			Vector3( half_w * taper, height, -half_d * taper),
			Vector3(            0.0, height,  half_d * taper),
		])
		
		var poly := section.shape as ConvexPolygonShape3D
		if poly:
			poly.points = points
		section.position = Vector3(center_x, 0.0, center_z)
		_settled[index] = is_equal_approx(growth, 1.0)


func _on_hit(hurtbox: HurtboxComponent) -> void:
	if knock_up <= 0.0:
		return
	if hurtbox.is_invincible():
		return
	var body: CharacterBody3D = hurtbox.owner as CharacterBody3D
	if body != null:
		body.velocity.y = maxf(body.velocity.y, knock_up)


func _on_wind_pushed(_impulse: Vector3) -> void:
	if not running:
		return
	var spark_pos := wind_receiver.global_position if wind_receiver else (global_position + Vector3(0.0, 1.0, 2.0))
	var combat_fx: Node = get_node_or_null(^"/root/CombatFx")
	if combat_fx and combat_fx.has_method(&"play_hit_spark"):
		combat_fx.play_hit_spark(spark_pos, -global_basis.z)
	cancel()
