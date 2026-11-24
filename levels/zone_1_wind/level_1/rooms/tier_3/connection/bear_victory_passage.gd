class_name BearVictoryPassage
extends Node3D
## Theo cờ thắng trận để cửa hoạt động cả khi gấu đã được gỡ khỏi cây.

signal collapse_started
signal impacted
signal passage_opened

@export_group("References")
@export var required_flag: StringName = &"level_1.enc_bear_miniboss"
@export var leaves: Array[Node3D] = []
@export var collision: CollisionShape3D
@export var cinematic: CameraCutscene
@export var dust: CPUParticles3D
@export var motes: CPUParticles3D
@export var wisps: CPUParticles3D
@export var backlight: MeshInstance3D

@export_group("Collapse")
@export_range(0.0, 3.0, 0.05) var anticipation: float = 0.8
@export_range(0.0, 5.0, 0.05) var open_duration: float = 1.0
@export_range(0.0, 1.0, 0.01) var shake_distance: float = 0.1
@export_range(0.0, 1.0, 0.01) var anticipation_trauma: float = 0.34
@export_range(0.0, 5.0, 0.05) var debris_hold: float = 0.25
@export_range(0.0, 5.0, 0.05) var debris_fade: float = 0.4
@export_range(0.0, 1.0, 0.01) var impact_trauma: float = 0.45

@export_group("Motion")
@export var shake_frequency: float = 24.0
@export var shake_depth_ratio: float = 0.5
@export var shake_twist: float = 0.025
@export var lift_height: float = 0.28
@export var separation: float = 0.14

var opened: bool = false
var _opening: bool = false
var _elapsed: float = 0.0
var _rest: Array[Vector3] = []
var _materials: Array[ShaderMaterial] = []


func _ready() -> void:
	set_process(false)
	var copies: Dictionary[ShaderMaterial, ShaderMaterial] = {}
	for leaf: Node3D in leaves:
		_rest.append(leaf.position)
		var mesh: MeshInstance3D = leaf as MeshInstance3D
		var material: ShaderMaterial = mesh.material_override as ShaderMaterial
		if material:
			# Mỗi cửa giữ ba material riêng để tiến trình tan rã không lan sang cửa khác.
			if not copies.has(material):
				copies[material] = material.duplicate() as ShaderMaterial
				_materials.append(copies[material])
			mesh.material_override = copies[material]
			copies[material].set_shader_parameter(&"wall_origin", global_position)
			if collision.shape is BoxShape3D:
				copies[material].set_shader_parameter(&"wall_height", (collision.shape as BoxShape3D).size.y * global_basis.y.length())
	if backlight:
		backlight.material_override = backlight.material_override.duplicate()
	_set_dissolve(0.0)
	_set_charge(0.0)
	if cinematic:
		cinematic.shot_reached.connect(_collapse)
	if GameState.has_flag(required_flag):
		_finish()
	else:
		GameState.progress_changed.connect(_check)


func _process(delta: float) -> void:
	_elapsed += delta
	var ramp: float = clampf(_elapsed / maxf(anticipation, 0.001), 0.0, 1.0)
	var offset: float = sin(_elapsed * TAU * shake_frequency) * shake_distance * ramp
	_set_charge(ramp)
	# Bù phần rung đã giảm theo thời gian để báo trước tăng dần tới đúng mức đặt.
	var desired_trauma: float = anticipation_trauma * ramp * ScreenShake.strength
	if desired_trauma > ScreenShake.trauma:
		ScreenShake.add_trauma((desired_trauma - ScreenShake.trauma) / maxf(ScreenShake.strength, 0.001))
	for index: int in leaves.size():
		var phase: float = sin(_elapsed * TAU * shake_frequency + float(index))
		leaves[index].position = _rest[index] + Vector3(offset, phase * shake_distance * ramp, -offset * shake_depth_ratio)
		leaves[index].rotation.z = phase * shake_twist * ramp
	if _elapsed >= anticipation:
		set_process(false)
		_disintegrate()


func _check() -> void:
	if _opening or opened or not GameState.has_flag(required_flag):
		return
	_opening = true
	GameState.progress_changed.disconnect(_check)
	var rig: CameraRig = get_tree().get_first_node_in_group(CameraRig.GROUP) as CameraRig
	var player: Player = rig.get_parent() as Player if rig else null
	if cinematic and player:
		cinematic.hold_indefinitely = true
		cinematic.play_for(player)
	else:
		_collapse()


func _collapse() -> void:
	if opened or is_processing():
		return
	collapse_started.emit()
	_elapsed = 0.0
	set_process(true)


func _disintegrate() -> void:
	var duration: float = maxf(open_duration, 0.001)
	var dissolve: Tween = create_tween().set_parallel()
	for index: int in leaves.size():
		leaves[index].position = _rest[index]
		var target: Vector3 = _rest[index] + Vector3(signf(_rest[index].x) * separation, lift_height, separation)
		dissolve.tween_property(leaves[index], "position", target, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		dissolve.tween_property(leaves[index], "rotation:z", 0.0, duration)
	if motes:
		motes.restart()
		motes.emitting = true
	if wisps:
		wisps.restart()
		wisps.emitting = true
	dissolve.tween_method(_set_dissolve, 0.0, 1.0, duration)
	dissolve.chain().tween_callback(_impact)


func _set_dissolve(value: float) -> void:
	for material: ShaderMaterial in _materials:
		material.set_shader_parameter(&"progress", value)
	if backlight:
		(backlight.material_override as ShaderMaterial).set_shader_parameter(&"progress", value)


func _set_charge(value: float) -> void:
	for material: ShaderMaterial in _materials:
		material.set_shader_parameter(&"charge", value)
	if backlight:
		(backlight.material_override as ShaderMaterial).set_shader_parameter(&"charge", value)


func _impact() -> void:
	collision.set_deferred(&"disabled", true)
	opened = true
	for leaf: Node3D in leaves:
		leaf.hide()
	if backlight:
		backlight.hide()
	if dust:
		dust.restart()
		dust.emitting = true
	ScreenShake.add_trauma(impact_trauma)
	impacted.emit()
	passage_opened.emit()
	var cleanup: Tween = create_tween()
	cleanup.tween_interval(maxf(debris_hold + debris_fade, 0.001))
	cleanup.tween_callback(_finish)


func _finish() -> void:
	opened = true
	_set_dissolve(1.0)
	if backlight:
		backlight.hide()
	set_process(false)
	collision.set_deferred(&"disabled", true)
	for leaf: Node3D in leaves:
		leaf.hide()
	if cinematic and cinematic.is_processing():
		cinematic.release_hold()
