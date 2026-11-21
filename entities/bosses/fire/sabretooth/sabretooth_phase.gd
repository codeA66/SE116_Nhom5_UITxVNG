class_name SabretoothPhase
extends Node3D
## Trình diễn biến hình thủ công với cùng skeleton đang chạy animation của hổ.

signal finished

const MOVE_ID := &"phase_two"
const MOVE_TITLE := "Chuyển sang Phase 2"
const PREVIEW_BLEND := 0.22
const PREVIEW_LIBRARY := &"sabretooth_preview"
const PREVIEW_CLIP := &"Loop"
const PREVIEW_PATH := &"sabretooth_preview/Loop"
const FLAME := preload("res://entities/bosses/fire/sabretooth/sabretooth_flame.gdshader")

@export var armored_rig: Node3D
@export var flame_model: PackedScene
@export var animator: AnimationPlayer
@export var framing: CameraCutscene
@export_range(0.2, 1.0, 0.01) var roar_speed: float = 0.58
@export_range(2.0, 8.0, 0.1) var rise_distance: float = 4.6

var is_in_phase_two: bool = false
var _was_in_phase_two: bool = false
var _playing: bool = false
var _roaring: bool = false
var _transformed: bool = false
var _roar_length: float
var _shot_offset: Vector3
var _armored: Array[MeshInstance3D]
var _flames: Array[MeshInstance3D]
var _original_materials: Array[Material]
var _skins: Array[ShaderMaterial]
var _preview_library := AnimationLibrary.new()

@onready var _light: OmniLight3D = $Firelight
@onready var _embers: CPUParticles3D = $Embers
@onready var _motion: SabretoothMotion = $"../Motion"
@onready var _fire_vfx: SabretoothFireVfx = $"../FireVfx"


func _ready() -> void:
	_shot_offset = framing.data.shot_offset
	var skeleton := armored_rig.find_child("Skeleton3D", true, false) as Skeleton3D
	_armored.append(skeleton.get_node("FireSabretooth_Body") as MeshInstance3D)
	_armored.append(skeleton.get_node("FireSabretooth_Eyes_FangTips") as MeshInstance3D)
	for mesh: MeshInstance3D in _armored:
		_original_materials.append(mesh.material_override)
	var source := flame_model.instantiate()
	var flame_skeleton := source.find_child("Skeleton3D", true, false) as Skeleton3D
	for mesh_name: String in ["FlameBody", "FlameEyes"]:
		var mesh := flame_skeleton.get_node(mesh_name) as MeshInstance3D
		mesh.owner = null
		flame_skeleton.remove_child(mesh)
		skeleton.add_child(mesh)
		mesh.skeleton = mesh.get_path_to(skeleton)
		mesh.extra_cull_margin = 2.5
		_flames.append(mesh)
	source.free()
	for form: int in 4:
		var material := ShaderMaterial.new()
		material.shader = FLAME
		material.set_shader_parameter(&"form", form)
		_skins.append(material)
	_flames[0].material_override = _skins[2]
	_flames[1].material_override = _skins[3]
	framing.shot_reached.connect(_start_roar)
	framing.finished.connect(_return_from_shot)
	animator.animation_finished.connect(_on_animation_finished)
	animator.add_animation_library(PREVIEW_LIBRARY, _preview_library)
	_set_form(false)
	set_process(false)


func _process(_delta: float) -> void:
	var progress := clampf(animator.current_animation_position / _roar_length, 0.0, 1.0)
	_set_flame_front(progress)


func preview(viewer: Player) -> void:
	if _playing or not animator.has_animation(SabretoothMotion.CINEMATIC_ROAR):
		return
	_playing = true
	_transformed = false
	_was_in_phase_two = is_in_phase_two
	_set_form(false)
	_roar_length = animator.get_animation(SabretoothMotion.CINEMATIC_ROAR).length
	framing.data.hold_time = _roar_length / roar_speed + PREVIEW_BLEND
	# Đổi sang dáng gốc lúc camera còn đang tiến vào để phần nối không lộ ở góc cận.
	animator.speed_scale = 1.0
	animator.play(SabretoothMotion.CINEMATIC_ROAR, PREVIEW_BLEND, 0.0)
	var forward := armored_rig.global_basis.z.slide(Vector3.UP).normalized()
	var right := Vector3.UP.cross(forward)
	framing.data.shot_offset = right * _shot_offset.x + Vector3.UP * _shot_offset.y + forward * _shot_offset.z
	framing.play_for(viewer)
	if not framing.is_processing():
		_start_roar()


func make_preview_loop(clip: StringName) -> StringName:
	var source := animator.get_animation(clip)
	if clip in [&"Run", &"Run2", &"Trot"] or source.length <= PREVIEW_BLEND:
		return clip
	# Nối dáng cuối về dáng đầu trong phòng thử, sau khi các frame trúng đòn đã qua.
	var preview_clip := _motion.preview_loop(source, PREVIEW_BLEND)
	if _preview_library.has_animation(PREVIEW_CLIP):
		_preview_library.remove_animation(PREVIEW_CLIP)
	_preview_library.add_animation(PREVIEW_CLIP, preview_clip)
	return PREVIEW_PATH


func show_flame_form() -> void:
	_set_form(true)


func show_phase_one_form() -> void:
	_set_form(false)


func begin_revert_to_phase_one() -> void:
	# Chuẩn bị tan biến hiệu ứng lửa Phase 2 từ trên đỉnh đầu xuống chân đồng thời trong lúc hổ ngã gục.
	var ground := global_position.y
	for material: ShaderMaterial in _skins:
		material.set_shader_parameter(&"rise_origin", ground)
		material.set_shader_parameter(&"transitioning", false)
		material.set_shader_parameter(&"reverting_top_down", true)
		material.set_shader_parameter(&"revert_progress", 0.0)
	for index: int in _armored.size():
		_armored[index].material_override = _skins[index]
		_armored[index].show()
	for mesh: MeshInstance3D in _flames:
		mesh.show()
	set_revert_progress(0.0)


