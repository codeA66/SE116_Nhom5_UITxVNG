class_name FlameFeedback
extends Node3D
## Phản hồi hình ảnh / âm thanh cho một ngọn lửa, dùng chung cho đuốc cầm tay, đuốc tường (sau này lửa trại...).
## Chủ ngọn lửa gọi setup() một lần, rồi ignite() / extinguish(); đặt intensity (1 → nhỏ dần) và sputter khi sắp tắt.
## Chỉ đổi hình (scale ngọn lửa, năng lượng đèn), không đụng logic cháy của chủ.
## Lửa thật = hạt lửa / khói / tàn lặp liên tục (GPUParticles tạo sẵn) + đèn chập chờn cả độ sáng, màu và vị trí.
## Hiệu năng: _process chỉ chạy khi đang cháy (chỉ vài phép sin); không instantiate gì khi chơi.

signal ignited
signal extinguished

@export var data: FlameFeedbackData

## Cường độ cháy 1 (đầy) → 0 (cạn); cỡ lửa / đèn đi từ 1 xuống data.burn_min_intensity. Chủ tween để lửa nhỏ dần
var intensity: float = 1.0
## Sắp tắt: chập chờn mạnh hơn
var sputter: bool = false
var is_burning: bool = false

var _flame: Node3D
var _light: OmniLight3D
var _light_base_pos: Vector3 = Vector3.ZERO
var _base_color: Color = Color.WHITE
# Các lớp hạt lặp thực sự dùng (amount > 0), bật khi cháy, tắt khi tắt
var _loop_fx: Array[GPUParticles3D] = []
var _last_ratio: float = -1.0
var _base_energy: float = 1.0
var _flame_base_scale: Vector3 = Vector3.ONE
var _flash: float = 1.0
var _pop: Vector3 = Vector3.ONE
var _time: float = 0.0
var _tween: Tween

@onready var _flame_fx: GPUParticles3D = $Flame
@onready var _plume: GPUParticles3D = $Plume
@onready var _rising_embers: GPUParticles3D = $RisingEmbers
@onready var _fill_light: OmniLight3D = $FillLight
@onready var _sparks: GPUParticles3D = $Sparks
@onready var _smoke: GPUParticles3D = $Smoke
@onready var _ignite_sfx: AudioStreamPlayer3D = $IgniteSfx
@onready var _extinguish_sfx: AudioStreamPlayer3D = $ExtinguishSfx


func _ready() -> void:
	set_process(false)
	# Lệch pha để nhiều đuốc cạnh nhau không chập chờn đồng loạt
	_time = randf() * 10.0
	_prepare_particles()


