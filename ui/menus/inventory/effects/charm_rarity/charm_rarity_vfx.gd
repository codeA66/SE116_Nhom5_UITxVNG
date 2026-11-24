class_name CharmRarityVfx
extends Control
## Shader tự chạy nhịp sáng; không cần _process hay tạo node cho từng hạt lấp lánh.

const MAX_SPARKLES: int = 4
const EXTENT_RATIO: float = 2.5
const AURA_EXTENT_RATIO: float = 2.9

var _rarity: CharmRarity
var _center: Vector2 = Vector2.INF
var _radius: float = -1.0
var _focused: bool = false
var _focus_set: bool = false
var _enabled: bool = false
var _material: ShaderMaterial
var _default_shader: Shader
var _aura_enabled: bool = false
var _entry_tween: Tween

@onready var _paint: ColorRect = $Paint


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	_material = _paint.material as ShaderMaterial
	_default_shader = _material.shader
	visibility_changed.connect(_on_visibility_changed)
	_apply_rarity()


func configure(rarity: CharmRarity) -> void:
	_rarity = rarity
	if is_node_ready():
		_apply_rarity()


func set_geometry(center: Vector2, radius: float, focused: bool) -> void:
	if not _enabled or radius <= 0.0:
		hide()
		return
	show()
	if center != _center or not is_equal_approx(radius, _radius):
		_center = center
		_radius = radius
		var extent: float = AURA_EXTENT_RATIO if _aura_enabled else EXTENT_RATIO
		size = Vector2.ONE * radius * extent
		position = center - size * 0.5
	if not _focus_set or focused != _focused:
		_focused = focused
		_focus_set = true
		_material.set_shader_parameter(&"selected", 1.0 if focused else 0.0)


func _apply_rarity() -> void:
	_enabled = _rarity != null and _rarity.glow_strength > 0.0
	if not _enabled:
		hide()
		return
	var use_aura: bool = _rarity.aura_shader != null and _rarity.aura_texture != null
	var shader: Shader = _rarity.aura_shader if use_aura else _default_shader
	var shader_changed: bool = shader != _material.shader
	if shader_changed:
		_material.shader = shader
		_radius = -1.0
		_focus_set = false
		_stop_entry()
	_aura_enabled = use_aura
	_material.set_shader_parameter(&"rarity_color", _rarity.tint)
	_material.set_shader_parameter(&"highlight_color", _rarity.highlight)
	_material.set_shader_parameter(&"glow_strength", clampf(_rarity.glow_strength, 0.0, 1.0))
	_material.set_shader_parameter(&"pulse_speed", clampf(_rarity.pulse_speed, 0.0, 2.0))
	if _aura_enabled:
		_material.set_shader_parameter(&"aura_texture", _rarity.aura_texture)
		if shader_changed:
			_on_visibility_changed()
	else:
		_material.set_shader_parameter(&"sparkle_count", clampi(_rarity.sparkle_count, 0, MAX_SPARKLES))
		_material.set_shader_parameter(&"sparkle_size", clampf(_rarity.sparkle_size, 0.0, 0.2))


func _on_visibility_changed() -> void:
	_stop_entry()
	if not _aura_enabled:
		return
	_material.set_shader_parameter(&"opening", 0.0)
	if not _enabled or not is_visible_in_tree() or _rarity.aura_open_duration <= 0.0:
		return
	# Tab dừng gameplay nên nhịp mở cần dùng tween chạy khi cây scene đang pause.
	_material.set_shader_parameter(&"opening", 1.0)
	_entry_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_entry_tween.tween_property(_material, ^"shader_parameter/opening", 0.0, _rarity.aura_open_duration)


func _stop_entry() -> void:
	if _entry_tween != null:
		_entry_tween.kill()
		_entry_tween = null
