class_name Boss1
extends Character
## Script điều khiển chính của Boss 1 (Dị Thú Tha Hoá).
## Quản lý các phase, cơ chế khóa máu 50%/20%, khiên bất hoại, và i-frames theo từng phase.

signal phase_changed(new_phase: int)
signal shield_broken
signal boss_defeated

@export var data: BossData
@export var melee_attack_data: AttackData
@export var shockwave_data: ShockwaveData
@export var magma_attack_data: AttackData = preload("res://resources/enemies/bosses/boss_1/boss_1_magma_attack.tres")
@export var fireball_scene: PackedScene

@export_group("Minion Scenes")
@export var grunt_scene: PackedScene = preload("res://entities/enemies/palace/enemy_1/enemy_1.tscn")
@export var shield_bearer_scene: PackedScene = preload("res://entities/enemies/palace/shield_bearer/shield_bearer.tscn")
@export var wisp_caster_scene: PackedScene = preload("res://entities/enemies/palace/wisp_caster/wisp_caster.tscn")

@export_group("Minion Summon - Phase 2 (50% HP)")
## Số lượng lính kiếm summon ở Phase 2
@export var phase2_grunt_count: int = 1
## Số lượng lính khiên summon ở Phase 2 (chắn đường trước mặt)
@export var phase2_shield_count: int = 1
## Số lượng pháp sư summon ở Phase 2
@export var phase2_caster_count: int = 0

@export_group("Minion Summon - Phase 3 (20% HP)")
## Số lượng lính kiếm summon ở Phase 3
@export var phase3_grunt_count: int = 2
## Số lượng lính khiên summon ở Phase 3
@export var phase3_shield_count: int = 1
## Số lượng pháp sư summon ở Phase 3
@export var phase3_caster_count: int = 1

@export_group("Minion Spawn & Roar Settings")
## Bán kính vòng tròn quanh Boss để xuất hiện quái phụ
@export var minion_spawn_radius: float = 4.5
## Bán kính tác động của tiếng gầm đẩy lùi người chơi
@export var roar_push_radius: float = 6.5
## Lực đẩy lùi người chơi
@export var roar_push_force: float = 14.0

@export_group("Hit Reaction")
## Màu nháy đỏ phủ lên Boss khi bị trúng đòn
@export var hit_flash_color: Color = Color(1.0, 0.15, 0.15, 0.75)
## Thời gian nháy đỏ mỗi hit (s)
@export var hit_flash_time: float = 0.12

@onready var _fireball_pool: ObjectPool = $FireballPool

var current_phase: int = 1
var is_shielded: bool = false
var shield_stacks: int = 0
var target_player: Node3D = null

var _melee_timer: float = 0.0
var _jump_slam_timer: float = 0.0
var _fireball_timer: float = 0.0
var _magma_stomp_timer: float = 0.0

var _gate_50_triggered: bool = false
var _gate_20_triggered: bool = false
var _is_current_anim_finished: bool = false
var _spawned_minions: Array[Node] = []

@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: HurtboxComponent = $HurtboxComponent
@onready var melee_hitbox: HitboxComponent = $Model/MeleeHitbox
@onready var shockwave: GroundShockwave = $GroundShockwave
@onready var radial_magma_hazard: Node3D = get_node_or_null(^"RadialMagmaHazard")
@onready var fireball_spawn: Marker3D = $Model/FireballSpawn
@onready var shield_sphere: MeshInstance3D = $ShieldSphere
@onready var aoe_indicator: Node3D = $AoeCircleIndicator
@onready var _shield_material: StandardMaterial3D = null

var _flash_material: StandardMaterial3D
var _model_meshes: Array[GeometryInstance3D] = []
var _flash_tween: Tween


