class_name LaserStatue
extends StaticBody3D
## Tượng đá bắn "tia tử thần": đường tia trên mặt đất nằm dọc hướng tượng → player, xuyên qua chỗ player,
## đầu tia chạy dọc đường từ phía gần tượng ra xa. Tượng có máu (HealthComponent + HurtboxComponent lớp enemy):
## player đánh vỡ được, vỡ thì sang StatueDead và lưu persistent_id.
## Hành vi nằm ở các state con của $StateMachine (StatueIdle → StatueAim → StatueLock → StatueFire → StatueCooldown,
## StatueDead khi hết máu);
## script này là API mỏng cho các state: mục tiêu, đường tia, chiếu tia từ mắt (raycast, tường chặn),
## đường cảnh báo / vệt cháy, vùng sát thương đi theo đầu tia.
## Hiệu năng: vùng phát hiện theo signal vào / ra; không có player trong tầm và đang chờ thì tắt _physics_process.

signal aim_started
signal locked(center: Vector3)
## Bắt đầu quét: hai đầu đường tia
signal fired(from: Vector3, to: Vector3)
signal destroyed

enum BeamMode { OFF, AIM, LOCK, FIRE }

## Chiều cao vùng sát thương tại đầu tia: cao bằng người
const DAMAGE_HEIGHT: float = 2.0
## Đường cảnh báo / vệt cháy nằm sát trên mặt đất (tránh z-fighting)
const GROUND_OFFSET: float = 0.03

@export var data: LaserStatueData
## Cờ GameState lưu tượng đã vỡ (vào lại map không hồi); trống = mỗi lần vào map đều còn
@export var persistent_id: StringName
@export var dead_state: StringName = &"StatueDead"
## Lớp phủ nháy khi bị đánh
@export var hit_flash_material: Material
## Phóng to tượng (hình, va chạm thân, hurtbox, mắt bắn tia). Đường tia, vùng sát thương và tầm phát hiện
## nằm trong data nên không đổi: tượng to hơn mà độ khó né giữ nguyên
@export_range(0.25, 5.0, 0.05) var model_scale: float = 1.0
## Vùng phòng (Area3D thấy player): có gán thì tượng chỉ nhắm khi player đã vào phòng, đứng ngoài cửa không bị bắn.
## Trống = chỉ dùng tầm phát hiện
@export var room_zone: Area3D
## Chờ bao lâu (s) sau khi player vào room_zone mới bắt đầu nhắm. 0 = ngay
@export_range(0.0, 10.0, 0.1) var start_delay: float = 0.0

var target: Player
## Tâm đường tia trên mặt đất (toàn cục)
var aim_point: Vector3

var _ray_query: PhysicsRayQueryParameters3D
## Player trong tầm phát hiện (chưa chắc đã vào phòng)
var _nearby: Player
var _in_room: bool = true
var _beam_width: float = 0.0
var _beam_mat: StandardMaterial3D
var _warn_mat: StandardMaterial3D
var _trail_mat: StandardMaterial3D
var _damage_box: BoxShape3D
var _trail_tween: Tween
var _flash_meshes: Array[GeometryInstance3D] = []
var _flash_tween: Tween

@onready var state_machine: StateMachine = $StateMachine
@onready var _eye: Marker3D = $Eye
@onready var _beam: MeshInstance3D = $Beam
@onready var _warn_line: MeshInstance3D = $WarnLine
@onready var _trail: MeshInstance3D = $Trail
@onready var _detect: Area3D = $Detect
@onready var _detect_shape: CollisionShape3D = $Detect/CollisionShape3D
@onready var _damage_area: DamageArea = $DamageArea
@onready var _damage_shape: CollisionShape3D = $DamageArea/CollisionShape3D
@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: HurtboxComponent = $HurtboxComponent
@onready var _model: Node3D = $Model


