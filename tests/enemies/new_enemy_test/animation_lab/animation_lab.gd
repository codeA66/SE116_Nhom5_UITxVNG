extends Node3D
## Phòng thử độc lập dùng cùng player và chỉ quản lý quái sinh trong ô giữa phòng.

const SPAWN_ACTION := &"lab_spawn_menu"
const CLIP_ACTION := &"lab_clip_menu"
const PHYSICS_DRAIN := preload("res://ui/transition/scene_physics_drain.gd")
const BOX_EDGES := [0, 1, 0, 2, 0, 4, 1, 3, 1, 5, 2, 3, 2, 6, 3, 7, 4, 5, 4, 6, 5, 7, 6, 7]

@export var player: Player
@export var entrance: InteractableComponent
@export var outside_arrival: Marker3D
@export var roster: Array[PackedScene]
@export var camera_view: CameraViewData

var inside: bool = false
var _controlled: Enemy
var _slot: Node3D
var _animator: AnimationPlayer
var _skeletons: Array[Skeleton3D]
var _default_hitbox_size: Vector3
var _default_hitbox_position: Vector3
var _ai_enabled: bool = false
var _travelling: bool = false
var _swapping: bool = false
var _paused_for_menu: bool = false
var _previous_camera: Camera3D
var _outside_camera_pose: Transform3D
var _outside_camera_fov: float
var _arena_modes: Dictionary[int, Node.ProcessMode]
var _clip: StringName
var _clip_time: float = 0.0
var _clip_duration: float = 0.0
var _preview_attack: AttackData
var _preview_paused: bool
var _manual_move: bool
var _installed_actions: Array[StringName]

@onready var _menu: EnemyLabMenu = $Menu
@onready var _spawn_point: Marker3D = $EnemySpawn
@onready var _arrival: Marker3D = $Arrival
@onready var _exit: InteractableComponent = $ReturnPillar/InteractableComponent


func _ready() -> void:
	_register_test_action(SPAWN_ACTION, KEY_I)
	_register_test_action(CLIP_ACTION, KEY_O)
	entrance.interacted.connect(_travel.bind(true))
	_exit.interacted.connect(_travel.bind(false))
	_menu.spawn_selected.connect(_replace_enemy)
	_menu.clear_selected.connect(_replace_enemy.bind(null))
	_menu.clip_selected.connect(_play_clip)
	_menu.move_selected.connect(_play_move)
	_menu.preview_pause_requested.connect(_toggle_preview_pause)
	_menu.ai_changed.connect(_set_ai)
	_menu.dismissed.connect(_close_catalog)
	_menu.shortcut_input.connect(handle_menu_input)
	_menu.animation_hovered.connect(player.set_attack_blocked_by_ui)
	set_physics_process(false)


func _exit_tree() -> void:
	if _paused_for_menu:
		get_tree().paused = false
	for action: StringName in _installed_actions:
		InputMap.erase_action(action)


func _physics_process(delta: float) -> void:
	if _clip.is_empty() or not is_instance_valid(_controlled):
		return
	_clip_time = minf(_clip_time + delta, _clip_duration)
	if _preview_attack is FireBossStrike:
		var strike := _preview_attack as FireBossStrike
		var bird := _controlled as Pyralon
		if bird:
			bird.pose.update_bones()
			bird.update_axe_hit(strike, _clip_time)
		else:
			strike.update_hitbox(_controlled.hitbox, _clip_time, 1.0)
	elif _preview_attack:
		var clip_start := _preview_attack.active_start * _preview_attack.anim_speed
		var clip_end := _preview_attack.active_end * _preview_attack.anim_speed
		if _clip_time >= clip_start and _clip_time < clip_end and not _controlled.hitbox.is_active():
			_controlled.hitbox.activate(_preview_attack, clip_end - _clip_time)
		elif _clip_time >= clip_end and _controlled.hitbox.is_active():
			_controlled.hitbox.deactivate()
	if _clip_time >= _clip_duration:
		_restart_clip()


