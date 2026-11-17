class_name FireToad
extends Character
## Ếch Hoả Vương: boss cuối map Lửa. Mọi hành vi nằm trong các state (states/); script này chỉ giữ máu, các mốc phase
## (bay lên ở hover_ratio, cuồng loạn ở enrage_ratio), pool đạn / vũng dung nham và vài hàm dùng chung cho state
## (nhảy vòng cung, thả cầu lửa, phủ tơ). Thông số trong FireToadData; cuồng loạn chỉ đổi sang bộ skill khác.
## Sân đấu: arena_center + arena_half_size (sàn vuông) và 4 bệ ngoài outer_platforms, gán trong scene đặt boss.
## Đánh theo hội (FireToadCourt): có throne thì mở màn ngồi ngai, court gọi engage() mới xuống sân; court cho phép
## skill nào được dùng (can_use_skill) để nhiều con không chồng đòn, và gọi enrage() khi đồng đội bị hạ.

signal phase_changed(phase: StringName)
signal defeated

const FireToadVfx = preload("res://assets/vfx/enemies/fire/fire_toad/boss/fire_toad_vfx.gd")

const PHASE_HOVER := &"hover"
const PHASE_ENRAGED := &"enraged"

@export var data: FireToadData
## Tâm sàn đấu (mặt sàn): boss nhảy về đây, tơ và cầu lửa giới hạn trong sàn
@export var arena_center: Node3D
## Nửa cạnh sàn vuông (m), tính từ arena_center
@export_range(1.0, 60.0, 0.5) var arena_half_size: float = 9.0
## Các bệ ngoài sân boss nhảy ra đứng (skill 2)
@export var outer_platforms: Array[Node3D] = []
## Nhện canh gọi ra khi boss rút ra ngoài sân (skill 2) và các bệ canh ở góc ngoài sân cho nhện đứng
@export var sentinel_scene: PackedScene = preload("res://entities/bosses/fire_toad/sentinel/fire_toad_sentinel.tscn")
@export var sentinel_perches: Array[Node3D] = []
## Ngai ngồi chờ ngoài sân (đánh theo hội). Trống = vào trận ngay ở Idle như boss đơn
@export var throne: Node3D
## Hết máu thì vào state này: Dead (ẩn) hoặc Bow (cúi chào về ngai, court quyết định kết thúc)
@export var defeat_state: StringName = &"Dead"
## Vị trí "giữa sân" riêng của con này (x, z tính từ tâm sàn): nhiều con cùng sân không đáp chồng lên nhau
@export var home_offset: Vector2 = Vector2.ZERO

@export_group("Pool")
## Số cầu lửa rơi / vũng dung nham / đạn tạo sẵn khi vào trận (thiếu thì pool tự tạo thêm). Lúc ngồi ngai không giữ
## đồ: mỗi đồ có shader instance uniform, renderer Compatibility chỉ có số ô giới hạn cho cả màn
@export_range(0, 32) var rain_pool_size: int = 8
@export_range(0, 8) var lava_pool_size: int = 3
@export_range(0, 16) var shot_pool_size: int = 5

var target_player: Player
var enraged: bool = false
## Court điều phối (null = đánh một mình)
var court: FireToadCourt
## Đang ngồi ngai (Throne đặt): chết lúc này thì biến mất tại chỗ, không rơi xuống sân
var seated: bool = false

var _sentinels: Array[Enemy] = []
## Tăng mỗi lần rút nhện: lượt gọi đang chờ lệch giờ thấy số đổi thì dừng, không gọi nhện sau khi đã rút
var _summon_gen: int = 0
var _hover_pending: bool = false
var _hover_done: bool = false
var _flash_material: StandardMaterial3D
var _enrage_material: StandardMaterial3D
var _model_meshes: Array[GeometryInstance3D] = []
var _flash_tween: Tween

