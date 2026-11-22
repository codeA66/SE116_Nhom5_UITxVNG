class_name PyralonPhase
extends Node3D
## Điều khiển biến hình tuần tự 4 bước sang Pyralon Phase 2 (Hỏa Ưng Tro Tàn) kèm góc quay CameraCutscene cinematic.

signal finished

const MOVE_ID := &"phase_two"
const MOVE_TITLE := "Chuyển sang Phase 2"
const SHADER := preload("res://entities/bosses/fire/pyralon/pyralon_phase_two.gdshader")
const BASE_CUT_SHADER := preload("res://entities/bosses/fire/pyralon/pyralon_phase_one_cut.gdshader")
const PREVIEW_BLEND := 0.20

@export var base_rig: Node3D
@export var phase_two_model: PackedScene
@export var animator: AnimationPlayer
@export var framing: CameraCutscene
@export_range(2.5, 7.0, 0.1) var transform_duration: float = 4.4

var is_in_phase_two: bool = false
var _was_in_phase_two: bool = false
var _playing: bool = false
var _staging: bool = false
var _defer_transform: bool = false
var _reverting: bool = false
var _transformed: bool = false
var _stage_time: float = 0.0
var _wing_burst_done: bool = false
var _shot_offset: Vector3
var _default_travel_time: float = 0.85
var _base_meshes: Array[MeshInstance3D] = []
var _p2_meshes: Array[MeshInstance3D] = []
var _p2_mat: ShaderMaterial
var _p1_cut_mat: ShaderMaterial

@onready var _light: OmniLight3D = $Firelight
@onready var _embers: CPUParticles3D = $Embers


func _ready() -> void:
	_shot_offset = framing.data.shot_offset
	_default_travel_time = framing.data.travel_time
	var skeleton := base_rig.find_child("Skeleton3D", true, false) as Skeleton3D
	for mesh_name: String in ["Pyralon_Body", "Pyralon_Axe"]:
		var base_mesh := skeleton.get_node_or_null(mesh_name) as MeshInstance3D
		if base_mesh:
			_base_meshes.append(base_mesh)
	var source := phase_two_model.instantiate()
	var p2_skeleton := source.find_child("Skeleton3D", true, false) as Skeleton3D
	for mesh_name: String in ["Pyralon_P2_Body", "Pyralon_P2_Axe"]:
		var mesh := p2_skeleton.get_node_or_null(mesh_name) as MeshInstance3D
		if mesh:
			mesh.owner = null
			p2_skeleton.remove_child(mesh)
			skeleton.add_child(mesh)
			mesh.skeleton = mesh.get_path_to(skeleton)
			mesh.extra_cull_margin = 3.0
			_p2_meshes.append(mesh)
	source.free()

	_p2_mat = ShaderMaterial.new()
	_p2_mat.shader = SHADER
	_p2_mat.set_shader_parameter(&"transitioning", false)
	for mesh: MeshInstance3D in _p2_meshes:
		mesh.material_override = _p2_mat
	_p1_cut_mat = ShaderMaterial.new()
	_p1_cut_mat.shader = BASE_CUT_SHADER
	_p1_cut_mat.set_shader_parameter(&"light_sweep", -0.3)

	framing.shot_reached.connect(_start_sequence)
	framing.finished.connect(_return_from_shot)
	_set_form(false)
	set_process(false)