func handle_menu_input(event: InputEvent) -> void:
	if not inside or _travelling or _swapping:
		return
	if event.is_action_pressed(SPAWN_ACTION):
		if _paused_for_menu:
			_close_catalog()
		elif not get_tree().paused:
			_menu.show_catalog(roster)
			get_tree().paused = true
			_paused_for_menu = true
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(CLIP_ACTION) and not get_tree().paused:
		_menu.toggle_clips()
		get_viewport().set_input_as_handled()


func _register_test_action(action: StringName, key: Key) -> void:
	if InputMap.has_action(action):
		return
	var shortcut := InputEventKey.new()
	shortcut.physical_keycode = key
	InputMap.add_action(action)
	InputMap.action_add_event(action, shortcut)
	_installed_actions.append(action)


func _travel(actor: Node3D, enter: bool) -> void:
	if actor != player or _travelling or SceneManager.is_busy() or _swapping:
		return
	_travelling = true
	_close_catalog()
	_menu.hide_clips()
	var rig := player.get_node("CameraRig") as CameraRig
	var player_camera := rig.get_node("Camera3D") as Camera3D
	if enter:
		_previous_camera = get_viewport().get_camera_3d()
		_outside_camera_pose = player_camera.transform
		_outside_camera_fov = player_camera.fov
		player_camera.make_current()
		_suspend_arena_enemies()
	else:
		await _remove_slot()
	player.set_controls_enabled(false)
	var marker: Marker3D = _arrival if enter else outside_arrival
	await SceneManager.warp_player(player, marker.global_position, marker.global_basis.z)
	player.set_controls_enabled(true)
	inside = enter
	if enter:
		rig.apply_view(camera_view)
	else:
		for id: int in _arena_modes:
			var enemy := instance_from_id(id) as Enemy
			if enemy:
				enemy.process_mode = _arena_modes[id]
		_arena_modes.clear()
		player_camera.transform = _outside_camera_pose
		player_camera.fov = _outside_camera_fov
		player_camera.reset_physics_interpolation()
		if is_instance_valid(_previous_camera):
			_previous_camera.make_current()
	_menu.set_in_room(inside)
	_travelling = false


func _suspend_arena_enemies() -> void:
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if enemy == null or is_ancestor_of(enemy):
			continue
		_arena_modes[enemy.get_instance_id()] = enemy.process_mode
		enemy.process_mode = Node.PROCESS_MODE_DISABLED


func _close_catalog() -> void:
	_menu.hide_catalog()
	if _paused_for_menu:
		get_tree().paused = false
		_paused_for_menu = false


func _replace_enemy(scene: PackedScene) -> void:
	if _swapping:
		return
	_swapping = true
	_close_catalog()
	await _remove_slot()
	if scene != null:
		_slot = Node3D.new()
		_slot.name = "ActiveEnemy"
		_slot.add_to_group(Enemy.ATTACK_POOL_SCOPE)
		_spawn_point.add_child(_slot)
		_controlled = scene.instantiate() as Enemy
		var elephant := _controlled as WarElephant
		if elephant:
			elephant.auto_introduction = false
			elephant.keep_test_corpse = true
		_slot.add_child(_controlled)
		_controlled.face_instantly((player.global_position - _controlled.global_position).slide(Vector3.UP).normalized())
		_controlled.died.connect(_on_enemy_died)
		_animator = _controlled.get_node("AnimationPlayer") as AnimationPlayer
		_skeletons.clear()
		for node: Node in _controlled.model.find_children("*", "Skeleton3D", true, false):
			_skeletons.append(node as Skeleton3D)
		var collision := _controlled.hitbox.get_node("CollisionShape3D") as CollisionShape3D
		_default_hitbox_position = collision.position
		if collision.shape is BoxShape3D:
			_default_hitbox_size = (collision.shape as BoxShape3D).size
		if _controlled is PreviewFireBoss:
			_show_active_hitbox(_controlled.hitbox, collision)
		var clips: PackedStringArray = _animator.get_animation_list()
		if elephant or _controlled is FireSabretooth:
			clips = _animator.get_animation_library(&"").get_animation_list()
		_menu.set_enemy(_controlled.data.display_name, clips)
		if elephant:
			_show_corpse_hitbox(elephant)
			elephant.lava.set_target(player)
			elephant.skill_finished.connect(_on_manual_move_finished)
			elephant.introduction.finished.connect(_on_manual_intro_finished)
			_menu.set_elephant_moves(elephant.wildlife.skills)
		var phase := _controlled.get_node_or_null("Phase") as SabretoothPhase
		if phase:
			phase.finished.connect(_on_manual_intro_finished)
			_menu.add_move(SabretoothPhase.MOVE_ID, SabretoothPhase.MOVE_TITLE)
			for skill: EnemySkillData in (_controlled as FireSabretooth).wildlife.skills:
				_menu.add_move(skill.skill_id, (skill as SabretoothSkill).title)
			(_controlled as FireSabretooth).skill_finished.connect(_on_manual_move_finished)
		var bird := _controlled as Pyralon
		if bird:
			for id: StringName in Pyralon.MOVE_TITLES:
				_menu.add_move(id, Pyralon.MOVE_TITLES[id])
			bird.preview_finished.connect(_on_pyralon_move_finished)
		_set_ai(false)
		if phase:
			await get_tree().physics_frame
			_controlled.apply_floor_snap()
			_controlled.reset_physics_interpolation()
		if elephant:
			elephant.play_action(WarElephant.SLEEP)
	_swapping = false


