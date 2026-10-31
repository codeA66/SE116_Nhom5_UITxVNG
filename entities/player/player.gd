class_name Player
extends Character
## Player: đọc input theo hướng camera, coyote time, các input buffer, nhặt vũ khí, mở khóa kỹ năng.
## Vũ khí và kỹ năng thuộc tiến trình (GameState), không lưu trong player: chuyển scene không bị mất.

## Vừa bắn cung, bắt đầu thời gian hồi (HUD nghe để hiện, không phải dò mỗi frame)
signal bow_cooldown_started(duration: float)
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
## Số mũi tên tạo sẵn trước combat; thiếu thì pool vẫn mở rộng để không mất phát bắn.
@export var arrow_pool_size: int = 4
## Chuẩn bị cả vũ khí chưa nhặt, không cấp vũ khí cho tiến trình.
@export var combat_weapons: Array[WeaponData] = [preload("res://resources/combat/weapons/bow.tres")]
## Khi nhắm cung, người quay nghiêng bấy nhiêu độ để vai trái hướng về mục tiêu như cung thủ;
## cung và mũi tên vẫn theo đúng hướng nhắm. Model nhìn theo +Z nên bên trái là +X. 0 = đứng thẳng mặt
@export_range(-180.0, 180.0, 0.5) var bow_stance_degrees: float = 90.0

## Đòn đánh gần nhất trúng player, state Hurt dùng để lấy hướng đẩy lùi
## Tắt khi cutscene / hội thoại: bỏ qua mọi phím (đi, nhảy, đánh, dash, gió, tương tác, đổi vũ khí).
## Vật lý vẫn chạy nên đứng trên thuyền / bệ vẫn được chở đi. Đổi bằng set_controls_enabled()
var controls_enabled: bool = true
var last_hit: DamageInfo
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
var _flash_material: StandardMaterial3D
var _model_meshes: Array[MeshInstance3D] = []
var _flash_tween: Tween
## Bảng UI đang mở và dùng chuột (tủ đồ): chuột trái cũng là nút đánh nên phải bỏ qua, nếu không kéo thả sẽ chém
var _attack_blocked_by_ui: bool = false
## Model cung đang gắn ở BowHold (tạo một lần, ẩn khi không nhắm) và scene đã dùng để tạo nó
var _bow_model: Node3D
var _bow_model_scene: PackedScene
## Pool đạn theo scene thuộc player; mỗi mũi tên top_level nên không đi theo người.
var _projectile_pools: Dictionary[PackedScene, ObjectPool] = {}
var _projectile_fusions: Dictionary[ArrowProjectile, FusionData] = {}
var _fusion_pools: Dictionary[FusionEffect, Dictionary] = {}
var _combat_prepared: bool = false
var _fusion_table: FusionTable
var _fusion_warmup_sources: Array[Node] = []
var _fusion_warmup_prepared: bool = false

@onready var energy: EnergyComponent = $EnergyComponent
@onready var hitbox: HitboxComponent = $Model/Hitbox
@onready var wind_blast: WindBlastArea = $Model/WindBlastArea
@onready var interactor: InteractorComponent = $Interactor
@onready var health: HealthComponent = $HealthComponent
@onready var _hurtbox: HurtboxComponent = $HurtboxComponent
@onready var _camera_rig: CameraRig = $CameraRig
@onready var _camera: Camera3D = $CameraRig/Camera3D
@onready var _weapon_socket: Node3D = $WeaponSocket
@onready var _arrow_spawn: Marker3D = $Model/ArrowSpawn
## Chỗ đặt cung khi nhắm (cầm ngang trước ngực), xoay theo model
@onready var _bow_hold: Node3D = $Model/BowHold


func _ready() -> void:
	super()
	add_to_group(ShaderWarmup.SOURCE_GROUP)
	hitbox.hit.connect(_on_hitbox_hit)
	GameState.weapon_changed.connect(_attach_weapon_model)
	GameState.progress_replaced.connect(_on_progress_replaced)
	# Vào scene mới: gắn lại vũ khí đã có trong tiến trình
	_attach_weapon_model(GameState.get_weapon())
	_last_safe_position = global_position
	# Máu được giữ qua các lần chuyển khu (player là object mới mỗi khu)
	var kept_health := GameState.get_player_health()
	if kept_health > 0:
		health.set_current_health(kept_health)
	# Năng lượng cũng giữ qua các lần chuyển khu
	var kept_energy := GameState.get_player_energy()
	if kept_energy >= 0:
		energy.set_current(kept_energy)
	energy.energy_changed.connect(_on_energy_changed)
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


