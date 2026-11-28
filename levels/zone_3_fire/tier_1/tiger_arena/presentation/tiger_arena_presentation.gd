extends Node3D
## Dàn cảnh cho Hổ Lửa cùng các tín hiệu của trận để nhịp mở màn không tách khỏi luồng chơi.

const HEAT_SHADER: Shader = preload("res://levels/zone_3_fire/tier_1/tiger_arena/presentation/tiger_arena_heat.gdshader")
const MAGMA_SHADER: Shader = preload("res://levels/zone_3_fire/tier_1/tiger_arena/presentation/tiger_arena_magma.gdshader")
const DUST_TEXTURE: Texture2D = preload("res://assets/vfx/shared/charms/charm_ultimate/shot/residue/skystrike_dust.png")
const BRAZIER_POINTS: Array[Vector3] = [
	Vector3(-11.8, 2.36, 11.9), Vector3(11.8, 2.36, 11.9),
	Vector3(-11.8, 2.36, -11.9), Vector3(11.8, 2.36, -11.9),
]

@export_group("Intro")
@export var cage_wait_position: Vector3 = Vector3(0.0, 0.32, -16.3)
@export var cage_mouth_position: Vector3 = Vector3(0.0, 2.6, -13.2)
@export_range(0.2, 2.0, 0.01) var jump_duration: float = 0.77
@export_range(0.0, 4.0, 0.05) var jump_height: float = 1.16
@export_range(0.05, 1.0, 0.01) var flame_spacing: float = 0.28
@export_range(0.1, 2.5, 0.05) var warning_time: float = 0.78
@export var intro_pounce_clip: StringName = &"Leaper"
@export var intro_roar_clip: StringName = &"Roaring"
@export_group("Lighting")
@export_range(0.0, 4.0, 0.05) var idle_flame_power: float = 1.4
@export_range(0.0, 4.0, 0.05) var fight_flame_power: float = 2.1
@export_range(0.0, 4.0, 0.05) var phase_two_flame_power: float = 3.0
@export_range(0.0, 1.0, 0.05) var cage_trauma: float = 0.45
@export var cage_hit_sound: AudioStream
@export var landing_sound: AudioStream

var _tiger: FireSabretooth
var _animator: AnimationPlayer
var _animator_mode: Node.ProcessMode
var _combat_start: Vector3
var _door_left: Node3D
var _door_right: Node3D
var _broken_parts: Array[Node3D] = []
var _left_home: Transform3D
var _right_home: Transform3D
var _flames: Array[Node3D] = []
var _lamps: Array[OmniLight3D] = []
var _rise: Array[CPUParticles3D] = []
var _led: ShaderMaterial
var _impact_sparks: CPUParticles3D
var _impact_dust: CPUParticles3D
var _landing_dust: CPUParticles3D
var _flash: OmniLight3D
var _cage_lamp: OmniLight3D
var _audio: AudioStreamPlayer3D
var _intro_tween: Tween
var _lighting_tween: Tween
var _jump_started: bool = false

@onready var _fight: BossFight = $"../TigerFight"
@onready var _intro: CameraCutscene = $"../TigerIntro"
@onready var _doors: Node3D = $"../Architecture/CageDoor"
@onready var _model: Node3D = $"../Architecture/ArenaModel"


func _ready() -> void:
	_tiger = _fight.boss as FireSabretooth
	_door_left = _doors.find_child("CageLeafLeft", true, false) as Node3D
	_door_right = _doors.find_child("CageLeafRight", true, false) as Node3D
	_broken_parts.assign([_doors.find_child("BrokenIronDoor", true, false), _doors.find_child("BrokenDoorRivets", true, false)])
	_left_home = _door_left.transform
	_right_home = _door_right.transform
	var first_visit: bool = _tiger != null and _intro.is_pending()
	_set_doors_closed(first_visit)
	_build_vfx()
	_fight.started.connect(_on_fight_started)
	_fight.defeated.connect(_on_defeated)
	_intro.started.connect(_on_intro_started)
	_intro.shot_reached.connect(_on_shot_reached)
	_intro.finished.connect(_on_intro_finished)
	if first_visit:
		_combat_start = _tiger.position
		_tiger.position = cage_wait_position - _fight.position
		_tiger.reset_physics_interpolation()
		_tiger.face_instantly(Vector3.BACK)
	else:
		for index: int in _flames.size():
			_set_brazier(idle_flame_power, index)


