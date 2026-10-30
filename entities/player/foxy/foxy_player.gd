class_name FoxyPlayer
extends Player
## Player dùng model Foxy (Blender); giữ nguyên FSM và component của project.
## Mọi tên clip / xương / đường dẫn rig để @export để đổi model khác không phải sửa code.

const LIBRARY_NAME: StringName = &"foxy"
const BOW_ANIMATIONS: GDScript = preload("res://entities/player/foxy/foxy_bow_animations.gd")
const TOON_SHADER: Shader = preload("res://assets/shaders/character/foxy_toon.gdshader")
const BLINK_SHAPE: StringName = &"Blink"
## Chuyển cảnh mặc định của clip hành động khi state không yêu cầu riêng
const ACTION_BLEND: float = 0.05

@export_group("Preview")
## Chỉ bật trong scene thử: không thay đổi tiến trình hoặc file save
@export var preview_sword: bool = false
@export var preview_dash: bool = false
@export var preview_weapon: WeaponData = preload("res://resources/combat/weapons/sword.tres")
@export var preview_dash_data: DashData = preload("res://abilities/dash/dash.tres")

@export_group("Rig")
## Đường dẫn Skeleton3D tính từ gốc model đã import
@export var skeleton_path: NodePath = ^"Foxy_Rig/Skeleton3D"
## Xương gắn cung (tay trái)
@export var bow_hand_bone: StringName = &"hand.L"
## Tên node kiếm đã gắn sẵn vào tay phải trong model
@export var sword_node_name: StringName = &"Sword"
## Vai trò -> tên xương, dùng để dựng tư thế cầm cung
@export var bow_arm_bones: Dictionary[StringName, StringName] = {
	&"upper_l": &"upper_arm.L", &"fore_l": &"forearm.L", &"hand_l": &"hand.L",
	&"upper_r": &"upper_arm.R", &"fore_r": &"forearm.R", &"hand_r": &"hand.R",
}

@export_group("Bow Aim Pose")
## Vai trò -> tên xương thân / đầu dùng cho tư thế giương cung
@export var bow_body_bones: Dictionary[StringName, StringName] = {
	&"spine": &"spine", &"chest": &"chest", &"neck": &"neck", &"head": &"head",
}
## Xoay thân trên sang trái khi giương cung (độ). 0 = ngực giữ nguyên như lúc đứng nghiêng
@export_range(-60.0, 60.0, 0.5) var bow_twist_degrees: float = 0.0
## Nghiêng người tới trước (độ)
@export_range(-30.0, 30.0, 0.5) var bow_lean_degrees: float = 0.0
## Cúi đầu (độ). 0 = mắt nhìn thẳng
@export_range(-30.0, 30.0, 0.5) var bow_head_tilt_degrees: float = 0.0
## Quay đầu (cổ + đầu) về phía mục tiêu khi đứng nghiêng (độ), mắt nhìn dọc mũi tên
@export_range(0.0, 120.0, 0.5) var bow_head_turn_degrees: float = 75.0

@export_group("Clips")
## Tên animation FSM/AttackData yêu cầu -> tên clip trong model Foxy
@export var clip_map: Dictionary[StringName, StringName] = {
	Player.ANIM_JUMP: &"Jump",
	Player.ANIM_FALL: &"Fall",
	Player.ANIM_PICK_UP: &"PickUp",
	Player.ANIM_HURT: &"Hurt",
	Player.ANIM_DEATH: &"Death",
	&"Rig_Medium_MovementAdvanced/Dodge_Forward": &"Dash",
	&"Rig_Medium_CombatMelee/Melee_1H_Attack_Slice_Horizontal": &"Attack_1",
	&"Attack_Backhand": &"Attack_2",
	&"Attack_Finisher": &"Attack_3",
	&"Attack_Horizontal": &"Attack_1",
}
@export var loop_clips: Array[StringName] = [&"Idle", &"Idle_Sword", &"Run", &"Run_Sword", &"Fall"]
## Mốc vung kiếm trong clip Foxy (hitbox và vệt chém bám theo các mốc này)
@export var animation_markers: AnimationMarkerSet = preload("res://resources/player/foxy_animation_markers.tres")
@export var dash_clip: StringName = &"Dash"
@export var land_clip: StringName = &"Land"

@export_group("Landing")
@export var landing_duration: float = 0.2
@export var hard_landing_speed: float = 3.0

@export_group("Locomotion")
## Tốc độ mặt đất (m/s) mà clip Run được dựng; phát nhanh/chậm theo tỉ lệ để chân không trượt
@export var run_reference_speed: float = 2.4
@export var min_run_playback: float = 0.85
@export var max_run_playback: float = 1.65
@export var locomotion_blend: float = 0.08
@export var run_playback_response: float = 12.0

@export_group("Look")
@export var outline_color: Color = Color(0.17, 0.08, 0.05)
@export var face_blink_interval: Vector2 = Vector2(2.0, 4.5)
@export var face_blink_time: float = 0.1

