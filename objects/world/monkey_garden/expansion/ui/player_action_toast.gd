class_name PlayerActionToast
extends Node
@export var cooldown: float = 1.0
var _player: Player
var _label: Label
var _next_time: int = 0
var _age: float = 0.0

static func show_for(player: Player, message: String) -> void:
	var toast: PlayerActionToast = player.get_node_or_null("PlayerActionToast") as PlayerActionToast
	if toast == null:
		toast = PlayerActionToast.new(); toast.name = "PlayerActionToast"; player.add_child(toast)
	toast.display(message)

func _ready() -> void:
	_player = get_parent() as Player
	var layer: CanvasLayer = CanvasLayer.new(); layer.layer = 32; add_child(layer)
	_label = Label.new(); _label.add_theme_font_size_override("font_size",16)
	_label.add_theme_color_override("font_outline_color",Color("10161c")); _label.add_theme_constant_override("outline_size",4)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE; layer.add_child(_label); _label.hide(); set_process(false)

func _input(event: InputEvent) -> void:
	if not _player.controls_enabled or event.is_echo(): return
	if not (event.is_action_pressed("attack") or event.is_action_pressed("aim") or event.is_action_pressed("skill")): return
	var carry: CarryComponent = _player.get_node_or_null("CarryComponent") as CarryComponent
	if carry and carry.held_item: display("Không dùng được, đang mang chuối thần!")

func display(message: String) -> void:
	if Time.get_ticks_msec() < _next_time: return
	_next_time = Time.get_ticks_msec()+int(cooldown*1000)
	_label.text = message; _label.reset_size(); _label.modulate.a = 1; _label.show(); _age = 0; set_process(true)

func _process(delta: float) -> void:
	_age += delta
	var camera: Camera3D = _player.get_viewport().get_camera_3d()
	_label.position = camera.unproject_position(_player.global_position+Vector3.UP*1.9)-Vector2(_label.size.x*0.5,18+_age*24)
	_label.modulate.a = 1.0-smoothstep(0.25,1.0,_age)
	if _age >= 1: _label.hide(); set_process(false)