@onready var vfx: FireToadVfx = $FireToadVfx
@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: HurtboxComponent = $HurtboxComponent
@onready var mouth: Marker3D = $Model/Mouth
@onready var slam_indicator: AoeCircleIndicator = $SlamIndicator
@onready var _rain_pool: ObjectPool = $RainPool
@onready var _lava_pool: ObjectPool = $LavaPoolPool
@onready var _shot_pool: ObjectPool = $ShotPool


func _enter_tree() -> void:
	var shot_pool: ObjectPool = $ShotPool
	var effects: FireToadVfx = $FireToadVfx
	shot_pool.configure_instance = effects.prepare_shot


func _ready() -> void:
	super()
	health.max_health = data.max_health
	health.heal_full()
	health.health_changed.connect(_on_health_changed)
	health.died.connect(_on_died)
	hurtbox.hurt.connect(_on_hurt)
	for mesh: Node in $Model/Visual.find_children("*", "GeometryInstance3D", true, false):
		_model_meshes.append(mesh as GeometryInstance3D)
	_flash_material = StandardMaterial3D.new()
	_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash_material.albedo_color = data.hit_flash_color
	_enrage_material = StandardMaterial3D.new()
	_enrage_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_enrage_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_enrage_material.albedo_color = data.enrage_tint
	_find_player()
	_adopt_model_animations()
	if throne:
		# Đổi trước khi StateMachine vào state đầu (nó chờ owner.ready)
		state_machine.initial_state = state_machine.get_node(^"Throne") as State
	else:
		warm_pools()
	vfx.bind_model($Model/Visual/ToadModel, mouth)
	phase_changed.connect(vfx.phase_changed)
	state_machine.state_changed.connect(vfx.state_changed)


## Bộ skill đang dùng: cuồng loạn thì bản nâng cấp
func skills() -> FireToadSkills:
	return data.enraged if enraged and data.enraged else data.normal


## Idle hỏi trước khi chọn skill: tới mốc máu thì bay lên (một lần), không cắt ngang skill đang dùng.
## Court không cho (đồng đội đang bay) thì giữ yêu cầu, lần sau hỏi lại
func consume_hover_request(hover_state: StringName) -> bool:
	if not _hover_pending or not can_use_skill(hover_state):
		return false
	_hover_pending = false
	return true


## Court cho dùng skill này lúc này không (không có court thì luôn được)
func can_use_skill(skill: StringName) -> bool:
	return court == null or court.allows_skill(self, skill)


## Court gọi: rời ngai nhảy xuống sân đánh
func engage() -> void:
	if not health.is_dead():
		state_machine.transition_to(&"Engage")


## Tạo sẵn đồ cho trận (gọi khi bắt đầu đánh)
func warm_pools() -> void:
	_rain_pool.reserve(rain_pool_size)
	_lava_pool.reserve(lava_pool_size)
	_shot_pool.reserve(shot_pool_size)


## Bỏ đồ đang rảnh khi ngồi ngai (đồ đang bay / đang cháy giữ lại tới lúc xong)
func trim_pools() -> void:
	_rain_pool.trim()
	_lava_pool.trim()
	_shot_pool.trim()


## Cuồng loạn ngay (court gọi khi đồng đội bị hạ, hoặc tự gọi khi máu tới enrage_ratio)
func enrage() -> void:
	if enraged or health.is_dead():
		return
	enraged = true
	for mesh in _model_meshes:
		mesh.material_overlay = _enrage_material
	phase_changed.emit(PHASE_ENRAGED)


## Court gọi khi kết thúc trận: ẩn đi (đang ngồi ngai thì biến mất tại chỗ)
func vanish() -> void:
	state_machine.transition_to(&"Dead")


## Miễn sát thương (ngồi ngai, bay lên, cúi chào): đòn và tên trúng không tính
func set_invulnerable(value: bool) -> void:
	hurtbox.invulnerable = value


## Chỗ "giữa sân" của con này: nhảy về, bay lên, đáp xuống ở đây
func home_point() -> Vector3:
	return arena_floor_point(home_offset)


func find_target() -> Player:
	if not is_instance_valid(target_player):
		_find_player()
	return target_player


func player_position() -> Vector3:
	var player := find_target()
	return player.global_position if player else arena_floor_point(Vector2.ZERO)