func _ready() -> void:
	assert(data != null, "%s: chưa gắn LaserStatueData" % get_path())
	_apply_model_scale()
	for n: Node3D in [_beam, _warn_line, _trail, _damage_area]:
		n.top_level = true
	# Vật liệu / shape riêng từng tượng: màu và kích thước đổi theo từng phát
	_beam_mat = _own_material(_beam)
	_warn_mat = _own_material(_warn_line)
	_trail_mat = _own_material(_trail)
	_warn_mat.albedo_color = data.warn_color
	_trail_mat.albedo_color = data.trail_color
	_damage_box = BoxShape3D.new()
	_damage_box.size = Vector3(data.line_width, DAMAGE_HEIGHT, data.line_width)
	_damage_shape.shape = _damage_box
	_damage_shape.position.y = DAMAGE_HEIGHT * 0.5
	_damage_shape.disabled = true
	_damage_area.damage = data.damage
	_damage_area.damage_type = data.damage_type
	_damage_area.knockback = data.knockback
	# Mỗi lượt quét chỉ trúng một lần
	_damage_area.hit_interval = data.sweep_time + 1.0
	var sphere := SphereShape3D.new()
	sphere.radius = data.detect_range
	_detect_shape.shape = sphere
	_detect_shape.position = _eye.position
	_detect.body_entered.connect(_on_body_entered)
	_detect.body_exited.connect(_on_body_exited)
	if room_zone:
		_in_room = false
		room_zone.body_entered.connect(_on_room_entered)
		room_zone.body_exited.connect(_on_room_exited)
	_ray_query = PhysicsRayQueryParameters3D.new()
	_ray_query.collision_mask = data.blocking_mask
	_ray_query.exclude = [get_rid()]
	set_beam(BeamMode.OFF)
	_warn_line.visible = false
	_trail.visible = false
	health.max_health = data.max_health
	health.heal_full()
	for node: Node in _model.find_children("*", "GeometryInstance3D", true, false):
		_flash_meshes.append(node as GeometryInstance3D)
	hurtbox.hurt.connect(_on_hurt)
	health.died.connect(_on_died)
	set_physics_process(false)
	if not persistent_id.is_empty() and GameState.has_flag(persistent_id):
		# Đã vỡ từ trước: vào thẳng trạng thái vỡ. Hoãn tới sau khi FSM vào state đầu (FSM chờ owner.ready)
		state_machine.transition_to.call_deferred(dead_state)


func _physics_process(delta: float) -> void:
	state_machine.physics_update(delta)


# ---------- Mục tiêu ----------

func get_eye_position() -> Vector3:
	return _eye.global_position


func has_target() -> bool:
	return target != null and is_instance_valid(target)


func get_target_feet() -> Vector3:
	return target.global_position


## Còn trong tầm và nhìn thấy (không có tường giữa mắt và người)
func can_see_target() -> bool:
	if not has_target():
		return false
	var chest := target.global_position + Vector3.UP * 0.8
	if _eye.global_position.distance_to(chest) > data.detect_range:
		return false
	return _raycast(_eye.global_position, chest).is_empty()


## Kéo tâm đường tia về phía chân player với tốc độ giới hạn
func track_target(delta: float) -> void:
	aim_point = aim_point.move_toward(get_target_feet(), data.track_speed * delta)


# ---------- Đường tia ----------

## Hướng đường tia: nằm ngang, dọc hướng tượng → tâm đường (đầu tia chạy từ phía tượng ra xa)
func line_direction() -> Vector3:
	var to := aim_point - global_position
	to.y = 0.0
	if to.length_squared() < 0.0001:
		to = global_basis.z
		to.y = 0.0
	return to.normalized()


func line_start() -> Vector3:
	return aim_point - line_direction() * data.line_length * 0.5


func line_end() -> Vector3:
	return aim_point + line_direction() * data.line_length * 0.5


## Điểm trên đường tia theo tiến độ quét 0..1
func line_point(t: float) -> Vector3:
	return line_start().lerp(line_end(), clampf(t, 0.0, 1.0))


