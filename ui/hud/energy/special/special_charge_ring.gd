extends Control

@export_group("Vòng Thiên Kích")
@export var empty_color: Color = Color(0.15, 0.12, 0.16, 0.96)
@export var charge_color: Color = Color(0.94, 0.65, 0.31)
@export var ready_color: Color = Color(1.0, 0.93, 0.70)
@export_range(1.0, 8.0, 0.2) var stroke: float = 2.8
@export_range(16, 100, 1) var arc_steps: int = 48

var _source: CharmUltimate
var _center: Vector2
var _radii: Vector2
var _ratio: float = 0.0
var _full: bool = false

@onready var _key: KeyGlyph = $Key


func _ready() -> void:
	hide()
	Settings.bindings_changed.connect(_sync_key)
	_sync_key()


func bind_player(player: Node) -> void:
	if not is_instance_valid(player):
		return
	player.child_entered_tree.connect(_bind_source)
	_bind_source(player.get_node_or_null(^"CharmUltimate"))


func place_around(rect: Rect2) -> void:
	_center = rect.position + rect.size * Vector2(0.5, 0.65)
	_radii = rect.size * Vector2(0.51, 0.62)
	_place_key()
	queue_redraw()


func get_charge_ratio() -> float:
	return _ratio


func _draw() -> void:
	if _radii.is_zero_approx():
		return
	_draw_band(1.0, Color(0.53, 0.37, 0.28, 0.78), stroke + 1.9)
	_draw_band(1.0, empty_color, stroke)
	if _full:
		_draw_band(1.0, Color(ready_color, 0.20), stroke * 3.4)
	if _ratio > 0.0:
		var tint: Color = ready_color if _full else charge_color
		_draw_band(_ratio, tint, stroke)
		draw_circle(_arc_point(_ratio), stroke * 0.80, tint, true, -1, true)


func _draw_band(ratio: float, color: Color, width: float) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	var steps: int = maxi(ceili(float(arc_steps) * ratio), 1)
	points.resize(steps + 1)
	for index: int in steps + 1:
		points[index] = _arc_point(ratio * float(index) / float(steps))
	draw_polyline(points, color, width, true)


func _arc_point(ratio: float) -> Vector2:
	var angle: float = lerpf(-2.93, -0.21, ratio)
	return _center + Vector2(cos(angle), sin(angle)) * _radii


func _bind_source(node: Node) -> void:
	var source: CharmUltimate = node as CharmUltimate
	if source == null or source == _source:
		return
	if is_instance_valid(_source) and _source.charge_changed.is_connected(_set_charge):
		_source.charge_changed.disconnect(_set_charge)
	_source = source
	_source.charge_changed.connect(_set_charge)
	_set_charge(source.get_charge(), source.get_capacity(), source.is_equipped())


func _set_charge(current: int, maximum: int, equipped: bool) -> void:
	visible = equipped
	_ratio = clampf(float(current) / float(maxi(maximum, 1)), 0.0, 1.0)
	_full = equipped and _ratio >= 1.0
	_key.visible = _full and not _source.is_casting()
	queue_redraw()


func _sync_key() -> void:
	_key.text = Settings.describe_event(Settings.get_primary_event(CharmUltimate.ACTION))
	_place_key()


func _place_key() -> void:
	_key.reset_size()
	var top: Vector2 = _arc_point(0.5)
	_key.position = Vector2(top.x - _key.size.x * 0.5, maxf(top.y - _key.size.y * 0.92, -12.0))
