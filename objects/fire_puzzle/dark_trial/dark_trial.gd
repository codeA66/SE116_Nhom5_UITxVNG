class_name DarkTrial
extends Node3D
## Thử thách u tối (tier 2 map Lửa, bản 2 giai đoạn 3): công tắc ở bệ sáng thì khu chìm vào bóng tối, đồng hồ chạy,
## các trụ năng lượng (EnergyPillar) xuất hiện. Thắp đủ trụ trước khi hết giờ: lưu data.done_flag, trời sáng lại.
## Hết giờ: dọn trụ, sáng lại, bệ hiện "THỬ LẠI". Chết giữa chừng thì scene tải lại nên thử thách tự về lúc chưa chạy.
## Vùng tối là DarkZone tạo lúc bắt đầu; vùng tối khác chồng lên (phòng 07) được tạm tắt để hai vùng không giành đèn.
## Hiệu năng: Timer một lần cho hết giờ; _process chỉ chạy khi đang thử thách và chỉ đổi chữ khi giây đổi.

signal started
signal pillar_lit(lit_count: int, total: int)
signal finished(success: bool)

@export var data: DarkTrialData
@export var altar: ShardAltar
@export_group("Ánh sáng")
@export var sun: DirectionalLight3D
@export var bounce_light: DirectionalLight3D
@export var world_environment: WorldEnvironment
## Vùng tối có sẵn nằm trong khu thử thách: tắt theo dõi lúc thử thách chạy
@export var suspend_zones: Array[DarkZone] = []
@export_group("Scene")
@export var pillar_scene: PackedScene = preload("res://objects/fire_puzzle/dark_trial/energy_pillar.tscn")
@export var dark_zone_scene: PackedScene = preload("res://objects/world/cellar/dark_zone/dark_zone.tscn")
@export_range(0.0, 1.0, 0.01) var complete_trauma: float = 0.35

var _running: bool = false
var _lit: int = 0
var _pillars: Array[EnergyPillar] = []
var _dark: DarkZone
var _shown_second: int = -1

@onready var _timer: Timer = $Timer
@onready var _hud: TrialTimer = $TrialTimer
@onready var _pillars_root: Node3D = $Pillars
@onready var _start: InteractableComponent = $StartInteract


func _ready() -> void:
	set_process(false)
	_start.enabled = false
	if data == null or altar == null:
		push_error("%s: thiếu data hoặc altar" % get_path())
		return
	if is_done():
		return
	_timer.one_shot = true
	_timer.ignore_time_scale = data.real_time_clock
	_timer.timeout.connect(_on_time_up)
	_start.interacted.connect(func(_actor: Node3D) -> void: start())
	_start.global_position = altar.global_position
	if altar.is_active():
		# Đã ghép công tắc từ trước (tải lại / hồi sinh): chờ người chơi bấm bệ để bắt đầu
		_offer(data.start_prompt)
	else:
		altar.activated.connect(start, CONNECT_ONE_SHOT)


func _process(_delta: float) -> void:
	var left: float = _timer.time_left
	var second: int = ceili(left)
	if second != _shown_second:
		_shown_second = second
		_hud.set_time(left, data.warning_time)


func is_done() -> bool:
	return not data.done_flag.is_empty() and GameState.has_flag(data.done_flag)


func is_running() -> bool:
	return _running


func lit_count() -> int:
	return _lit


func get_pillars() -> Array[EnergyPillar]:
	return _pillars


func time_left() -> float:
	return _timer.time_left if _running else 0.0


func start() -> void:
	if _running or is_done():
		return
	_running = true
	_lit = 0
	_start.enabled = false
	for zone: DarkZone in suspend_zones:
		zone.monitoring = false
	for pillar_data: DarkTrialPillarData in data.pillars:
		var pillar := pillar_scene.instantiate() as EnergyPillar
		pillar.setup(pillar_data)
		_pillars_root.add_child(pillar)
		pillar.lit.connect(_on_pillar_lit, CONNECT_ONE_SHOT)
		_pillars.append(pillar)
	_dark = dark_zone_scene.instantiate() as DarkZone
	_dark.boxes = data.dark_boxes
	_dark.sun = sun
	_dark.bounce_light = bounce_light
	_dark.world_environment = world_environment
	_dark.dark_ambient_ratio = data.dark_ambient_ratio
	add_child(_dark)
	_timer.start(data.duration)
	_shown_second = -1
	_hud.show_timer()
	set_process(true)
	_process(0.0)
	started.emit()


func _on_pillar_lit() -> void:
	_lit += 1
	pillar_lit.emit(_lit, _pillars.size())
	if _lit >= _pillars.size():
		_finish(true)


func _on_time_up() -> void:
	_finish(false)


func _finish(success: bool) -> void:
	if not _running:
		return
	_running = false
	set_process(false)
	_timer.stop()
	_hud.hide_timer()
	_clear_dark()
	for zone: DarkZone in suspend_zones:
		zone.monitoring = true
	if success:
		if not data.done_flag.is_empty():
			GameState.set_flag(data.done_flag)
		if complete_trauma > 0.0:
			ScreenShake.add_trauma(complete_trauma)
	else:
		for pillar: EnergyPillar in _pillars:
			pillar.queue_free()
		_pillars.clear()
		_offer(data.retry_prompt)
	finished.emit(success)


func _offer(prompt: String) -> void:
	_start.prompt_text = prompt
	_start.enabled = true


## Đẩy vùng tối ra xa để DarkZone nhận body_exited và tự trả ánh sáng, rồi bỏ sau khi tween sáng lại xong
func _clear_dark() -> void:
	if _dark == null:
		return
	var zone: DarkZone = _dark
	_dark = null
	zone.global_position += Vector3(0.0, -1000.0, 0.0)
	get_tree().create_timer(zone.fade_time + 0.3).timeout.connect(zone.queue_free)