## Đường cảnh báo phủ cả đường tia (gọi mỗi frame lúc ngắm vì tâm đường đổi)
func show_warning(color: Color) -> void:
	_warn_mat.albedo_color = color
	_warn_line.global_transform = _ground_strip(line_start(), line_end())
	_warn_line.visible = true


func hide_warning() -> void:
	_warn_line.visible = false


## Vệt cháy từ đầu đường tới điểm head (sau đầu tia)
func show_trail(head: Vector3) -> void:
	if _trail_tween:
		_trail_tween.kill()
	_trail_mat.albedo_color = data.trail_color
	_trail.global_transform = _ground_strip(line_start(), head)
	_trail.visible = true


func fade_trail() -> void:
	if _trail_tween:
		_trail_tween.kill()
	if data.trail_fade_time <= 0.0:
		_trail.visible = false
		return
	var clear := data.trail_color
	clear.a = 0.0
	_trail_tween = create_tween()
	_trail_tween.tween_property(_trail_mat, ^"albedo_color", clear, data.trail_fade_time)
	_trail_tween.tween_callback(_trail.hide)


# ---------- Tia từ mắt ----------

func set_beam(mode: BeamMode) -> void:
	_beam.visible = mode != BeamMode.OFF
	if mode == BeamMode.OFF:
		return
	_beam_width = data.fire_width if mode == BeamMode.FIRE else data.aim_width
	match mode:
		BeamMode.AIM:
			_beam_mat.albedo_color = data.aim_color
		BeamMode.LOCK:
			_beam_mat.albedo_color = data.lock_color
		BeamMode.FIRE:
			_beam_mat.albedo_color = data.fire_color


func set_beam_color(color: Color) -> void:
	_beam_mat.albedo_color = color


## Dựng tia từ mắt tới point; trả về điểm chạm thật (dừng ở vật cản đầu tiên) và cờ bị chặn
func aim_beam_at(point: Vector3) -> Dictionary:
	var from := _eye.global_position
	var hit := _raycast(from, point)
	var end: Vector3 = point if hit.is_empty() else hit[&"position"]
	# Chạm sát đích (mặt đất ngay dưới điểm) không tính là bị chặn
	var blocked := not hit.is_empty() and end.distance_to(point) > 0.3
	_beam.global_transform = _segment_transform(from, end, Vector3(_beam_width, from.distance_to(end), _beam_width))
	return {&"end": end, &"blocked": blocked}


# ---------- Sát thương ----------

## Đặt vùng sát thương tại đầu tia; bị tường chặn thì tắt
func damage_at(point: Vector3, active: bool) -> void:
	_damage_area.global_transform = Transform3D(Basis(Vector3.UP, atan2(line_direction().x, line_direction().z)), point)
	if active == _damage_shape.disabled:
		_damage_shape.set_deferred(&"disabled", not active)


func disable_damage() -> void:
	_damage_shape.set_deferred(&"disabled", true)


func is_damaging() -> bool:
	return not _damage_shape.disabled


func shake() -> void:
	if data.shake_trauma > 0.0:
		ScreenShake.add_trauma_at(data.shake_trauma, aim_point, 8.0, 20.0)


# ---------- Độ bền ----------

func is_destroyed() -> bool:
	return health.is_dead()


## Vỡ: tắt mọi tia / vùng, ngừng nhận đòn, ngừng phát hiện; model sụp xuống đất. instant = vào map lúc đã vỡ
func crumble(instant: bool) -> void:
	set_beam(BeamMode.OFF)
	hide_warning()
	_trail.visible = false
	disable_damage()
	hurtbox.set_deferred(&"monitorable", false)
	_detect.set_deferred(&"monitoring", false)
	target = null
	$FigureCollision.set_deferred(&"disabled", true)
	var sunk := Vector3(1.0, 0.25, 1.0) * model_scale
	if instant or data.crumble_time <= 0.0:
		_model.scale = sunk
		return
	create_tween().tween_property(_model, ^"scale", sunk, data.crumble_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)