func _ready() -> void:
	super._ready()
	assert(data != null, "Boss1 chưa được gán BossData!")
	
	health.max_health = data.max_health
	health.current_health = data.max_health
	
	# Cài đặt I-frame cho Phase 1
	hurtbox.invincibility_time = data.iframe_duration_normal
	hurtbox.hurt.connect(_on_hurtbox_hurt)
	health.died.connect(_on_died)
	
	if _anim:
		_anim.animation_finished.connect(_on_animation_finished)
	
	# Chuẩn bị material cho quả cầu khiên
	if shield_sphere:
		_shield_material = shield_sphere.get_active_material(0) as StandardMaterial3D
		if _shield_material == null:
			_shield_material = StandardMaterial3D.new()
			_shield_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_shield_material.cull_mode = BaseMaterial3D.CULL_DISABLED
			_shield_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			shield_sphere.material_override = _shield_material
		shield_sphere.visible = false
	
	# Chuẩn bị flash material cho hiệu ứng trúng đòn
	_flash_material = StandardMaterial3D.new()
	_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash_material.albedo_color = hit_flash_color
	
	if model:
		for node: Node in model.find_children("*", "GeometryInstance3D", true, false):
			_model_meshes.append(node as GeometryInstance3D)
	
	if melee_hitbox:
		melee_hitbox.monitoring = false
		melee_hitbox.monitorable = false
	
	# Ưu tiên kết nối signal player_spawned từ ZoneRoot để không quét cây scene mỗi frame.
	# Nếu chạy trực tiếp (F6 test), quét một lần duy nhất tại _ready.
	var zone := _find_zone_root()
	if zone:
		zone.player_spawned.connect(_on_player_spawned)
	else:
		_find_player_once()


func _on_player_spawned(p: Player) -> void:
	target_player = p
	# Khi player rời scene (ví dụ: reload) thì xoá tham chiếu
	p.tree_exiting.connect(_on_player_removed)


func _on_player_removed() -> void:
	target_player = null


func _find_zone_root() -> ZoneRoot:
	# Leo lên cây scene cho đến khi tìm thấy ZoneRoot; không quét toàn bộ cây
	var p: Node = get_parent()
	while p != null:
		if p is ZoneRoot:
			return p as ZoneRoot
		p = p.get_parent()
	return null


func _find_player_once() -> void:
	# Chỉ chạy một lần tại _ready, không chạy mỗi frame
	var players := get_tree().get_nodes_in_group(&"player")
	if not players.is_empty():
		target_player = players[0] as Node3D


func play_anim(anim_name: StringName) -> void:
	_is_current_anim_finished = false
	super.play_anim(anim_name)


func play_action(anim_name: StringName, speed: float = 1.0, blend: float = -1.0) -> void:
	_is_current_anim_finished = false
	super.play_action(anim_name, speed, blend)


func is_anim_finished() -> bool:
	return _is_current_anim_finished or (_anim != null and not _anim.is_playing())


func _on_animation_finished(_anim_name: StringName) -> void:
	_is_current_anim_finished = true


func _physics_process(delta: float) -> void:
	_melee_timer = maxf(_melee_timer - delta, 0.0)
	_jump_slam_timer = maxf(_jump_slam_timer - delta, 0.0)
	_fireball_timer = maxf(_fireball_timer - delta, 0.0)
	_magma_stomp_timer = maxf(_magma_stomp_timer - delta, 0.0)
	
	super._physics_process(delta)


## --- Quản lý Máu & Khóa Máu (Health Gating) ---

func _on_hurtbox_hurt(_info: DamageInfo, _damage_taken: int) -> void:
	# Nếu đang có khiên bảo vệ: Hồi lại máu ngay (miễn nhiễm sát thương tuyệt đối)
	if is_shielded:
		health.current_health = health.current_health + _damage_taken
		var fx: Node = get_node_or_null(^"/root/CombatFx")
		if fx and fx.has_method(&"spawn_hit"):
			fx.spawn_hit(global_position + Vector3(0, 1.5, 0), Vector3.UP)
		return
	
	# Hiệu ứng nháy đỏ model và tia lửa va chạm khi trúng đòn thực tế
	_flash_hit()
	var combat_fx: Node = get_node_or_null(^"/root/CombatFx")
	if combat_fx and combat_fx.has_method(&"spawn_hit"):
		combat_fx.spawn_hit(global_position + Vector3(0, 1.5, 0), Vector3.UP)
	
	var hp_ratio := float(health.current_health) / float(data.max_health)
	
	# Khóa máu ở mốc 50% (lần đầu chạm <= 50%)
	if not _gate_50_triggered and hp_ratio <= 0.50:
		_gate_50_triggered = true
		health.current_health = int(data.max_health * 0.50)
		current_phase = 2
		phase_changed.emit(2)
		state_machine.transition_to(&"Buff")
		return
	
	# Khóa máu ở mốc 20% (lần đầu chạm <= 20%) -> Chuyển Phase 3, hồi máu lên 40% (Aura Đỏ), kích hoạt x2 damage
	if not _gate_20_triggered and hp_ratio <= 0.20:
		_gate_20_triggered = true
		current_phase = 3
		phase_changed.emit(3)
		# Hồi phục sinh lực lên 40% Max HP theo cơ chế Aura Đỏ
		health.current_health = int(data.max_health * 0.40)
		print("[Boss1] Kích hoạt Khiên Bất Hoại Lần 2 & Hồi phục sinh lực lên 40% HP (Aura Đỏ)!")
		_apply_phase_3_damage_multiplier()
		state_machine.transition_to(&"Buff")
		return


