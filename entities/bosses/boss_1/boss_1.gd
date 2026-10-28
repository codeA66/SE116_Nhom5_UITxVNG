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
@export var fireball_scene: PackedScene

@onready var _fireball_pool: ObjectPool = $FireballPool

var current_phase: int = 1
var is_shielded: bool = false
var shield_stacks: int = 0
var target_player: Node3D = null

var _melee_timer: float = 0.0
var _jump_slam_timer: float = 0.0
var _fireball_timer: float = 0.0

var _gate_50_triggered: bool = false
var _gate_20_triggered: bool = false
var _is_current_anim_finished: bool = false

@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: HurtboxComponent = $HurtboxComponent
@onready var melee_hitbox: HitboxComponent = $Model/MeleeHitbox
@onready var shockwave: GroundShockwave = $GroundShockwave
@onready var fireball_spawn: Marker3D = $Model/FireballSpawn
@onready var shield_sphere: MeshInstance3D = $ShieldSphere
@onready var aoe_indicator: Node3D = $AoeCircleIndicator
@onready var _shield_material: StandardMaterial3D = null


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
		state_machine.transition_to(&"Stunned")


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
		shockwave.launch(global_position, shockwave_data, self)
	var shake: Node = get_node_or_null(^"/root/ScreenShake")
	if shake and shake.has_method(&"add_trauma"):
		shake.add_trauma(0.5)


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


func on_death() -> void:
	collision_layer = 0
	collision_mask = 1 # Chỉ chặn sàn để không rơi
	if hurtbox:
		hurtbox.set_deferred(&"monitorable", false)
	boss_defeated.emit()
