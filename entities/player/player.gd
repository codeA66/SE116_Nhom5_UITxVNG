class_name Player
extends Character
## Player: đọc input theo hướng camera, coyote time, các input buffer, nhặt vũ khí, mở khóa kỹ năng.
## Vũ khí và kỹ năng thuộc tiến trình (GameState), không lưu trong player: chuyển scene không bị mất.

## Vừa bắn cung, bắt đầu thời gian hồi (HUD nghe để hiện, không phải dò mỗi frame)
signal bow_cooldown_started(duration: float)
signal bow_projectile_fired(primary: bool)
## Độ kéo cung 0..1 mỗi lần đổi (VFX báo tiến độ / đã đầy); về 0 khi bắn xong hoặc thôi nhắm
signal bow_draw_progress(amount: float)
## Thả sớm khi chưa kéo đủ: phát này bị hủy, không bắn (VFX khói báo cho người chơi)
signal bow_draw_cancelled
signal bow_enemy_hit
signal bow_enemy_hit_contact(hurtbox: HurtboxComponent, position: Vector3, direction: Vector3)
signal targetability_changed(targetable: bool)
## Vừa dùng kỹ năng gió, bắt đầu thời gian hồi (tính cả thời gian ra đòn)
signal wind_blast_cooldown_started(duration: float)
## Vừa dùng một kỹ năng chủ động bất kỳ (SkillData), bắt đầu thời gian khoá của nó
signal skill_cooldown_started(skill_id: StringName, duration: float)
## Một nhát cận chiến vừa bật khi vũ khí đang ghép nguyên tố element_id (VFX kiếm Lửa / Băng... tự lọc theo id).
## Nhát cuối combo: combo_index == combo_size - 1. Chung cho mọi nguyên tố để thêm nguyên tố mới không sửa Player
signal fusion_melee_swing(element_id: StringName, attack: AttackData, combo_index: int, combo_size: int, direction: Vector3, active_time: float)
## Độ kéo cung (0..1) khi cung đang ghép nguyên tố element_id (VFX tụ lửa / băng... tự lọc theo id)
signal fusion_bow_draw(element_id: StringName, amount: float)
## Vừa buông dây bắn khi cung đang ghép element_id
signal fusion_bow_released(element_id: StringName)
## Cất cung (sau khi bắn hoặc huỷ kéo) khi cung đang ghép element_id: VFX tắt hẳn
signal fusion_bow_aim_ended(element_id: StringName)
signal combat_action_committed(element_id: StringName, skill_id: StringName)

## Chỉ số cộng thêm vào máu tối đa (StatBonusEffect.stat)
const MAX_HEALTH_STAT := &"max_health"
const MAX_ENERGY_STAT: StringName = &"max_energy"
const WEAPON_DAMAGE_BONUS_STAT: StringName = &"weapon_damage_bonus"
const BOW_EXTRA_PROJECTILES_STAT: StringName = &"bow_extra_projectiles"
const MAX_BOW_VOLLEY_PROJECTILES: int = 8
const MAX_BOW_VOLLEY_RESERVE: int = 64
const BOW_VOLLEY_PREWARM_COUNT: int = 2
const BOW_VOLLEY_TICK_EPSILON: float = 0.001
const ANIM_IDLE := &"Rig_Medium_General/Idle_A"
const ANIM_RUN := &"Rig_Medium_MovementBasic/Running_A"
const ANIM_JUMP := &"Rig_Medium_MovementBasic/Jump_Start"
const ANIM_FALL := &"Rig_Medium_MovementBasic/Jump_Idle"
const ANIM_PICK_UP := &"Rig_Medium_General/PickUp"
const ANIM_HURT := &"Rig_Medium_General/Hit_A"
const ANIM_DEATH := &"Rig_Medium_General/Death_A"

@export_group("Input Feel")
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.12
@export var attack_buffer_time: float = 0.25
## Không ngắn hơn cancel_start của đòn chém: bấm dash sớm trong đòn vẫn được giữ tới lúc hủy được
@export var dash_buffer_time: float = 0.2
## Buffer phím kỹ năng (mọi SkillData: Gió, Lửa...). Giữ tên cũ để scene đã chỉnh số không mất giá trị
@export var wind_blast_buffer_time: float = 0.15

@export_group("Fall Recovery")
## Thời gian bất tử sau khi được đưa về chỗ an toàn
@export var recovery_invincibility: float = 1.0
## Số frame trên đất liên tục không gió trước khi một vị trí được coi là an toàn
@export var safe_ground_frames: int = 8

@export_group("Damage Feedback")
## Chu kỳ nháy hình trong lúc bất tử sau khi bị đánh
@export var blink_interval: float = 0.08
## Nháy đỏ trước khi chết vì bẫy chết người (gai...); màu phủ lên model
@export var lethal_flash_color: Color = Color(1.0, 0.12, 0.1, 0.65)
@export var lethal_flash_time: float = 0.4

@export_group("Combat")
## Bán kính tìm mục tiêu để tự quay về khi ra đòn
@export var soft_lock_range: float = 4.0
## Góc lệch tối đa (độ) giữa hướng input và mục tiêu để được soft-lock
@export var soft_lock_angle: float = 60.0
## Mức dự trữ tối thiểu; pool được làm nóng thêm theo số phát và thời gian tên tồn tại.
@export var arrow_pool_size: int = 4
## Chuẩn bị cả vũ khí chưa nhặt, không cấp vũ khí cho tiến trình.
@export var combat_weapons: Array[WeaponData] = [preload("res://resources/combat/weapons/bow.tres")]
## Khi nhắm cung, người quay nghiêng bấy nhiêu độ để vai trái hướng về mục tiêu như cung thủ;
## cung và mũi tên vẫn theo đúng hướng nhắm. Model nhìn theo +Z nên bên trái là +X. 0 = đứng thẳng mặt
@export_range(-180.0, 180.0, 0.5) var bow_stance_degrees: float = 90.0

@export_group("Bow Volley")
@export_range(0.0, 1.0, 0.01, "or_greater") var bow_volley_interval: float = 0.20
@export_range(1, 8) var bow_volley_limit: int = 8

## Đòn đánh gần nhất trúng player, state Hurt dùng để lấy hướng đẩy lùi
## Tắt khi cutscene / hội thoại: bỏ qua mọi phím (đi, nhảy, đánh, dash, gió, tương tác, đổi vũ khí).
## Vật lý vẫn chạy nên đứng trên thuyền / bệ vẫn được chở đi. Đổi bằng set_controls_enabled()
var controls_enabled: bool = true
var _terrain_speed_scales: Dictionary[Node, float] = {}
var _terrain_speed: float = 1.0
var last_hit: DamageInfo
## Lúc nhận đòn làm khựng gần nhất (ms, Time.get_ticks_msec): hai đòn liền nhau thì bị hất ngã
var _last_stagger_msec: int = -1000000
## Vũ khí đang chờ gắn vào tay trong state PickUp
var pending_weapon: WeaponData
## Bấm đổi trong một hành động: thực hiện sau khi hành động kết thúc.
var _requested_weapon_slot: int = -1