var _landing_remaining: float = 0.0
var _was_grounded: bool = false
var _previous_vertical_speed: float = 0.0
var _locomotion: StringName = Player.ANIM_IDLE
var _sword_mesh: Node3D
var _face: MeshInstance3D
var _blink_shape: int = -1
var _face_blink_timer: float = 0.0

## Không có thì kiếm luôn ở tay như trước
@onready var _holster: WeaponHolsterComponent = get_node_or_null(^"WeaponHolster")


func _ready() -> void:
	var imported := _find_imported_player()
	_apply_toon_materials(model)
	_face = _find_face(model)
	if _face:
		_blink_shape = _face.find_blend_shape_by_name(BLINK_SHAPE)
	_install_animations(imported)
	_sword_mesh = model.find_child(String(sword_node_name), true, false) as Node3D
	_face_blink_timer = randf_range(face_blink_interval.x, face_blink_interval.y)
	if _holster:
		_holster.drawn_changed.connect(_on_sword_drawn_changed)
	super()


## Vũ khí lấy đúng từ tiến trình (vật phẩm đã nhặt); kiếm xem thử chỉ dùng khi bật preview_sword
func get_weapon() -> WeaponData:
	return preview_weapon if preview_sword else super()


func get_ability(id: StringName) -> AbilityData:
	if preview_dash and id == DashData.ID:
		return preview_dash_data
	return super(id)


func has_ability(id: StringName) -> bool:
	return get_ability(id) != null


func play_anim(anim_name: StringName) -> void:
	if anim_name == Player.ANIM_IDLE or anim_name == Player.ANIM_RUN:
		_locomotion = anim_name
		if _landing_remaining > 0.0:
			return
	else:
		_landing_remaining = 0.0
	var clip := _resolve_clip(anim_name)
	if _anim.current_animation != clip:
		_anim.play(clip, locomotion_blend)


func play_action(anim_name: StringName, speed: float = 1.0, blend: float = -1.0) -> void:
	_landing_remaining = 0.0
	_anim.speed_scale = 1.0
	var clip := _resolve_clip(anim_name)
	if _short_name(clip) == dash_clip:
		# Nén clip dash vào đúng thời gian của state
		var dash := get_ability(DashData.ID) as DashData
		if dash:
			speed = _clip_length(clip) / maxf(dash.duration, 0.01)
	_anim.play(clip, ACTION_BLEND if blend < 0.0 else blend, speed)
	_anim.seek(0.0, true)


## Tay phải kéo dây nên cất kiếm trong lúc cầm cung
func begin_bow_aim() -> void:
	super()
	if is_instance_valid(_sword_mesh):
		_sword_mesh.visible = false


func end_bow_aim() -> void:
	super()
	_update_sword_visibility()


## Tên đòn trong AttackData là tên clip gốc: đổi sang clip của Foxy trước khi đọc marker
func get_action_marker_time(anim_name: StringName, marker: StringName) -> float:
	return super(_resolve_clip(anim_name), marker)


func _pre_state_update(delta: float) -> void:
	super(delta)
	var grounded := is_on_floor()
	var state := state_machine.current_state
	if state != null and state.name == PlayerState.RUN and _landing_remaining <= 0.0:
		var horizontal_speed := Vector2(velocity.x, velocity.z).length()
		var target_rate := clampf(horizontal_speed / maxf(run_reference_speed, 0.01), min_run_playback, max_run_playback)
		_anim.speed_scale = lerpf(_anim.speed_scale, target_rate, 1.0 - exp(-run_playback_response * delta))
	elif state != null and state.name in [PlayerState.IDLE, PlayerState.FALL]:
		_anim.speed_scale = 1.0
	var can_land := state != null and state.name in [PlayerState.FALL, PlayerState.IDLE, PlayerState.RUN]
	if grounded and not _was_grounded and _previous_vertical_speed < -hard_landing_speed and can_land:
		_landing_remaining = landing_duration
		_anim.play(StringName("%s/%s" % [LIBRARY_NAME, land_clip]), 0.04)
	elif _landing_remaining > 0.0:
		_landing_remaining = maxf(0.0, _landing_remaining - delta)
		if _landing_remaining <= 0.0:
			play_anim(_locomotion)
	_was_grounded = grounded
	_previous_vertical_speed = velocity.y
	_update_blink(delta)


func _attach_weapon_model(_data: WeaponData) -> void:
	# Kiếm đã gắn sẵn vào tay phải trong model; cung là vũ khí phụ, Player hiện ở BowHold khi nhắm
	_update_sword_visibility()


func _update_sword_visibility() -> void:
	var equipped := get_weapon()
	if is_instance_valid(_sword_mesh):
		_sword_mesh.visible = equipped != null and equipped.slot == WeaponData.Slot.SWORD


## Clip kéo cung đứng yên (speed 0); tua theo độ kéo để tay khớp đúng với dây
func _on_bow_draw_changed(amount: float) -> void:
	var bow := get_bow()
	if bow == null:
		return
	var clip := _resolve_clip(bow.draw_animation)
	if _anim.current_animation == clip:
		_anim.seek(amount * _clip_length(clip), true)


