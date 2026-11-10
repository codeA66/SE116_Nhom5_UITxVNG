class_name SkillShrine
extends Node3D
## Phòng học kỹ năng lần đầu (tham khảo phòng nhận phép của Hollow Knight): sách nằm trên bệ giữa cột năng lượng.
## Bước vào gần bệ: phòng tối dần quanh sách, gió và bụi trôi về bệ, cột sáng mạnh lên. Nhặt sách: chuỗi trình diễn
## nhận kỹ năng chạy với nhịp riêng của phòng (có pha Hấp thu). Học xong: phòng rút màu, phủ sương (đã cạn sức mạnh)
## rồi dịch chuyển player tới arrival_spawn_id (phòng kế tiếp). Không bỏ qua được.
## Hành vi theo FSM dạng node (states/). Đổi kỹ năng / nơi đến chỉ cần đổi export, không sửa code.

signal player_entered(player: Player)
signal player_exited
signal ceremony_started
signal ceremony_finished
## Kỹ năng đã học: phòng làm nguồn mở cổng (StoneGate đọc signal activated + is_active())
signal activated

@export var ability: AbilityData
## Cờ lưu "đã học": trùng với cờ của cuốn sách. Đổi chỗ đặt sách thì giữ nguyên cờ cũ để save cũ không nhận lại
@export var persistent_id: StringName
## Điểm xuất hiện (SpawnPoint.spawn_id) ở phòng kế tiếp; trống = học xong không dịch chuyển
@export var arrival_spawn_id: StringName
## Nhịp trình diễn riêng của phòng học (có pha Hấp thu)
@export var acquire_data: AbilityAcquireData = preload("res://resources/feedback/ability_acquire/ability_acquire_shrine.tres")

@export_group("Mood")
## Tối dần quanh sách khi đến gần (0..1) và thời gian chuyển
@export_range(0.0, 1.0) var approach_dim: float = 0.55
@export var approach_time: float = 1.2
## Học xong: rút màu, phủ sương (0..1), giữ bao lâu trước khi dịch chuyển
@export_range(0.0, 1.0) var spent_desaturate: float = 0.85
@export_range(0.0, 1.0) var spent_fog: float = 0.25
@export var spent_time: float = 1.6
@export_group("Aura")
@export var idle_aura: float = 0.55
@export var approach_aura: float = 1.0
@export_group("Lights")
@export var beam_idle_energy: float = 2.0
@export var beam_approach_energy: float = 5.0
@export var glow_idle_energy: float = 0.8
@export var glow_approach_energy: float = 2.2
## Lúc nghi thức: hạ đèn bệ để mặt bệ không loé thành mảng trắng sau lưng nhân vật
@export var beam_ceremony_energy: float = 0.6
@export var glow_ceremony_energy: float = 0.3
@export var ceremony_light_time: float = 0.4
@export_group("Aura color")
## Màu đốm sáng nghi thức (trắng tinh theo Hollow Knight)
@export var aura_color: Color = Color.WHITE

var player: Player

var _mood_tween: Tween
var _light_tween: Tween
var _camera: Camera3D

@onready var book: AbilityPickup = get_node_or_null(^"Book") as AbilityPickup
@onready var state_machine: StateMachine = $StateMachine
@onready var _aura: ShrineAura = $Aura
@onready var _drift: CPUParticles3D = $Drift
@onready var _beam: SpotLight3D = $Beam
@onready var _glow: OmniLight3D = $Glow
@onready var _rune: MeshInstance3D = $Pedestal/RuneRing
@onready var _approach: Area3D = $ApproachArea
@onready var _mood: ColorRect = $Mood/Screen
@onready var _mood_material: ShaderMaterial = _mood.material as ShaderMaterial


## Gán kỹ năng, cờ và nhịp trình diễn cho sách trước khi sách vào cây (trình diễn đọc dữ liệu ở _enter_tree)
func _enter_tree() -> void:
	var pickup := get_node_or_null(^"Book") as AbilityPickup
	if pickup == null:
		return
	pickup.ability = ability
	pickup.persistent_id = persistent_id
	var acquisition := pickup.get_node_or_null(^"AbilityAcquireVfx")
	if acquisition and acquire_data:
		acquisition.set(&"data", acquire_data)


func _ready() -> void:
	set_process(false)
	_mood.hide()
	_apply_mood(Vector3.ZERO)
	var accent: Color = ability.accent_color if ability else Color.WHITE
	_aura.set_color(aura_color)
	if book:
		_aura.set_source(_aura.to_local(book.global_position + Vector3.UP * acquire_data.book_rise))
	_glow.light_color = accent
	_beam.light_color = accent.lerp(Color.WHITE, 0.6)
	_drift.color = accent.lerp(Color.WHITE, 0.4)
	# Vòng khắc trên mặt bệ sáng theo màu nguyên tố (material riêng, không đổi material dùng chung của scene)
	var rune := StandardMaterial3D.new()
	rune.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rune.albedo_color = accent.lerp(Color.WHITE, 0.35)
	_rune.material_override = rune
	_approach.body_entered.connect(_on_body_entered)
	_approach.body_exited.connect(_on_body_exited)
	if book:
		var acquisition: AbilityAcquireVfx = book.get_node_or_null(^"AbilityAcquireVfx") as AbilityAcquireVfx
		if acquisition:
			acquisition.phase_started.connect(_on_phase_started)
			acquisition.finished.connect(_on_acquisition_finished)
			if acquire_data.continuous_energy:
				acquisition.renderer.spatial_frame.connect(_aura.set_ceremony_frame)
				acquisition.cancelled.connect(_on_acquisition_cancelled)


