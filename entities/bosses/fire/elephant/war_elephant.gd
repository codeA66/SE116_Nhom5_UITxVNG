class_name WarElephant
extends PreviewFireBoss

@warning_ignore("unused_signal")
signal corpse_settled

const SLEEP := &"sleep"
const WAKE := &"wakeup"
const INTRO_FINISH := &"fight idle01"
const CHARGE_WINDUP_LIBRARY := &"elephant_charge"
const CHARGE_WINDUP := &"elephant_charge/trunk_windup"
const POSE_BLEND: float = 0.24
const WAKE_TURN := Vector2(0.34, 0.62)
const WAKE_STRETCH: float = 0.8

@export var auto_introduction: bool = true
@export var wake_distance: float = 9.0
@export var corpse_distance: float = 48.0
@export var corpse_size: Vector3 = Vector3(2.35, 1.15, 2.95)
@export var corpse_offset: Vector3 = Vector3(-0.43, 0.59, -0.16)
@export var trail_spacing: float = 0.94
@export var charge_stop_distance: float = 2.2
@export_range(0.1, 0.99, 0.01) var charge_player_speed_ratio: float = 0.78
@export_range(0.1, 1.0, 0.05) var true_death_time_scale: float = 0.5

var _introduced: bool
var _intro_stage: int
var _preview_intro: bool
var _skill_index: int
var _preview_skill: bool
var keep_test_corpse: bool

@onready var lava: ElephantLava = $Lava
@onready var coat: ElephantCoat = $Coat
@onready var introduction: CameraCutscene = $Introduction
@onready var body_collision: CollisionShape3D = $CollisionShape3D
@onready var attack_collision: CollisionShape3D = $Model/Hitbox/CollisionShape3D


func _ready() -> void:
	super()
	_align_stationary_clips()
	_soften_wake_turn()
	_prepare_charge_windup()
	_anim.get_animation(SLEEP).loop_mode = Animation.LOOP_LINEAR
	for clip: StringName in [&"idle Trumped", &"run attack"]:
		_anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	_anim.get_animation(wildlife.death_animation).loop_mode = Animation.LOOP_NONE
	coat.setup(_rig.find_child("Skeleton3D", true, false) as Skeleton3D)
	introduction.shot_reached.connect(_wake)
	introduction.finished.connect(_finish_introduction)
	_anim.animation_finished.connect(_on_intro_clip_finished)
	body_collision.shape = body_collision.shape.duplicate()


func resists_knockback() -> bool:
	return true


func alert_pending() -> bool:
	return auto_introduction and not _introduced and has_target() and distance_to_target() <= wake_distance


func begin_alert() -> float:
	play_introduction(target as Player)
	return introduction.data.travel_time + introduction.data.hold_time + introduction.data.return_time + 0.1


func choose_skill() -> EnemySkillData:
	if auto_introduction and not _introduced:
		return null
	var next := wildlife.skills[_skill_index]
	return next if skill_ready(next) else null


func begin_preview_skill(skill: EnemySkillData) -> void:
	_preview_skill = true
	begin_skill(skill)


func complete_skill(skill: EnemySkillData, completed: bool, cooldown_started: bool = false) -> void:
	if _preview_skill:
		_preview_skill = false
		skill_finished.emit(skill, completed)
		pending_skill = null
		return
	if completed and skill == wildlife.skills[_skill_index]:
		_skill_index = (_skill_index + 1) % wildlife.skills.size()
	super(skill, completed, cooldown_started)


func play_anim(clip: StringName) -> void:
	if auto_introduction and not _introduced and _intro_stage == 0 and clip in [&"Idle", &"Walk", &"Run"]:
		super(SLEEP)
	else:
		super(clip)


func move_toward_direction(direction: Vector3, delta: float) -> void:
	super(Vector3.ZERO if auto_introduction and not _introduced else direction, delta)


func play_introduction(viewer: Player, manual: bool = false) -> void:
	if _intro_stage > 0:
		return
	if viewer == null or get_viewport().get_camera_3d() == null:
		_introduced = not manual
		return
	_preview_intro = manual
	_intro_stage = 1
	_anim.speed_scale = 1.0
	if _anim.current_animation != SLEEP:
		_anim.play(SLEEP, POSE_BLEND)
	_anim.get_animation(INTRO_FINISH).loop_mode = Animation.LOOP_NONE
	introduction.data.hold_time = _anim.get_animation(WAKE).length + _anim.get_animation(INTRO_FINISH).length + 0.36
	introduction.play_for(viewer)