func _on_intro_started() -> void:
	_lighting_tween = create_tween().set_parallel(true)
	for index: int in _flames.size():
		var delay: float = index * flame_spacing
		_lighting_tween.tween_method(_swell_flame.bind(index), 0.0, 1.0, 0.64).set_delay(delay)
	_lighting_tween.tween_method(_set_led, 0.13, 1.1, 1.05)
	_lighting_tween.tween_property(_cage_lamp, ^"light_energy", 2.6, 0.94).set_delay(0.35)


func _on_shot_reached() -> void:
	if not is_instance_valid(_tiger):
		return
	_animator = _tiger.animation_player()
	_animator_mode = _animator.process_mode
	# Cho rig chạy riêng để hitbox và các state săn vẫn ngủ trước khi trả điều khiển.
	_animator.process_mode = Node.PROCESS_MODE_ALWAYS
	_tiger.motion.play(intro_roar_clip, 0.11)
	_intro_tween = create_tween()
	_intro_tween.tween_method(_rattle, 0.0, 1.0, warning_time)
	_intro_tween.tween_callback(_begin_jump)
	_intro_tween.tween_method(_move_tiger, 0.0, 1.0, jump_duration)
	_intro_tween.tween_callback(_land)


func _on_intro_finished() -> void:
	if _intro_tween and _intro_tween.is_running():
		_intro_tween.kill()
	if is_instance_valid(_animator):
		_animator.speed_scale = 1.0
		_animator.process_mode = _animator_mode
	if is_instance_valid(_tiger):
		_tiger.position = _combat_start
		_tiger.reset_physics_interpolation()
	_intro.camera.h_offset = 0.0
	_intro.camera.v_offset = 0.0
	_set_doors_closed(false)
	create_tween().tween_property(_cage_lamp, ^"light_energy", 0.42, 0.46)


func _on_fight_started(boss: Node3D) -> void:
	var tiger: FireSabretooth = boss as FireSabretooth
	if tiger != null:
		tiger.phase.finished.connect(_on_phase_changed.bind(tiger))
		tiger.state_machine.state_changed.connect(_on_boss_state_changed)
	_set_heat(fight_flame_power, 0.8)


func _on_phase_changed(tiger: FireSabretooth) -> void:
	if tiger.phase.is_in_phase_two:
		_set_heat(phase_two_flame_power, 1.46)


func _on_boss_state_changed(_from: StringName, next: StringName) -> void:
	if next == &"TigerTransformation":
		_set_heat(idle_flame_power * 0.55, 0.32)
	elif next == &"TigerFireBeam":
		_set_heat(phase_two_flame_power, 1.46)


func _on_defeated() -> void:
	_set_heat(idle_flame_power * 0.64, 0.22)