var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _attack_buffer_timer: float = 0.0
var _dash_buffer_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _air_dashes_used: int = 0
## Buffer phím và thời gian khoá theo id kỹ năng: thêm kỹ năng mới không cần thêm biến
var _skill_buffers: Dictionary[StringName, float] = {}
var _skill_cooldowns: Dictionary[StringName, float] = {}
var _bow_cooldown_timer: float = 0.0
## Vị trí trên đất cuối cùng không bị gió đẩy, dùng khi rơi xuống vực
var _last_safe_position: Vector3
## Vị trí trên đất của các frame gần nhất (không gió), phần tử đầu là cũ nhất
var _recent_floor_positions: Array[Vector3] = []
var _blink_time_left: float = 0.0
var _blink_clock: float = 0.0
## Lần chết này có nháy đỏ trước không (state Dead đọc một lần)
var _lethal_flash_pending: bool = false
var _local_respawn: Callable
## Checkpoint loé sáng khi cảnh hồi sinh bắt đầu (begin_respawn -> state Respawn)
var _revive_anchor: Node3D
var _flash_material: StandardMaterial3D
var _model_meshes: Array[MeshInstance3D] = []
var _flash_tween: Tween
## Bảng UI đang mở và dùng chuột (tủ đồ): chuột trái cũng là nút đánh nên phải bỏ qua, nếu không kéo thả sẽ chém
var _attack_blocked_by_ui: bool = false
## Mỗi cơ chế giữ khóa riêng; thả vật không vô tình gỡ khóa của UI hay cơ chế khác.
var _combat_locks: Dictionary[Node, bool] = {}
## Mỗi cơ chế giữ khóa dash riêng (dính tơ nhện...); thả vật không vô tình gỡ khóa của cơ chế khác.
var _dash_locks: Dictionary[Node, bool] = {}
## Mỗi cơ chế giữ khóa trói chân riêng (xích lửa boss...): khóa di chuyển, roll & nhảy nhưng vẫn đánh/cung/skill tại chỗ.
var _root_locks: Dictionary[Node, bool] = {}
var _targetability_locks: Dictionary[Node, bool] = {}
var _damage_protection: Dictionary[Node, bool] = {}
var _previous_invulnerable: bool = false
## Model cung đang gắn ở BowHold (tạo một lần, ẩn khi không nhắm) và scene đã dùng để tạo nó
var _bow_model: Node3D
var _bow_model_scene: PackedScene
## Pool đạn theo scene thuộc player; mỗi mũi tên top_level nên không đi theo người.
var _projectile_pools: Dictionary[PackedScene, ObjectPool] = {}
var _projectile_fusions: Dictionary[ArrowProjectile, FusionData] = {}
var _bow_imbues: Dictionary[StringName, FusionData] = {}
var _active_bow_imbue: FusionData
var _weapon_damage_projectiles: Dictionary[ArrowProjectile, bool] = {}
var _last_volley_weapon: BowData
var _last_volley_count: int = -1
var _bow_volley_weapon: BowData
var _bow_volley_direction: Vector3
var _bow_volley_speed: float = 0.0
var _bow_volley_damage: int = 0
var _bow_volley_left: int = 0
var _bow_volley_sent: int = 0
var _fusion_pools: Dictionary[FusionEffect, Dictionary] = {}
var _combat_prepared: bool = false
## Máu tối đa gốc trong scene, chưa tính bùa
var _base_max_health: int = 0
var _fusion_table: FusionTable
var _fusion_warmup_sources: Array[Node] = []
var _fusion_warmup_prepared: bool = false

@onready var energy: EnergyComponent = $EnergyComponent
## Hệ số chỉ số từ bùa / buff (tốc độ chém...); nơi dùng tự đọc lúc cần
@onready var stats: StatModifiers = $StatModifiers
@onready var hitbox: HitboxComponent = $Model/Hitbox
@onready var wind_blast: WindBlastArea = $Model/WindBlastArea
@onready var interactor: InteractorComponent = $Interactor
@onready var health: HealthComponent = $HealthComponent
@onready var _charms: CharmHolder = $CharmHolder
@onready var _hurtbox: HurtboxComponent = $HurtboxComponent
@onready var _camera_rig: CameraRig = $CameraRig
@onready var _camera: Camera3D = $CameraRig/Camera3D
@onready var _weapon_socket: Node3D = $WeaponSocket
@onready var _arrow_spawn: Marker3D = $Model/ArrowSpawn
## Chỗ đặt cung khi nhắm (cầm ngang trước ngực), xoay theo model
@onready var _bow_hold: Node3D = $Model/BowHold
@onready var _bow_volley_timer: Timer = $BowVolleyTimer


func _ready() -> void:
	super()
	_bow_volley_timer.timeout.connect(_on_bow_volley_timeout)
	add_to_group(ShaderWarmup.SOURCE_GROUP)
	hitbox.hit.connect(_on_hitbox_hit)
	GameState.weapon_changed.connect(_attach_weapon_model)
	GameState.progress_changed.connect(_warm_bow_volley_pool)
	GameState.progress_replaced.connect(_on_progress_replaced)
	# Vào scene mới: gắn lại vũ khí đã có trong tiến trình
	_attach_weapon_model(GameState.get_weapon())
	_last_safe_position = global_position
	# Áp bùa trước khi khôi phục máu cũ: máu giữ qua khu vượt mức gốc (bùa thêm máu) không bị kẹp mất
	_base_max_health = health.max_health
	stats.changed.connect(_on_stat_changed)
	_charms.refresh()
	# Máu được giữ qua các lần chuyển khu (player là object mới mỗi khu)
	var kept_health := GameState.get_player_health()
	if kept_health > 0:
		health.set_current_health(kept_health)
	# Năng lượng cũng giữ qua các lần chuyển khu
	var kept_energy := GameState.get_player_energy()
	if kept_energy >= 0:
		energy.set_current(kept_energy)
	energy.energy_changed.connect(_on_energy_changed)
	# Giá trị giữ qua khu phải khớp mức đã kẹp sau khi áp bùa.
	GameState.set_player_energy(energy.current)
	health.health_changed.connect(_on_health_changed)
	health.died.connect(_on_died)
	_hurtbox.hurt.connect(_on_hurt)
	# Chỉ chạy _process khi đang nháy hình
	set_process(false)
	prepare_for_combat()


func prepare_for_combat() -> void:
	if _combat_prepared:
		return
	_combat_prepared = true
	# Nạp lúc chạy để tránh vòng preload FusionTable -> FusionEffect -> Player.
	_fusion_table = load("res://resources/combat/fusion/fusion_table.tres") as FusionTable
	var weapons: Array[WeaponData] = combat_weapons.duplicate()
	weapons.append_array(GameState.progress.weapons)
	for weapon in weapons:
		if weapon == null:
			continue
		if weapon.projectile_scene:
			_get_projectile_pool(weapon.projectile_scene)
		if weapon is BowData:
			_prepare_bow_model(weapon)
	FusionEffect.prepare_loaded_effects(self)
	_warm_bow_volley_pool()


## Pool thuộc player để tự dọn khi đổi khu; hiệu ứng đặt top_level để không đi theo player.
func get_fusion_pool(effect: FusionEffect, scene: PackedScene, count: int, configure: Callable = Callable()) -> ObjectPool:
	if not _fusion_pools.has(effect):
		_fusion_pools[effect] = {}
	var pools: Dictionary = _fusion_pools[effect]
	var pool: ObjectPool = pools.get(scene)
	if is_instance_valid(pool):
		return pool
	pool = ObjectPool.new()
	pool.name = "FusionPool"
	pool.scene = scene
	pool.initial_size = maxi(count, 0)
	pool.configure_instance = _configure_fusion_instance.bind(configure, pool)
	pools[scene] = pool
	add_child(pool)
	return pool


func _configure_fusion_instance(node: Node, configure: Callable, pool: ObjectPool) -> void:
	if configure.is_valid():
		configure.call(node)
	assert(node.has_signal(&"finished"), "Hiệu ứng dùng pool phải phát finished khi kết thúc")
	node.connect(&"finished", pool.release.bind(node))


