extends Node3D
## Phòng thử thách tuỳ chọn (5.3), mở sau khi thắng đấu trường 5.2. Bước vào thì cửa khoá, đánh lần lượt các đợt
## (mỗi Encounter con của Waves là một đợt, theo thứ tự cây). Quái ở đây không rơi Soul Jade; xong đợt cuối thì cửa
## mở và bùa thưởng hiện giữa phòng. Thêm đợt = thêm một Encounter dưới Waves, không sửa file này.
## Chết giữa chừng thì khu tải lại nên phải đánh lại từ đợt đầu.

signal wave_started(index: int)
signal activated

const TrialGrille := preload("../grille/trial_grille.gd")

@export var cleared_flag: StringName = &"level_1.wind_challenge_cleared"
## Nghỉ giữa hai đợt (giây)
@export var wave_break: float = 2.0
## Tắt: quái trong thử thách không rơi Soul Jade (phần thưởng là bùa cuối phòng)
@export var enemies_drop_loot: bool = false

var current_wave: int = -1

var _waves: Array[Encounter] = []

@onready var _trigger: Area3D = $EntryTrigger
@onready var _gate: TrialGrille = $EntryGate
@onready var _waves_root: Node3D = $Waves
@onready var _reward: CharmPickup = get_node_or_null(^"RewardCharm") as CharmPickup


## Gỡ bảng rơi đồ lúc quái còn nằm trong cây: Encounter tháo quái ẩn ra khỏi cây ngay ở _ready của nó.
func _enter_tree() -> void:
	if enemies_drop_loot:
		return
	for node: Node in find_children("*", "", true, false):
		if node is LootDropComponent:
			(node as LootDropComponent).drop_table = null


func _ready() -> void:
	for child: Node in _waves_root.get_children():
		if child is Encounter:
			_waves.append(child as Encounter)
	if is_active():
		_trigger.monitoring = false
		for wave: Encounter in _waves:
			wave.queue_free()
		_waves.clear()
		_reveal_reward()
		return
	for index: int in range(_waves.size()):
		_waves[index].cleared.connect(_on_wave_cleared.bind(index), CONNECT_ONE_SHOT)
	_trigger.body_entered.connect(_on_entry)


## Đã vượt thử thách (cờ lưu)
func is_active() -> bool:
	return GameState.has_flag(cleared_flag)


func _on_entry(body: Node3D) -> void:
	if not body is Player or current_wave >= 0 or _waves.is_empty():
		return
	_trigger.set_deferred(&"monitoring", false)
	_gate.set_open(false)
	# Đang trong callback vật lý: đưa quái vào cây ở frame sau
	_start_wave.call_deferred(0)


func _start_wave(index: int) -> void:
	current_wave = index
	wave_started.emit(index)
	_waves[index].start()


func _on_wave_cleared(index: int) -> void:
	if index + 1 >= _waves.size():
		_finish()
		return
	var pause := create_tween()
	pause.tween_interval(maxf(wave_break, 0.0))
	pause.tween_callback(_start_wave.bind(index + 1))


func _finish() -> void:
	GameState.set_flag(cleared_flag)
	_gate.set_open(true)
	_reveal_reward()
	activated.emit()


func _reveal_reward() -> void:
	if is_instance_valid(_reward):
		_reward.reveal()
