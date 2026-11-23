class_name CharmRarityVfx
extends Control
## Shader tự chạy nhịp sáng; không cần _process hay tạo node cho từng hạt lấp lánh.

const MAX_SPARKLES: int = 4
const EXTENT_RATIO: float = 2.5

var _rarity: CharmRarity
var _center: Vector2 = Vector2.INF
var _radius: float = -1.0
var _focused: bool = false
var _focus_set: bool = false
var _enabled: bool = false
var _material: ShaderMaterial

@onready var _paint: ColorRect = $Paint


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	_material = _paint.material as ShaderMaterial
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
		size = Vector2.ONE * radius * EXTENT_RATIO
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
	_material.set_shader_parameter(&"rarity_color", _rarity.tint)
	_material.set_shader_parameter(&"highlight_color", _rarity.highlight)
	_material.set_shader_parameter(&"glow_strength", clampf(_rarity.glow_strength, 0.0, 1.0))
	_material.set_shader_parameter(&"pulse_speed", clampf(_rarity.pulse_speed, 0.0, 2.0))
	_material.set_shader_parameter(&"sparkle_count", clampi(_rarity.sparkle_count, 0, MAX_SPARKLES))
	_material.set_shader_parameter(&"sparkle_size", clampf(_rarity.sparkle_size, 0.0, 0.2))