## Điểm trên sàn đấu theo toạ độ (x, z) tính từ tâm sàn, kẹp trong sàn
func arena_floor_point(offset: Vector2) -> Vector3:
	var center := arena_center.global_position if arena_center else global_position
	var limit := arena_half_size - 0.5
	return center + Vector3(clampf(offset.x, -limit, limit), 0.0, clampf(offset.y, -limit, limit))


## Kẹp một điểm thế giới vào trong sàn đấu, đặt lên mặt sàn
func clamp_to_arena(point: Vector3) -> Vector3:
	var center := arena_center.global_position if arena_center else global_position
	return arena_floor_point(Vector2(point.x - center.x, point.z - center.z))


func drop_fireball(target: Vector3, warn_time: float, radius: float) -> void:
	var fireball := _rain_pool.acquire() as FallingFireball
	if not fireball.finished.is_connected(_rain_pool.release):
		fireball.finished.connect(_rain_pool.release)
	fireball.launch(target, warn_time, radius, enraged)


func spawn_lava(where: Vector3, radius: float, lifetime: float) -> void:
	var pool := _lava_pool.acquire() as LavaPool
	if not pool.finished.is_connected(_lava_pool.release):
		pool.finished.connect(_lava_pool.release)
	pool.activate(where, radius, lifetime, enraged)


## Bắn count quả cầu lửa xoè quạt spread_degrees về player (đứng ngoài sân). Đạn bay ngang ở data.shot_height.
## Quả giữa luôn nhắm thẳng chỗ player đang đứng; lead 0..1: player đang chạy thì quạt nới rộng cho một mép phủ tới
## chỗ player sẽ tới, nên chạy thẳng một hướng vẫn bị trúng. Thổi Gió phản lại được, trúng boss thì mất máu
func shoot_fan(count: int, spread_degrees: float, lead: float) -> void:
	var floor_y := arena_floor_point(Vector2.ZERO).y + data.shot_height
	var origin := Vector3(mouth.global_position.x, floor_y, mouth.global_position.z)
	var target := player_position()
	var to_now := Vector3(target.x - origin.x, 0.0, target.z - origin.z)
	if to_now.length_squared() < 0.01:
		to_now = -global_basis.z
	var half_spread := deg_to_rad(spread_degrees) * 0.5
	var player := find_target()
	var shots := maxi(count, 1)
	for i in shots:
		var fireball := _shot_pool.acquire() as BossFireball
		if not fireball.finished.is_connected(_shot_pool.release):
			fireball.finished.connect(_shot_pool.release)
		if i == 0 and player and lead > 0.0:
			var run := Vector3(player.velocity.x, 0.0, player.velocity.z)
			var flight_time := to_now.length() / maxf(fireball.speed, 0.1)
			var to_lead := to_now + run * flight_time * lead
			half_spread = maxf(half_spread, absf(to_now.signed_angle_to(to_lead, Vector3.UP)))
		var direction := to_now.normalized()
		if shots > 1:
			var t := float(i) / float(shots - 1) * 2.0 - 1.0
			direction = direction.rotated(Vector3.UP, half_spread * t)
		fireball.launch(origin, direction, self)
		vfx.play_shot(fireball, direction)


## Quả cầu lửa bị phản (BossFireball gọi theo tên)
func on_fireball_hit(_fireball: Node) -> void:
	var info := DamageInfo.new(1, DamageInfo.Type.FIRE, Vector3.ZERO, null)
	hurtbox.receive_hit(info)


