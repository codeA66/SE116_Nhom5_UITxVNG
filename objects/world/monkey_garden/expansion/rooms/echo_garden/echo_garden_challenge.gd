class_name EchoGardenChallenge
extends Node3D
signal cleared
@export var reward: OfferingBanana
@export var item: BananaItemPickup
@export var pads: Array[EchoPad] = []
@export var guide: GardenTotemGuide
@export var display: Label3D
@export var flash_interval: float = 0.7
@export var rounds: int = 3
@export var pattern_seed: int = 116
var started: bool = false
var completed: bool = false
var round_index: int = 0
var progress: int = 0
var sequence: Array[int] = []
var accepting: bool = false
var _generation: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _camera: Camera3D
var _saved_camera: Camera3D

func _ready() -> void:
	_rng.seed = pattern_seed
	for pad: EchoPad in pads: pad.stepped.connect(_step)
	guide.reading_closed.connect(replay)
	_setup.call_deferred()

func _setup() -> void:
	reward.set_available(false); display.text = "VƯỜN KÝ ỨC\nF · Đọc cột hướng dẫn"

func is_cleared() -> bool:
	return completed

func begin(_actor: Player) -> void:
	if started: return
	started = true; _focus_camera(); _next_round()

func _next_round() -> void:
	round_index += 1; sequence.clear()
	var previous: int = -1
	for step: int in round_index+1:
		var selected: int = _rng.randi_range(0,pads.size()-1)
		while selected==previous: selected = _rng.randi_range(0,pads.size()-1)
		sequence.append(selected); previous = selected
	replay()

func replay() -> void:
	if not started or completed: return
	_generation += 1; var token: int = _generation; accepting = false; progress = 0
	display.text = "VÒNG %d / %d\nQuan sát nhịp sáng"%[round_index,rounds]
	await get_tree().create_timer(0.8,false).timeout
	for index: int in sequence:
		if token!=_generation or completed: return
		pads[index].pulse()
		await get_tree().create_timer(maxf(flash_interval,0.1),false).timeout
	if token!=_generation or completed: return
	accepting = true; display.text = "Lặp lại nhịp sáng\n0 / %d"%sequence.size()

func _step(index: int) -> void:
	if not accepting or completed: return
	pads[index].pulse()
	if index!=sequence[progress]:
		accepting = false; display.text = "Sai nhịp — xem lại!"
		await get_tree().create_timer(0.8,false).timeout; replay(); return
	progress += 1; display.text = "Lặp lại nhịp sáng\n%d / %d"%[progress,sequence.size()]
	if progress < sequence.size(): return
	accepting = false
	if round_index < rounds:
		display.text = "Đúng rồi!"; await get_tree().create_timer(0.8,false).timeout; _next_round()
	else:
		completed = true; display.text = "KÝ ỨC ĐÃ THỨC TỈNH"
		if is_instance_valid(_saved_camera) and _camera.is_current(): _saved_camera.make_current()
		GardenCombatEffects.confetti(get_parent(),global_position+Vector3.UP)
		GardenRewards.offering(reward); item.reveal()
		get_tree().create_timer(2.2,false).timeout.connect(func() -> void: cleared.emit())

func _focus_camera() -> void:
	_saved_camera = get_viewport().get_camera_3d()
	_camera = Camera3D.new(); _camera.projection = Camera3D.PROJECTION_ORTHOGONAL; _camera.size = 36
	add_child(_camera)
	_camera.global_position = global_position+Vector3(0,34,0.1); _camera.look_at(global_position)
	var target: Transform3D = _camera.global_transform
	_camera.global_transform = _saved_camera.global_transform; _camera.make_current()
	var tween: Tween = create_tween(); tween.tween_property(_camera,"global_transform",target,0.75).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
