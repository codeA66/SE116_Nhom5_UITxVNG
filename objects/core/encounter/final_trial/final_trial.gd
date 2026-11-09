class_name FinalTrial
extends Node3D
## Thử thách cuối ở Hub: trụ xanh (Altar) giữa phòng. Sàn phòng do node này dựng (lưới ô grid_cells x cell_size),
## mỗi ô (trừ các ô sát trụ) có một ngọn lửa vuông GridFlame vừa khít ô.
## - Chưa có unlock_flag: tương tác trụ chỉ hiện locked_text.
## - Có unlock_flag: hỏi ask_text (ĐỒNG Ý / CHƯA). Đồng ý: mọi ô sàn rung rồi đổi sang sàn lưới dung nham,
##   các cửa (TrialSeal con của Seals) đóng, đồng hồ duration giây. Lửa phun theo các kiểu lặp vòng (patterns):
##   từ giữa lan theo chiều dọc, từ giữa lan theo chiều ngang, từ giữa lan ra 4 phía, so le kiểu bàn cờ.
##   Càng về cuối càng nhanh: thời gian cảnh báo, khoảng giữa các bước và nghỉ giữa các kiểu đều ngắn dần.
## - Sống hết giờ: sàn trở lại, cửa mở, lưu persistent_id, phát completed / activated (nguồn cho cổng phòng boss).
## - Hết máu giữa chừng (thất bại): không chết thật; màn tối, player xuất hiện lại trước trụ (Retry) đầy máu,
##   lửa tắt, sàn và cửa trở lại, chạm trụ để nhận lại thử thách. Tắt fail_returns_to_altar thì chết như thường.
## Hiệu năng: không có _process; nhịp lửa dùng timer của SceneTree, rung sàn là tween ngắn.

signal started
signal completed
signal failed
signal activated

enum Pattern { SPREAD_VERTICAL, SPREAD_HORIZONTAL, SPREAD_ALL, CHECKER }

const PLAIN_TILE: PackedScene = preload("res://assets/models/map_fire/fire_kit/floor_4m.glb")
const GRATE_TILE: PackedScene = preload("res://assets/models/map_fire/fire_kit/floor_lava_grate_4m.glb")
const FLAME_SCENE: PackedScene = preload("res://objects/core/encounter/final_trial/grid_flame.tscn")

## Cờ mở thử thách (ví dụ cổng xuống phòng 13 đã mở)
@export var unlock_flag: StringName
## Cờ lưu đã vượt thử thách
@export var persistent_id: StringName
@export_range(5.0, 600.0, 1.0) var duration: float = 60.0
## Thất bại thì về trước trụ để làm lại thay vì chết và hồi sinh ở checkpoint
@export var fail_returns_to_altar: bool = true
@export_group("Floor")
## Số ô (x, z) và tâm ô đầu tiên so với gốc node
@export var grid_cells: Vector2i = Vector2i(6, 6)
@export var cell_size: float = 4.0
@export var first_cell: Vector3 = Vector3(-10, -0.32, -10)
## Không đặt lửa ở ô có tâm gần trụ hơn khoảng này (m); 0 = mọi ô đều có lửa
@export var keep_clear_radius: float = 0.0
@export_range(0.1, 3.0, 0.05) var shake_time: float = 1.2
@export var shake_strength: float = 0.12
@export_group("Flames")
## Thứ tự các kiểu lửa, lặp vòng tới hết giờ
@export var patterns: Array[Pattern] = [Pattern.SPREAD_VERTICAL, Pattern.SPREAD_HORIZONTAL, Pattern.SPREAD_ALL, Pattern.CHECKER]
## Đầu thử thách → cuối thử thách (nội suy theo thời gian đã qua: nhanh dần).
## Luôn giữ step_gap >= burst_time + 0.4 để khi bước sau bùng thì bước trước đã tắt: còn chỗ né vào ô vừa cháy
@export var warning_time: Vector2 = Vector2(1.8, 1.1)
@export var step_gap: Vector2 = Vector2(1.6, 1.0)
@export var pattern_pause: Vector2 = Vector2(2.0, 1.0)
@export var burst_time: float = 0.5
@export_group("Text")
@export_multiline var locked_text: String = "Ngươi chưa đủ can đảm để chạm vào ngọn lửa này."
@export_multiline var ask_text: String = "Còn một thử thách cuối cùng: sống sót giữa biển lửa trong 60 giây.\nNgươi có đồng ý không?"
@export_multiline var done_text: String = "Ngươi đã vượt qua thử thách. Cửa vào phòng boss đã mở."

