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

@export_group("Roar")
## Bán kính tác động của tiếng gầm đẩy lùi người chơi
@export var roar_push_radius: float = 6.5
## Lực đẩy lùi người chơi
@export var roar_push_force: float = 14.0

var current_phase: int:
	get:
		return health.current_phase
	set(value):
		health.current_phase = clampi(value, 1, 3)
		_refresh_attack_damage()
var is_shielded: bool:
	get:
		return health.is_shielded
	set(value):
		health.is_shielded = value
var shield_stacks: int:
	get:
		return health.shield_stacks
	set(value):
		health.shield_stacks = maxi(value, 0)
var target_player: Node3D = null


var _is_current_anim_finished: bool = false
var _tracked_animation: StringName
var _death_handled: bool = false
var _attacks: Dictionary[AttackData, AttackData] = {}
var _shockwave_base_damage: int = 0

@onready var minions: BossMinionController = $Minions
@onready var _cooldowns: BossCooldowns = $Cooldowns
@onready var _fireball_pool: ObjectPool = $FireballPool
@onready var action_selector: BossActionSelector = $ActionSelector
@onready var health: BossPhaseController = $HealthComponent
@onready var hurtbox: HurtboxComponent = $HurtboxComponent
@onready var melee_hitbox: HitboxComponent = $Model/MeleeHitbox
@onready var shockwave: GroundShockwave = $GroundShockwave
@onready var radial_magma_hazard: Node3D = get_node_or_null(^"RadialMagmaHazard")
@onready var fireball_spawn: Marker3D = $Model/FireballSpawn
@onready var shield_sphere: MeshInstance3D = $ShieldSphere
@onready var aoe_indicator: Node3D = $AoeCircleIndicator
@onready var _shield_material: StandardMaterial3D = null

func _ready() -> void:
	super._ready()
	assert(data != null, "Boss1 chưa được gán BossData!")
	
	movement = movement.duplicate() as MovementStats
	health.configure(data)
	health.phase_changed.connect(_on_phase_changed)
	melee_attack_data = get_attack_data(melee_attack_data)
	_shockwave_base_damage = shockwave_data.damage
	shockwave_data = shockwave_data.duplicate() as ShockwaveData
	magma_attack_data = get_attack_data(magma_attack_data)
	
	# Cài đặt I-frame cho Phase 1
	hurtbox.invincibility_time = data.iframe_duration_normal
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
		else:
			_shield_material = _shield_material.duplicate() as StandardMaterial3D
		shield_sphere.material_override = _shield_material
		shield_sphere.visible = false
	
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
	set_target_player(p)


func set_target_player(player: Node3D) -> void:
	target_player = player
	if player == null:
		return
	var callback: Callable = _on_player_removed.bind(player)
	if not player.tree_exiting.is_connected(callback):
		player.tree_exiting.connect(callback, CONNECT_ONE_SHOT)


func _on_player_removed(player: Node3D) -> void:
	if target_player == player:
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
		set_target_player(players[0] as Node3D)


func play_anim(anim_name: StringName) -> void:
	if _anim.current_animation == anim_name and _anim.is_playing():
		return
	_is_current_anim_finished = false
	_tracked_animation = anim_name
	_anim.play(anim_name, ANIM_BLEND, 1.0)


func play_action(anim_name: StringName, speed: float = 1.0, blend: float = -1.0) -> void:
	_is_current_anim_finished = false
	_tracked_animation = anim_name
	super.play_action(anim_name, speed, blend)


func is_anim_finished() -> bool:
	return _is_current_anim_finished or (_anim != null and not _anim.is_playing())


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == _tracked_animation:
		_is_current_anim_finished = true


func _on_phase_changed(phase: int) -> void:
	_refresh_attack_damage()
	movement.max_speed = get_current_walk_speed()
	phase_changed.emit(phase)
	state_machine.transition_to(&"Buff")


func get_damage_multiplier() -> int:
	return maxi(data.damage_multiplier_phase3, 0) if current_phase == 3 else 1