func _show_active_hitbox(hitbox: HitboxComponent, collision: CollisionShape3D) -> void:
	var outline := _make_hitbox_outline(collision, &"ActiveHitboxOutline")
	hitbox.activated.connect(func(_attack: AttackData) -> void:
		outline.scale = (collision.shape as BoxShape3D).size
		outline.show())
	hitbox.deactivated.connect(outline.hide)


func _show_corpse_hitbox(elephant: WarElephant) -> void:
	var collision := elephant.body_collision
	var outline := _make_hitbox_outline(collision, &"CorpseHitboxOutline")
	elephant.corpse_settled.connect(func() -> void:
		outline.scale = (collision.shape as BoxShape3D).size
		outline.show())
	elephant.state_machine.state_changed.connect(func(from: StringName, _to: StringName) -> void:
		if from == &"Dead":
			outline.hide())


func _make_hitbox_outline(collision: CollisionShape3D, outline_name: StringName) -> MeshInstance3D:
	var unit_box := AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)
	var wireframe := ImmediateMesh.new()
	wireframe.surface_begin(Mesh.PRIMITIVE_LINES)
	for endpoint: int in BOX_EDGES:
		wireframe.surface_add_vertex(unit_box.get_endpoint(endpoint))
	wireframe.surface_end()
	var outline := MeshInstance3D.new()
	outline.name = outline_name
	outline.mesh = wireframe
	outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("ffc274")
	outline.material_override = material
	outline.hide()
	collision.add_child(outline)
	return outline


func _remove_slot() -> void:
	if not is_instance_valid(_slot):
		return
	set_physics_process(false)
	_stop_manual_move()
	var bird := _controlled as Pyralon
	if bird:
		bird.reset_combat()
	var elephant := _controlled as WarElephant
	if elephant:
		elephant.lava.clear()
	if is_instance_valid(_controlled) and _controlled.hitbox.is_active():
		_controlled.hitbox.cancel()
	_release_slot_attacks()
	_clip = &""
	_preview_attack = null
	_controlled = null
	_animator = null
	_skeletons.clear()
	_menu.set_enemy("", PackedStringArray())
	_menu.set_preview_pause(false)
	if Engine.is_in_physics_frame():
		await get_tree().process_frame
	var drain := PHYSICS_DRAIN.new()
	await drain.prepare(_slot)
	_slot.queue_free()
	await _slot.tree_exited
	drain.clear()
	_slot = null


func _on_enemy_died(enemy: Enemy) -> void:
	if enemy != _controlled:
		return
	set_physics_process(false)
	_clip = &""
	_clear_support(enemy)
	if enemy is WarElephant:
		_show_elephant_death(enemy as WarElephant)
		return
	if enemy is FireSabretooth and (enemy as FireSabretooth).encounter_complete:
		_ai_enabled = false
		_menu.set_ai(false)
		_menu.set_playing(&"Đã hoàn thành chuỗi Phase 2")
		return
	_controlled = null
	_animator = null
	_skeletons.clear()
	_menu.set_enemy("", PackedStringArray())
	_menu.set_preview_pause(false)