func _process(delta: float) -> void:
	if not _staging:
		return
	_stage_time += delta
	var total := maxf(transform_duration, 2.0)
	var p := clampf(_stage_time / total, 0.0, 1.0)
	# Trình tự biến hình tuần tự rõ từng bộ phận + giữ hiệu ứng khung lưới năng lượng ở 4 bước đầu,
	# rồi phát làn sóng ánh sáng vàng-trắng lan tỏa khắp người (0.80..0.98) để chuyển mượt sang 3D Phase 2 hoàn chỉnh!
	var s_axe := smoothstep(0.00, 0.20, p)
	var s_body := smoothstep(0.20, 0.40, p)
	var s_head := smoothstep(0.40, 0.60, p)
	var s_wings := smoothstep(0.60, 0.80, p)
	var sweep := lerpf(-0.25, 1.32, smoothstep(0.79, 0.98, p)) if p >= 0.79 else -0.30
	_apply_stages(s_axe, s_body, s_head, s_wings, sweep)
	# Khi sóng ánh sáng đã quét qua hết chóp cánh (sweep >= 1.12), ẩn mượt mesh Phase 1 bên dưới để không bị khựng khung cuối.
	if sweep >= 1.12:
		for mesh: MeshInstance3D in _base_meshes:
			mesh.hide()
	var sweep_flash := sin(clampf((p - 0.79) / 0.19, 0.0, 1.0) * PI) * 1.65 if p >= 0.79 else 0.0
	var base_energy := lerpf(0.40 + p * 0.95 + sin(p * PI) * 0.65, 0.82, smoothstep(0.86, 1.0, p))
	_light.light_energy = base_energy + sweep_flash
	if not _wing_burst_done and s_wings >= 0.35:
		_wing_burst_done = true
		var boss := get_parent() as Pyralon
		if boss and boss.field:
			boss.field.effect(PyralonFireFx.Kind.SHOCK, boss.global_position, Vector3.ZERO, Vector2.ONE * 5.2, 0.55)
		ScreenShake.add_trauma_at(0.32, global_position, 10.0, 24.0)
	if p >= 1.0:
		_staging = false
		set_process(false)
		_set_form(true)
		_transformed = true
		if framing.is_processing():
			if framing.hold_indefinitely:
				framing.release_hold()
		else:
			_return_from_shot()


func _aim_framing() -> void:
	var forward := base_rig.global_basis.z.slide(Vector3.UP).normalized()
	if forward.length_squared() < 0.01:
		forward = Vector3.BACK
	var right := Vector3.UP.cross(forward).normalized()
	framing.data.shot_offset = right * _shot_offset.x + Vector3.UP * _shot_offset.y + forward * _shot_offset.z


func preview(viewer: Player) -> void:
	if _playing:
		return
	_playing = true
	_defer_transform = false
	_transformed = false
	_was_in_phase_two = is_in_phase_two
	_set_form(false)
	framing.data.travel_time = _default_travel_time
	framing.data.hold_time = transform_duration + 0.35
	framing.unscaled_time = false
	framing.hold_indefinitely = false
	_aim_framing()
	if animator.has_animation(&"Idle2"):
		animator.play(&"Idle2", PREVIEW_BLEND)
		animator.speed_scale = 0.72
	if viewer:
		framing.play_for(viewer)
	if not framing.is_processing():
		_start_sequence()


func begin_held_zoom(viewer: Player) -> void:
	# Zoom mượt vào Pyralon ở cuối đòn Sky Dive (khi chạy slow-mo 0.5x), GIỮ NGUYÊN zoom để nối thẳng sang biến hình Phase 2!
	if _playing:
		return
	_playing = true
	_defer_transform = true
	_transformed = false
	_was_in_phase_two = is_in_phase_two
	_set_form(false)
	framing.data.travel_time = 0.45
	framing.data.hold_time = transform_duration + 0.35
	framing.unscaled_time = true
	framing.hold_indefinitely = true
	_aim_framing()
	if viewer and get_viewport().get_camera_3d() != null:
		framing.play_for(viewer)


func start_transform_while_zoomed() -> void:
	# Giữ nguyên khung hình zoom hiện tại, trả tốc độ camera về 1x và chạy ngay trình tự biến hình 4 bước Phase 2!
	_defer_transform = false
	_playing = true
	framing.unscaled_time = false
	_start_sequence()


func show_phase_two_form(active: bool = true) -> void:
	_reverting = false
	_set_form(active)


func is_reverting() -> bool:
	return _reverting


func begin_revert_top_down() -> void:
	# Chuẩn bị tan biến hiệu ứng Phase 2 từ đỉnh đầu xuống chân đồng thời lộ dần thân trắng Phase 1 bên dưới.
	_reverting = true
	for mesh: MeshInstance3D in _base_meshes:
		mesh.material_override = null
		mesh.show()
	for mesh: MeshInstance3D in _p2_meshes:
		mesh.show()
	_p2_mat.set_shader_parameter(&"transitioning", false)
	_p2_mat.set_shader_parameter(&"reverting", true)
	_p2_mat.set_shader_parameter(&"revert_progress", 0.0)
	_apply_stages(1.0, 1.0, 1.0, 1.0, -0.3)
	_light.show()
	_embers.emitting = true