## Nhân bản một lần, giữ Resource nguồn bất biến giữa các instance.
func get_attack_data(source: AttackData) -> AttackData:
	if source == null:
		return null
	if _attacks.has(source):
		return _attacks[source]
	var runtime: AttackData = source.duplicate() as AttackData
	runtime.damage = source.damage * get_damage_multiplier()
	_attacks[source] = runtime
	return runtime


func _refresh_attack_damage() -> void:
	for source: AttackData in _attacks:
		_attacks[source].damage = source.damage * get_damage_multiplier()
	if shockwave_data:
		shockwave_data.damage = _shockwave_base_damage * get_damage_multiplier()


func _on_died() -> void:
	state_machine.transition_to(&"Dead")


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
	return _cooldowns.is_ready(&"Melee")


func start_melee_cooldown() -> void:
	_cooldowns.start_cooldown(&"Melee", data.get_phase_value(&"melee_cooldown", current_phase))

func set_melee_hitbox_active(is_active: bool, duration: float = -1.0) -> void:
	if melee_hitbox:
		if is_active and melee_attack_data:
			melee_hitbox.activate(melee_attack_data, duration)
		else:
			melee_hitbox.deactivate()


func can_jump_slam() -> bool:
	return _cooldowns.is_ready(&"JumpSlam") and is_on_floor()


func start_jump_slam_cooldown() -> void:
	_cooldowns.start_cooldown(&"JumpSlam", data.get_phase_value(&"jump_slam_cooldown", current_phase))

func show_jump_indicator(target_pos: Vector3, radius: float, duration: float) -> void:
	if aoe_indicator:
		aoe_indicator.show_indicator(target_pos, radius, duration)


func update_jump_indicator(target_pos: Vector3) -> void:
	if aoe_indicator:
		aoe_indicator.update_target(target_pos)


func hide_jump_indicator() -> void:
	if aoe_indicator:
		aoe_indicator.hide_indicator()


func trigger_ground_slam(snap_to_floor: bool = false) -> void:
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
		if snap_to_floor:
			global_position = slam_pos
		shockwave.launch(slam_pos, shockwave_data, self)
	var shake: Node = get_node_or_null(^"/root/ScreenShake")
	if shake and shake.has_method(&"add_trauma"):
		shake.add_trauma(0.5)


func can_magma_stomp() -> bool:
	return _cooldowns.is_ready(&"MagmaStomp") and is_on_floor()


func start_magma_stomp_cooldown() -> void:
	_cooldowns.start_cooldown(&"MagmaStomp", data.get_phase_value(&"magma_stomp_cooldown", current_phase))

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
	return _cooldowns.is_ready(&"Fireball")


func start_fireball_cooldown() -> void:
	_cooldowns.start_cooldown(&"Fireball", data.get_phase_value(&"fireball_cooldown", current_phase))

func get_current_anim_speed() -> float:
	return maxf(data.get_phase_value(&"anim_speed", current_phase), 0.01)


func spawn_fireball() -> void:
	if _fireball_pool == null or health.is_dead():
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
	fireball.launch(spawn_pos, shoot_dir.normalized(), self, get_damage_multiplier())


func _on_fireball_finished(fireball: BossFireball) -> void:
	# Trả fireball về pool thay vì queue_free
	_fireball_pool.release(fireball)


func get_current_walk_speed() -> float:
	return maxf(data.get_phase_value(&"walk_speed", current_phase), 0.0)


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
	minions.summon(current_phase)


func on_death() -> void:
	if _death_handled:
		return
	_death_handled = true
	melee_hitbox.deactivate()
	hide_jump_indicator()
	shield_sphere.visible = false
	health.is_shielded = false
	shockwave.stop(true)
	if radial_magma_hazard:
		radial_magma_hazard.cancel()
	_fireball_pool.release_all()
	_cooldowns.stop_all()
	collision_layer = 0
	collision_mask = 1 # Chỉ chặn sàn để không rơi
	if hurtbox:
		hurtbox.set_deferred(&"monitorable", false)
	
	minions.clear()
	boss_defeated.emit()