## Mọi fusion đăng ký đều được chuẩn bị khi nạp khu, kể cả kỹ năng chưa nhặt.
## Nguồn thuộc Player để được dọn tự động khi rời khu; không quét trong vòng lặp nóng.
func get_shader_warmup_sources() -> Array[Node]:
	if not _fusion_warmup_prepared:
		_fusion_warmup_prepared = true
		for source: Node in FusionEffect.collect_shader_warmup_sources():
			add_child(source)
			if source.has_method(&"prepare_shader_warmup"):
				source.call(&"prepare_shader_warmup")
			# Chỉ bản sao của ShaderWarmup hoạt động; nguồn không chạy hạt/vật lý mỗi frame.
			source.process_mode = Node.PROCESS_MODE_DISABLED
			if source is Node3D:
				(source as Node3D).visible = false
			_fusion_warmup_sources.append(source)
		for pools: Dictionary in _fusion_pools.values():
			for pool: ObjectPool in pools.values():
				for instance: Node in pool.get_children():
					if instance.has_method(&"prepare_shader_warmup"):
						instance.call(&"prepare_shader_warmup")
				_fusion_warmup_sources.append(pool)
	return _fusion_warmup_sources


func _process(delta: float) -> void:
	_blink_time_left -= delta
	if _blink_time_left <= 0.0:
		_stop_blink()
		return
	_blink_clock += delta
	model.visible = fmod(_blink_clock, blink_interval * 2.0) >= blink_interval


func set_controls_enabled(enabled: bool) -> void:
	controls_enabled = enabled
	if not enabled:
		cancel_bow_volley()
		# Xoá lệnh đang chờ trong buffer: thả khoá xong không tự bật đòn đã bấm lúc bị khoá
		_jump_buffer_timer = 0.0
		_attack_buffer_timer = 0.0
		_dash_buffer_timer = 0.0
		_skill_buffers.clear()
		_requested_weapon_slot = -1


func get_move_direction() -> Vector3:
	if not controls_enabled:
		return Vector3.ZERO
	# get_vector đã chuẩn hóa: đi chéo không nhanh hơn, có deadzone cho tay cầm
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var cam_basis := _camera.global_basis
	var forward := Vector3(-cam_basis.z.x, 0.0, -cam_basis.z.z).normalized()
	var right := Vector3(cam_basis.x.x, 0.0, cam_basis.x.z).normalized()
	return right * input.x - forward * input.y


func get_slip_steering() -> Vector3:
	return get_move_direction()


func get_slip_recovery_state() -> StringName:
	if health.is_dead(): return &"Dead"
	if not is_on_floor(): return &"Fall"
	return &"Idle" if get_move_direction().is_zero_approx() else &"Run"


func play_slip_animation() -> void:
	play_action(ANIM_HURT)


## Hướng ngang từ player tới điểm con trỏ chuột chỉ trên mặt phẳng ngang ở độ cao chân player.
## Trả về Vector3.ZERO nếu không xác định được (chuột ngoài cửa sổ, tia song song mặt phẳng, chuột trùng chân player)
func get_mouse_aim_direction() -> Vector3:
	# Chạy headless (test tự động) không có chuột thật: vị trí chuột vô nghĩa, để state dùng hướng phím
	if DisplayServer.get_name() == "headless":
		return Vector3.ZERO
	var hit: Vector3 = project_cursor_to_height(get_viewport().get_mouse_position(), global_position.y)
	if not hit.is_finite():
		return Vector3.ZERO
	var offset: Vector3 = hit - global_position
	offset.y = 0.0
	return offset.normalized() if offset.length() > 0.05 else Vector3.ZERO


func project_cursor_to_height(cursor: Vector2, height: float) -> Vector3:
	var origin: Vector3 = _camera.project_ray_origin(cursor)
	var direction: Vector3 = _camera.project_ray_normal(cursor)
	var point: Variant = Plane(Vector3.UP, height).intersects_ray(origin, direction)
	return Vector3.INF if point == null else point as Vector3


func can_start_ground_cast() -> bool:
	if not controls_enabled or _attack_blocked_by_ui or combat_locked() or root_locked():
		return false
	if health.is_dead() or SceneManager.is_busy() or not is_on_floor() or state_machine.current_state == null:
		return false
	return state_machine.current_state.name in [PlayerState.IDLE, PlayerState.RUN]


func is_targetable() -> bool:
	return _targetability_locks.is_empty() and (health == null or not health.is_dead())


func set_targetability_block(source: Node, blocked: bool) -> void:
	var was_targetable: bool = is_targetable()
	if blocked:
		_targetability_locks[source] = true
	else:
		_targetability_locks.erase(source)
	if is_targetable() != was_targetable:
		targetability_changed.emit(is_targetable())


func set_damage_protection(source: Node, enabled: bool) -> void:
	if enabled:
		if _damage_protection.is_empty():
			_previous_invulnerable = _hurtbox.invulnerable
		_damage_protection[source] = true
		_hurtbox.invulnerable = true
	elif _damage_protection.erase(source) and _damage_protection.is_empty():
		_hurtbox.invulnerable = _previous_invulnerable


## Đúng khi có jump buffer, còn coyote time và không bị trói chân
func can_jump() -> bool:
	return not root_locked() and _jump_buffer_timer > 0.0 and _coyote_timer > 0.0


func jump() -> void:
	super()
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0


func get_weapon() -> WeaponData:
	return GameState.get_weapon()


func has_weapon() -> bool:
	return get_weapon() != null


func get_weapon_damage_bonus(origin: Node, attack: AttackData) -> int:
	if health.is_dead():
		return 0
	if origin == hitbox:
		var weapon: WeaponData = get_weapon()
		if weapon == null or weapon.slot != WeaponData.Slot.SWORD or weapon.is_ranged() or not weapon.combo.has(attack):
			return 0
	elif not origin is ArrowProjectile or not _weapon_damage_projectiles.has(origin):
		return 0
	return maxi(roundi(stats.get_bonus(WEAPON_DAMAGE_BONUS_STAT)), 0)


## Đúng khi đang cầm vũ khí, có lệnh đánh trong buffer và đủ năng lượng (cung tiêu năng lượng mỗi phát)
func can_attack() -> bool:
	return not combat_locked() and has_weapon() and not get_weapon().combo.is_empty() and _attack_buffer_timer > 0.0 \
		and energy.can_spend(get_weapon().energy_cost)


## Buff ghép của vũ khí đang cầm; null nếu chưa ghép
func get_fusion() -> FusionData:
	return GameState.get_active_fusion()


## State Attack báo hitbox cận chiến vừa bật: chạy các buff nguyên tố của vũ khí (nhát cuối phóng gió, phản đạn...)
func notify_melee_active(attack: AttackData, combo_index: int, combo_size: int, direction: Vector3, active_time: float) -> void:
	var fusion := get_fusion()
	var element_id: StringName = fusion.element.id if fusion and fusion.element else &""
	combat_action_committed.emit(element_id, &"")
	if fusion == null:
		return
	for effect in fusion.effects:
		effect.on_melee_active(self, attack, combo_index, combo_size, direction, active_time)
	if fusion.element:
		fusion_melee_swing.emit(fusion.element.id, attack, combo_index, combo_size, direction, active_time)


## Bảng UI dùng chuột đang mở thì không nhận nút đánh (chuột trái)
func set_attack_blocked_by_ui(blocked: bool) -> void:
	_attack_blocked_by_ui = blocked
	if blocked:
		_attack_buffer_timer = 0.0


func consume_attack_input() -> void:
	_attack_buffer_timer = 0.0


## Khóa tấn công/cung/kỹ năng chủ động; vẫn đi, nhảy, dash và tương tác khi mang vật.
func set_combat_locked(source: Node, locked: bool) -> void:
	if locked:
		_combat_locks[source] = true
		var release := _release_combat_lock.bind(source)
		if not source.tree_exiting.is_connected(release):
			source.tree_exiting.connect(release, CONNECT_ONE_SHOT)
		_attack_buffer_timer = 0.0
		_skill_buffers.clear()
	else:
		_release_combat_lock(source)


func combat_locked() -> bool:
	return not _combat_locks.is_empty()


