class_name WebEntangle
extends Node
## Trạng thái dính tơ trên một Player: chậm đi (WebData.speed_scale) và khóa dash cho tới khi MỌI tấm tơ đang bám
## vào người bị phá (chém đủ nhát hoặc bị lửa đốt) hoặc biến mất.
## Không sửa logic di chuyển của player: làm chậm bằng cách tạm thay MovementStats bằng bản sao chậm hơn (giống ColdZone),
## khóa dash qua Player.set_dash_locked(). Dính nhiều tấm thì lấy mức chậm nhất, không nhân dồn.
## Node này tự tạo ở lần dính đầu tiên (get_or_create) và nằm dưới player; không có _process.
## Lưu ý: ColdZone cũng thay MovementStats của player; hai thứ cùng lúc có thể trả lại sai bản (chưa gộp).

signal entangled_changed(entangled: bool)

const NODE_NAME: StringName = &"WebEntangle"

var _player: Player
var _webs: Array[WebPatch] = []
var _normal: MovementStats
var _slowed: MovementStats


static func get_or_create(player: Player) -> WebEntangle:
	var existing: WebEntangle = player.get_node_or_null(NodePath(NODE_NAME)) as WebEntangle
	if existing != null:
		return existing
	var created: WebEntangle = WebEntangle.new()
	created.name = NODE_NAME
	player.add_child(created)
	return created


## Player có đang dính tơ không (null / chưa từng dính thì false)
static func is_entangled_node(player: Node) -> bool:
	if player == null:
		return false
	var existing: WebEntangle = player.get_node_or_null(NodePath(NODE_NAME)) as WebEntangle
	return existing != null and existing.is_entangled()


func _ready() -> void:
	_player = get_parent() as Player
	assert(_player != null, "WebEntangle phải là con của Player")


func _exit_tree() -> void:
	_restore()


func is_entangled() -> bool:
	return not _webs.is_empty()


func get_web_count() -> int:
	return _webs.size()


func entangle(web: WebPatch) -> void:
	if web in _webs:
		return
	_webs.append(web)
	web.broken.connect(_on_web_gone.bind(web), CONNECT_ONE_SHOT)
	web.tree_exiting.connect(_on_web_gone.bind(web), CONNECT_ONE_SHOT)
	_refresh()
	if _webs.size() == 1:
		entangled_changed.emit(true)


func _on_web_gone(web: WebPatch) -> void:
	var index: int = _webs.find(web)
	if index == -1:
		return
	_webs.remove_at(index)
	_refresh()
	if _webs.is_empty():
		entangled_changed.emit(false)


func _refresh() -> void:
	if _webs.is_empty():
		_restore()
		return
	var scale_min: float = 1.0
	var lock: bool = false
	for web: WebPatch in _webs:
		scale_min = minf(scale_min, web.data.speed_scale)
		lock = lock or web.data.lock_dash
	if _normal == null:
		_normal = _player.movement
		_slowed = _normal.duplicate() as MovementStats
	_slowed.max_speed = _normal.max_speed * scale_min
	_player.movement = _slowed
	_player.set_dash_locked(self, lock)


func _restore() -> void:
	if _normal != null and is_instance_valid(_player):
		if _player.movement == _slowed:
			_player.movement = _normal
		_player.set_dash_locked(self, false)
	_normal = null
	_slowed = null