func _show_elephant_death(elephant: WarElephant) -> void:
	_ai_enabled = false
	_menu.set_ai(false, true)
	_menu.set_playing(elephant.wildlife.death_animation)
	_menu.set_preview_pause(false)


func _restore_elephant_for_preview(elephant: WarElephant) -> void:
	if elephant and elephant.state_machine.current_state.name == &"Dead":
		elephant.health.heal_full()
		elephant.state_machine.transition_to(&"Idle")
		elephant.hurtbox.invulnerable = true
		elephant.set_physics_process(false)
		_menu.set_ai(false)


func _clear_support(primary: Enemy) -> void:
	_release_slot_attacks()
	for child: Node in _slot.get_children():
		if child is Enemy and child != primary:
			child.queue_free()


func _release_slot_attacks() -> void:
	for child: Node in _slot.get_children():
		if child is ObjectPool:
			(child as ObjectPool).release_all()


func _set_ai(enabled: bool) -> void:
	if not is_instance_valid(_controlled):
		return
	if _controlled is WarElephant and _controlled.state_machine.current_state.name == &"Dead":
		return
	_stop_manual_move()
	if _controlled is FireSabretooth:
		(_controlled as FireSabretooth).restore_preview()
		if enabled:
			(_controlled as FireSabretooth).resume_combat()
	var bird := _controlled as Pyralon
	if bird:
		bird.reset_combat()
	_ai_enabled = enabled
	_controlled.velocity = Vector3.ZERO
	_controlled.state_machine.transition_to(&"Idle")
	_reset_preview()
	_controlled.hurtbox.invulnerable = not enabled
	_controlled.set_dormant(not enabled)
	_controlled.set_physics_process(enabled)
	if _controlled.wind_receiver:
		_controlled.wind_receiver.clear_push()
		_controlled.wind_receiver.enabled = enabled
	if enabled:
		var wild := _controlled as WildEnemy
		if wild:
			wild.receive_rally(player)
		_controlled.target = player
	else:
		_controlled.target = null
		_clear_support(_controlled)
	_menu.set_ai(enabled)


func _play_clip(clip: StringName) -> void:
	if _ai_enabled or not is_instance_valid(_controlled) or not _animator.has_animation(clip):
		return
	_stop_manual_move()
	if _controlled is FireSabretooth:
		(_controlled as FireSabretooth).restore_preview()
	var bird := _controlled as Pyralon
	if bird:
		bird.reset_combat()
	var elephant := _controlled as WarElephant
	if elephant and clip == elephant.wildlife.death_animation:
		if elephant.state_machine.current_state.name != &"Dead":
			_reset_preview(false)
			elephant.state_machine.transition_to(&"Dead")
			_show_elephant_death(elephant)
		return
	_restore_elephant_for_preview(elephant)
	_reset_preview()
	var phase := _controlled.get_node_or_null("Phase") as SabretoothPhase
	_clip = phase.make_preview_loop(clip) if phase else clip
	_clip_duration = _animator.get_animation(_clip).length
	_preview_attack = _attack_for_clip(clip)
	_restart_clip()
	_menu.set_playing(clip)
	_menu.set_preview_pause(true)
	set_physics_process(true)


func _restart_clip() -> void:
	_clip_time = 0.0
	if _controlled.hitbox.is_active():
		_controlled.hitbox.cancel()
	_animator.stop()
	_animator.play(_clip, 0.0)
	_animator.advance(0.0)