var is_running: bool = false
var is_completed: bool = false
## Số bước (nhóm ô) đã phun, theo từng kiểu (test đọc)
var fired_steps: Dictionary[Pattern, int] = {}

var _plain: Array[Node3D] = []
var _grate: Array[Node3D] = []
var _flames: Array[GridFlame] = []
var _flame_cells: Array[Vector2i] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _player: Player
var _asker: Player
## Tăng mỗi lần bắt đầu: vòng lửa của lượt cũ (đang chờ timer) tự dừng khi lượt mới chạy
var _run_id: int = 0

@onready var _interactable: InteractableComponent = $Altar/InteractableComponent
@onready var _dialog: DialogBox = $DialogBox
@onready var _seals: Node3D = $Seals
@onready var _floor: Node3D = $Floor
@onready var _trial_timer: Timer = $TrialTimer
@onready var _label_timer: Timer = $LabelTimer
@onready var _hud: CanvasLayer = $Hud
@onready var _time_label: Label = $Hud/Time
@onready var _retry: Marker3D = $Retry


func _ready() -> void:
	_build_floor()
	_hud.hide()
	_trial_timer.one_shot = true
	_trial_timer.timeout.connect(_complete)
	_label_timer.wait_time = 0.25
	_label_timer.timeout.connect(_update_label)
	_interactable.interacted.connect(_on_altar)
	_dialog.answered.connect(_on_answered)
	is_completed = not persistent_id.is_empty() and GameState.has_flag(persistent_id)


func is_active() -> bool:
	return is_completed


func time_left() -> float:
	return _trial_timer.time_left if is_running else 0.0


func get_flames() -> Array[GridFlame]:
	return _flames


## Bắt đầu thử thách (đồng ý trong hộp thoại; test gọi thẳng)
func begin(player: Player = null) -> void:
	if is_running or is_completed:
		return
	is_running = true
	_run_id += 1
	_watch_player(player)
	_interactable.enabled = false
	fired_steps.clear()
	_set_seals(true)
	started.emit()
	await _shake_and_swap(true)
	if not is_inside_tree():
		return
	_trial_timer.start(duration)
	_hud.show()
	_update_label()
	_label_timer.start()
	_run_patterns(_run_id)


## Các nhóm ô phun lần lượt của một kiểu (mỗi phần tử là một bước)
func build_steps(pattern: Pattern) -> Array[Array]:
	var steps: Array[Array] = []
	var center: Vector2 = Vector2(grid_cells - Vector2i.ONE) * 0.5
	for i: int in range(_flames.size()):
		var c: Vector2i = _flame_cells[i]
		var key: int
		match pattern:
			Pattern.SPREAD_VERTICAL:
				key = floori(absf(c.y - center.y))
			Pattern.SPREAD_HORIZONTAL:
				key = floori(absf(c.x - center.x))
			Pattern.SPREAD_ALL:
				key = floori(maxf(absf(c.x - center.x), absf(c.y - center.y)))
			Pattern.CHECKER:
				key = (c.x + c.y) % 2
		while steps.size() <= key:
			steps.append([])
		steps[key].append(_flames[i])
	return steps.filter(func(s: Array) -> bool: return not s.is_empty())


func _on_altar(actor: Node3D) -> void:
	if is_running:
		return
	var player: Player = actor as Player
	_asker = player
	if is_completed:
		_dialog.say(done_text, player)
	elif unlock_flag.is_empty() or GameState.has_flag(unlock_flag):
		_dialog.ask(ask_text, player)
	else:
		_dialog.say(locked_text, player)


func _on_answered(accepted: bool) -> void:
	if accepted:
		begin(_asker)


func _build_floor() -> void:
	var plain_root: Node3D = Node3D.new()
	plain_root.name = "Plain"
	var grate_root: Node3D = Node3D.new()
	grate_root.name = "Grate"
	var flame_root: Node3D = Node3D.new()
	flame_root.name = "Flames"
	_floor.add_child(plain_root)
	_floor.add_child(grate_root)
	_floor.add_child(flame_root)
	for ix: int in range(grid_cells.x):
		for iz: int in range(grid_cells.y):
			var p: Vector3 = first_cell + Vector3(ix * cell_size, 0.0, iz * cell_size)
			var plain: Node3D = PLAIN_TILE.instantiate() as Node3D
			plain.position = p
			plain_root.add_child(plain)
			_plain.append(plain)
			var grate: Node3D = GRATE_TILE.instantiate() as Node3D
			# Nhô 1 cm: không z-fighting với ô thường lúc chuyển
			grate.position = p + Vector3(0.0, 0.01, 0.0)
			grate.visible = false
			grate_root.add_child(grate)
			_grate.append(grate)
			if Vector2(p.x, p.z).length() <= keep_clear_radius:
				continue
			var flame: GridFlame = FLAME_SCENE.instantiate() as GridFlame
			flame.cell_size = cell_size
			flame.burst_time = burst_time
			flame.position = p + Vector3(0.0, 0.32, 0.0)
			flame_root.add_child(flame)
			_flames.append(flame)
			_flame_cells.append(Vector2i(ix, iz))