## Khóa dash (dính tơ nhện...); vẫn đi, nhảy, đánh và dùng kỹ năng. Xóa luôn lệnh dash đang chờ trong buffer.
## source tự được gỡ khóa khi rời cây (nguồn bị xóa thì không kẹt khóa mãi)
func set_dash_locked(source: Node, locked: bool) -> void:
	if locked:
		_dash_locks[source] = true
		var release := _release_dash_lock.bind(source)
		if not source.tree_exiting.is_connected(release):
			source.tree_exiting.connect(release, CONNECT_ONE_SHOT)
		_dash_buffer_timer = 0.0
	else:
		_release_dash_lock(source)


func dash_locked() -> bool:
	return not _dash_locks.is_empty()


## Trói chân (xích lửa boss...): khóa di chuyển, roll (Shift) và nhảy, vẫn cho đánh/bắn cung/dùng chiêu E tại chỗ.
## Tự gỡ khi source rời cây để không bao giờ kẹt trói vĩnh viễn.
func set_root_locked(source: Node, locked: bool) -> void:
	if locked:
		_root_locks[source] = true
		var release := _release_root_lock.bind(source)
		if not source.tree_exiting.is_connected(release):
			source.tree_exiting.connect(release, CONNECT_ONE_SHOT)
		set_terrain_speed(source, 0.0)
		set_dash_locked(source, true)
		_jump_buffer_timer = 0.0
		velocity.x = 0.0
		velocity.z = 0.0
		if state_machine.current_state and state_machine.current_state.name in [PlayerState.DASH, PlayerState.JUMP]:
			state_machine.transition_to(PlayerState.IDLE if is_on_floor() else PlayerState.FALL)
	else:
		_release_root_lock(source)


func root_locked() -> bool:
	return not _root_locks.is_empty()


func _release_root_lock(source: Node) -> void:
	_root_locks.erase(source)
	set_terrain_speed(source, 1.0)
	set_dash_locked(source, false)
	var release := _release_root_lock.bind(source)
	if is_instance_valid(source) and source.tree_exiting.is_connected(release):
		source.tree_exiting.disconnect(release)


func _release_dash_lock(source: Node) -> void:
	_dash_locks.erase(source)
	var release := _release_dash_lock.bind(source)
	if is_instance_valid(source) and source.tree_exiting.is_connected(release):
		source.tree_exiting.disconnect(release)


func _release_combat_lock(source: Node) -> void:
	_combat_locks.erase(source)
	var release := _release_combat_lock.bind(source)
	if is_instance_valid(source) and source.tree_exiting.is_connected(release):
		source.tree_exiting.disconnect(release)


## Gọi từ vật phẩm khi được tương tác: chuyển sang state nhặt, vũ khí gắn vào tay trong lúc nhặt
func pick_up_weapon(data: WeaponData) -> void:
	# Lưu quyền sở hữu ngay khi nhặt, kể cả khi animation bị ngắt.
	GameState.add_weapon(data)
	pending_weapon = data
	state_machine.transition_to(PlayerState.PICK_UP)


func equip_weapon(data: WeaponData) -> void:
	pending_weapon = null
	# Cung là vũ khí phụ: chỉ cần sở hữu (đã thêm lúc nhặt), không thay vũ khí chính đang cầm
	if data is BowData:
		GameState.add_weapon(data)
		return
	GameState.set_weapon(data)


## Cung đã nhặt (vũ khí phụ, dùng bằng phím aim); null nếu chưa có
func get_bow() -> BowData:
	return GameState.get_weapon_in_slot(WeaponData.Slot.BOW) as BowData


func is_holding_aim() -> bool:
	return controls_enabled and Input.is_action_pressed(&"aim")


## Đúng khi đang giữ phím aim, có cung bắn được, đã hết thời gian hồi và đủ năng lượng cho một phát.
## Thiếu năng lượng thì không cho kéo: trước đây vẫn kéo được rồi thả ra không bắn, người chơi tưởng lỗi
func can_aim_bow() -> bool:
	var bow := get_bow()
	return not combat_locked() and bow != null and bow.is_ranged() and not bow.combo.is_empty() and is_holding_aim() \
			and _bow_cooldown_timer <= 0.0 and energy.can_spend(bow.energy_cost)


## Hiện cung ở BowHold và bắt đầu tư thế kéo dây
func begin_bow_aim() -> void:
	var bow := get_bow()
	if bow == null or bow.model_scene == null:
		return
	_prepare_bow_model(bow)
	# Cung nằm ngang, bụng cung chĩa theo hướng nhắm (không theo mặt nhân vật khi đứng nghiêng)
	var forward := _get_bow_aim_local()
	var limbs := Vector3.UP.cross(forward)
	_bow_hold.basis = Basis(limbs.cross(forward), limbs, forward)
	_bow_model.visible = true
	if _bow_model is BowVisual:
		# Tắt cụm tụ lực mặc định của model cung (sao, vòng co): tín hiệu kéo / đầy giờ do BowDrawFeedback lo
		# (mũi tên chỉ hướng đổi màu kiểu Death's Door); để cả hai thì quanh cung rối mắt
		(_bow_model as BowVisual).default_charge_enabled = false
		(_bow_model as BowVisual).set_aiming(true)
	play_action(bow.draw_animation, 0.0)
	set_bow_draw(0.0)


## Hướng bắn của cung (thế giới, mặt phẳng ngang) theo cách đứng hiện tại
func get_bow_aim_direction() -> Vector3:
	var direction := model.global_basis * _get_bow_aim_local()
	direction.y = 0.0
	return direction.normalized()


## Xoay người để hướng bắn của cung (không phải mặt) chỉ về direction. rate < 0 = xoay ngay
func turn_bow_toward(direction: Vector3, rate: float, delta: float) -> void:
	if direction.is_zero_approx():
		return
	var target := atan2(direction.x, direction.z) - deg_to_rad(bow_stance_degrees)
	model.rotation.y = target if rate < 0.0 else lerp_angle(model.rotation.y, target, 1.0 - exp(-rate * delta))


## Một lần nhả dây chỉ tiêu năng lượng và phát hồi cung một lần, dù có nhiều mũi tên.
func shoot_bow(draw: float) -> void:
	cancel_bow_volley()
	var bow := get_bow()
	if bow == null:
		return
	# Cung tiêu năng lượng mỗi phát (luật của nhánh energy-fusion); thiếu thì spend() tự báo và không bắn
	if not energy.spend(bow.energy_cost):
		return
	_bow_volley_weapon = bow
	_bow_volley_direction = get_bow_aim_direction()
	_bow_volley_speed = bow.get_shot_speed(draw)
	_bow_volley_damage = bow.get_shot_damage(draw)
	_bow_volley_left = get_bow_projectile_count() - 1
	_bow_volley_sent = 1
	_fire_bow_projectile(bow, _bow_volley_direction, _bow_volley_speed, _bow_volley_damage, true)
	_schedule_bow_followup()
	_bow_cooldown_timer = bow.shot_cooldown
	if bow.shot_cooldown > 0.0:
		bow_cooldown_started.emit(bow.shot_cooldown)


func get_bow_projectile_count() -> int:
	var limit: int = clampi(bow_volley_limit, 1, MAX_BOW_VOLLEY_PROJECTILES)
	var extra: float = clampf(stats.get_bonus(BOW_EXTRA_PROJECTILES_STAT), 0.0, float(limit - 1))
	return 1 + roundi(extra)


func has_pending_bow_shots() -> bool:
	return _bow_volley_left > 0


func shoot_bow_followup() -> bool:
	if not has_pending_bow_shots():
		return false
	if health.is_dead() or not controls_enabled or get_bow() != _bow_volley_weapon or _bow_volley_sent >= get_bow_projectile_count():
		cancel_bow_volley()
		return false
	_bow_volley_left -= 1
	_bow_volley_sent += 1
	_fire_bow_projectile(_bow_volley_weapon, _bow_volley_direction, _bow_volley_speed, _bow_volley_damage, false)
	if _bow_volley_left == 0:
		cancel_bow_volley()
	return true


