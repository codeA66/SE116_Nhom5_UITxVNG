extends Control
## Nguồn buff cung cấp icon và timer công khai; bùa mới chỉ cần khai báo dữ liệu hiển thị.

class StatusEntry:
	extends RefCounted
	var source: Node
	var icon: Texture2D
	var color: Color
	var duration: float = 0.0
	var remaining: float = 0.0
	var active: bool = false

const MAX_ICONS_CAP: int = 12
const ARC_STEPS: int = 48

@export_group("Kết nối")
@export var player_path: NodePath

@export_group("Hình ảnh")
@export_range(0.0, 96.0, 1.0, "or_greater") var icon_size: float = 36.0
@export_range(0.0, 16.0, 0.5, "or_greater") var padding: float = 5.0
@export_range(0.0, 8.0, 0.5, "or_greater") var ring_width: float = 2.0
@export_range(0.0, 32.0, 1.0, "or_greater") var icon_gap: float = 8.0
@export_range(0, 12) var max_icons: int = 8
@export var background_color: Color = Color(0.035, 0.05, 0.07, 0.92)
@export var rim_color: Color = Color(0.9, 0.86, 0.75, 0.28)

var _player: Node
var _entries: Dictionary[Node, StatusEntry] = {}
var _active: Array[StatusEntry] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	hide()
	if player_path.is_empty():
		return
	_player = get_node_or_null(player_path)
	if _player == null:
		return
	_player.child_entered_tree.connect(_bind_source)
	for child: Node in _player.get_children():
		_bind_source(child)


func _exit_tree() -> void:
	if is_instance_valid(_player) and _player.child_entered_tree.is_connected(_bind_source):
		_player.child_entered_tree.disconnect(_bind_source)
	for source: Node in _entries:
		_disconnect_source(source)
	_entries.clear()
	_active.clear()
	set_process(false)


func _process(_delta: float) -> void:
	for index: int in range(_visible_count()):
		var entry: StatusEntry = _active[index]
		entry.remaining = maxf(float(entry.source.call(&"get_time_left")), 0.0)
	queue_redraw()


func _draw() -> void:
	var extent: float = maxf(icon_size, 0.0) + maxf(padding, 0.0) * 2.0
	var radius: float = maxf(extent * 0.5 - maxf(ring_width, 0.0), 0.0)
	if radius <= 0.0:
		return
	for index: int in range(_visible_count()):
		var entry: StatusEntry = _active[index]
		var center: Vector2 = Vector2(extent * 0.5 + float(index) * (extent + maxf(icon_gap, 0.0)), extent * 0.5)
		var ratio: float = clampf(entry.remaining / maxf(entry.duration, 0.001), 0.0, 1.0)
		draw_circle(center, radius, background_color, true, -1.0, true)
		draw_arc(center, radius, 0.0, TAU, ARC_STEPS, rim_color, maxf(ring_width, 0.5), true)
		var box: Vector2 = Vector2.ONE * maxf(icon_size, 0.0)
		if entry.icon and box.x > 0.0:
			draw_texture_rect(entry.icon, Rect2(center - box * 0.5, box), false)
		if ratio > 0.0 and ring_width > 0.0:
			draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * ratio, ARC_STEPS, entry.color, ring_width, true)


func get_active_count() -> int:
	return _active.size()


func get_displayed_ratio(index: int = 0) -> float:
	if index < 0 or index >= _active.size():
		return 0.0
	var entry: StatusEntry = _active[index]
	return clampf(entry.remaining / maxf(entry.duration, 0.001), 0.0, 1.0)


func _bind_source(source: Node) -> void:
	if _entries.has(source) or not source.has_method(&"get_status_icon") or not source.has_method(&"get_time_left"):
		return
	var icon: Texture2D = source.call(&"get_status_icon") as Texture2D
	if icon == null or not source.has_signal(&"activated") or not source.has_signal(&"deactivated"):
		return
	var entry: StatusEntry = StatusEntry.new()
	entry.source = source
	entry.icon = icon
	entry.color = (source.call(&"get_status_color") as Color) if source.has_method(&"get_status_color") else Color.WHITE
	_entries[source] = entry
	source.connect(&"activated", _on_activated.bind(source))
	source.connect(&"deactivated", _on_deactivated.bind(source))
	source.tree_exiting.connect(_unbind_source.bind(source))


func _on_activated(duration: float, source: Node) -> void:
	var entry: StatusEntry = _entries.get(source)
	if entry == null:
		return
	entry.duration = maxf(duration, 0.0)
	entry.remaining = entry.duration
	if not entry.active:
		entry.active = true
		_active.append(entry)
	_update_size()


func _on_deactivated(source: Node) -> void:
	var entry: StatusEntry = _entries.get(source)
	if entry == null:
		return
	entry.active = false
	_active.erase(entry)
	_update_size()


func _unbind_source(source: Node) -> void:
	_on_deactivated(source)
	_disconnect_source(source)
	_entries.erase(source)


func _disconnect_source(source: Node) -> void:
	if not is_instance_valid(source):
		return
	var on: Callable = _on_activated.bind(source)
	var off: Callable = _on_deactivated.bind(source)
	var exiting: Callable = _unbind_source.bind(source)
	if source.is_connected(&"activated", on):
		source.disconnect(&"activated", on)
	if source.is_connected(&"deactivated", off):
		source.disconnect(&"deactivated", off)
	if source.tree_exiting.is_connected(exiting):
		source.tree_exiting.disconnect(exiting)


func _visible_count() -> int:
	return mini(_active.size(), clampi(max_icons, 0, MAX_ICONS_CAP))


func _update_size() -> void:
	var count: int = _visible_count()
	var extent: float = maxf(icon_size, 0.0) + maxf(padding, 0.0) * 2.0
	custom_minimum_size = Vector2(extent * count + maxf(icon_gap, 0.0) * maxi(count - 1, 0), extent) if count > 0 else Vector2.ZERO
	size = custom_minimum_size
	visible = count > 0
	set_process(count > 0)
	queue_redraw()
