extends Node
## Chỉ chạy tween khi vào/ra hội thoại; dùng camera sẵn có và ba lớp màu đơn giản.

const CAMERA_OWNER: StringName = &"conversation_cinematic"

@export_range(0.75, 1.0) var zoom_ratio: float = 0.9
@export_range(0.0, 0.14) var bar_ratio: float = 0.065
@export var tint: Color = Color(0.06, 0.04, 0.02, 0.12)
@export var enter_time: float = 1.0
@export var leave_time: float = 0.35
@export_range(0.0, 0.5) var focus_ratio: float = 0.35
@export var focus_height: float = 0.3

var _npc: Npc
var _camera: Camera3D
var _hud: CanvasLayer
var _hud_was_visible: bool = true
var _hidden_layers: Dictionary[CanvasLayer, bool] = {}
var _original_fov: float
var _original_size: float
var _original_position: Vector3
var _overlay: Control
var _top: ColorRect
var _bottom: ColorRect
var _tween: Tween


func _ready() -> void:
	_npc = get_parent() as Npc
	assert(_npc != null)
	_npc.conversation_started.connect(_begin)
	_npc.conversation_ended.connect(_end)
	var layer := CanvasLayer.new()
	layer.layer = _npc.ui_layer - 1
	add_child(layer)
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_overlay)
	var shade := _rect(tint)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_top = _rect(Color.BLACK)
	_top.anchor_right = 1.0
	_top.anchor_bottom = bar_ratio
	_bottom = _rect(Color.BLACK)
	_bottom.anchor_right = 1.0
	_bottom.anchor_top = 1.0 - bar_ratio
	_bottom.anchor_bottom = 1.0
	_overlay.modulate.a = 0.0
	_overlay.hide()
	set_process(false)


func _rect(color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(rect)
	return rect


func _begin(player: Player) -> void:
	release()
	_camera = get_viewport().get_camera_3d()
	# Không chiếm camera của một cutscene khác.
	if _camera == null or not player.is_ancestor_of(_camera):
		_camera = null
		return
	var previous: Node = _camera.get_meta(CAMERA_OWNER) if _camera.has_meta(CAMERA_OWNER) else null
	if is_instance_valid(previous) and previous != self:
		previous.release()
	_camera.set_meta(CAMERA_OWNER, self)
	_original_fov = _camera.fov
	_original_size = _camera.size
	_original_position = _camera.position
	_hud = player.get_node_or_null("HUD") as CanvasLayer
	if _hud:
		_hud_was_visible = _hud.visible
		_hud.hide()
	# Các overlay đăng ký sẵn: không quét cả cây scene khi bắt đầu nói chuyện.
	for node: Node in get_tree().get_nodes_in_group(&"gameplay_overlay"):
		var layer := node as CanvasLayer
		if layer:
			_hidden_layers[layer] = layer.visible
			layer.hide()
	var offset := (_npc.global_position - player.global_position) * focus_ratio
	offset.y += focus_height
	var parent := _camera.get_parent() as Node3D
	if parent:
		offset = parent.global_basis.inverse() * offset
	_overlay.show()
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var duration := maxf(enter_time, 0.01)
	_tween.tween_property(_overlay, "modulate:a", 1.0, duration)
	_tween.tween_property(_camera, "position", _original_position + offset, duration)
	_tween.tween_property(_camera, "fov", _original_fov * zoom_ratio, duration)
	_tween.tween_property(_camera, "size", _original_size * zoom_ratio, duration)


func _end(_player: Player) -> void:
	_stop_tween()
	_restore_hud()
	if not is_inside_tree() or not is_instance_valid(_camera):
		release()
		return
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var duration := maxf(leave_time, 0.01)
	_tween.tween_property(_overlay, "modulate:a", 0.0, duration)
	_tween.tween_property(_camera, "position", _original_position, duration)
	_tween.tween_property(_camera, "fov", _original_fov, duration)
	_tween.tween_property(_camera, "size", _original_size, duration)
	_tween.chain().tween_callback(release)


## Khôi phục ngay khi bị xóa hoặc nhường camera cho cuộc trò chuyện kế tiếp.
func release() -> void:
	_stop_tween()
	_restore_hud()
	if is_instance_valid(_camera) and _camera.has_meta(CAMERA_OWNER) and _camera.get_meta(CAMERA_OWNER) == self:
		_camera.position = _original_position
		_camera.fov = _original_fov
		_camera.size = _original_size
		_camera.remove_meta(CAMERA_OWNER)
	_camera = null
	if is_instance_valid(_overlay):
		_overlay.modulate.a = 0.0
		_overlay.hide()


func _restore_hud() -> void:
	if is_instance_valid(_hud):
		_hud.visible = _hud_was_visible
	_hud = null
	for layer: CanvasLayer in _hidden_layers:
		if is_instance_valid(layer):
			layer.visible = _hidden_layers[layer]
	_hidden_layers.clear()


func _stop_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null


func _exit_tree() -> void:
	release()