## flame: node hình ngọn lửa (có thể null); light: đèn của ngọn lửa; base_energy: năng lượng đèn lúc cháy bình thường
func setup(flame: Node3D, light: OmniLight3D, base_energy: float) -> void:
	_flame = flame
	_light = light
	_base_energy = base_energy
	if _flame:
		_flame_base_scale = _flame.scale * data.core_scale
		_flame.scale = _flame_base_scale
		# Mesh ngọn lửa không đổ bóng: đèn nằm ngay trong nó, bóng sẽ che hết ánh sáng
		var meshes: Array[Node] = _flame.find_children("*", "GeometryInstance3D", true, false)
		if _flame is GeometryInstance3D:
			meshes.append(_flame)
		for mesh: Node in meshes:
			(mesh as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _light:
		_light_base_pos = _light.position
		_base_color = _light.light_color


## Bắt đầu cháy có bùng lửa (châm / châm lại)
func ignite() -> void:
	_start_burning()
	if _tween:
		_tween.kill()
	_flash = data.flash_multiplier
	_pop = data.ignite_pop_scale
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, ^"_flash", 1.0, data.flash_settle_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, ^"_pop", Vector3.ONE, data.ignite_pop_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_burst(_sparks, data.spark_amount)
	if data.ignite_trauma > 0.0:
		ScreenShake.add_trauma(data.ignite_trauma)
	_play(_ignite_sfx)
	ignited.emit()


## Cháy sẵn không bùng (nạp lại trạng thái đã thắp từ save)
func start_quiet() -> void:
	_start_burning()
	_flash = 1.0
	_pop = Vector3.ONE


func extinguish() -> void:
	if not is_burning:
		return
	is_burning = false
	sputter = false
	set_process(false)
	_set_loop_fx(false)
	_fill_light.visible = false
	if _tween:
		_tween.kill()
	if _light:
		_light.position = _light_base_pos
		_light.light_color = _base_color
	if _flame:
		_flame.scale = _flame_base_scale
	_burst(_smoke, data.smoke_amount)
	_play(_extinguish_sfx)
	extinguished.emit()


func _process(delta: float) -> void:
	_time += delta
	var amount: float = data.sputter_flicker_amount if sputter else data.flicker_amount
	var speed: float = data.sputter_flicker_speed if sputter else data.flicker_speed
	# Tổng hai sóng sin lệch tần số: chập chờn mượt, không giật như random mỗi frame
	var wave: float = 0.6 * sin(_time * speed) + 0.4 * sin(_time * speed * 2.37 + 1.3)
	var fuel: float = clampf(intensity, 0.0, 1.0)
	var size: float = lerpf(data.burn_min_intensity, 1.0, fuel)
	if _light:
		_light.light_energy = maxf(_base_energy * size * _flash * (1.0 + amount * wave), 0.0)
		# Ngọn lửa xẹp (wave âm) hoặc cạn nhiên liệu thì ánh sáng ngả đỏ; bùng thì vàng
		var cool: float = clampf(data.color_flicker * (0.5 - 0.5 * wave) + data.dying_red_shift * (1.0 - fuel), 0.0, 1.0)
		_light.light_color = _base_color * Color(1.0, 1.0 - 0.5 * cool, 1.0 - cool)
		# Đèn nhảy quanh ngọn: ba sóng tần số lệch nhau để bóng đổ lắc không lặp lại đều đều
		var t: float = _time * data.light_wobble_speed
		var wobble: Vector3 = Vector3(sin(t) + 0.5 * sin(t * 2.7 + 1.0), 0.6 * sin(t * 1.7 + 2.1), cos(t * 1.3) + 0.5 * sin(t * 3.1))
		_light.position = _light_base_pos + wobble * data.light_wobble * size
	if data.fill_light_energy > 0.0:
		_fill_light.light_energy = data.fill_light_energy * size * minf(_flash, 1.5) * (1.0 + amount * wave)
	if _flame:
		var flicker_y: float = 1.0 + amount * 0.5 * wave
		_flame.scale = _flame_base_scale * _pop * Vector3(size, size * flicker_y, size)
	# Lửa nhỏ dần thì ít hạt đi; sắp tắt thì hạt thưa thớt chập chờn
	var ratio: float = lerpf(0.35, 1.0, fuel)
	if sputter:
		ratio *= 0.75 + 0.25 * wave
	if absf(ratio - _last_ratio) > 0.02:
		_last_ratio = ratio
		for fx: GPUParticles3D in _loop_fx:
			fx.amount_ratio = ratio


func _start_burning() -> void:
	is_burning = true
	intensity = 1.0
	sputter = false
	_last_ratio = -1.0
	_set_loop_fx(true)
	_fill_light.visible = data.fill_light_energy > 0.0
	set_process(true)


func _burst(particles: GPUParticles3D, amount: int) -> void:
	if amount <= 0:
		return
	particles.amount = amount
	particles.restart()


func _play(player: AudioStreamPlayer3D) -> void:
	# Chỗ cắm âm thanh: chưa có file thì bỏ qua
	if player.stream:
		player.play()


# Mỗi instance nhân kích thước / vận tốc / bán kính hạt theo data: duplicate material một lần để các lửa khác cỡ không ảnh hưởng nhau
func _prepare_particles() -> void:
	_fill_light.omni_range = data.fill_light_range
	_plume.position.y = data.plume_height
	_tune(_flame_fx, data.flame_amount, data.emission_radius)
	_tune(_plume, data.plume_amount, data.emission_radius)
	_tune(_rising_embers, data.ember_amount, data.emission_radius * 1.5)


func _tune(fx: GPUParticles3D, count: int, radius: float) -> void:
	if count <= 0:
		return
	var mat: ParticleProcessMaterial = (fx.process_material as ParticleProcessMaterial).duplicate() as ParticleProcessMaterial
	# Cỡ hạt tách riêng khỏi chiều cao lửa để lửa lớn cao lên chứ không phình bè
	mat.scale_min *= data.blob_scale
	mat.scale_max *= data.blob_scale
	mat.initial_velocity_min *= data.particle_size
	mat.initial_velocity_max *= data.particle_size
	mat.emission_sphere_radius = radius
	fx.process_material = mat
	fx.amount = count
	fx.preprocess = data.preprocess
	_loop_fx.append(fx)


func _set_loop_fx(on: bool) -> void:
	for fx: GPUParticles3D in _loop_fx:
		fx.emitting = on
		# preprocess chỉ có tác dụng khi hệ hạt khởi động lại, nên restart lúc bật
		if on and data.preprocess > 0.0:
			fx.restart()