func cancel_introduction() -> void:
	if _intro_stage == 0:
		return
	_intro_stage = 0
	introduction.cancel_playback()


func _wake() -> void:
	_intro_stage = 2
	_anim.play(WAKE, POSE_BLEND)


func _on_intro_clip_finished(clip: StringName) -> void:
	if _intro_stage == 2 and clip == WAKE:
		_intro_stage = 3
		_anim.play(INTRO_FINISH, POSE_BLEND)


func _finish_introduction() -> void:
	_anim.get_animation(INTRO_FINISH).loop_mode = Animation.LOOP_LINEAR
	if _intro_stage == 0:
		return
	_intro_stage = 0
	if not _preview_intro:
		_introduced = true


func _align_stationary_clips() -> void:
	# Các clip đứng yên được xuất ở các tọa độ khác nhau. Giữ chuyển động dọc khi voi đứng dậy.
	var idle := _anim.get_animation(INTRO_FINISH)
	for index: int in idle.get_track_count():
		var path := idle.track_get_path(index)
		if idle.track_get_type(index) != Animation.TYPE_POSITION_3D or path.get_concatenated_subnames() != ground_motion_bone:
			continue
		var anchor: Vector3 = idle.track_get_key_value(index, 0)
		for clip: StringName in [SLEEP, WAKE, &"idle trumpet", &"idle Trumped"]:
			var animation := _anim.get_animation(clip)
			var track := animation.find_track(path, Animation.TYPE_POSITION_3D)
			if track < 0:
				continue
			for key: int in animation.track_get_key_count(track):
				var at: Vector3 = animation.track_get_key_value(track, key)
				animation.track_set_key_value(track, key, Vector3(anchor.x, at.y, anchor.z))
		break


func _soften_wake_turn() -> void:
	# Đoạn vòi vung ngay sau khi nhấc đầu đổi góc quá nhanh ở clip gốc.
	var wake := _anim.get_animation(WAKE)
	for track: int in wake.get_track_count():
		for key: int in range(wake.track_get_key_count(track) - 1, -1, -1):
			var at := wake.track_get_key_time(track, key)
			if at <= WAKE_TURN.x:
				break
			wake.track_set_key_time(track, key, at + (minf(at, WAKE_TURN.y) - WAKE_TURN.x) * WAKE_STRETCH)
	wake.length += (WAKE_TURN.y - WAKE_TURN.x) * WAKE_STRETCH


func _prepare_charge_windup() -> void:
	for entry: EnemySkillData in wildlife.skills:
		var skill := entry as ElephantSkill
		if skill == null or skill.kind != ElephantSkill.Kind.CHARGE or skill.first_hold_duration <= 0.0:
			continue
		var running := _anim.get_animation(wildlife.run_animation).duplicate() as Animation
		var attack := _anim.get_animation(skill.animation)
		var pose_time := clampf(skill.first_hold_frame, 0.0, attack.length)
		# Cổ, đầu và vòi dùng chung khung hình để nhịp gật đầu của Run không làm lệch dáng lấy đà.
		for track: int in running.get_track_count():
			var path := running.track_get_path(track)
			var bone := String(path.get_concatenated_subnames())
			if not bone.begins_with("proboscis") and bone != "head1_neck" and bone != "head1_head":
				continue
			var type := running.track_get_type(track)
			var source := attack.find_track(path, type)
			if source < 0:
				continue
			var pose: Variant
			match type:
				Animation.TYPE_POSITION_3D: pose = attack.position_track_interpolate(source, pose_time)
				Animation.TYPE_ROTATION_3D: pose = attack.rotation_track_interpolate(source, pose_time)
				Animation.TYPE_SCALE_3D: pose = attack.scale_track_interpolate(source, pose_time)
				_: continue
			for key: int in range(running.track_get_key_count(track) - 1, -1, -1):
				running.track_remove_key(track, key)
			running.track_insert_key(track, 0.0, pose)
		var library := AnimationLibrary.new()
		library.add_animation(&"trunk_windup", running)
		_anim.add_animation_library(CHARGE_WINDUP_LIBRARY, library)
		break