func set_revert_progress(progress: float, head_world: Vector3 = Vector3.INF) -> void:
	var p := clampf(progress, 0.0, 1.0)
	var inv := 1.0 - p
	var head_pt := head_world if head_world.is_finite() else (global_position + Vector3.UP * 1.45)
	var top_span := maxf(head_pt.y - global_position.y + 0.45, 0.85)
	for material: ShaderMaterial in _skins:
		material.set_shader_parameter(&"revert_progress", p)
		material.set_shader_parameter(&"revert_head_pos", head_pt)
		material.set_shader_parameter(&"revert_top_y", top_span)
	_fire_vfx.set_tail_growth(clampf(1.0 - smoothstep(0.45, 0.96, p), 0.0, 1.0))
	_embers.emitting = inv > 0.25
	_light.visible = inv > 0.05
	_light.light_energy = 0.68 * inv + sin(p * PI) * 0.40
	if p >= 1.0:
		_set_form(false)


func dissolve_finale(progress: float) -> void:
	_skins[2].set_shader_parameter(&"dissolve", progress)
	_skins[3].set_shader_parameter(&"dissolve", progress)
	_fire_vfx.set_tail_dissolve(progress)
	_embers.emitting = is_in_phase_two and progress < 0.26
	_light.light_energy = 0.68 * (1.0 - progress)


func set_portal_clip(active: bool, origin: Vector3 = Vector3.ZERO, normal: Vector3 = Vector3.UP) -> void:
	for idx: int in [2, 3]:
		_skins[idx].set_shader_parameter(&"portal_clip", active)
		_skins[idx].set_shader_parameter(&"portal_origin", origin)
		_skins[idx].set_shader_parameter(&"portal_normal", normal)
	_fire_vfx.set_tail_portal_clip(active, origin, normal)


func set_reform_progress(progress: float) -> void:
	var clamped := clampf(progress, 0.0, 1.0)
	_skins[2].set_shader_parameter(&"reform", clamped)
	_skins[3].set_shader_parameter(&"reform", clamped)
	_fire_vfx.set_tail_growth(smoothstep(0.50, 0.94, clamped) if is_in_phase_two else 0.0)
	_light.visible = is_in_phase_two and clamped > 0.15
	_light.light_energy = lerpf(0.25, 0.68, clamped) + sin(clamped * PI) * 0.85
	_embers.emitting = is_in_phase_two and clamped >= 0.45


func set_ambient_active(active: bool) -> void:
	_light.visible = active and is_in_phase_two
	_embers.emitting = active and is_in_phase_two
	_fire_vfx.set_tail_growth(1.0 if active and is_in_phase_two else 0.0)


func cancel_preview() -> void:
	if not _playing:
		return
	animator.stop(true)
	_set_form(is_in_phase_two or _was_in_phase_two)
	_transformed = false
	_roaring = false
	set_process(false)
	if framing.is_processing():
		framing.cancel_playback()
	else:
		_return_from_shot()


func _start_roar() -> void:
	_roaring = true
	var ground := global_position.y
	for material: ShaderMaterial in _skins:
		material.set_shader_parameter(&"rise_origin", ground)
		material.set_shader_parameter(&"transitioning", true)
	for index: int in _armored.size():
		_armored[index].material_override = _skins[index]
	for mesh: MeshInstance3D in _flames:
		mesh.show()
	_light.show()
	_embers.emitting = true
	_set_flame_front(0.0)
	animator.play(SabretoothMotion.CINEMATIC_ROAR, 0.0, roar_speed)
	set_process(true)


func _set_flame_front(progress: float) -> void:
	var height := lerpf(-0.20, rise_distance, smoothstep(0.04, 0.88, progress))
	var tails := smoothstep(0.40, 0.92, progress)
	for material: ShaderMaterial in _skins:
		material.set_shader_parameter(&"rise_height", height)
	_fire_vfx.set_tail_growth(tails)
	_light.light_energy = sin(progress * PI) * 1.55 + progress * 0.68


func _set_form(flame: bool) -> void:
	is_in_phase_two = flame
	for index: int in _armored.size():
		_armored[index].material_override = _original_materials[index]
		_armored[index].visible = not flame
	for mesh: MeshInstance3D in _flames:
		mesh.visible = flame
	for material: ShaderMaterial in _skins:
		material.set_shader_parameter(&"transitioning", false)
		material.set_shader_parameter(&"reverting_top_down", false)
		material.set_shader_parameter(&"revert_progress", 0.0)
	dissolve_finale(0.0)
	set_portal_clip(false)
	set_reform_progress(1.0)
	_fire_vfx.set_tail_growth(1.0 if flame else 0.0)
	_light.visible = flame
	_light.light_energy = 0.68
	_embers.emitting = flame


func _on_animation_finished(clip: StringName) -> void:
	if not _roaring or clip != SabretoothMotion.CINEMATIC_ROAR:
		return
	_roaring = false
	set_process(false)
	_set_form(true)
	_transformed = true
	if not framing.is_processing():
		_return_from_shot()


func _return_from_shot() -> void:
	if not _playing:
		return
	if _roaring:
		return
	_playing = false
	# Chỉ nối về dáng chờ sau khi camera đã trở lại góc nhìn chơi.
	if _transformed:
		_motion.play(&"Growling", PREVIEW_BLEND, true)
	finished.emit()