## Gọi count nhện canh lên các bệ góc (bệ ngẫu nhiên, không trùng), lệch nhau stagger giây.
## Nhện bị giết trước đó thì lần gọi sau mới có lại; nhện cũ còn sống thì giữ nguyên
func summon_sentinels(count: int, stagger: float) -> void:
	_sentinels = _sentinels.filter(func(s: Enemy) -> bool: return is_instance_valid(s) and not s.is_dead())
	var free_perches: Array[Node3D] = sentinel_perches.duplicate()
	free_perches.shuffle()
	var wanted := mini(count, free_perches.size()) - _sentinels.size()
	var gen := _summon_gen
	for i in maxi(wanted, 0):
		if i > 0 and stagger > 0.0:
			await get_tree().create_timer(stagger, false, true).timeout
		if gen != _summon_gen or not is_inside_tree() or health.is_dead():
			return
		var spider := sentinel_scene.instantiate() as Enemy
		get_parent().add_child(spider)
		spider.global_position = free_perches[i].global_position
		spider.reset_physics_interpolation()
		_sentinels.append(spider)
		vfx.sentinel_puff(spider.global_position, true)


## Boss quay về sân / chết: nhện canh còn sống rút đi (không rơi đồ, không tính là bị giết)
func dismiss_sentinels() -> void:
	_summon_gen += 1
	for spider in _sentinels:
		if is_instance_valid(spider):
			vfx.sentinel_puff(spider.global_position, false)
			spider.queue_free()
	_sentinels.clear()


## Nhảy vòng cung tới target trong time giây (boss tự di chuyển, không cần vật lý). Chờ được bằng await
func leap_to(target: Vector3, height: float, time: float) -> void:
	var start := global_position
	var flat := Vector3(target.x - start.x, 0.0, target.z - start.z)
	if flat.length_squared() > 0.01:
		face_instantly(flat.normalized())
	velocity = Vector3.ZERO
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_method(func(t: float) -> void:
		global_position = start.lerp(target, t) + Vector3.UP * height * 4.0 * t * (1.0 - t), 0.0, 1.0, time)
	await tween.finished


## Bay lên / hạ xuống theo đường thẳng đứng (phase 2)
func fly_to(target: Vector3, time: float) -> void:
	velocity = Vector3.ZERO
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(self, ^"global_position", target, time).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	await tween.finished


func face_player() -> void:
	var to_player := player_position() - global_position
	to_player.y = 0.0
	if to_player.length_squared() > 0.01:
		face_instantly(to_player.normalized())


## Chạy clip nếu model có (model tạm chưa có animation thì bỏ qua, không lỗi)
func play_clip(clip: StringName, loop: bool = false) -> void:
	if not _anim.has_animation(clip):
		return
	if loop:
		play_anim(clip)
	else:
		play_action(clip)


## Model .glb mang AnimationPlayer riêng: chuyển thư viện clip sang AnimationPlayer của Character để play_anim /
## play_action dùng chung. Đổi model khác chỉ cần thay node trong Model/Visual, không sửa code
func _adopt_model_animations() -> void:
	if _anim.has_animation_library(&""):
		return
	var players := $Model/Visual.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return
	var source := players[0] as AnimationPlayer
	source.stop()
	_anim.root_node = _anim.get_path_to(source.get_node(source.root_node))
	_anim.add_animation_library(&"", source.get_animation_library(&""))
	source.active = false


func _find_player() -> void:
	var found := get_tree().get_first_node_in_group(&"player") as Player
	if found == null and get_tree().current_scene:
		var players := get_tree().current_scene.find_children("*", "Player", true, false)
		if not players.is_empty():
			found = players[0] as Player
	target_player = found


func _on_health_changed(current: int, max_value: int) -> void:
	var ratio := float(current) / maxf(float(max_value), 1.0)
	if not _hover_done and current > 0 and ratio <= data.hover_ratio:
		_hover_done = true
		_hover_pending = true
		phase_changed.emit(PHASE_HOVER)
	if current > 0 and ratio <= data.enrage_ratio:
		enrage()


func _on_hurt(_info: DamageInfo, _damage_taken: int) -> void:
	for mesh in _model_meshes:
		mesh.material_overlay = _flash_material
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_interval(data.hit_flash_time)
	_flash_tween.tween_callback(_restore_overlay)


func _restore_overlay() -> void:
	for mesh in _model_meshes:
		mesh.material_overlay = _enrage_material if enraged else null


func _on_died() -> void:
	state_machine.transition_to(defeat_state)
	defeated.emit()