func _apply_phase_3_damage_multiplier() -> void:
	if melee_attack_data:
		melee_attack_data.damage = data.melee_damage * data.damage_multiplier_phase3
	if shockwave_data:
		shockwave_data.damage = data.jump_slam_damage * data.damage_multiplier_phase3
	if magma_attack_data:
		magma_attack_data.damage = data.magma_stomp_damage * data.damage_multiplier_phase3


func _on_died() -> void:
	state_machine.transition_to(&"Dead")


func _flash_hit() -> void:
	if _model_meshes.is_empty() and model:
		for node: Node in model.find_children("*", "GeometryInstance3D", true, false):
			_model_meshes.append(node as GeometryInstance3D)
	
	if _flash_material == null:
		return
	
	_set_flash_overlay(true)
	if _flash_tween:
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_interval(hit_flash_time)
	_flash_tween.tween_callback(_set_flash_overlay.bind(false))


func _set_flash_overlay(on: bool) -> void:
	var mat: Material = _flash_material if on else null
	for mesh: GeometryInstance3D in _model_meshes:
		if is_instance_valid(mesh):
			mesh.material_overlay = mat


## --- Khiên Bất Tử & Phản Đòn Cầu Lửa ---

func activate_invulnerable_shield() -> void:
	is_shielded = true
	if current_phase == 2:
		shield_stacks = 1
	else:
		shield_stacks = 2 # Mốc 20% cần phản 2 lần
	
	_update_shield_visual()


func on_fireball_hit(_fireball: BossFireball) -> void:
	_crack_shield()


## Vụ nổ (TNT...) trúng boss: tính như một lần phản cầu lửa, để người chơi có cách khác phá khiên
func on_explosion_hit(_source: Node3D) -> void:
	_crack_shield()


## Khiên mất một lớp; hết lớp thì vỡ
func _crack_shield() -> void:
	if not is_shielded:
		return
	
	shield_stacks -= 1
	var shake: Node = get_node_or_null(^"/root/ScreenShake")
	if shake and shake.has_method(&"add_trauma"):
		shake.add_trauma(0.3)
	
	if shield_stacks > 0:
		# Đợt 2 trúng lần 1: Khiên bị nứt -> chuyển sang màu nhạt hơn
		_update_shield_visual()
	else:
		# Khiên vỡ hoàn toàn
		is_shielded = false
		if shield_sphere:
			shield_sphere.visible = false
		
		# Ở Phase cuối: Tắt hoàn toàn I-Frames theo yêu cầu
		if current_phase == 3:
			hurtbox.invincibility_time = 0.0
		
		shield_broken.emit()
		state_machine.transition_to(&"Idle")


func _update_shield_visual() -> void:
	if not shield_sphere or not _shield_material:
		return
	shield_sphere.visible = true
	
	if shield_stacks >= 2:
		# Khiên đợt 2 nguyên vẹn: Màu cam đậm rõ nét
		_shield_material.albedo_color = Color(1.0, 0.45, 0.1, 0.65)
	elif shield_stacks == 1 and current_phase == 3:
		# Khiên đợt 2 bị nứt: Nhạt màu hẳn đi
		_shield_material.albedo_color = Color(1.0, 0.6, 0.2, 0.22)
	else:
		# Khiên đợt 1 (50%): Độ đậm vừa phải
		_shield_material.albedo_color = Color(1.0, 0.45, 0.1, 0.50)


## --- Đòn Đánh & Kỹ Năng ---

func can_melee() -> bool:
	return _melee_timer <= 0.0


