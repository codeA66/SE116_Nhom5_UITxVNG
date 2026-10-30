class_name ClawScreenOverlay
extends Node3D
## Original DarkClaw, rendered on transparent canvas so camera angles never distort it.
const ORIGINAL: PackedScene = preload("res://assets/vfx/enemies/wolf/dark_claw/dark_claw.tscn")
@export var world_radius: float = 2.4
@export var center_height: float = 0.8
@export var duration: float = 1.1
var _rect: TextureRect
var _viewport: SubViewport
var _claw: Node3D
var _active: bool = false

func _ready() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(512, 512)
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	var stage: Node3D = Node3D.new(); _viewport.add_child(stage)
	_claw = ORIGINAL.instantiate() as Node3D
	stage.add_child(_claw)
	_claw.set(&"manual_clock", true); _claw.set_process(false)
	_claw.call(&"set_layer_enabled", "Aura", false)
	_claw.call(&"set_color_palette", 0.5, 1.0)
	var camera: Camera3D = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = 5.8
	stage.add_child(camera); camera.position = Vector3(0, 0, 8); camera.make_current()
	var layer: CanvasLayer = CanvasLayer.new(); layer.layer = 5; add_child(layer)
	_rect = TextureRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.texture = _viewport.get_texture()
	_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.add_child(_rect)
	seek(-1.0)

func seek(seconds: float) -> void:
	_active = seconds >= 0.0 and seconds < duration and is_visible_in_tree()
	_rect.visible = _active
	set_process(_active)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if _active else SubViewport.UPDATE_DISABLED
	if _active:
		var style: Resource = _claw.get(&"style") as Resource
		_claw.call(&"seek", float(style.get(&"duration")) * 0.115 + seconds)
		_project()

func _process(_delta: float) -> void:
	_project()

func _project() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		_rect.hide(); return
	var center: Vector3 = global_position + Vector3.UP * center_height
	if camera.is_position_behind(center):
		_rect.hide(); return
	var screen: Vector2 = camera.unproject_position(center)
	var edge: Vector2 = camera.unproject_position(center + camera.global_basis.x * world_radius)
	var radius: float = maxf(edge.distance_to(screen), 1.0)
	_rect.size = Vector2.ONE * radius * 2.0
	_rect.position = screen - _rect.size * 0.5
	_rect.show()

func screen_rect() -> Rect2:
	return Rect2(_rect.position, _rect.size)

func overlay_visible() -> bool:
	return _rect.visible