func _resolve_clip(anim_name: StringName) -> StringName:
	var clip: StringName
	if anim_name == Player.ANIM_IDLE:
		clip = &"Idle_Bow" if _has_bow() else (&"Idle_Sword" if _is_sword_in_hand() else &"Idle")
	elif anim_name == Player.ANIM_RUN:
		clip = &"Run_Bow" if _has_bow() else (&"Run_Sword" if _is_sword_in_hand() else &"Run")
	else:
		clip = clip_map.get(anim_name, anim_name)
	return StringName("%s/%s" % [LIBRARY_NAME, clip])


func _short_name(clip: StringName) -> StringName:
	var text := String(clip)
	return StringName(text.substr(text.find("/") + 1))


func _clip_length(clip: StringName) -> float:
	return _anim.get_animation(clip).length if _anim.has_animation(clip) else 0.2


## Kiếm đã cất vào chỗ đeo thì đứng/chạy bằng clip tay không
func _is_sword_in_hand() -> bool:
	return has_weapon() and (_holster == null or _holster.drawn)


## state_changed phát sau enter(): Idle/Run đã chọn clip theo trạng thái cũ, chọn lại cho khớp
func _on_sword_drawn_changed(_drawn: bool) -> void:
	var state := state_machine.current_state
	if state != null and state.name in [PlayerState.IDLE, PlayerState.RUN]:
		play_anim(_locomotion)


func _has_bow() -> bool:
	return get_weapon() != null and get_weapon().slot == WeaponData.Slot.BOW


func _update_blink(delta: float) -> void:
	if _blink_shape < 0:
		return
	_face_blink_timer -= delta
	# Chớp kiểu "bậc thang": nhắm hẳn vài frame rồi mở, hợp phong cách 2D
	_face.set_blend_shape_value(_blink_shape, 1.0 if _face_blink_timer < 0.0 else 0.0)
	if _face_blink_timer < -face_blink_time:
		_face_blink_timer = randf_range(face_blink_interval.x, face_blink_interval.y)


func _find_imported_player() -> AnimationPlayer:
	var players := model.find_children("*", "AnimationPlayer", true, false)
	assert(not players.is_empty(), "Model Foxy thiếu AnimationPlayer")
	return players[0] as AnimationPlayer


func _install_animations(imported: AnimationPlayer) -> void:
	var library := AnimationLibrary.new()
	for clip in imported.get_animation_list():
		if clip == &"RESET":
			continue
		var animation := imported.get_animation(clip).duplicate() as Animation
		# Mặt do code điều khiển, bỏ track blend shape từ Blender để không giành quyền
		for track in range(animation.get_track_count() - 1, -1, -1):
			if animation.track_get_type(track) == Animation.TYPE_BLEND_SHAPE:
				animation.remove_track(track)
		animation.loop_mode = Animation.LOOP_LINEAR if clip in loop_clips else Animation.LOOP_NONE
		library.add_animation(clip, animation)
	var model_root := imported.get_node(imported.root_node)
	var skeleton := model_root.get_node(skeleton_path) as Skeleton3D
	assert(skeleton != null, "Không tìm thấy Skeleton3D tại %s" % skeleton_path)
	BOW_ANIMATIONS.install(library, skeleton, model_root.get_path_to(skeleton), bow_arm_bones, {
		"bones": bow_body_bones, "twist": bow_twist_degrees, "lean": bow_lean_degrees,
		"head_tilt": bow_head_tilt_degrees, "aim_yaw": bow_stance_degrees,
		# Quay về cùng phía với hướng nhắm
		"head_turn": bow_head_turn_degrees * signf(bow_stance_degrees),
	})
	if animation_markers:
		animation_markers.apply_to(library)
	var socket := get_node(^"WeaponSocket") as BoneAttachment3D
	socket.external_skeleton = socket.get_path_to(skeleton)
	socket.bone_name = bow_hand_bone
	_anim.root_node = _anim.get_path_to(model_root)
	_anim.add_animation_library(LIBRARY_NAME, library)
	imported.stop()
	imported.active = false


func _apply_toon_materials(root: Node) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.get_active_material(surface) as BaseMaterial3D
			if source == null:
				continue
			mesh_instance.set_surface_override_material(surface, _make_material(source))


func _make_material(source: BaseMaterial3D) -> Material:
	var source_name := String(source.resource_name)
	if source_name.contains("Outline"):
		# Viền dạng inverted hull đã bake trong mesh, chỉ cần màu phẳng
		var outline := StandardMaterial3D.new()
		outline.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		outline.albedo_color = outline_color
		outline.cull_mode = BaseMaterial3D.CULL_BACK
		return outline
	if source_name.contains("Highlight"):
		var glint := StandardMaterial3D.new()
		glint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glint.albedo_color = Color.WHITE
		return glint
	var toon := ShaderMaterial.new()
	toon.shader = TOON_SHADER
	toon.set_shader_parameter(&"albedo", source.albedo_color)
	return toon


func _find_face(root: Node) -> MeshInstance3D:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.get_blend_shape_count() > 0:
			return mesh_instance
	return null
