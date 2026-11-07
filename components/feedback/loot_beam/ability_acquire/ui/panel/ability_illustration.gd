class_name AbilityIllustration
extends Control
## Hình minh họa trên bảng nhận kỹ năng: dựng từ chính model cáo, tạo dáng theo animation của kỹ năng,
## vẽ thành nét trắng phát sáng trên nền đen. Kỹ năng không đặt animation thì dùng ảnh vẽ sẵn (illustration / icon).
## Thêm kỹ năng mới chỉ cần điền illustration_animation + illustration_time trong .tres.
## SubViewport chỉ vẽ khi bảng đang mở; còn lại tắt hẳn.

const Tuning = preload("res://resources/feedback/ability_acquire/ability_acquire_data.gd")
## Hiệu ứng chiêu bắt đầu từ khoảng tay cáo (phần bề ngang ô cáo)
const EFFECT_START := 0.62

## Vật liệu thân cáo (nét mực); next_pass là vật liệu viền ngoài. Dùng chung cho mọi mesh của cáo
@export var body_material: ShaderMaterial

var _data: Tuning
var _use_figure: bool = false

@onready var _halo: TextureRect = $Halo
@onready var _effect: ColorRect = $Effect
@onready var _figure: TextureRect = $Figure
@onready var _art: TextureRect = $Art
@onready var _stage: SubViewport = $Stage
@onready var _camera: Camera3D = $Stage/Camera3D
@onready var _fox: Node3D = $Stage/Fox
@onready var _anim: AnimationPlayer = $Stage/Fox/AnimationPlayer
@onready var _figure_material: ShaderMaterial = _figure.material as ShaderMaterial
@onready var _art_material: ShaderMaterial = _art.material as ShaderMaterial


func _ready() -> void:
	_stage.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_figure.texture = _stage.get_texture()
	for mesh: MeshInstance3D in _fox.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = body_material
		# Hình minh họa chỉ có dáng cáo, không vẽ bóng
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Áp thông số chung (cỡ, màu nét, góc máy). Gọi một lần khi bảng được tạo
func configure(data: Tuning) -> void:
	_data = data
	# Khung ngang: cáo chiếm ô vuông bên trái, hiệu ứng chiêu kéo từ tay cáo sang hết bên phải
	custom_minimum_size = Vector2(data.illustration_size * data.illustration_aspect, data.illustration_size)
	var figure_share := 1.0 / maxf(data.illustration_aspect, 1.0)
	for node: Control in [_figure, _art]:
		node.anchor_right = figure_share
	_halo.anchor_right = figure_share
	_effect.anchor_left = figure_share * EFFECT_START
	_stage.size = Vector2i.ONE * data.figure_resolution
	body_material.set_shader_parameter(&"fill_color", data.figure_fill_color)
	body_material.set_shader_parameter(&"line_color", data.figure_line_color)
	body_material.set_shader_parameter(&"rim_power", data.figure_rim_power)
	body_material.set_shader_parameter(&"rim_strength", data.figure_rim_strength)
	var outline := body_material.next_pass as ShaderMaterial
	outline.set_shader_parameter(&"line_color", data.figure_line_color)
	outline.set_shader_parameter(&"width", data.figure_outline_width)
	_figure_material.set_shader_parameter(&"glow_radius", data.figure_glow_radius)
	_figure_material.set_shader_parameter(&"glow_strength", data.figure_glow_strength)
	for node_name: String in data.hidden_visual_names:
		var hidden_node := _fox.find_child(node_name, true, false) as Node3D
		if hidden_node:
			hidden_node.visible = false
	_place_camera()


## Chuẩn bị cho một kỹ năng: tạo dáng cáo (hoặc lấy ảnh), chưa hiện
func setup(ability: AbilityData) -> void:
	var accent := ability.accent_color
	_halo.modulate = Color(accent, _data.figure_halo_strength)
	_figure_material.set_shader_parameter(&"glow_color", accent)
	_art_material.set_shader_parameter(&"accent", accent)
	_use_figure = not ability.illustration_animation.is_empty() and _anim.has_animation(ability.illustration_animation)
	if not ability.illustration_animation.is_empty() and not _use_figure:
		push_warning("AbilityIllustration: foxy.glb không có animation '%s', dùng ảnh thay thế" % ability.illustration_animation)
	_figure.visible = _use_figure
	_effect.material = ability.illustration_effect
	_effect.visible = ability.illustration_effect != null
	_art.visible = not _use_figure
	if _use_figure:
		_anim.play(ability.illustration_animation)
		_anim.seek(ability.illustration_time, true)
		_anim.pause()
		_stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	else:
		_art.texture = ability.illustration if ability.illustration else ability.icon
	set_reveal(0.0)


## 0 = ẩn, 1 = hiện hết (mực dâng từ dưới lên)
func set_reveal(value: float) -> void:
	_figure_material.set_shader_parameter(&"reveal", value)
	_art_material.set_shader_parameter(&"progress", value)
	_halo.self_modulate.a = value


## Tắt vẽ SubViewport khi bảng đóng
func release() -> void:
	_stage.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_anim.stop()


## Vẽ một khung lúc nạp khu (màn còn đen) để shader nét mực được biên dịch sẵn
func prewarm() -> void:
	_stage.render_target_update_mode = SubViewport.UPDATE_ONCE


## Tâm hình cáo (icon bay về HUD xuất phát từ đây)
func get_center() -> Vector2:
	return _figure.get_global_rect().get_center()


func _place_camera() -> void:
	var yaw := deg_to_rad(_data.figure_camera_yaw_degrees)
	var pitch := deg_to_rad(_data.figure_camera_pitch_degrees)
	var target := Vector3(0.0, _data.figure_look_height, 0.0)
	var offset := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * _data.figure_camera_distance
	_camera.fov = _data.figure_camera_fov
	_camera.look_at_from_position(target + offset, target, Vector3.UP)