func cancel_bow_volley() -> void:
	if is_instance_valid(_bow_volley_timer):
		_bow_volley_timer.stop()
	_bow_volley_left = 0
	_bow_volley_sent = 0
	_bow_volley_weapon = null
	_bow_volley_direction = Vector3.ZERO
	_bow_volley_speed = 0.0
	_bow_volley_damage = 0


## amount 0..1: độ kéo dây
func set_bow_draw(amount: float) -> void:
	var visual := _bow_model as BowVisual
	if visual:
		visual.draw_amount = amount
	_on_bow_draw_changed(amount)
	bow_draw_progress.emit(amount)
	var element_id := _bow_element_id()
	if element_id != &"":
		fusion_bow_draw.emit(element_id, amount)


## State kéo cung gọi khi người chơi thả sớm (chưa đủ độ kéo): báo để VFX hiện là phát này không bắn
func notify_bow_draw_cancelled() -> void:
	bow_draw_cancelled.emit()


## Buông dây sau khi bắn: dây bật về, chạy animation buông
func release_bow(primary: bool = true) -> void:
	var bow := get_bow()
	if bow:
		play_action(bow.release_animation)
	if _bow_model is BowVisual:
		(_bow_model as BowVisual).play_release_flash()
	var element_id := _bow_element_id()
	if primary and element_id != &"":
		fusion_bow_released.emit(element_id)
	# Sau play_action: clip buông chạy từ tư thế đang kéo, không bị tua về đầu clip kéo trước
	set_bow_draw(0.0)


## Cất cung (rời state nhắm vì bất cứ lý do gì)
func end_bow_aim() -> void:
	if _bow_model:
		set_bow_draw(0.0)
		if _bow_model is BowVisual:
			(_bow_model as BowVisual).set_aiming(false)
		_bow_model.visible = false
	var element_id := _bow_element_id()
	if element_id != &"":
		fusion_bow_aim_ended.emit(element_id)


## Vị trí + hướng tay cầm cung (thế giới; +Z = hướng bắn): VFX tụ lực đặt ở mũi tên lúc kéo
func get_bow_grip_transform() -> Transform3D:
	return _bow_hold.global_transform


## Id nguyên tố đang ghép vào cung; &"" nếu chưa ghép
func _bow_element_id() -> StringName:
	var infusion: FusionData = _get_bow_projectile_fusion(true)
	return infusion.element.id if infusion and infusion.element else &""


## Nguồn có định danh để tháo một bùa không gỡ nhầm tác dụng của bùa khác.
func register_bow_imbue(source: StringName, infusion: FusionData) -> void:
	if source.is_empty():
		return
	if infusion == null or infusion.weapon_slot != WeaponData.Slot.BOW or infusion.element == null:
		unregister_bow_imbue(source)
		return
	_bow_imbues[source] = infusion
	for effect: FusionEffect in infusion.effects:
		if effect:
			effect.prepare_for_combat(self)
	_refresh_bow_imbue()


func unregister_bow_imbue(source: StringName) -> void:
	if _bow_imbues.erase(source):
		_refresh_bow_imbue()


func get_bow_imbue() -> FusionData:
	return null if health and health.is_dead() else _active_bow_imbue


func _refresh_bow_imbue() -> void:
	var previous: StringName = _bow_element_id()
	_active_bow_imbue = null
	# Chỉ giải quyết ưu tiên lúc đổi trang bị; không quét bùa khi tên đang bay.
	for infusion: FusionData in _bow_imbues.values():
		_active_bow_imbue = infusion
	var current: StringName = _bow_element_id()
	if previous != current and previous != &"":
		fusion_bow_aim_ended.emit(previous)
	if _bow_model is BowVisual:
		(_bow_model as BowVisual).default_charge_enabled = current == &""


func _get_bow_projectile_fusion(primary: bool) -> FusionData:
	if get_bow() == null or (health and health.is_dead()):
		return null
	var imbue: FusionData = get_bow_imbue()
	if imbue:
		return imbue
	if not primary or _fusion_table == null:
		return null
	var element: ElementData = GameState.get_fused_element(WeaponData.Slot.BOW)
	return _fusion_table.get_fusion(WeaponData.Slot.BOW, element.id) if element else null


func _on_progress_replaced() -> void:
	cancel_bow_volley()
	_requested_weapon_slot = -1
	_attach_weapon_model(GameState.get_weapon())


func _update_weapon_selection() -> void:
	if health.is_dead() or not controls_enabled:
		_requested_weapon_slot = -1
		return
	# Cung không chọn bằng phím số: luôn dùng được qua phím aim
	if Input.is_action_just_pressed(&"weapon_1"):
		_requested_weapon_slot = WeaponData.Slot.SWORD
	if _requested_weapon_slot < 0:
		return
	if GameState.get_weapon_in_slot(_requested_weapon_slot) == null:
		_requested_weapon_slot = -1
		return
	var state := state_machine.current_state
	if state == null or state.name not in [PlayerState.IDLE, PlayerState.RUN, PlayerState.JUMP, PlayerState.FALL]:
		return
	GameState.select_weapon(_requested_weapon_slot)
	_requested_weapon_slot = -1
	if state.name == PlayerState.IDLE:
		play_anim(ANIM_IDLE)
	elif state.name == PlayerState.RUN:
		play_anim(ANIM_RUN)


## speed < 0 = weapon.projectile_speed; damage < 0 = attack.damage
func shoot_arrow(weapon: WeaponData, attack: AttackData, direction: Vector3, speed: float = -1.0, damage: int = -1) -> void:
	if not energy.spend(weapon.energy_cost):
		return
	_launch_projectile(weapon, attack, direction, _arrow_spawn.global_position, speed, damage)


## Buff nguyên tố của cung (hố hút...) chạy khi tên trúng. Tên dùng pool nên nối một lần cho mỗi mũi
## và giữ fusion theo đúng vũ khí đã bắn, kể cả đang chọn kiếm hoặc đổi trang bị giữa đường bay.
func _on_arrow_impacted(hit_position: Vector3, direction: Vector3, arrow: ArrowProjectile) -> void:
	var fusion: FusionData = _projectile_fusions.get(arrow)
	if fusion == null:
		return
	for effect in fusion.effects:
		effect.on_projectile_impact(self, hit_position, direction)


func unlock_ability(ability: AbilityData) -> void:
	GameState.unlock_ability(ability)


func has_ability(id: StringName) -> bool:
	return GameState.has_ability(id)


func get_ability(id: StringName) -> AbilityData:
	return GameState.get_ability(id)


## Đúng khi đã mở khóa dash, có lệnh dash trong buffer, hết cooldown và còn lượt dash trên không
func can_dash() -> bool:
	var dash := get_ability(DashData.ID) as DashData
	if dash == null or _dash_buffer_timer <= 0.0 or _dash_cooldown_timer > 0.0 or not _dash_locks.is_empty():
		return false
	return is_on_floor() or _air_dashes_used < dash.air_dashes


## Gọi khi vào state Dash: tiêu input, tính cooldown, trừ lượt trên không, bật i-frames
func start_dash() -> DashData:
	var dash := get_ability(DashData.ID) as DashData
	_dash_buffer_timer = 0.0
	_dash_cooldown_timer = dash.duration + dash.cooldown
	if not is_on_floor():
		_air_dashes_used += 1
	_hurtbox.set_invincible(dash.duration)
	return dash


func set_terrain_speed(source: Node, factor: float) -> void:
	if factor < 1.0:
		_terrain_speed_scales[source] = factor
	else:
		_terrain_speed_scales.erase(source)
	_terrain_speed = 1.0
	for scale_factor: float in _terrain_speed_scales.values():
		_terrain_speed = minf(_terrain_speed, scale_factor)