func set_revert_progress(progress: float) -> void:
	var p := clampf(progress, 0.0, 1.0)
	_p2_mat.set_shader_parameter(&"revert_progress", p)
	var inv := 1.0 - p
	_light.visible = inv > 0.05
	_light.light_energy = 0.82 * inv + sin(p * PI) * 0.35
	_embers.emitting = inv > 0.22
	if p >= 1.0:
		_reverting = false
		_set_form(false)


func set_sky_hidden(hidden: bool) -> void:
	# Khi Pyralon bay khuất lên trời trong Sky Dive, tắt đèn lửa & tàn bay quanh thân để không để lại ánh sáng lơ lửng trên sàn.
	if hidden:
		_light.hide()
		_embers.emitting = false
	elif is_in_phase_two:
		_light.show()
		_embers.emitting = true


func set_stage_preview(s_axe: float, s_body: float, s_head: float, s_wings: float, sweep: float = -0.3) -> void:
	# Hỗ trợ kiểm tra trực quan từng bước biến hình độc lập (kể cả làn sóng ánh sáng cuối).
	var mid := (s_axe < 0.999 or s_body < 0.999 or s_head < 0.999 or s_wings < 0.999 or (sweep > -0.25 and sweep < 1.25))
	for mesh: MeshInstance3D in _base_meshes:
		mesh.visible = mid
		mesh.material_override = _p1_cut_mat if mid else null
	for mesh: MeshInstance3D in _p2_meshes:
		mesh.show()
	_p2_mat.set_shader_parameter(&"transitioning", mid)
	_apply_stages(s_axe, s_body, s_head, s_wings, sweep)
	_light.show()
	_embers.emitting = s_wings > 0.1 or s_body > 0.5


func cancel_preview() -> void:
	if not _playing:
		return
	_staging = false
	_defer_transform = false
	set_process(false)
	animator.speed_scale = 1.0
	_set_form(is_in_phase_two or _was_in_phase_two)
	_transformed = false
	if framing.is_processing():
		framing.cancel_playback()
	else:
		_return_from_shot()


func _start_sequence() -> void:
	if _defer_transform or _staging:
		return
	_staging = true
	_stage_time = 0.0
	_wing_burst_done = false
	# Gắn tạm shader cắt đồng bộ lên mesh gốc Phase 1 để trước sóng giữ hiệu ứng khung lưới và sau sóng biến mất từng pixel không nháy.
	for mesh: MeshInstance3D in _base_meshes:
		mesh.material_override = _p1_cut_mat
		mesh.show()
	for mesh: MeshInstance3D in _p2_meshes:
		mesh.show()
	_p2_mat.set_shader_parameter(&"transitioning", true)
	_apply_stages(0.0, 0.0, 0.0, 0.0, -0.3)
	_light.show()
	_light.light_energy = 0.45
	_embers.emitting = true
	if animator.has_animation(&"Idle2"):
		animator.play(&"Idle2", 0.15)
		animator.speed_scale = 0.65
	set_process(true)


func _apply_stages(s_axe: float, s_body: float, s_head: float, s_wings: float, sweep: float = -0.3) -> void:
	_p2_mat.set_shader_parameter(&"stage_axe", s_axe)
	_p2_mat.set_shader_parameter(&"stage_body", s_body)
	_p2_mat.set_shader_parameter(&"stage_head", s_head)
	_p2_mat.set_shader_parameter(&"stage_wings", s_wings)
	_p2_mat.set_shader_parameter(&"light_sweep", sweep)
	if _p1_cut_mat:
		_p1_cut_mat.set_shader_parameter(&"light_sweep", sweep)


func _set_form(phase_two: bool) -> void:
	is_in_phase_two = phase_two
	_reverting = false
	for mesh: MeshInstance3D in _base_meshes:
		mesh.material_override = null
		mesh.visible = not phase_two
	for mesh: MeshInstance3D in _p2_meshes:
		mesh.visible = phase_two
	_p2_mat.set_shader_parameter(&"transitioning", false)
	_p2_mat.set_shader_parameter(&"reverting", false)
	_p2_mat.set_shader_parameter(&"revert_progress", 0.0)
	var val := 1.0 if phase_two else 0.0
	_apply_stages(val, val, val, val, -0.3)
	_light.visible = phase_two
	_light.light_energy = 0.82
	_embers.emitting = phase_two


func _return_from_shot() -> void:
	if not _playing or _staging:
		return
	_playing = false
	animator.speed_scale = 1.0
	if _transformed and animator.has_animation(&"Idle1"):
		animator.play(&"Idle1", PREVIEW_BLEND)
	finished.emit()
