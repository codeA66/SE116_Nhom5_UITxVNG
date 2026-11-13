class_name ShardAltar
extends StaticBody3D
## Bệ công tắc: bấm interact thì đặt mọi mảnh đang mang lên hốc của nó (lưu cờ đã đặt từng mảnh).
## Đặt đủ thì công tắc sáng, lưu shards.switch_flag và phát activated (thử thách u tối nghe signal / cờ này).
## Hốc là con của $Sockets theo thứ tự shards.shard_flags. Hiệu năng: chỉ nghe signal tương tác và progress_changed.

signal shard_placed(placed_count: int)
signal activated

@export var shards: ForgeShardSet
@export var ready_prompt: String = "ĐẶT MẢNH VỠ"
@export var missing_prompt: String = "KIỂM TRA BỆ"
@export_multiline var missing_text: String = "Bệ có ba hốc trống.\nCần tìm mảnh vỡ ở ba hướng quanh Hub."
@export_group("Sáng khi đủ")
@export var lit_energy: float = 3.0
@export_range(0.0, 1.0, 0.01) var complete_trauma: float = 0.3
@export var pop_time: float = 0.35

var _active: bool = false

@onready var _interactable: InteractableComponent = $InteractableComponent
@onready var _sockets: Node3D = $Sockets
@onready var _glow: OmniLight3D = $Glow
@onready var _dialog: DialogBox = $DialogBox


func _ready() -> void:
	if shards == null:
		push_error("%s: chưa gắn ForgeShardSet" % get_path())
		return
	_interactable.availability_check = func(_actor: Node3D) -> bool: return not _active
	_interactable.interacted.connect(_on_interacted)
	for i: int in shards.total():
		_socket(i).visible = shards.is_placed(i)
	if not shards.switch_flag.is_empty() and GameState.has_flag(shards.switch_flag):
		_light(true)
		return
	_glow.light_energy = 0.0
	GameState.progress_changed.connect(_refresh_prompt)
	_refresh_prompt()


func is_active() -> bool:
	return _active


func _socket(index: int) -> Node3D:
	return _sockets.get_child(index) as Node3D


func _has_carried() -> bool:
	for i: int in shards.total():
		if shards.is_carried(i):
			return true
	return false


func _refresh_prompt() -> void:
	if not _active:
		_interactable.prompt_text = ready_prompt if _has_carried() else missing_prompt


func _on_interacted(actor: Node3D) -> void:
	if _active:
		return
	if not _has_carried():
		_dialog.say(missing_text, actor as Player)
		return
	for i: int in shards.total():
		if not shards.is_carried(i):
			continue
		GameState.set_flag(shards.placed_flags[i])
		_pop(_socket(i))
	shard_placed.emit(shards.placed_count())
	if shards.placed_count() >= shards.total():
		_light(false)


func _pop(socket: Node3D) -> void:
	socket.show()
	socket.scale = Vector3.ONE * 0.01
	create_tween().tween_property(socket, ^"scale", Vector3.ONE, pop_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _light(instant: bool) -> void:
	_active = true
	_interactable.enabled = false
	if GameState.progress_changed.is_connected(_refresh_prompt):
		GameState.progress_changed.disconnect(_refresh_prompt)
	if instant:
		_glow.light_energy = lit_energy
		return
	_glow.light_energy = 0.0
	create_tween().tween_property(_glow, ^"light_energy", lit_energy, pop_time * 2.0).set_ease(Tween.EASE_OUT)
	if complete_trauma > 0.0:
		ScreenShake.add_trauma(complete_trauma)
	if not shards.switch_flag.is_empty():
		GameState.set_flag(shards.switch_flag)
	activated.emit()