func _on_hurt(_info: DamageInfo, _taken: int) -> void:
	if hit_flash_material == null or data.hit_flash_time <= 0.0 or health.is_dead():
		return
	_set_overlay(hit_flash_material)
	if _flash_tween:
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_interval(data.hit_flash_time)
	_flash_tween.tween_callback(_set_overlay.bind(null))


func _on_died() -> void:
	_set_overlay(null)
	if not persistent_id.is_empty():
		GameState.set_flag(persistent_id)
	state_machine.transition_to(dead_state)
	destroyed.emit()


## Không scale node vật lý (Godot không hỗ trợ tốt): nhân kích thước shape và vị trí thay vào đó
func _apply_model_scale() -> void:
	if is_equal_approx(model_scale, 1.0):
		return
	_model.scale = Vector3.ONE * model_scale
	_eye.position *= model_scale
	for shape_node: CollisionShape3D in [$PedestalCollision, $FigureCollision, $HurtboxComponent/CollisionShape3D]:
		var box: BoxShape3D = (shape_node.shape as BoxShape3D).duplicate() as BoxShape3D
		box.size *= model_scale
		shape_node.shape = box
		shape_node.position *= model_scale


func _set_overlay(mat: Material) -> void:
	for mesh: GeometryInstance3D in _flash_meshes:
		mesh.material_overlay = mat


# ---------- Nội bộ ----------

func _own_material(mesh: MeshInstance3D) -> StandardMaterial3D:
	var mat := (mesh.mesh.surface_get_material(0) as StandardMaterial3D).duplicate() as StandardMaterial3D
	mesh.material_override = mat
	return mat


## Biến đổi trải một tấm phẳng 1 × 1 (PlaneMesh, trục X × Z) từ a tới b trên mặt đất, rộng line_width
func _ground_strip(a: Vector3, b: Vector3) -> Transform3D:
	var along := b - a
	along.y = 0.0
	var length := maxf(along.length(), 0.001)
	var x := along / length
	var z := Vector3(-x.z, 0.0, x.x)
	var center := (a + b) * 0.5
	center.y = aim_point.y + GROUND_OFFSET
	return Transform3D(Basis(x * length, Vector3.UP, z * data.line_width), center)


## Biến đổi đặt một hình trụ cao 1 (trục Y) nằm dọc đoạn a → b, scale theo size
func _segment_transform(a: Vector3, b: Vector3, size: Vector3) -> Transform3D:
	var y := b - a
	var length := y.length()
	y = y / length if length > 0.0001 else Vector3.DOWN
	var side := Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT
	var x := y.cross(side).normalized()
	var z := x.cross(y).normalized()
	return Transform3D(Basis(x * size.x, y * size.y, z * size.z), (a + b) * 0.5)


func _raycast(from: Vector3, to: Vector3) -> Dictionary:
	_ray_query.from = from
	_ray_query.to = to
	return get_world_3d().direct_space_state.intersect_ray(_ray_query)


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		_nearby = body as Player
		_update_target()


func _on_body_exited(body: Node3D) -> void:
	if body == _nearby:
		_nearby = null
		_update_target()


func _on_room_entered(body: Node3D) -> void:
	if body is Player:
		if start_delay > 0.0:
			await get_tree().create_timer(start_delay, false).timeout
			if not is_inside_tree() or not room_zone.overlaps_body(body):
				return
		_in_room = true
		_update_target()


func _on_room_exited(body: Node3D) -> void:
	if body is Player:
		_in_room = false
		_update_target()


## Chỉ nhắm khi player vừa trong tầm vừa ở trong phòng
func _update_target() -> void:
	if is_destroyed():
		return
	target = _nearby if _in_room and is_instance_valid(_nearby) else null
	if target:
		set_physics_process(true)
