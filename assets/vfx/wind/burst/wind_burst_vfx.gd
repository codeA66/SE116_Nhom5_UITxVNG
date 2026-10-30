class_name WindBurstVfx
extends Node3D
## Hiệu ứng gió một lần (gồng, bung, vòng sóng, hạt, hơi mờ), hướng bung là +Z cục bộ.
## Dùng cho cú thổi và bụi khi trúng vật; khác nhau chỉ ở WindBurstStyle.
## Chỉ chạy _process trong lúc đang phát; mesh và material dựng một lần khi vào scene.

signal finished

enum Kind { STROKE, MOTE, RING, CHARGE }

const BURST_SHADER: Shader = preload("res://assets/shaders/wind/blast/wind_burst.gdshader")
const MIST_SHADER: Shader = preload("res://assets/shaders/wind/ambient/wind_dust.gdshader")
## Độ rộng thêm của hộp bao (m) để hạt bay lên/ra ngoài không bị cắt khi camera lọc vật ngoài màn hình
const BOUNDS_MARGIN := 2.0

@export var style: WindBurstStyle
## Seed riêng để các hiệu ứng đặt cạnh nhau không giống hệt
@export var seed_value: int = 1

var playing: bool = false
var charging: bool = false

var _age: float = 0.0
var _charge_age: float = 0.0
var _charge_duration: float = 0.1
var _stroke_material: ShaderMaterial
var _mote_material: ShaderMaterial
var _ring_material: ShaderMaterial
var _charge_material: ShaderMaterial
var _mist_material: ShaderMaterial

@onready var _strokes: MultiMeshInstance3D = $Strokes
@onready var _motes: MultiMeshInstance3D = $Motes
@onready var _ring: MeshInstance3D = $Ring
@onready var _charge: MultiMeshInstance3D = $Charge
@onready var _mist: MultiMeshInstance3D = $Mist


func _ready() -> void:
	set_process(false)
	if style == null:
		push_error("%s chưa gán WindBurstStyle, hiệu ứng bị tắt" % get_path())
		return
	_stroke_material = _burst_material(Kind.STROKE)
	_mote_material = _burst_material(Kind.MOTE)
	_ring_material = _burst_material(Kind.RING)
	_charge_material = _burst_material(Kind.CHARGE)
	_charge_material.set_shader_parameter(&"width", style.charge_width)
	_mist_material = ShaderMaterial.new()
	_mist_material.shader = MIST_SHADER
	_mist_material.set_shader_parameter(&"one_shot", true)
	_mist_material.set_shader_parameter(&"duration", style.duration)
	_mist_material.set_shader_parameter(&"tint", style.mist_color)
	_mist_material.set_shader_parameter(&"opacity", style.mist_opacity)
	_mist_material.set_shader_parameter(&"puff_size", style.mist_size)
	_mist_material.set_shader_parameter(&"spread", style.mist_spread)
	_mist_material.set_shader_parameter(&"box_size", Vector3(1.0, 0.6, 1.0))

	var strip := WindVfxGeometry.strip()
	var quad := WindVfxGeometry.quad()
	_setup(_strokes, WindVfxGeometry.build_multimesh(strip, style.stroke_count, seed_value), _stroke_material)
	_setup(_motes, WindVfxGeometry.build_multimesh(quad, style.mote_count, seed_value + 1), _mote_material)
	_setup(_charge, WindVfxGeometry.build_multimesh(strip, style.charge_strokes, seed_value + 2), _charge_material)
	_setup(_mist, WindVfxGeometry.build_multimesh(quad, style.mist_count, seed_value + 3), _mist_material)
	_ring.mesh = WindVfxGeometry.plane()
	_ring.material_override = _ring_material
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	set_reach(style.reach)
	_hide_burst()
	_charge.visible = false


func _process(delta: float) -> void:
	if charging:
		_charge_age += delta
		_charge_material.set_shader_parameter(&"age", _charge_age)
		if _charge_age >= _charge_duration:
			stop_charge()
	if playing:
		_age += delta
		for material in [_stroke_material, _mote_material, _ring_material, _mist_material]:
			(material as ShaderMaterial).set_shader_parameter(&"age", _age)
		if _age >= style.duration:
			playing = false
			_hide_burst()
			finished.emit()
	if not playing and not charging:
		set_process(false)


