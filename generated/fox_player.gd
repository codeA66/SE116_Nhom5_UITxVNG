extends Player
## Player dùng model cáo tự tạo; giữ nguyên FSM và component của project.

const FOX_WEAPON: WeaponData = preload("res://generated/resources/fox_sword.tres")
const FOX_DASH: DashData = preload("res://abilities/dash/dash.tres")
const FOX_MATERIAL: Material = preload("res://generated/resources/fox_material.tres")
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


func _ready() -> void:
    for node in model.find_children("*", "MeshInstance3D", true, false):
        (node as MeshInstance3D).material_override = FOX_MATERIAL
    _install_animations()
    _sword_mesh = model.find_child("Sword", true, false) as Node3D
    super()


func get_weapon() -> WeaponData:
    return FOX_WEAPON if preview_sword or GameState.get_weapon() != null else null


func get_ability(id: StringName) -> AbilityData:
    if preview_dash and id == DashData.ID:
        return FOX_DASH
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


func play_action(anim_name: StringName, speed: float = 1.0) -> void:
    _landing_remaining = 0.0
    _anim.speed_scale = 1.0
    var clip := _resolve_clip(anim_name)
    # Dash dài 0.18 s, clip 0.20 s: nén đúng khoảng thời gian state.
    if clip == &"fox/Dash":
        var dash := get_ability(DashData.ID) as DashData
        if dash:
            speed = 0.2 / maxf(dash.duration, 0.01)
    _anim.play(clip, 0.05, speed)
    _anim.seek(0.0, true)


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
    # Kiếm đã skin vào xương bàn tay phải, không gắn thêm model KayKit.
    if is_instance_valid(_sword_mesh):
        _sword_mesh.visible = get_weapon() != null


func _resolve_clip(anim_name: StringName) -> StringName:
    var clip: StringName
    if anim_name == Player.ANIM_IDLE:
        clip = &"Idle_Sword" if has_weapon() else &"Idle"
    elif anim_name == Player.ANIM_RUN:
        clip = &"Run_Sword" if has_weapon() else &"Run"
    else:
        clip = CLIP_MAP.get(anim_name, anim_name)
    return StringName("fox/%s" % clip)


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
    _anim.root_node = _anim.get_path_to(imported.get_node(imported.root_node))
    _anim.add_animation_library(&"fox", library)
    imported.stop()
    imported.active = false

