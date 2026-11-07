@tool
class_name HudStyle
extends Resource
## DONE: dữ liệu hình ảnh HUD dùng chung; widget chỉ biết component và style được gán.
## NOTES: tham số trình diễn riêng của Foxy, không suy ra timing từ game tham khảo.
const Glyph = preload("res://ui/hud/skills/glyphs/hud_glyph.gd")
@export_group("Ink and typography")
@export var theme: Theme = preload("res://ui/theme/menu_theme.tres")
@export var ivory: Color = Color("#f1ecdc")
@export var gold: Color = Color("#c6b58b")
@export var muted: Color = Color("#817b6b")
@export var ink: Color = Color(0.025,0.035,0.042,0.85)
@export var empty_ink: Color = Color(0.03,0.045,0.055,0.66)
@export var damage_color: Color = Color("#da6553")
@export var heal_color: Color = Color("#fff0b8")
@export var line_width: float = 1.25
@export var line_limits: Vector2 = Vector2(0.5,4.0)
@export var minimum_duration: float = 0.001
@export var glyphs: Dictionary[StringName,Glyph] = {}
@export var texture_overrides: Dictionary[StringName,Texture2D] = {}
@export_group("Layout")
@export var margin: Vector2 = Vector2(24,24)
@export var hud_scale: float = 1.0
@export var scale_limits: Vector2 = Vector2(0.5,2.0)
@export var health_offset: Vector2 = Vector2(106,5)
@export var energy_offset: Vector2 = Vector2.ZERO
@export var currency_offset: Vector2 = Vector2(110,53)
@export var skills_offset: Vector2 = Vector2(92,88)
@export var safe_bottom_margin: float = 24.0
@export var layout_gap: float = 8.0
@export_group("Health")
@export var health_icon_size: Vector2 = Vector2(29,33)
@export var health_spacing: int = 4
@export var health_shadow_width: float = 2.5
@export var health_max_width: float = 820.0
@export var health_icon_max_height: float = 64.0
@export var health_crack_time: float = 0.10
@export var health_transition_time: float = 0.25
@export var health_shard_time: float = 0.42
@export_range(0,4) var health_shard_count: int = 4
@export var health_shard_distance: float = 18.0
@export var health_shard_turn: float = 0.6
@export var health_low_threshold: int = 1
@export var health_pulse_speed: float = 4.2
@export var health_pulse_amount: float = 0.25
@export var health_full_texture: Texture2D
@export var health_empty_texture: Texture2D
@export var low_health_strength: float = 0.30
@export var low_health_tint: Color = Color(0.015,0.02,0.028,1)
@export_group("Hurt feedback")
@export var hurt_attack_time: float = 0.05
@export var hurt_fade_time: float = 0.45
@export var hurt_peak: float = 0.6
@export var hurt_ember_count: int = 24
@export var hurt_ember_lifetime: float = 0.55
@export var hurt_ember_size: Vector2 = Vector2(14,34)
@export var hurt_ember_speed: Vector2 = Vector2(20,80)
@export var hurt_ember_accel: Vector2 = Vector2(-1100,-700)
@export_group("Linh luc")
@export var energy_size: Vector2 = Vector2(86,106)
@export var energy_size_limit: Vector2 = Vector2(160,180)
@export var energy_diameter: float = 82.0
@export_range(16,128) var energy_curve_steps: int = 48
@export var energy_preview_units: int = 4
@export var energy_rim: float = 6.0
@export var energy_wave_height: float = 0.018
@export var energy_wave_speed: float = 4.0
@export var energy_wave_frequency: float = 8.0
@export_range(0,1) var energy_idle_wave: float = 0.18
@export var energy_fill_time: float = 0.30
@export var energy_drop_time: float = 0.42
@export var energy_shell_extent: float = 0.49
@export var energy_shell_color: Color = Color("#244d45")
@export var energy_shell_accent: Color = Color("#97b6a1")
@export var energy_shell_tip_color: Color = Color("#dfd8b7")
@export var energy_shell_tip_start: int = 1
@export_range(0,1) var energy_inner_rim_opacity: float = 0.55
@export var energy_full_time: float = 0.45
@export var energy_warn_time: float = 0.32
@export var energy_shake: float = 4.0
@export var energy_shake_speed: float = 45.0
@export var energy_label: String = "LINH LỰC"
@export var energy_font_size: int = 12
@export var energy_frame_texture: Texture2D
@export var energy_mask_texture: Texture2D
@export var energy_fallback: Color = Color("#93c5a4")
@export var element_colors: Dictionary[StringName,Color] = {&"wind":Color("#9fdce0"),&"fire":Color("#ee964e"),&"ice":Color("#a1cced"),&"thunder":Color("#e6cb6b")}
@export_group("Skill cluster")
@export var skill_radius: float = 25.0
@export var skill_radius_limits: Vector2 = Vector2(12,48)
@export var skill_step_limit: float = 80.0
@export var skill_scale_limit: float = 1.35
@export var skill_padding: float = 9.0
@export var skill_step: float = 32.0
@export var skill_anchors: Dictionary[StringName,Vector2] = {&"bow":Vector2(0,-1),&"wind_blast":Vector2(-1,0),&"sword":Vector2(1,0),&"flame_breath":Vector2(0,1)}
@export var skill_icon_scale: float = 0.65
@export var skill_icon_rotations: Dictionary[StringName,float] = {}
@export var skill_show_key_badges: bool = true
@export var skill_active_scale: float = 1.13
@export var skill_active_time: float = 0.13
@export var skill_press_scale: float = 1.08
@export var skill_press_time: float = 0.16
@export var skill_active_line: float = 2.0
@export var skill_inner_gap: float = 3.5
@export var skill_fill: Color = Color(0.025,0.035,0.045,0.72)
@export var skill_selected_fill: Color = Color(0.09,0.105,0.11,0.84)
@export var skill_cooldown_color: Color = Color(0.015,0.025,0.035,0.80)
@export var skill_cooldown_line: Color = Color(0.89,0.82,0.62,0.65)
@export_range(8,96) var skill_sweep_steps: int = 48
@export var skill_badge_anchor: Vector2 = Vector2(0,0.79)
@export var skill_badge_height: float = 15.0
@export var skill_key_font: int = 10
@export var skill_cooldown_font: int = 12
@export var skill_badge_padding: float = 7.0
@export var element_badge_anchor: Vector2 = Vector2(0.70,-0.15)
@export var element_badge_radius: float = 4.0
@export_group("Soul Jade")
@export var currency_icon_size: Vector2 = Vector2(17,23)
@export var currency_font_size: int = 23
@export var currency_spacing: int = 8
@export var currency_count_time: float = 0.45
@export var currency_pop_time: float = 0.25
@export var currency_pop_scale: float = 1.22
@export var currency_show_time: float = 2.2
@export var currency_appear_time: float = 0.12
@export var currency_fade_time: float = 0.30
@export var currency_texture: Texture2D
@export_group("Interaction prompt")
@export var prompt_offset: Vector2 = Vector2(0,-68)
@export var prompt_font: int = 21
@export var prompt_key_font: int = 14
@export var prompt_key_size: Vector2 = Vector2(26,26)
@export var prompt_gap: int = 10
@export var prompt_rule_width: float = 130.0
@export var prompt_rule_gap: float = 11.0
@export var prompt_diamond_size: float = 3.0
@export var prompt_appear_time: float = 0.14
@export var prompt_fade_time: float = 0.12
@export var prompt_slide: float = 7.0
@export var prompt_text_width: float = 180.0
## Nét vẫn hữu hạn khi nhập nhầm giá trị lớn; giới hạn cũng thuộc style.
func stroke_width() -> float:
	var lower: float = maxf(minf(line_limits.x,line_limits.y),0.1)
	return clampf(line_width,lower,maxf(maxf(line_limits.x,line_limits.y),lower))
## Giữ các ô có hình hữu dụng khi radius bị chỉnh bằng không hoặc quá lớn.
func get_skill_radius() -> float:
	var lower: float = maxf(minf(skill_radius_limits.x,skill_radius_limits.y),1)
	return clampf(skill_radius,lower,maxf(maxf(skill_radius_limits.x,skill_radius_limits.y),lower))
## Khoảng cách nhỏ nhất đã tính cả scale active để các ô không chồng lên nhau.
func get_skill_step() -> float:
	var lower: float = get_skill_radius()*get_active_scale()+stroke_width()
	return clampf(skill_step,lower,maxf(skill_step_limit,lower))
## Scale cảnh báo/bấm bị chặn trong khoảng nhỏ để không che cả cụm HUD.
func get_active_scale() -> float:
	return clampf(skill_active_scale,1,maxf(skill_scale_limit,1))