func get_terrain_speed() -> float:
	return _terrain_speed


func move_toward_direction(direction: Vector3, delta: float) -> void:
	super(direction * _terrain_speed, delta)


## Kỹ năng chủ động vừa được bấm và dùng được ngay (đã mở khóa, không đang ghép vào vũ khí, có lệnh trong buffer,
## hết thời gian khoá, đủ năng lượng); null nếu không có. State nền / trên không chuyển sang skill.state
func get_ready_skill() -> SkillData:
	if combat_locked():
		return null
	for ability in GameState.get_abilities():
		var skill := ability as SkillData
		if skill == null or not is_skill_available(skill.id):
			continue
		if _skill_buffers.get(skill.id, 0.0) <= 0.0 or _skill_cooldowns.get(skill.id, 0.0) > 0.0:
			continue
		var form := get_skill_form(skill)
		if energy.can_spend(form.energy_cost):
			return form
	return null


## Dạng đang dùng của kỹ năng theo cấp nâng (Thổi gió cấp 2 = Lốc xoáy); cấp 1 là chính kỹ năng đó
func get_skill_form(skill: SkillData) -> SkillData:
	return skill.resolve(GameState.get_ability_level(skill)) as SkillData


## Gọi khi vào state của kỹ năng: tiêu input, tính thời gian khoá, trừ năng lượng
## id là của kỹ năng gốc hoặc của dạng đã nâng cấp; buffer / hồi chiêu luôn tính theo kỹ năng gốc (cùng một phím)
func start_skill(id: StringName) -> SkillData:
	var base := _find_skill(id)
	var data := get_skill_form(base)
	energy.spend(data.energy_cost)
	_skill_buffers[base.id] = 0.0
	_skill_cooldowns[base.id] = data.get_lockout()
	skill_cooldown_started.emit(base.id, _skill_cooldowns[base.id])
	combat_action_committed.emit(&"", data.id)
	return data


## Kỹ năng gốc đã mở khóa ứng với id (id gốc, hoặc id của dạng đang dùng sau nâng cấp)
func _find_skill(id: StringName) -> SkillData:
	var direct := get_ability(id) as SkillData
	if direct:
		return direct
	for ability in GameState.get_abilities():
		var skill := ability as SkillData
		if skill and get_skill_form(skill).id == id:
			return skill
	return null


## Đúng khi kỹ năng gió dùng được ngay (giữ cho code / test cũ gọi theo tên)
func can_wind_blast() -> bool:
	var skill := get_ready_skill()
	return skill != null and skill.id == WindBlastData.ID


## Kỹ năng đã mở khóa và nguyên tố của nó không đang ghép vào vũ khí
func is_skill_available(id: StringName) -> bool:
	return has_ability(id) and not GameState.is_ability_fused(id)


## Gọi khi vào state WindBlast: như start_skill, phát thêm signal riêng của gió cho HUD / test cũ
func start_wind_blast() -> WindBlastData:
	var data := start_skill(WindBlastData.ID) as WindBlastData
	wind_blast_cooldown_started.emit(_skill_cooldowns[WindBlastData.ID])
	return data


func register_local_respawn(handler: Callable) -> void:
	_local_respawn = handler


func unregister_local_respawn(handler: Callable) -> void:
	if _local_respawn == handler:
		_local_respawn = Callable()


func request_local_respawn() -> bool:
	if not _local_respawn.is_valid():
		return false
	_local_respawn.call_deferred(self)
	return true


func revive_locally(target_position: Vector3, facing: Vector3) -> void:
	health.heal_full()
	teleport(target_position, facing)
	_hurtbox.set_invincible(recovery_invincibility)
	# Hồi sinh tại chỗ cũng diễn cảnh hồi sinh (không có miếu loé)
	begin_respawn(null)


## Bắt đầu cảnh hồi sinh (cáo nằm, hiện dần từ đầu xuống chân, đứng dậy). anchor = checkpoint chứa điểm xuất hiện,
## có play_revive() thì loé sáng theo; null = hồi sinh tại chỗ. Không có state Respawn thì đứng sẵn như cũ
func begin_respawn(anchor: Node3D) -> void:
	if not state_machine.has_node(NodePath(String(PlayerState.RESPAWN))):
		return
	_revive_anchor = anchor
	state_machine.transition_to(PlayerState.RESPAWN)


## State Respawn lấy checkpoint cần loé (đọc xong thì xoá)
func consume_revive_anchor() -> Node3D:
	var anchor := _revive_anchor
	_revive_anchor = null
	return anchor if is_instance_valid(anchor) else null


## Bất tử trong duration giây; blink = cáo nhấp nháy như lúc vừa bị đánh (tắt khi đang diễn cảnh hồi sinh)
func grant_invincibility(duration: float, blink: bool = true) -> void:
	if duration <= 0.0:
		return
	_hurtbox.set_invincible(duration)
	if blink:
		_start_blink(duration)


func receive_environment_hit(info: DamageInfo) -> bool:
	return _hurtbox.receive_hit(info)


## Dịch chuyển kèm đặt lại chỗ an toàn và camera (cổng, hồi sinh)
func teleport(target_position: Vector3, facing: Vector3 = Vector3.ZERO) -> void:
	super(target_position, facing)
	# Chỗ mới là chỗ an toàn ban đầu; bỏ lịch sử vị trí ở chỗ cũ
	_last_safe_position = target_position
	_recent_floor_positions.clear()
	_camera_rig.snap()
	# Player vừa được tạo thì FSM chưa có state hiện tại, khi đó đã ở Idle sẵn
	if state_machine.current_state:
		state_machine.transition_to(PlayerState.IDLE)


## Gọi từ KillZone: đưa về chỗ đứng an toàn gần nhất
func on_kill_zone_entered() -> void:
	return_to_safe_ground()


## Gọi từ vùng chết người (nước sâu, gai...): chết thật, hồi sinh ở checkpoint qua state Dead.
## red_flash: nháy đỏ trước rồi mới ngã (bẫy gai); rơi nước thì không
func on_lethal_zone_entered(red_flash: bool = false) -> void:
	if health.is_dead() or not _damage_protection.is_empty():
		return
	_lethal_flash_pending = red_flash
	health.take_damage(health.current_health)


## State Dead gọi khi vào: lần chết này có nháy đỏ không (đọc xong thì xóa)
func consume_lethal_flash() -> bool:
	var pending := _lethal_flash_pending
	_lethal_flash_pending = false
	return pending


## Nháy màu lethal_flash_color lên model trong duration giây
func start_red_flash(duration: float) -> void:
	if _flash_material == null:
		# Tạo một lần, dùng lại cho các lần sau
		_flash_material = StandardMaterial3D.new()
		_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_flash_material.albedo_color = lethal_flash_color
		for node in model.find_children("*", "MeshInstance3D", true, false):
			_model_meshes.append(node as MeshInstance3D)
	if _flash_tween:
		_flash_tween.kill()
	var cycles := maxi(ceili(duration / (blink_interval * 2.0)), 1)
	_flash_tween = create_tween().set_loops(cycles)
	_flash_tween.tween_callback(_set_flash_overlay.bind(true))
	_flash_tween.tween_interval(blink_interval)
	_flash_tween.tween_callback(_set_flash_overlay.bind(false))
	_flash_tween.tween_interval(blink_interval)


## Về chỗ đứng an toàn gần nhất (rơi vực, trúng bẫy). stunned = choáng tại chỗ như bị đánh
func return_to_safe_ground(stunned: bool = false) -> void:
	# Lưới cứu rơi không được ngắt state Dead trước khi hồi sinh tại checkpoint.
	if health.is_dead() or not _damage_protection.is_empty():
		return
	teleport(_last_safe_position, get_facing_direction())
	_hurtbox.set_invincible(recovery_invincibility)
	if stunned:
		# Không đẩy lùi ở chỗ mới, chỉ choáng
		last_hit = null
		state_machine.transition_to(PlayerState.HURT)


