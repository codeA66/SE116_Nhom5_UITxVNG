extends Player
## Player dùng model cáo tự tạo; giữ nguyên FSM và component của project.

const FOX_WEAPON: WeaponData = preload("res://resources/weapons/fox_sword.tres")
const FOX_DASH: DashData = preload("res://abilities/dash/dash.tres")
const FOX_MATERIAL: Material = preload("res://assets/characters/fox/fox_material.tres")
const BOW_ANIMATIONS = preload("res://entities/player/fox_bow_animations.gd")
## Mốc vung kiếm đo từ chuyển động tay phải trong clip (hitbox và vệt chém bám theo các mốc này)
const FOX_MARKERS: AnimationMarkerSet = preload("res://resources/player/fox_animation_markers.tres")
## Chuyển cảnh mặc định của clip hành động khi state không yêu cầu riêng
const ACTION_BLEND := 0.05
const LOOP_CLIPS: Array[StringName] = [&"Idle", &"Idle_Sword", &"Run", &"Run_Sword", &"Fall"]
const CLIP_MAP: Dictionary[StringName, StringName] = {
    Player.ANIM_JUMP: &"Jump",
    Player.ANIM_FALL: &"Fall",
    Player.ANIM_PICK_UP: &"PickUp",
    Player.ANIM_HURT: &"Hurt",
    Player.ANIM_DEATH: &"Death",
    &"Rig_Medium_MovementAdvanced/Dodge_Forward": &"Dash",
    &"Rig_Medium_CombatMelee/Melee_1H_Attack_Slice_Horizontal": &"Attack_Horizontal",
}

@export_group("Generated Preview")
## Chỉ bật trong scene thử: không thay đổi tiến trình hoặc file save.
@export var preview_sword: bool = false
@export var preview_dash: bool = false
@export_group("Landing")
@export var landing_duration: float = 0.2
@export var hard_landing_speed: float = 3.0
@export_group("Locomotion")
@export var run_reference_speed: float = 4.0
@export var min_run_playback: float = 0.85
@export var max_run_playback: float = 1.65
@export var locomotion_blend: float = 0.08
@export var run_playback_response: float = 12.0

var _landing_remaining: float = 0.0
var _was_grounded: bool = false
var _previous_vertical_speed: float = 0.0
var _locomotion: StringName = Player.ANIM_IDLE
var _sword_mesh: Node3D
var _bow_visual: BowVisual
var _bow_tween: Tween


func _ready() -> void:
    for node in model.find_children("*", "MeshInstance3D", true, false):
        (node as MeshInstance3D).material_override = FOX_MATERIAL
    _install_animations()
    _sword_mesh = model.find_child("Sword", true, false) as Node3D
    super()


## Vũ khí lấy đúng từ tiến trình (vật phẩm đã nhặt). Kiếm cáo chỉ dùng trong scene xem thử (preview_sword)
func get_weapon() -> WeaponData:
    return FOX_WEAPON if preview_sword else super()


func get_ability(id: StringName) -> AbilityData:
    if preview_dash and id == DashData.ID:
        return FOX_DASH
    return super(id)


func has_ability(id: StringName) -> bool:
    return get_ability(id) != null


func play_anim(anim_name: StringName) -> void:
    if _bow_tween:
        _bow_tween.kill()
    if is_instance_valid(_bow_visual):
        _bow_visual.draw_amount = 0.0
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
    # Co giãn clip dash theo độ dài clip thật để hết clip đúng lúc hết dash
    if clip == &"fox/Dash":
        var dash := get_ability(DashData.ID) as DashData
        if dash and _anim.has_animation(clip):
            speed = _anim.get_animation(clip).length / maxf(dash.duration, 0.01)
    _anim.play(clip, ACTION_BLEND if blend < 0.0 else blend, speed)
    _anim.seek(0.0, true)
    if _bow_tween:
        _bow_tween.kill()
    if is_instance_valid(_bow_visual):
        _bow_visual.draw_amount = 0.0
        if anim_name == &"Bow_Shoot":
            var release := get_weapon().combo[0].active_start
            _bow_tween = create_tween()
            _bow_tween.tween_property(_bow_visual, "draw_amount", 1.0, maxf(release, 0.01))
            _bow_tween.tween_property(_bow_visual, "draw_amount", 0.0, 0.06)


## Tên đòn trong AttackData là tên clip gốc: đổi sang clip của cáo trước khi đọc marker
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
    else:
        _anim.speed_scale = 1.0
    var can_land := state != null and state.name in [PlayerState.FALL, PlayerState.IDLE, PlayerState.RUN]
    if grounded and not _was_grounded and _previous_vertical_speed < -hard_landing_speed and can_land:
        _landing_remaining = landing_duration
        _anim.play(&"fox/Land", 0.04)
    elif _landing_remaining > 0.0:
        _landing_remaining = maxf(0.0, _landing_remaining - delta)
        if _landing_remaining <= 0.0:
            play_anim(_locomotion)
    _was_grounded = grounded
    _previous_vertical_speed = velocity.y


func _attach_weapon_model(_data: WeaponData) -> void:
    # Kiếm đã skin vào tay phải; cung gắn vào Hand_L bằng BoneAttachment3D.
    if _bow_tween:
        _bow_tween.kill()
    var equipped := get_weapon()
    if is_instance_valid(_sword_mesh):
        _sword_mesh.visible = equipped != null and equipped.slot == WeaponData.Slot.SWORD
    for child in _weapon_socket.get_children():
        child.queue_free()
    _bow_visual = null
    if equipped and equipped.slot == WeaponData.Slot.BOW and equipped.model_scene:
        _bow_visual = equipped.model_scene.instantiate() as BowVisual
        _weapon_socket.add_child(_bow_visual)


func _resolve_clip(anim_name: StringName) -> StringName:
    var clip: StringName
    if anim_name == Player.ANIM_IDLE:
        clip = &"Idle_Bow" if _has_bow() else (&"Idle_Sword" if has_weapon() else &"Idle")
    elif anim_name == Player.ANIM_RUN:
        clip = &"Run_Bow" if _has_bow() else (&"Run_Sword" if has_weapon() else &"Run")
    else:
        clip = CLIP_MAP.get(anim_name, anim_name)
    return StringName("fox/%s" % clip)


func _has_bow() -> bool:
    return get_weapon() != null and get_weapon().slot == WeaponData.Slot.BOW


func _install_animations() -> void:
    var players := model.find_children("*", "AnimationPlayer", true, false)
    assert(not players.is_empty(), "Model cáo thiếu AnimationPlayer")
    var imported := players[0] as AnimationPlayer
    var library := AnimationLibrary.new()
    for clip in imported.get_animation_list():
        if clip == &"RESET":
            continue
        var animation := imported.get_animation(clip).duplicate() as Animation
        animation.loop_mode = Animation.LOOP_LINEAR if clip in LOOP_CLIPS else Animation.LOOP_NONE
        library.add_animation(clip, animation)
    var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
    BOW_ANIMATIONS.install(library, skeleton)
    FOX_MARKERS.apply_to(library)
    var socket := get_node("WeaponSocket") as BoneAttachment3D
    socket.external_skeleton = socket.get_path_to(skeleton)
    _anim.root_node = _anim.get_path_to(imported.get_node(imported.root_node))
    _anim.add_animation_library(&"fox", library)
    imported.stop()
    imported.active = false

