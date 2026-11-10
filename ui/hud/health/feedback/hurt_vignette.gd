class_name HurtVignette
extends ColorRect
## Viền đau và nền tối low-HP dùng cùng material có sẵn, không thêm lớp screen copy.
const Style = preload("res://resources/ui/hud_style.gd")
@export_group("Binding")
@export var hurtbox: HurtboxComponent
@export var health: HealthComponent
@export var style: Style = preload("res://resources/ui/hud_style.tres")
var attack_time: float:
	get: return style.hurt_attack_time
var fade_time: float:
	get: return style.hurt_fade_time
var peak_strength: float:
	get: return style.hurt_peak
var _tween: Tween
var _base: float = 0.0
var _hurt_strength: float = 0.0
@onready var _embers: CPUParticles2D = $Embers
@onready var _shader_material: ShaderMaterial = material as ShaderMaterial
## Hình nền không chặn input; component thiếu không làm widget bị lỗi khởi tạo.
func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_process(false)
	material = _shader_material.duplicate()
	_shader_material = material as ShaderMaterial
	apply_style()
	if hurtbox != null: hurtbox.hurt.connect(_on_hurt)
	if health != null:
		if not health.is_node_ready(): await health.ready
		if not is_inside_tree(): return
		health.health_changed.connect(_on_health)
		_on_health(health.current_health,health.max_health)
	else: _set_strength(0.0)
## Tắt tween/hạt khi thoát; không còn callback tác động vào scene cũ.
func _exit_tree() -> void:
	if _tween != null and _tween.is_valid(): _tween.kill()
## Điểm phát hạt chỉ dựng lúc resize/đổi style, không dựng trong mỗi lần bị đánh.
func apply_style() -> void:
	_embers.amount = clampi(style.hurt_ember_count,1,64)
	_embers.lifetime = maxf(style.hurt_ember_lifetime,0.01)
	_embers.scale_amount_min = maxf(style.hurt_ember_size.x,0)
	_embers.scale_amount_max = maxf(style.hurt_ember_size.y,_embers.scale_amount_min)
	_embers.initial_velocity_min = style.hurt_ember_speed.x
	_embers.initial_velocity_max = style.hurt_ember_speed.y
	_embers.radial_accel_min = minf(style.hurt_ember_accel.x,style.hurt_ember_accel.y)
	_embers.radial_accel_max = maxf(style.hurt_ember_accel.x,style.hurt_ember_accel.y)
	_embers.color_ramp = FxUtil.make_alpha_gradient([[0.0,0.0],[0.2,1.0],[1.0,0.0]])
	_embers.scale_amount_curve = FxUtil.make_curve([Vector2(0,1),Vector2(1,0.3)])
	_setup_embers()
	if not get_viewport().size_changed.is_connected(_setup_embers): get_viewport().size_changed.connect(_setup_embers)
## Không xóa cảnh báo nguy cấp khi đuôi hit flash kết thúc.
func _on_health(current: int, _max_value: int) -> void:
	_base = style.low_health_strength if current>0 and current<=style.health_low_threshold else 0.0
	_set_strength(_hurt_strength)
## Mỗi lượt đau chỉ thay một tween; không cộng chồng vô hạn.
func _on_hurt(_info: DamageInfo, _damage_taken: int) -> void:
	if _tween != null and _tween.is_valid(): _tween.kill()
	show()
	if style.hurt_ember_count>0: _embers.restart()
	_tween = create_tween()
	_tween.tween_method(_set_strength,_hurt_strength,style.hurt_peak,maxf(style.hurt_attack_time,0.001))
	_tween.tween_method(_set_strength,style.hurt_peak,0.0,maxf(style.hurt_fade_time,0.001)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
## Màu và độ đậm về nền đen khi còn 1 HP, về ẩn hoàn toàn khi an toàn.
func _set_strength(value: float) -> void:
	_hurt_strength = value
	_shader_material.set_shader_parameter(&"strength",clampf(_base+value,0,1))
	_shader_material.set_shader_parameter(&"tint",style.low_health_tint.lerp(style.damage_color,clampf(value/maxf(style.hurt_peak,0.001),0,1)))
	visible = _base+value>0.0
## Dữ liệu mép màn hình cập nhật theo resize, không giữ vị trí của cửa sổ cũ.
func _setup_embers() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	_embers.position = viewport_size*0.5
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in range(clampi(style.hurt_ember_count,1,64)):
		var angle: float = TAU*float(index)/float(clampi(style.hurt_ember_count,1,64))
		var direction: Vector2 = Vector2(cos(angle),sin(angle))
		var edge: float = minf(viewport_size.x*0.5/maxf(absf(direction.x),0.0001),viewport_size.y*0.5/maxf(absf(direction.y),0.0001))
		points.append(direction*edge)
	_embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
	_embers.emission_points = points