## Rung mọi ô sàn rồi đổi kiểu (to_grate: thường → lưới dung nham)
func _shake_and_swap(to_grate: bool) -> void:
	var from: Array[Node3D] = _plain if to_grate else _grate
	var to: Array[Node3D] = _grate if to_grate else _plain
	var steps: int = 8
	for tile: Node3D in from:
		var rest: Vector3 = tile.position
		var seq: Tween = create_tween()
		for s: int in range(steps):
			var off: Vector3 = Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.5, 1), _rng.randf_range(-1, 1)) * shake_strength
			seq.tween_property(tile, ^"position", rest + off, shake_time / steps)
		seq.tween_property(tile, ^"position", rest, 0.05)
	ScreenShake.add_trauma(0.35)
	await get_tree().create_timer(shake_time + 0.05, false).timeout
	for tile: Node3D in from:
		tile.visible = false
	for tile: Node3D in to:
		tile.visible = true


func _run_patterns(run: int) -> void:
	var index: int = 0
	while _is_current(run) and not patterns.is_empty():
		var pattern: Pattern = patterns[index % patterns.size()]
		index += 1
		for step: Array in build_steps(pattern):
			if not _is_current(run):
				return
			var t: float = _progress()
			for flame: GridFlame in step:
				flame.fire(lerpf(warning_time.x, warning_time.y, t), burst_time)
			fired_steps[pattern] = fired_steps.get(pattern, 0) + 1
			await get_tree().create_timer(lerpf(step_gap.x, step_gap.y, t), false).timeout
		if not _is_current(run):
			return
		var t2: float = _progress()
		# Chờ lửa của kiểu này tắt hẳn rồi nghỉ một nhịp mới sang kiểu sau
		await get_tree().create_timer(lerpf(warning_time.x, warning_time.y, t2) + burst_time + lerpf(pattern_pause.x, pattern_pause.y, t2), false).timeout


func _is_current(run: int) -> bool:
	return is_running and run == _run_id and is_inside_tree()


## Tiến độ 0 → 1 theo thời gian đã qua
func _progress() -> float:
	return clampf(1.0 - _trial_timer.time_left / duration, 0.0, 1.0)


func _complete() -> void:
	if not is_running:
		return
	is_running = false
	is_completed = true
	_unwatch_player()
	_label_timer.stop()
	_hud.hide()
	if not persistent_id.is_empty():
		GameState.set_flag(persistent_id)
	await _shake_and_swap(false)
	_set_seals(false)
	_interactable.enabled = true
	completed.emit()
	activated.emit()


func _set_seals(closed: bool) -> void:
	for seal: Node in _seals.get_children():
		if seal is TrialSeal:
			(seal as TrialSeal).set_closed(closed)


func _update_label() -> void:
	_time_label.text = "%d" % ceili(_trial_timer.time_left)


func _watch_player(player: Player) -> void:
	_unwatch_player()
	_player = player
	if fail_returns_to_altar and is_instance_valid(_player):
		_player.health.died.connect(_on_player_died)


func _unwatch_player() -> void:
	if is_instance_valid(_player) and _player.health.died.is_connected(_on_player_died):
		_player.health.died.disconnect(_on_player_died)
	_player = null


## Player vừa hết máu trong lúc thử thách: huỷ trạng thái chết (signal died của player đã chuyển sang Dead trước),
## hồi đầy máu, đưa về trước trụ và đặt lại thử thách
func _on_player_died() -> void:
	if not is_running:
		return
	var player: Player = _player
	is_running = false
	_run_id += 1
	_unwatch_player()
	_trial_timer.stop()
	_label_timer.stop()
	_hud.hide()
	for flame: GridFlame in _flames:
		flame.cancel()
	player.health.heal_full()
	player.state_machine.transition_to(PlayerState.IDLE)
	failed.emit()
	await SceneManager.warp_player(player, _retry.global_position, _retry.global_basis.z)
	if not is_inside_tree():
		return
	await _shake_and_swap(false)
	_set_seals(false)
	_interactable.enabled = true