## Hướng ra đòn: ưu tiên mục tiêu gần nhất nằm trong tầm và lệch không quá soft_lock_angle so với preferred
func find_attack_direction(preferred: Vector3) -> Vector3:
	var best_direction := preferred
	var best_distance := INF
	var weapon := get_weapon()
	var lock_range := weapon.attack_range if weapon and weapon.is_ranged() else soft_lock_range
	for node in get_tree().get_nodes_in_group(HurtboxComponent.GROUP):
		var hurtbox := node as HurtboxComponent
		# Chỉ nhắm vào phe mà hitbox của mình đánh được
		if hurtbox.collision_layer & hitbox.collision_mask == 0 or not hurtbox.is_alive():
			continue
		var offset := hurtbox.global_position - global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance > lock_range or distance < 0.01:
			continue
		var direction := offset / distance
		if rad_to_deg(preferred.angle_to(direction)) > soft_lock_angle:
			continue
		if distance < best_distance:
			best_distance = distance
			best_direction = direction
	return best_direction


func _pre_state_update(delta: float) -> void:
	_update_weapon_selection()
	if is_on_floor():
		_coyote_timer = coyote_time
		_air_dashes_used = 0
		# Area3D nhận biết vùng gió trễ vài frame: chỉ công nhận vị trí của safe_ground_frames frame trước,
		# khi suốt khoảng đó không có gió. Chỗ an toàn vì vậy luôn lùi khỏi mép vùng gió và mép vực
		if wind_receiver != null and not wind_receiver.get_wind().is_zero_approx():
			_recent_floor_positions.clear()
		else:
			_recent_floor_positions.append(global_position)
			if _recent_floor_positions.size() > safe_ground_frames:
				_last_safe_position = _recent_floor_positions.pop_front()
	else:
		_coyote_timer -= delta

	_jump_buffer_timer = _update_buffer(&"jump", _jump_buffer_timer, jump_buffer_time, delta)
	if _attack_blocked_by_ui:
		_attack_buffer_timer = 0.0
	else:
		_attack_buffer_timer = _update_buffer(&"attack", _attack_buffer_timer, attack_buffer_time, delta)
	_report_unaffordable_input()
	_dash_buffer_timer = _update_buffer(&"dash", _dash_buffer_timer, dash_buffer_time, delta)
	_dash_cooldown_timer = maxf(_dash_cooldown_timer - delta, 0.0)
	for ability in GameState.get_abilities():
		var skill := ability as SkillData
		if skill and not skill.input_action.is_empty():
			_skill_buffers[skill.id] = _update_buffer(skill.input_action, _skill_buffers.get(skill.id, 0.0), wind_blast_buffer_time, delta)
	for id: StringName in _skill_cooldowns:
		_skill_cooldowns[id] = maxf(_skill_cooldowns[id] - delta, 0.0)
	_bow_cooldown_timer = maxf(_bow_cooldown_timer - delta, 0.0)
	if combat_locked():
		_attack_buffer_timer = 0.0
		_skill_buffers.clear()


func _attach_weapon_model(data: WeaponData) -> void:
	for child in _weapon_socket.get_children():
		child.queue_free()
	if data and data.model_scene:
		_weapon_socket.add_child(data.model_scene.instantiate())


## Lớp con ghi đè để đồng bộ tư thế với độ kéo dây (ví dụ tua clip kéo cung)
func _on_bow_draw_changed(_amount: float) -> void:
	pass


func _launch_projectile(weapon: WeaponData, attack: AttackData, direction: Vector3, spawn: Vector3,
		speed: float, damage: int, primary: bool = true) -> void:
	var pool := _get_projectile_pool(weapon.projectile_scene)
	var arrow := pool.acquire() as ArrowProjectile
	if not arrow.finished.is_connected(pool.release):
		arrow.finished.connect(pool.release)
	var impacted := _on_arrow_impacted.bind(arrow)
	if not arrow.impacted.is_connected(impacted):
		arrow.impacted.connect(impacted)
	if not arrow.finished.is_connected(_on_projectile_finished):
		arrow.finished.connect(_on_projectile_finished)
	var damage_confirmed: Callable = _on_arrow_enemy_damaged.bind(arrow)
	if not arrow.enemy_damaged.is_connected(damage_confirmed):
		arrow.enemy_damaged.connect(damage_confirmed)
	var contact_confirmed: Callable = _on_bow_hit_contact.bind(arrow)
	if not arrow.enemy_damage_confirmed.is_connected(contact_confirmed):
		arrow.enemy_damage_confirmed.connect(contact_confirmed)
	var element: ElementData = GameState.get_fused_element(weapon.slot) if primary else null
	var fusion: FusionData = _get_bow_projectile_fusion(primary) if weapon.slot == WeaponData.Slot.BOW else (_fusion_table.get_fusion(weapon.slot, element.id) if element else null)
	if fusion:
		element = fusion.element
	if fusion:
		_projectile_fusions[arrow] = fusion
	else:
		_projectile_fusions.erase(arrow)
	arrow.global_position = spawn
	# Chỉ tên gốc do vũ khí cung bắn mới được nhận bonus; đạn phụ fusion dùng pool riêng.
	if weapon.slot == WeaponData.Slot.BOW:
		_weapon_damage_projectiles[arrow] = true
	else:
		_weapon_damage_projectiles.erase(arrow)
	# Quét từ thân (cùng độ cao) tới đầu tên trong frame đầu để không bắn xuyên tường sát người.
	var origin := Vector3(global_position.x, spawn.y, global_position.z)
	var shot_speed := weapon.projectile_speed if speed < 0.0 else speed
	arrow.launch(attack, shot_speed, weapon.projectile_lifetime, direction, self, origin, damage)
	# Đạn phụ không nhân đôi sự kiện dùng cung; bùa có thể áp hiệu ứng cho cả loạt tên.
	if primary:
		combat_action_committed.emit(element.id if fusion and element else &"", &"")
	if fusion:
		for effect: FusionEffect in fusion.effects:
			effect.on_projectile_fired(self, arrow)


func _schedule_bow_followup() -> void:
	if has_pending_bow_shots():
		var step: float = 1.0 / maxf(float(Engine.physics_ticks_per_second), 1.0)
		# Timer so sánh nghiêm với 0; trừ sai số nhỏ hơn một bước để 0,20 s không thành 13 tick.
		_bow_volley_timer.start(maxf(bow_volley_interval, step) - step * BOW_VOLLEY_TICK_EPSILON)


func _on_bow_volley_timeout() -> void:
	# Phát đã trả năng lượng thuộc lượt nhả dây, không phụ thuộc state lăn hoặc bị khựng.
	if shoot_bow_followup():
		_schedule_bow_followup()


func _on_projectile_finished(arrow: ArrowProjectile) -> void:
	_projectile_fusions.erase(arrow)
	_weapon_damage_projectiles.erase(arrow)


func _on_arrow_enemy_damaged(arrow: ArrowProjectile) -> void:
	if _weapon_damage_projectiles.has(arrow) and not health.is_dead():
		bow_enemy_hit.emit()


func _on_bow_hit_contact(hurtbox: HurtboxComponent, position: Vector3, direction: Vector3, arrow: ArrowProjectile) -> void:
	if _weapon_damage_projectiles.has(arrow) and not health.is_dead():
		bow_enemy_hit_contact.emit(hurtbox, position, direction)