func start_melee_cooldown() -> void:
	if current_phase == 1:
		_melee_timer = data.melee_cooldown_phase1
	elif current_phase == 2:
		_melee_timer = data.melee_cooldown_phase2
	else:
		_melee_timer = data.melee_cooldown_phase3


func set_melee_hitbox_active(is_active: bool) -> void:
	if melee_hitbox:
		if is_active and melee_attack_data:
			melee_hitbox.activate(melee_attack_data, 0.55)
		else:
			melee_hitbox.deactivate()


func can_jump_slam() -> bool:
	return _jump_slam_timer <= 0.0 and is_on_floor()


func start_jump_slam_cooldown() -> void:
	if current_phase == 1:
		_jump_slam_timer = data.jump_slam_cooldown_phase1
	elif current_phase == 2:
		_jump_slam_timer = data.jump_slam_cooldown_phase2
	else:
		_jump_slam_timer = data.jump_slam_cooldown_phase3


func show_jump_indicator(target_pos: Vector3, radius: float, duration: float) -> void:
	if aoe_indicator:
		aoe_indicator.show_indicator(target_pos, radius, duration)


func hide_jump_indicator() -> void:
	if aoe_indicator:
		aoe_indicator.hide_indicator()


func trigger_ground_slam() -> void:
	if shockwave and shockwave_data:
		var slam_pos: Vector3 = global_position
		var space_state := get_world_3d().direct_space_state
		var query := PhysicsRayQueryParameters3D.create(
			global_position + Vector3.UP * 1.5,
			global_position + Vector3.DOWN * 10.0,
			1
		)
		var hit := space_state.intersect_ray(query)
		if not hit.is_empty():
			slam_pos.y = (hit["position"] as Vector3).y
		shockwave.launch(slam_pos, shockwave_data, self)
	var shake: Node = get_node_or_null(^"/root/ScreenShake")
	if shake and shake.has_method(&"add_trauma"):
		shake.add_trauma(0.5)


func can_magma_stomp() -> bool:
	return _magma_stomp_timer <= 0.0 and is_on_floor()


func start_magma_stomp_cooldown() -> void:
	if current_phase == 1:
		_magma_stomp_timer = data.magma_stomp_cooldown_phase1
	elif current_phase == 2:
		_magma_stomp_timer = data.magma_stomp_cooldown_phase2
	else:
		_magma_stomp_timer = data.magma_stomp_cooldown_phase3


func show_magma_indicators(duration: float) -> void:
	if radial_magma_hazard and radial_magma_hazard.has_method(&"show_telegraph"):
		radial_magma_hazard.show_telegraph(global_position, duration)


func hide_magma_indicators() -> void:
	if radial_magma_hazard and radial_magma_hazard.has_method(&"hide_telegraph"):
		radial_magma_hazard.hide_telegraph()


func trigger_magma_stomp() -> void:
	hide_magma_indicators()
	if radial_magma_hazard and magma_attack_data and radial_magma_hazard.has_method(&"launch"):
		radial_magma_hazard.launch(global_position, magma_attack_data)
	var shake: Node = get_node_or_null(^"/root/ScreenShake")
	if shake and shake.has_method(&"add_trauma"):
		shake.add_trauma(0.4)


func can_cast_fireball() -> bool:
	return _fireball_timer <= 0.0


func start_fireball_cooldown() -> void:
	if current_phase == 1:
		_fireball_timer = data.fireball_cooldown_phase1
	elif current_phase == 2:
		_fireball_timer = data.fireball_cooldown_phase2
	else:
		# Giãn cách 10s cho Phase 3 theo đúng yêu cầu
		_fireball_timer = data.fireball_cooldown_phase3


func get_current_anim_speed() -> float:
	if current_phase == 1:
		return data.anim_speed_phase1
	elif current_phase == 2:
		return data.anim_speed_phase2
	else:
		return data.anim_speed_phase3


func spawn_fireball() -> void:
	if _fireball_pool == null:
		return
	var fireball := _fireball_pool.acquire() as BossFireball
	if fireball == null:
		return
	
	var spawn_pos: Vector3 = fireball_spawn.global_position if fireball_spawn else global_position + Vector3(0, 1.5, 0)
	var shoot_dir: Vector3
	if is_instance_valid(target_player):
		shoot_dir = (target_player.global_position + Vector3(0, 0.9, 0)) - spawn_pos
	else:
		shoot_dir = get_facing_direction()
	
	# Kết nối một lần: khi fireball xong thì trả về pool
	if not fireball.finished.is_connected(_on_fireball_finished):
		fireball.finished.connect(_on_fireball_finished)
	fireball.launch(spawn_pos, shoot_dir.normalized(), self)