## Hướng ngang từ player tới điểm con trỏ chuột chỉ trên mặt phẳng ngang ở độ cao chân player.
## Trả về Vector3.ZERO nếu không xác định được (chuột ngoài cửa sổ, tia song song mặt phẳng, chuột trùng chân player)
func get_mouse_aim_direction() -> Vector3:
	# Chạy headless (test tự động) không có chuột thật: vị trí chuột vô nghĩa, để state dùng hướng phím
	if DisplayServer.get_name() == "headless":
		return Vector3.ZERO
	var mouse := get_viewport().get_mouse_position()
	var origin := _camera.project_ray_origin(mouse)
	var normal := _camera.project_ray_normal(mouse)
	var hit: Variant = Plane(Vector3.UP, global_position.y).intersects_ray(origin, normal)
	if hit == null:
		return Vector3.ZERO
	var offset: Vector3 = (hit as Vector3) - global_position
	offset.y = 0.0
	return offset.normalized() if offset.length() > 0.05 else Vector3.ZERO


## Đúng khi có jump buffer và còn coyote time
func can_jump() -> bool:
	return _jump_buffer_timer > 0.0 and _coyote_timer > 0.0


func jump() -> void:
	super()
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0


func get_weapon() -> WeaponData:
	return GameState.get_weapon()


func has_weapon() -> bool:
	return get_weapon() != null


## Đúng khi đang cầm vũ khí, có lệnh đánh trong buffer và đủ năng lượng (cung tiêu năng lượng mỗi phát)
func can_attack() -> bool:
	return has_weapon() and not get_weapon().combo.is_empty() and _attack_buffer_timer > 0.0 \
		and energy.can_spend(get_weapon().energy_cost)


## Buff ghép của vũ khí đang cầm; null nếu chưa ghép
func get_fusion() -> FusionData:
	return GameState.get_active_fusion()


## State Attack báo hitbox cận chiến vừa bật: chạy các buff nguyên tố của vũ khí (nhát cuối phóng gió, phản đạn...)
func notify_melee_active(attack: AttackData, combo_index: int, combo_size: int, direction: Vector3, active_time: float) -> void:
	var fusion := get_fusion()
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


## Đúng khi đang giữ phím aim, có cung bắn được và đã hết thời gian hồi
func can_aim_bow() -> bool:
	var bow := get_bow()
	return bow != null and bow.is_ranged() and not bow.combo.is_empty() and is_holding_aim() \
			and _bow_cooldown_timer <= 0.0


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
		# Cung đang ghép nguyên tố: VFX tụ lực của nguyên tố thay cho cụm tụ lực mặc định
		(_bow_model as BowVisual).default_charge_enabled = _bow_element_id() == &""
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


## Bắn một mũi tên từ cung đang cầm; draw 0..1 quyết định tốc độ và sát thương
func shoot_bow(draw: float) -> void:
	var bow := get_bow()
	if bow == null:
		return
	# Cung tiêu năng lượng mỗi phát (luật của nhánh energy-fusion); thiếu thì spend() tự báo và không bắn
	if not energy.spend(bow.energy_cost):
		return
	var direction := get_bow_aim_direction()
	# Xuất phát trên đường thẳng qua tâm người (hướng chuột tính từ tâm), ngang tay cầm cung:
	# đứng nghiêng thì tay cầm lệch sang bên, bắn từ đó sẽ trượt khỏi chỗ chuột chỉ
	var grip := _bow_hold.global_position
	var flat_offset := Vector3(grip.x - global_position.x, 0.0, grip.z - global_position.z)
	var spawn := global_position + direction * flat_offset.dot(direction)
	spawn.y = grip.y
	_launch_projectile(bow, bow.combo[0], direction, spawn, bow.get_shot_speed(draw), bow.get_shot_damage(draw))
	_bow_cooldown_timer = bow.shot_cooldown
	if bow.shot_cooldown > 0.0:
		bow_cooldown_started.emit(bow.shot_cooldown)


## amount 0..1: độ kéo dây
func set_bow_draw(amount: float) -> void:
	var visual := _bow_model as BowVisual
	if visual:
		visual.draw_amount = amount
	_on_bow_draw_changed(amount)
	var element_id := _bow_element_id()
	if element_id != &"":
		fusion_bow_draw.emit(element_id, amount)


## Buông dây sau khi bắn: dây bật về, chạy animation buông
func release_bow() -> void:
	var bow := get_bow()
	if bow:
		play_action(bow.release_animation)
	if _bow_model is BowVisual:
		(_bow_model as BowVisual).play_release_flash()
	var element_id := _bow_element_id()
	if element_id != &"":
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
	var bow := get_bow()
	if bow == null:
		return &""
	var element := GameState.get_fused_element(bow.slot)
	return element.id if element else &""


