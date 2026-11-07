class_name GameHud
extends Control
## Lớp ghép chỉ bố trí/nối màu. HealthBar/EnergyBar không biết Player hoặc GameState.
const Style = preload("res://resources/ui/hud_style.gd")
@export_group("HUD")
@export var style: Style = preload("res://resources/ui/hud_style.tres")
@export var energy_bar: Control
@export var currency_counter: Control
var _laying_out: bool = false
@onready var _health_panel: Control = $HealthPanel
@onready var _health_bar: HealthBar = $HealthPanel/HealthBar
@onready var _cluster: Control = $SkillCluster
## Deferred để các sibling EnergyBar/CurrencyCounter đã dựng hình trước khi apply.
func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_process(false)
	get_viewport().size_changed.connect(_layout)
	_health_bar.minimum_size_changed.connect(_layout)
	if is_instance_valid(currency_counter): currency_counter.minimum_size_changed.connect(_layout)
	GameState.weapon_changed.connect(_on_weapon)
	GameState.fusion_changed.connect(_refresh_element)
	GameState.progress_replaced.connect(_refresh_element)
	apply_style.call_deferred()
## Một resource dùng cho cả cụm; cập nhật theo sự kiện, không chạy layout trong process.
func apply_style() -> void:
	if not is_inside_tree(): return
	theme = style.theme
	_health_bar.style = style
	_health_bar.apply_style()
	_cluster.set(&"style",style)
	_cluster.call(&"apply_style")
	for widget: Control in [energy_bar,currency_counter]:
		if is_instance_valid(widget):
			widget.set(&"style",style)
			widget.call(&"apply_style")
	_layout()
	_refresh_element()
## Các NodePath công khai vẫn như cũ, chỉ thay tọa độ/bề mặt để giữ tính tương thích.
func _layout() -> void:
	if _laying_out: return
	_laying_out = true
	var viewport: Vector2 = get_viewport_rect().size
	position = style.margin.clamp(Vector2.ZERO,viewport*0.2)
	var lower: float = maxf(minf(style.scale_limits.x,style.scale_limits.y),0.1)
	var upper: float = maxf(maxf(style.scale_limits.x,style.scale_limits.y),lower)
	var factor: float = clampf(style.hud_scale,lower,upper)
	var gap: float = clampf(style.layout_gap,0,32)
	var energy_offset: Vector2 = style.energy_offset.clamp(Vector2.ZERO,viewport*0.2)
	var energy_size: Vector2 = energy_bar.get_combined_minimum_size() if is_instance_valid(energy_bar) else Vector2.ZERO
	var health_offset: Vector2 = style.health_offset.clamp(Vector2.ZERO,viewport*0.4)
	health_offset.x = maxf(health_offset.x,energy_offset.x+energy_size.x+gap)
	var currency_offset: Vector2 = style.currency_offset.clamp(Vector2.ZERO,viewport*0.4)
	currency_offset.x = maxf(currency_offset.x,health_offset.x)
	currency_offset.y = maxf(currency_offset.y,health_offset.y+_health_bar.get_combined_minimum_size().y+gap)
	var currency_height: float = currency_counter.get_combined_minimum_size().y if is_instance_valid(currency_counter) else 0.0
	var skills_offset: Vector2 = style.skills_offset.clamp(Vector2.ZERO,viewport*0.4)
	skills_offset.x = maxf(skills_offset.x,energy_offset.x+energy_size.x+gap)
	skills_offset.y = maxf(skills_offset.y,currency_offset.y+currency_height+gap)
	var height: float = maxf(energy_offset.y+energy_size.y,skills_offset.y+_cluster.size.y)
	factor = minf(factor,maxf((viewport.y-position.y-maxf(style.safe_bottom_margin,0))/maxf(height,1),0.1))
	scale = Vector2.ONE*factor
	_health_bar.fit_width(maxf((viewport.x-position.x*2.0)/factor-health_offset.x,1))
	_health_panel.position = health_offset
	_health_panel.size = _health_panel.get_combined_minimum_size()
	_cluster.position = skills_offset
	if is_instance_valid(energy_bar):
		energy_bar.scale = scale
		energy_bar.position = position+energy_offset*factor
	if is_instance_valid(currency_counter):
		currency_counter.scale = scale
		currency_counter.position = position+currency_offset*factor
	_laying_out = false
## Signal có payload được đổi thành refresh màu, không can thiệp vũ khí.
func _on_weapon(_weapon: WeaponData) -> void:
	_refresh_element()
## Khi hai vũ khí khác nguyên tố, bình theo vũ khí GameState đang trang bị như kế hoạch đã duyệt.
func _refresh_element() -> void:
	if not is_instance_valid(energy_bar): return
	var tint: Color = style.energy_fallback
	var weapon: WeaponData = GameState.get_weapon()
	if weapon != null:
		var element: ElementData = GameState.get_fused_element(weapon.slot)
		if element != null: tint = style.element_colors.get(element.id,element.color)
	energy_bar.call(&"set_element_color",tint)