func _on_fireball_finished(fireball: BossFireball) -> void:
	# Trả fireball về pool thay vì queue_free
	_fireball_pool.release(fireball)


func get_current_walk_speed() -> float:
	if current_phase == 1:
		return data.walk_speed_phase1
	elif current_phase == 2:
		return data.walk_speed_phase2
	else:
		return data.walk_speed_phase3


func is_enraged() -> bool:
	return current_phase == 3


func perform_buff_roar() -> void:
	var shake: Node = get_node_or_null(^"/root/ScreenShake")
	if shake and shake.has_method(&"add_trauma"):
		shake.add_trauma(0.6)
	
	if is_instance_valid(target_player):
		var to_player: Vector3 = target_player.global_position - global_position
		to_player.y = 0.0
		var dist: float = to_player.length()
		if dist <= roar_push_radius and dist > 0.001:
			var push_dir: Vector3 = to_player.normalized()
			var player_receiver := target_player.get_node_or_null(^"WindReceiverComponent") as WindReceiverComponent
			if player_receiver:
				player_receiver.push(push_dir * roar_push_force)
			if target_player is CharacterBody3D:
				(target_player as CharacterBody3D).velocity += push_dir * (roar_push_force * 0.6)


func summon_minions_for_current_phase() -> void:
	var grunts: int = 0
	var shields: int = 0
	var casters: int = 0
	
	if current_phase == 2:
		grunts = phase2_grunt_count
		shields = phase2_shield_count
		casters = phase2_caster_count
	elif current_phase == 3:
		grunts = phase3_grunt_count
		shields = phase3_shield_count
		casters = phase3_caster_count
	
	var scenes_to_spawn: Array[PackedScene] = []
	if grunt_scene:
		for i in grunts:
			scenes_to_spawn.append(grunt_scene)
	if shield_bearer_scene:
		for i in shields:
			scenes_to_spawn.append(shield_bearer_scene)
	if wisp_caster_scene:
		for i in casters:
			scenes_to_spawn.append(wisp_caster_scene)
	
	var total: int = scenes_to_spawn.size()
	if total == 0:
		return
	
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	
	var angle_step: float = TAU / float(total)
	var base_angle: float = model.rotation.y if model else 0.0
	var fx: Node = get_node_or_null(^"/root/CombatFx")
	
	for i in total:
		var scene: PackedScene = scenes_to_spawn[i]
		var minion := scene.instantiate() as Node3D
		if minion == null:
			continue
		
		var angle: float = base_angle + float(i) * angle_step + randf_range(-0.15, 0.15)
		var offset: Vector3 = Vector3(sin(angle), 0.0, cos(angle)) * minion_spawn_radius
		var spawn_pos: Vector3 = global_position + offset
		
		parent_node.add_child(minion)
		minion.global_position = spawn_pos
		_spawned_minions.append(minion)
		
		minion.tree_exiting.connect(_on_minion_removed.bind(minion))
		
		if fx and fx.has_method(&"spawn_hit"):
			fx.spawn_hit(spawn_pos + Vector3(0, 1.0, 0), Vector3.UP)


func _on_minion_removed(minion: Node) -> void:
	_spawned_minions.erase(minion)


func on_death() -> void:
	collision_layer = 0
	collision_mask = 1 # Chỉ chặn sàn để không rơi
	if hurtbox:
		hurtbox.set_deferred(&"monitorable", false)
	
	# Tiêu diệt toàn bộ quái phụ được triệu hồi khi Boss bị hạ gục
	for minion in _spawned_minions.duplicate():
		if is_instance_valid(minion):
			var health_comp: HealthComponent = minion.get_node_or_null(^"HealthComponent") as HealthComponent
			if health_comp and not health_comp.is_dead():
				health_comp.take_damage(999)
			elif minion.has_method(&"queue_free"):
				minion.queue_free()
	_spawned_minions.clear()
	
	boss_defeated.emit()