func _on_progress_replaced() -> void:
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
	if dash == null or _dash_buffer_timer <= 0.0 or _dash_cooldown_timer > 0.0:
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


## Kỹ năng chủ động vừa được bấm và dùng được ngay (đã mở khóa, không đang ghép vào vũ khí, có lệnh trong buffer,
## hết thời gian khoá, đủ năng lượng); null nếu không có. State nền / trên không chuyển sang skill.state
func get_ready_skill() -> SkillData:
	for ability in GameState.get_abilities():
		var skill := ability as SkillData
		if skill == null or not is_skill_available(skill.id):
			continue
		if _skill_buffers.get(skill.id, 0.0) <= 0.0 or _skill_cooldowns.get(skill.id, 0.0) > 0.0:
			continue
		if energy.can_spend(skill.energy_cost):
			return skill
	return null


## Gọi khi vào state của kỹ năng: tiêu input, tính thời gian khoá, trừ năng lượng
func start_skill(id: StringName) -> SkillData:
	var data := get_ability(id) as SkillData
	energy.spend(data.energy_cost)
	_skill_buffers[id] = 0.0
	_skill_cooldowns[id] = data.get_lockout()
	skill_cooldown_started.emit(id, _skill_cooldowns[id])
	return data


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
	if health.is_dead():
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
	if health.is_dead():
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


func _attach_weapon_model(data: WeaponData) -> void:
	for child in _weapon_socket.get_children():
		child.queue_free()
	if data and data.model_scene:
		_weapon_socket.add_child(data.model_scene.instantiate())


## Lớp con ghi đè để đồng bộ tư thế với độ kéo dây (ví dụ tua clip kéo cung)
func _on_bow_draw_changed(_amount: float) -> void:
	pass


func _launch_projectile(weapon: WeaponData, attack: AttackData, direction: Vector3, spawn: Vector3,
		speed: float, damage: int) -> void:
	var pool := _get_projectile_pool(weapon.projectile_scene)
	var arrow := pool.acquire() as ArrowProjectile
	if not arrow.finished.is_connected(pool.release):
		arrow.finished.connect(pool.release)
	var impacted := _on_arrow_impacted.bind(arrow)
	if not arrow.impacted.is_connected(impacted):
		arrow.impacted.connect(impacted)
	if not arrow.finished.is_connected(_on_projectile_finished):
		arrow.finished.connect(_on_projectile_finished)
	var element := GameState.get_fused_element(weapon.slot)
	var fusion := _fusion_table.get_fusion(weapon.slot, element.id) if element else null
	if fusion:
		_projectile_fusions[arrow] = fusion
	else:
		_projectile_fusions.erase(arrow)
	arrow.global_position = spawn
	# Quét từ thân (cùng độ cao) tới đầu tên trong frame đầu để không bắn xuyên tường sát người.
	var origin := Vector3(global_position.x, spawn.y, global_position.z)
	var shot_speed := weapon.projectile_speed if speed < 0.0 else speed
	arrow.launch(attack, shot_speed, weapon.projectile_lifetime, direction, self, origin, damage)
	if fusion:
		for effect: FusionEffect in fusion.effects:
			effect.on_projectile_fired(self, arrow)


func _on_projectile_finished(arrow: ArrowProjectile) -> void:
	_projectile_fusions.erase(arrow)


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
	state_machine.transition_to(PlayerState.HURT)


func _on_died() -> void:
	_stop_blink()
	state_machine.transition_to(PlayerState.DEAD)


func _on_health_changed(current: int, _max_value: int) -> void:
	GameState.set_player_health(current)


func _on_energy_changed(current: int, _max_value: int) -> void:
	GameState.set_player_energy(current)


## Bấm cung / kỹ năng mà thiếu năng lượng: báo một lần lúc bấm (HUD nháy, âm báo), không báo mỗi frame
func _report_unaffordable_input() -> void:
	if not controls_enabled:
		return
	if not _attack_blocked_by_ui and Input.is_action_just_pressed(&"attack") and has_weapon() \
			and not energy.can_spend(get_weapon().energy_cost):
		energy.notify_insufficient(get_weapon().energy_cost)
	for ability in GameState.get_abilities():
		var skill := ability as SkillData
		if skill and not skill.input_action.is_empty() and Input.is_action_just_pressed(skill.input_action) \
				and is_skill_available(skill.id) and not energy.can_spend(skill.energy_cost):
			energy.notify_insufficient(skill.energy_cost)


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