func _prepare_bow_model(bow: WeaponData) -> void:
	if bow.model_scene == null or (is_instance_valid(_bow_model) and _bow_model_scene == bow.model_scene):
		return
	if is_instance_valid(_bow_model):
		_bow_model.queue_free()
	_bow_model = bow.model_scene.instantiate() as Node3D
	_bow_model_scene = bow.model_scene
	_bow_hold.add_child(_bow_model)
	_bow_model.visible = false


## Hướng nhắm trong không gian model khi đứng nghiêng bow_stance_degrees
func _get_bow_aim_local() -> Vector3:
	var stance := deg_to_rad(bow_stance_degrees)
	return Vector3(sin(stance), 0.0, cos(stance))


func _get_projectile_pool(scene: PackedScene) -> ObjectPool:
	var pool: ObjectPool = _projectile_pools.get(scene)
	if is_instance_valid(pool):
		return pool
	pool = ObjectPool.new()
	pool.name = "ProjectilePool"
	pool.scene = scene
	pool.initial_size = maxi(arrow_pool_size, 0)
	pool.configure_instance = _configure_projectile_instance
	add_child(pool)
	_projectile_pools[scene] = pool
	return pool


func _fire_bow_projectile(bow: BowData, direction: Vector3, speed: float, damage: int, primary: bool) -> void:
	# Tâm ngắm nằm giữa người; bắn từ tay lệch bên sẽ trượt khỏi hướng chuột.
	var grip: Vector3 = _bow_hold.global_position
	var flat_offset: Vector3 = Vector3(grip.x - global_position.x, 0.0, grip.z - global_position.z)
	var spawn: Vector3 = global_position + direction * flat_offset.dot(direction)
	spawn.y = grip.y
	_launch_projectile(bow, bow.combo[0], direction, spawn, speed, damage, primary)
	bow_projectile_fired.emit(primary)


func _warm_bow_volley_pool() -> void:
	if not _combat_prepared or not is_inside_tree():
		return
	var bow: BowData = get_bow()
	if bow == null:
		for weapon: WeaponData in combat_weapons:
			if weapon is BowData:
				bow = weapon as BowData
				break
	if bow == null or bow.projectile_scene == null:
		return
	# Giữ hai phát ngay từ đầu để đeo/tháo Ưng Nhãn không phải tạo/xóa đạn trong pool.
	var count: int = maxi(get_bow_projectile_count(), BOW_VOLLEY_PREWARM_COUNT)
	if bow == _last_volley_weapon and count == _last_volley_count:
		return
	_last_volley_weapon = bow
	_last_volley_count = count
	var pool: ObjectPool = _get_projectile_pool(bow.projectile_scene)
	pool.reserve(1)
	var arrow: ArrowProjectile = pool.get_child(0) as ArrowProjectile
	var fade: float = maxf(arrow.trail_fade_time, 0.0) if arrow else 0.0
	var interval: float = maxf(bow.shot_cooldown, bow.release_recovery + maxf(bow.draw_time, 0.0) * clampf(bow.min_draw_to_shoot, 0.0, 1.0))
	interval = maxf(interval, 1.0 / maxf(float(Engine.physics_ticks_per_second), 1.0))
	var overlap: float = clampf((maxf(bow.projectile_lifetime, 0.0) + fade) / interval, 0.0, float(MAX_BOW_VOLLEY_RESERVE))
	var required: int = mini(maxi(arrow_pool_size, (1 + ceili(overlap)) * count), MAX_BOW_VOLLEY_RESERVE)
	# Làm nóng khi vào khu / đổi bùa / nhận cung, không tạo đạn trong từng lượt bắn.
	pool.reserve(required)


func _configure_projectile_instance(node: Node) -> void:
	(node as Node3D).set_as_top_level(true)


func _is_holding_jump() -> bool:
	return controls_enabled and Input.is_action_pressed("jump")


func _update_buffer(action: StringName, timer: float, buffer_time: float, delta: float) -> float:
	if controls_enabled and Input.is_action_just_pressed(action):
		return buffer_time
	return timer - delta


func _on_hurt(info: DamageInfo, _damage_taken: int) -> void:
	# Đòn kết liễu đã chuyển sang Dead qua signal died
	if health.is_dead():
		return
	last_hit = info
	_start_blink(_hurtbox.invincibility_time)
	# Đòn không làm khựng (tick cháy) giống quái: chỉ nháy + mất máu, không chuyển Hurt, không huỷ dash / đòn đang đánh
	if not info.staggers:
		return
	var now := Time.get_ticks_msec()
	var since_last := float(now - _last_stagger_msec) / 1000.0
	_last_stagger_msec = now
	# Đòn mạnh hoặc đòn thứ hai liền nhau: hất ngã (thoát khỏi chỗ bị vây). Không có state Knockdown thì khựng như cũ
	var knockdown := state_machine.get_node_or_null(NodePath(String(PlayerState.KNOCKDOWN)))
	if knockdown and knockdown.has_method(&"should_knock_down") and knockdown.call(&"should_knock_down", info, since_last):
		state_machine.transition_to(PlayerState.KNOCKDOWN)
		return
	state_machine.transition_to(PlayerState.HURT)


func _on_died() -> void:
	var bow_element: StringName = _active_bow_imbue.element.id if _active_bow_imbue and _active_bow_imbue.element else _bow_element_id()
	if bow_element != &"":
		fusion_bow_aim_ended.emit(bow_element)
	cancel_bow_volley()
	_stop_blink()
	state_machine.transition_to(PlayerState.DEAD)


func _on_stat_changed(stat: StringName) -> void:
	if stat == BOW_EXTRA_PROJECTILES_STAT:
		_warm_bow_volley_pool()
		if _bow_volley_sent >= get_bow_projectile_count():
			cancel_bow_volley()
	if stat == MAX_ENERGY_STAT:
		energy.set_max_bonus(roundi(stats.get_bonus(MAX_ENERGY_STAT)))
	if stat == MAX_HEALTH_STAT:
		# Đeo bùa thêm máu: ô mới đổ đầy luôn; tháo thì kẹp về mức gốc
		var new_max := _base_max_health + roundi(stats.get_bonus(MAX_HEALTH_STAT))
		if new_max != health.max_health:
			health.set_max_health(new_max, new_max > health.max_health)


func _on_health_changed(current: int, _max_value: int) -> void:
	GameState.set_player_health(current)


func _on_energy_changed(current: int, _max_value: int) -> void:
	GameState.set_player_energy(current)


## Bấm cung / kỹ năng mà thiếu năng lượng: báo một lần lúc bấm (HUD nháy, âm báo), không báo mỗi frame
func _report_unaffordable_input() -> void:
	if not controls_enabled or combat_locked():
		return
	if not _attack_blocked_by_ui and Input.is_action_just_pressed(&"attack") and has_weapon() \
			and not energy.can_spend(get_weapon().energy_cost):
		energy.notify_insufficient(get_weapon().energy_cost)
	var bow := get_bow()
	if bow and bow.is_ranged() and Input.is_action_just_pressed(&"aim") and not energy.can_spend(bow.energy_cost):
		energy.notify_insufficient(bow.energy_cost)
	for ability in GameState.get_abilities():
		var skill := ability as SkillData
		if skill and not skill.input_action.is_empty() and Input.is_action_just_pressed(skill.input_action) \
				and is_skill_available(skill.id) and not energy.can_spend(get_skill_form(skill).energy_cost):
			energy.notify_insufficient(get_skill_form(skill).energy_cost)


func _start_blink(duration: float) -> void:
	_blink_time_left = duration
	_blink_clock = 0.0
	set_process(true)


func _set_flash_overlay(on: bool) -> void:
	for mesh in _model_meshes:
		mesh.material_overlay = _flash_material if on else null


func _stop_blink() -> void:
	_blink_time_left = 0.0
	model.visible = true
	set_process(false)


func _on_hitbox_hit(_target: HurtboxComponent) -> void:
	HitStop.stop(hitbox.attack.hitstop)