func _build_vfx() -> void:
	var flame_material: ShaderMaterial = ShaderMaterial.new()
	flame_material.shader = HEAT_SHADER
	var flame_mesh: QuadMesh = QuadMesh.new()
	flame_mesh.size = Vector2(1.92, 3.15)
	flame_mesh.material = flame_material
	var spark_material: StandardMaterial3D = StandardMaterial3D.new()
	spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_material.vertex_color_use_as_albedo = true
	spark_material.emission_enabled = true
	spark_material.emission = Color(1.0, 0.18, 0.012)
	spark_material.emission_energy_multiplier = 1.25
	var spark_mesh: BoxMesh = BoxMesh.new()
	spark_mesh.size = Vector3(0.032, 0.12, 0.032)
	spark_mesh.material = spark_material
	for point: Vector3 in BRAZIER_POINTS:
		var flame: Node3D = Node3D.new()
		flame.position = point
		add_child(flame)
		for card: int in 2:
			var leaf: MeshInstance3D = MeshInstance3D.new()
			leaf.mesh = flame_mesh
			leaf.position.y = flame_mesh.size.y * 0.5 - 0.04
			leaf.rotation.y = 0.38 + card * PI * 0.5
			leaf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			flame.add_child(leaf)
		flame.hide()
		_flames.append(flame)
		_lamps.append(_make_light(point + Vector3.UP * 1.22, Color(1.0, 0.47, 0.19), 9.7))
		var embers: CPUParticles3D = _make_particles(spark_mesh, point, 15, 1.55, Vector3.UP, 23.0, Vector2(0.4, 1.95), Vector3(0.38, 0.1, 0.38))
		embers.one_shot = false
		embers.explosiveness = 0.0
		embers.gravity = Vector3(0.16, 0.56, 0.06)
		_rise.append(embers)

	_led = ShaderMaterial.new()
	_led.shader = HEAT_SHADER
	_led.set_shader_parameter(&"heated_iron", true)
	_set_led(0.13)
	var led_mesh: QuadMesh = QuadMesh.new()
	led_mesh.size = Vector2(0.135, 1.14)
	led_mesh.material = _led
	for side: float in [-1.0, 1.0]:
		for mark: float in [1.96, 3.80]:
			var slit: MeshInstance3D = MeshInstance3D.new()
			slit.mesh = led_mesh
			slit.position = Vector3(side * 5.53, mark, -12.65)
			slit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(slit)
	_cage_lamp = _make_light(Vector3(-2.9, 5.1, -11.65), Color(1.0, 0.57, 0.33), 10.0)
	_flash = _make_light(cage_mouth_position + Vector3(0, 0.38, 1.45), Color(1.0, 0.32, 0.075), 8.8)

	var smoke: StandardMaterial3D = StandardMaterial3D.new()
	smoke.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	smoke.vertex_color_use_as_albedo = true
	smoke.albedo_texture = DUST_TEXTURE
	var dust_mesh: QuadMesh = QuadMesh.new()
	dust_mesh.material = smoke
	dust_mesh.size = Vector2(2.6, 2.6)
	_impact_sparks = _make_particles(spark_mesh, cage_mouth_position, 66, 0.61, Vector3(0, 0.26, 1), 62.0, Vector2(4.2, 15.1), Vector3(2.31, 1.12, 0.12))
	_impact_sparks.gravity = Vector3.DOWN * 12.0
	_impact_dust = _make_particles(dust_mesh, cage_mouth_position - Vector3.UP * 1.24, 22, 1.33, Vector3(0, 0.28, 1), 87.0, Vector2(0.7, 5.4), Vector3(1.58, 0.36, 0.22))
	_impact_dust.color_ramp = _dust_gradient(Color(0.46, 0.27, 0.23, 0.73))
	_landing_dust = _make_particles(dust_mesh, Vector3.ZERO, 22, 1.08, Vector3.UP, 86.0, Vector2(1.72, 4.6), Vector3(0.92, 0.16, 1.3))
	_landing_dust.color_ramp = _dust_gradient(Color(0.37, 0.29, 0.29, 0.51))
	_audio = AudioStreamPlayer3D.new()
	add_child(_audio)
	# Bỏ bóng trên bề mặt phát sáng dưới vực để đèn không tốn thêm lượt vẽ.
	var basin: MeshInstance3D = _model.find_child("MagmaticBasin", true, false) as MeshInstance3D
	var source: StandardMaterial3D = basin.get_active_material(0) as StandardMaterial3D
	var magma: ShaderMaterial = ShaderMaterial.new()
	magma.shader = MAGMA_SHADER
	magma.set_shader_parameter(&"magma_pattern", source.albedo_texture)
	var cascade: ShaderMaterial = magma.duplicate() as ShaderMaterial
	cascade.set_shader_parameter(&"drift", Vector2(0.0, -0.066))
	for candidate: Node in _model.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = candidate as MeshInstance3D
		if mesh == basin:
			mesh.material_override = magma
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif String(mesh.name).begins_with("LavaCascade"):
			mesh.material_override = cascade
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _make_light(point: Vector3, tint: Color, radius: float) -> OmniLight3D:
	var lamp: OmniLight3D = OmniLight3D.new()
	lamp.position = point
	lamp.light_color = tint
	lamp.light_energy = 0.0
	lamp.omni_range = radius
	lamp.omni_attenuation = 1.27
	lamp.shadow_enabled = false
	add_child(lamp)
	return lamp


func _make_particles(mesh: Mesh, point: Vector3, count: int, life: float, heading: Vector3, spread: float, speed: Vector2, bounds: Vector3) -> CPUParticles3D:
	var fx: CPUParticles3D = CPUParticles3D.new()
	fx.emitting = false
	fx.one_shot = true
	fx.explosiveness = 0.94
	fx.amount = count
	fx.lifetime = life
	fx.lifetime_randomness = 0.34
	fx.mesh = mesh
	fx.position = point
	fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	fx.emission_box_extents = bounds
	fx.direction = heading.normalized()
	fx.spread = spread
	fx.initial_velocity_min = speed.x
	fx.initial_velocity_max = speed.y
	fx.gravity = Vector3.UP * 0.28
	fx.scale_amount_min = 0.34
	fx.scale_amount_max = 1.12
	fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fx)
	return fx


