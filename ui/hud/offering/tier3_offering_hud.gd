class_name Tier3OfferingHud
extends PanelContainer
## Chỉ hiện bộ đếm khi người chơi ở trong Tier 3 của màn chính.
@export var style: HudStyle = preload("res://resources/ui/hud_style.tres")
var _player: Player
var _bounds: Area3D
var _always_visible: bool = false
@onready var _counter: Label = $Counter

func _ready() -> void:
	theme = style.theme
	var panel: StyleBoxFlat = StyleBoxFlat.new()
	panel.bg_color = style.ink
	panel.border_color = style.gold; panel.border_width_left = 2
	panel.content_margin_left = 14; panel.content_margin_right = 16
	panel.content_margin_top = 8; panel.content_margin_bottom = 9
	add_theme_stylebox_override("panel",panel)
	_counter.add_theme_color_override("font_color",style.ivory)
	_counter.add_theme_font_size_override("font_size",20)
	hide(); set_process(false); set_physics_process(false)

func bind_player(player: Player, bounds: Area3D, always_visible: bool) -> void:
	_player = player; _bounds = bounds; _always_visible = always_visible
	if not _bounds.body_entered.is_connected(_body_changed):
		_bounds.body_entered.connect(_body_changed); _bounds.body_exited.connect(_body_changed)
	_refresh.call_deferred()

func set_count(count: int, total: int) -> void:
	_counter.text = "Chuối thần đã hiến tế : %d/%d" % [count,total]
	reset_size()

func _body_changed(body: Node3D) -> void:
	if body == _player: _refresh.call_deferred()

func _refresh() -> void:
	visible = _always_visible or (is_instance_valid(_player) and _bounds.overlaps_body(_player))