## Tầm bay của nét (m); style.reach >= 0 thì luôn dùng giá trị trong style
func set_reach(reach: float) -> void:
	if style == null:
		return
	var value := style.reach if style.reach >= 0.0 else maxf(reach, 0.5)
	for material in [_stroke_material, _mote_material]:
		(material as ShaderMaterial).set_shader_parameter(&"reach", value)
	var extent := maxf(value, maxf(style.ring_radius, style.ground_reach)) + BOUNDS_MARGIN
	var bounds := AABB(Vector3(-extent, -1.0, -extent), Vector3(extent * 2.0, style.shot_height + style.height_spread + BOUNDS_MARGIN + 1.0, extent * 2.0))
	for instance: GeometryInstance3D in [_strokes, _motes, _ring, _charge, _mist]:
		instance.custom_aabb = bounds


## Bắt đầu gồng: nét xoáy hút vào quanh tâm trong duration giây
func start_charge(duration: float) -> void:
	if style == null or style.charge_strokes <= 0:
		return
	_charge_duration = maxf(duration, 0.01)
	_charge_age = 0.0
	_charge_material.set_shader_parameter(&"duration", _charge_duration)
	_charge_material.set_shader_parameter(&"age", 0.0)
	_charge.visible = true
	charging = true
	set_process(true)


func stop_charge() -> void:
	charging = false
	_charge.visible = false


## Phát cú bung. has_ground = false (đang trên không) thì bỏ vòng sóng và nét sát đất
func play(has_ground: bool = true) -> void:
	if style == null:
		return
	stop_charge()
	_age = 0.0
	for material in [_stroke_material, _mote_material, _ring_material, _mist_material]:
		(material as ShaderMaterial).set_shader_parameter(&"age", 0.0)
	_stroke_material.set_shader_parameter(&"ground_fraction", style.ground_fraction if has_ground else 0.0)
	_strokes.visible = style.stroke_count > 0
	_motes.visible = style.mote_count > 0
	_mist.visible = style.mist_count > 0
	_ring.visible = has_ground and style.ring_radius > 0.0
	playing = true
	set_process(true)


## Dừng ngay mọi thứ (bị ngắt giữa chừng)
func stop() -> void:
	stop_charge()
	if playing:
		playing = false
		_hide_burst()
	set_process(false)


func _burst_material(kind: Kind) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = BURST_SHADER
	material.set_shader_parameter(&"kind", kind)
	material.set_shader_parameter(&"duration", style.duration)
	material.set_shader_parameter(&"core_color", style.core_color)
	material.set_shader_parameter(&"edge_color", style.edge_color)
	material.set_shader_parameter(&"width", style.width)
	material.set_shader_parameter(&"stroke_length", style.stroke_length)
	material.set_shader_parameter(&"cone_half_angle", deg_to_rad(style.cone_half_angle_degrees))
	material.set_shader_parameter(&"shot_height", style.shot_height)
	material.set_shader_parameter(&"height_spread", style.height_spread)
	material.set_shader_parameter(&"ground_fraction", style.ground_fraction)
	material.set_shader_parameter(&"ground_reach", style.ground_reach)
	material.set_shader_parameter(&"curl_fraction", style.curl_fraction)
	material.set_shader_parameter(&"curl_radius", style.curl_radius)
	material.set_shader_parameter(&"curl_turns", style.curl_turns)
	material.set_shader_parameter(&"leaf_fraction", style.leaf_fraction)
	material.set_shader_parameter(&"leaf_color", style.leaf_color)
	material.set_shader_parameter(&"leaf_color_alt", style.leaf_color_alt)
	material.set_shader_parameter(&"vein_color", style.vein_color)
	material.set_shader_parameter(&"leaf_size", style.leaf_size)
	material.set_shader_parameter(&"speck_size", style.speck_size)
	material.set_shader_parameter(&"mote_reach", style.mote_reach)
	material.set_shader_parameter(&"mote_lift", style.mote_lift)
	material.set_shader_parameter(&"ring_radius", style.ring_radius)
	material.set_shader_parameter(&"ring_width", style.ring_width)
	material.set_shader_parameter(&"charge_radius", style.charge_radius)
	return material


func _setup(instance: MultiMeshInstance3D, multimesh: MultiMesh, material: ShaderMaterial) -> void:
	instance.multimesh = multimesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _hide_burst() -> void:
	_strokes.visible = false
	_motes.visible = false
	_ring.visible = false
	_mist.visible = false
