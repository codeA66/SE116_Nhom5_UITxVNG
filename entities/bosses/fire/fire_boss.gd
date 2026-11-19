class_name PreviewFireBoss
extends WildEnemy
## Dùng chung FSM của quái hoang dã và rig gốc cho các boss hệ lửa.

@export var ground_motion_bone: StringName

@onready var _rig: Node3D = $Model/Visual/Rig


func _ready() -> void:
	var imported := _rig.find_child("AnimationPlayer", true, false) as AnimationPlayer
	imported.stop()
	imported.active = false
	_anim.root_node = _anim.get_path_to(imported.get_node(imported.root_node))
	var library := AnimationLibrary.new()
	var config := data as WildEnemyData
	for clip: StringName in imported.get_animation_list():
		var animation := imported.get_animation(clip).duplicate() as Animation
		_remove_ground_motion(animation)
		if clip in [config.idle_animation, config.walk_animation, config.run_animation]:
			animation.loop_mode = Animation.LOOP_LINEAR
		library.add_animation(clip, animation)
	if _anim.has_animation_library(&""):
		_anim.remove_animation_library(&"")
	_anim.add_animation_library(&"", library)
	super()


func choose_skill() -> EnemySkillData:
	var selected: EnemySkillData
	var count: int = 0
	for skill: EnemySkillData in wildlife.skills:
		if (skill as FireBossStrike).automatic and skill_ready(skill):
			count += 1
			if _rng.randi_range(1, count) == 1:
				selected = skill
	return selected


func _remove_ground_motion(animation: Animation) -> void:
	for index: int in animation.get_track_count():
		if animation.track_get_type(index) != Animation.TYPE_POSITION_3D:
			continue
		var path := animation.track_get_path(index)
		if path.get_subname_count() != 1 or path.get_subname(0) != ground_motion_bone:
			continue
		if animation.track_get_key_count(index) == 0:
			continue
		var start: Vector3 = animation.track_get_key_value(index, 0)
		for key: int in animation.track_get_key_count(index):
			var value: Vector3 = animation.track_get_key_value(index, key)
			value.x = start.x
			value.z = start.z
			animation.track_set_key_value(index, key, value)