## Chỉ chạy khi lớp không khí đang hiện: tâm vùng sáng bám theo chỗ sách trên màn hình
func _process(_delta: float) -> void:
	if _camera == null or not is_instance_valid(_camera):
		_camera = get_viewport().get_camera_3d()
		if _camera == null:
			return
	var focus_point: Vector3 = global_position + Vector3.UP
	if not _camera.is_position_behind(focus_point):
		var size: Vector2 = get_viewport().get_visible_rect().size
		_mood_material.set_shader_parameter(&"focus", _camera.unproject_position(focus_point) / size)
		_mood_material.set_shader_parameter(&"aspect", size.x / maxf(size.y, 1.0))


## Đúng khi kỹ năng của phòng đã học (sách không còn)
func is_learned() -> bool:
	return GameState.has_flag(persistent_id) or (ability != null and GameState.has_ability(ability.id))


## Cho cổng đá: đã học thì coi như nguồn đang bật
func is_active() -> bool:
	return is_learned()


## Chuyển không khí phòng (tối quanh sách, rút màu, sương) trong time giây; tất cả về 0 thì tắt hẳn lớp phủ
func set_mood(dim: float, desaturate: float, fog: float, time: float) -> void:
	if _mood_tween and _mood_tween.is_valid():
		_mood_tween.kill()
	var target := Vector3(dim, desaturate, fog)
	if not target.is_zero_approx():
		_mood.show()
		set_process(true)
	var start := Vector3(float(_mood_material.get_shader_parameter(&"dim")), float(_mood_material.get_shader_parameter(&"desaturate")), float(_mood_material.get_shader_parameter(&"fog")))
	# Rút sương trước khi fade dịch chuyển mở lại để màn hình mới không còn lượt vẽ của phòng cũ.
	var duration: float = time
	if acquire_data.continuous_energy and target.is_zero_approx() and start.z > 0.0:
		duration = minf(duration, SceneManager.fade_duration)
	_mood_tween = create_tween()
	_mood_tween.tween_method(_apply_mood, start, target, maxf(duration, 0.001))
	if target.is_zero_approx():
		_mood_tween.tween_callback(_hide_mood)


## Mức sáng của cột năng lượng, đèn rọi và gió trôi về bệ theo trạng thái
func set_presence(aura: float, beam: float, glow: float, drifting: bool, time: float) -> void:
	_aura.set_intensity(aura, time)
	_drift.emitting = drifting and not acquire_data.continuous_energy
	set_lights(beam, glow, time)


## Chỉ đổi đèn rọi và đèn quanh bệ, không đụng cột năng lượng (nghi thức đang điều khiển nó)
func set_lights(beam: float, glow: float, time: float) -> void:
	if _light_tween and _light_tween.is_valid():
		_light_tween.kill()
	# Nghi thức dừng cây (pause) nên tween đèn phải chạy cả khi pause
	_light_tween = create_tween().set_parallel(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_light_tween.tween_property(_beam, "light_energy", beam, maxf(time, 0.001))
	_light_tween.tween_property(_glow, "light_energy", glow, maxf(time, 0.001))



## Vòng khắc sáng trên mặt bệ: tắt lúc nghi thức để không thành vành elip trắng sau lưng nhân vật
func set_rune_visible(value: bool) -> void:
	_rune.visible = value

## Dịch chuyển player tới điểm xuất hiện của phòng kế tiếp (tối màn → đặt → sáng). Trả false nếu không có nơi đến
func warp_to_arrival() -> bool:
	if arrival_spawn_id.is_empty() or not is_instance_valid(player):
		return false
	var zone: Node = get_tree().current_scene if get_tree().current_scene else owner
	var spawn := SpawnPoint.find_in(zone, arrival_spawn_id)
	if spawn == null:
		push_warning("%s: không tìm thấy SpawnPoint '%s'" % [name, arrival_spawn_id])
		return false
	await SceneManager.warp_player(player, spawn.global_position, spawn.get_facing())
	return true


func _apply_mood(value: Vector3) -> void:
	_mood_material.set_shader_parameter(&"dim", value.x)
	_mood_material.set_shader_parameter(&"desaturate", value.y)
	_mood_material.set_shader_parameter(&"fog", value.z)


func _hide_mood() -> void:
	_mood.hide()
	set_process(false)


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		player = body as Player
		player_entered.emit(player)


func _on_body_exited(body: Node3D) -> void:
	if body == player:
		player_exited.emit()


## Màn đen cắt hẳn lượt vẽ sau khi đuôi gió đã tan.
func _on_phase_started(phase: StringName) -> void:
	if acquire_data.continuous_energy and (phase == &"Blackout" or phase == &"Reveal"):
		_aura.end_ceremony()
	ceremony_started.emit()


## Hủy cũng dọn mesh ngay, không chờ một pha sau có thể không chạy.
func _on_acquisition_cancelled(_committed: bool) -> void:
	_aura.end_ceremony()


func _on_acquisition_finished() -> void:
	ceremony_finished.emit()
	activated.emit()
