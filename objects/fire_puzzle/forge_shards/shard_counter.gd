class_name ForgeShardCounter
extends CanvasLayer
## Bộ đếm mảnh vỡ góc màn hình. Chỉ hiện khi người chơi trong khu (nối player_entered/player_exited của TierZone).
## Cập nhật theo signal progress_changed, không kiểm tra mỗi frame.

@export var shards: ForgeShardSet
@export var style: HudStyle = preload("res://resources/ui/hud_style.tres")
@export var font_size: int = 20

@onready var _panel: PanelContainer = $Panel
@onready var _label: Label = $Panel/Count


func _ready() -> void:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = style.ink
	box.border_color = style.gold
	box.border_width_left = 2
	box.content_margin_left = 14
	box.content_margin_right = 16
	box.content_margin_top = 8
	box.content_margin_bottom = 9
	_panel.theme = style.theme
	_panel.add_theme_stylebox_override("panel", box)
	_label.add_theme_color_override("font_color", style.ivory)
	_label.add_theme_font_size_override("font_size", font_size)
	_panel.hide()
	GameState.progress_changed.connect(_refresh)
	_refresh()


func show_counter() -> void:
	_refresh()
	_panel.show()


func hide_counter() -> void:
	_panel.hide()


func get_text() -> String:
	return _label.text


func _refresh() -> void:
	if shards == null:
		return
	_label.text = shards.label_text()
