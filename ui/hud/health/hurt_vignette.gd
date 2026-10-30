class_name HurtVignette
extends ColorRect
## Viền đỏ + đốm lửa bay vào từ mép màn hình khi player bị đánh. Nghe hurtbox.hurt, tự ẩn khi xong.
## Phủ toàn màn hình nhưng bỏ qua chuột.

@export var hurtbox: HurtboxComponent

@export_group("Timing")
## Tăng lên đỉnh rất nhanh rồi tan chậm (ease-out)
@export var attack_time: float = 0.05
@export var fade_time: float = 0.45

@export_group("Look")
@export_range(0.0, 1.0) var peak_strength: float = 0.6
## Số đốm lửa dọc mép màn hình
@export var ember_points: int = 24

var _tween: Tween

@onready var _embers: CPUParticles2D = $Embers
@onready var _shader_material: ShaderMaterial = material as ShaderMaterial


func _ready() -> void:
	visible = false
	if hurtbox == null:
		push_error("%s cần hurtbox" % get_path())
		return
	hurtbox.hurt.connect(_on_hurt)
	_setup_embers()
	_embers.color_ramp = FxUtil.make_alpha_gradient([[0.0, 0.0], [0.2, 1.0], [1.0, 0.0]])
	_embers.scale_amount_curve = FxUtil.make_curve([Vector2(0.0, 1.0), Vector2(1.0, 0.3)])


func _on_hurt(_info: DamageInfo, _damage_taken: int) -> void:
	if _tween:
		_tween.kill()
	visible = true
	_embers.restart()
	_tween = create_tween()
	_tween.tween_method(_set_strength, 0.0, peak_strength, attack_time)
	_tween.tween_method(_set_strength, peak_strength, 0.0, fade_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(hide)


func _set_strength(value: float) -> void:
	_shader_material.set_shader_parameter(&"strength", value)


## Đốm xuất phát từ mép khung hình (toạ độ tương đối tâm màn hình) rồi bị hút vào tâm
func _setup_embers() -> void:
	var viewport_size := get_viewport_rect().size
	_embers.position = viewport_size * 0.5
	var points := PackedVector2Array()
	for i in ember_points:
		var angle := TAU * float(i) / float(ember_points)
		var dir := Vector2(cos(angle), sin(angle))
		# Chiếu hướng ra mép hình chữ nhật
		var edge := minf(viewport_size.x * 0.5 / maxf(absf(dir.x), 0.0001), viewport_size.y * 0.5 / maxf(absf(dir.y), 0.0001))
		points.append(dir * edge)
	_embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
	_embers.emission_points = points
