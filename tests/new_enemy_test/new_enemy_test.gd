extends Node3D
## F6 chạy sân thử độc lập, không ghi tiến trình hay thay scene chính của đồ án.
@export var training_mode: bool = true
@onready var player: FoxyPlayer = $Player
@onready var overview: Camera3D = $OverviewCamera
@onready var status: Label = $HUD/Panel/Margin/VBox/Status
@onready var training: CheckButton = $HUD/Panel/Margin/VBox/Training
var _overview: bool = false
var _hits: int = 0

func _ready() -> void:
	training.button_pressed = training_mode
	training.toggled.connect(_set_training)
	$HUD/Panel/Margin/VBox/Reset.pressed.connect(_reset)
	$HUD/Panel/Margin/VBox/View.pressed.connect(_toggle_view)
	player.health.damaged.connect(_on_damaged)
	player.health.health_changed.connect(_refresh_health)
	_refresh_health(player.health.current_health, player.health.max_health)
	# Tùy chọn dòng lệnh cho ảnh QA; người chơi vẫn dùng camera đi theo mặc định.
	if "--enemy-overview" in OS.get_cmdline_user_args(): _toggle_view()

func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo: return
	if key.keycode == KEY_TAB: _toggle_view(); get_viewport().set_input_as_handled()
	if key.keycode == KEY_R: _reset(); get_viewport().set_input_as_handled()

func _set_training(enabled: bool) -> void:
	training_mode = enabled
	if enabled: player.health.heal_full()

func _on_damaged(_amount: int) -> void:
	_hits += 1
	if training_mode: player.health.heal_full()
	_refresh_health(player.health.current_health, player.health.max_health)

func _refresh_health(current: int, maximum: int) -> void:
	status.text = "HP %d / %d  |  Đã trúng đòn: %d" % [current, maximum, _hits]

func _toggle_view() -> void:
	_overview = not _overview
	if _overview: overview.make_current()
	else: (player.get_node("CameraRig/Camera3D") as Camera3D).make_current()

func _reset() -> void:
	get_tree().reload_current_scene()