func _dust_gradient(middle: Color) -> Gradient:
	var ramp: Gradient = Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.16, 0.49, 1.0])
	ramp.colors = PackedColorArray([Color(middle, 0.0), middle, Color(middle, middle.a * 0.56), Color(middle, 0.0)])
	return ramp


func _swell_flame(progress: float, index: int) -> void:
	var rise: float = smoothstep(0.0, 0.36, progress)
	var flare: float = 1.0 + 0.36 * (1.0 - smoothstep(0.33, 1.0, progress))
	_set_brazier(fight_flame_power * rise * flare, index)


func _set_brazier(power: float, index: int) -> void:
	var flame: Node3D = _flames[index]
	var on: bool = power > 0.03
	flame.visible = on
	flame.scale = Vector3(0.89, clampf(power * 0.42, 0.19, 1.35), 0.89)
	_lamps[index].light_energy = power
	if on and not _rise[index].emitting:
		_rise[index].emitting = true
	elif not on:
		_rise[index].emitting = false


func _set_led(power: float) -> void:
	_led.set_shader_parameter(&"power", power)


func _set_heat(power: float, led_power: float) -> void:
	if _lighting_tween:
		_lighting_tween.kill()
	_lighting_tween = create_tween().set_parallel(true)
	for index: int in _flames.size():
		_lighting_tween.tween_method(_set_brazier.bind(index), _lamps[index].light_energy, power, 0.7)
	_lighting_tween.tween_method(_set_led, float(_led.get_shader_parameter(&"power")), led_power, 0.7)


func _set_doors_closed(closed: bool) -> void:
	_door_left.visible = closed
	_door_right.visible = closed
	for piece: Node3D in _broken_parts:
		piece.visible = not closed


func _rattle(progress: float) -> void:
	var shiver: float = sin(progress * 48.0) * progress * progress
	_door_left.position = _left_home.origin + Vector3(shiver * 0.058, 0.0, shiver * 0.134)
	_door_right.position = _right_home.origin - Vector3(shiver * 0.047, 0.0, shiver * 0.11)
	_door_left.rotation.z = shiver * 0.036
	_door_right.rotation.z = shiver * 0.027


func _begin_jump() -> void:
	_jump_started = false
	var length: float = _tiger.motion.play(intro_pounce_clip, 0.075)
	_animator.speed_scale = length / jump_duration


func _move_tiger(progress: float) -> void:
	var arrive: float = smoothstep(0.0, 1.0, progress)
	var start: Vector3 = cage_wait_position - _fight.position
	_tiger.position = start.lerp(_combat_start, arrive)
	_tiger.position.y += sin(progress * PI) * jump_height
	if arrive >= 0.35 and not _jump_started:
		_jump_started = true
		_break_cage()


func _break_cage() -> void:
	_impact_sparks.restart()
	_impact_dust.restart()
	_play_sound(cage_hit_sound, cage_mouth_position)
	_flash.light_energy = 5.4
	create_tween().tween_property(_flash, ^"light_energy", 0.0, 0.34).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	create_tween().tween_method(_shake_shot, 1.0, 0.0, 0.38)
	var scatter: Tween = create_tween().set_parallel(true)
	scatter.tween_property(_door_left, ^"position", _left_home.origin + Vector3(-4.7, -1.7, 2.71), 0.61).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	scatter.tween_property(_door_right, ^"position", _right_home.origin + Vector3(4.6, -1.6, 2.16), 0.61).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	scatter.tween_property(_door_left, ^"rotation", Vector3(1.19, -0.54, -0.75), 0.61)
	scatter.tween_property(_door_right, ^"rotation", Vector3(1.12, 0.64, 0.53), 0.61)
	scatter.chain().tween_callback(_set_doors_closed.bind(false))


func _land() -> void:
	_landing_dust.global_position = _tiger.global_position + Vector3.UP * 0.33
	_landing_dust.restart()
	_play_sound(landing_sound, _tiger.global_position)
	_animator.speed_scale = 1.0
	_tiger.motion.play(intro_roar_clip, 0.13)
	create_tween().tween_method(_shake_shot, 0.64, 0.0, 0.31)


func _shake_shot(weight: float) -> void:
	var gain: float = weight * cage_trauma * ScreenShake.strength
	var phase: float = weight * 48.0
	_intro.camera.h_offset = sin(phase) * gain * 0.30
	_intro.camera.v_offset = cos(phase * 1.44) * gain * 0.23


func _play_sound(stream: AudioStream, point: Vector3) -> void:
	if stream != null:
		_audio.global_position = point
		_audio.stream = stream
		_audio.play()