func _reset_preview(reset_pose: bool = true) -> void:
	_clip = &""
	_clip_time = 0.0
	_preview_paused = false
	_preview_attack = null
	set_physics_process(false)
	if _controlled.hitbox.is_active():
		_controlled.hitbox.cancel()
	var collision := _controlled.hitbox.get_node("CollisionShape3D") as CollisionShape3D
	collision.position = _default_hitbox_position
	if collision.shape is BoxShape3D:
		(collision.shape as BoxShape3D).size = _default_hitbox_size
	_animator.speed_scale = 1.0
	if reset_pose:
		_animator.stop()
		if _animator.has_animation(&"RESET"):
			_animator.play(&"RESET", 0.0)
			_animator.advance(0.0)
			_animator.stop(true)
		for skeleton: Skeleton3D in _skeletons:
			skeleton.reset_bone_poses()
		_controlled.play_anim(&"Idle")
	_menu.set_playing(&"")
	_menu.set_preview_pause(false)


func _toggle_preview_pause() -> void:
	if not is_instance_valid(_controlled) or _ai_enabled or _clip.is_empty():
		return
	_preview_paused = not _preview_paused
	_animator.speed_scale = 0.0 if _preview_paused else 1.0
	if _controlled.hitbox.is_active():
		_controlled.hitbox.set_deferred(&"monitoring", not _preview_paused)
	set_physics_process(not _preview_paused)
	_menu.set_preview_pause(true, _preview_paused)


func _play_move(id: StringName, title: String) -> void:
	if _ai_enabled or not is_instance_valid(_controlled):
		return
	var bird := _controlled as Pyralon
	if bird and Pyralon.MOVE_TITLES.has(id):
		_stop_manual_move()
		_reset_preview(false)
		_manual_move = true
		_menu.set_playing(StringName(title))
		bird.play_move(id, player)
		return
	if id == SabretoothPhase.MOVE_ID:
		var phase := _controlled.get_node_or_null("Phase") as SabretoothPhase
		if phase:
			_stop_manual_move()
			_reset_preview(false)
			_menu.set_playing(StringName(title))
			phase.preview(player)
		return
	var tiger := _controlled as FireSabretooth
	if tiger:
		for entry: EnemySkillData in tiger.wildlife.skills:
			if entry.skill_id == id:
				_stop_manual_move()
				_reset_preview(false)
				_manual_move = true
				_menu.set_playing(StringName(title))
				tiger.preview_skill(entry as SabretoothSkill, player)
				return
	var elephant := _controlled as WarElephant
	if not elephant:
		return
	_stop_manual_move()
	_restore_elephant_for_preview(elephant)
	_reset_preview(id != &"introduction")
	_menu.set_playing(StringName(title))
	if id == &"introduction":
		elephant.play_introduction(player, true)
		return
	for skill: EnemySkillData in elephant.wildlife.skills:
		if skill.skill_id == id:
			_manual_move = true
			elephant.target = player
			elephant.set_physics_process(true)
			elephant.begin_preview_skill(skill)
			return


func _stop_manual_move() -> void:
	if not is_instance_valid(_controlled):
		return
	var bird := _controlled as Pyralon
	if bird and bird.is_previewing():
		bird.reset_combat()
		_manual_move = false
	var phase := _controlled.get_node_or_null("Phase") as SabretoothPhase
	if phase:
		phase.cancel_preview()
	var tiger := _controlled as FireSabretooth
	if tiger:
		tiger.stop_preview_skill()
		_manual_move = false
	var elephant := _controlled as WarElephant
	if not elephant:
		return
	elephant.cancel_introduction()
	if _manual_move:
		elephant.state_machine.transition_to(&"Idle")


func _on_pyralon_move_finished() -> void:
	_on_manual_move_finished(null, true)


func _on_manual_move_finished(_skill: EnemySkillData, _completed: bool) -> void:
	if not _manual_move:
		return
	_manual_move = false
	_controlled.target = null
	_controlled.set_physics_process(false)
	_menu.set_playing(&"")


func _on_manual_intro_finished() -> void:
	if not _ai_enabled:
		_menu.set_playing(&"")


func _attack_for_clip(clip: StringName) -> AttackData:
	if _controlled is WildEnemy:
		for skill: EnemySkillData in (_controlled as WildEnemy).wildlife.skills:
			if skill.animation == clip and skill.melee_enabled:
				return skill
	if _controlled.data.attack and _controlled.data.attack.animation == clip:
		return _controlled.data.attack
	return null
