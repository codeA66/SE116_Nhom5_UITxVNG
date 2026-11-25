class_name FireRainVfx
extends Node3D
## Hình của Mưa Hỏa Tiễn, nghe signal của FireRain (node cha). Theo nhịp chiêu R của Rumble (đã xem video tham khảo):
## - Bolt: cầu lửa kéo đuôi lao chéo từ phía người gọi xuống từng điểm chạm, đúng mốc chạm đất của dữ liệu.
## - Mỗi điểm chạm: quả cầu lửa vàng bùng to (Blast), khói đen cuộn lên (Smoke), tia lửa văng (Spark),
##   vết nổ dưới chân (lóe + vòng sóng + tia nứt), rồi một cụm lửa cháy tại chỗ tới hết dải cháy (Cluster).
##   Lửa thành từng cụm theo điểm rơi, có khoảng trống giữa các cụm như tham khảo, không trải đều.
## - Strip: vết cháy xém + quầng sáng cam dưới mỗi cụm lửa (không vẽ nứt sáng: nhìn ra dung nham), hiện dần theo các
##   quả đã rơi; tắt lửa thì quầng tắt, vết xém mờ dần. Cụm lửa có thêm lưỡi lửa nhỏ bốc nhanh (Tongue). Embers: tàn lửa bay khắp phần dải đã cháy.
## Node gốc tắt physics interpolation: mọi lớp do _process dời chỗ (cầu lửa bay, vết nổ / cụm lửa dùng lại ở chỗ mới),
## để interpolation bật thì chúng trượt từ chỗ cũ sang, nhìn như nhảy lung tung.
## Mỗi lớp một material. Không dùng đèn điểm: bật đèn lần đầu làm renderer Compatibility biên dịch thêm biến thể
## shader (giật lần đầu). Node theo từng điểm chạm tạo theo số quả lớn nhất từng dùng rồi giữ lại
## (FireRain nằm trong pool nên không tạo lại). Chỉ chạy _process khi đang có gì chuyển động.

## Thời gian một quả bay từ trên trời xuống (s); dữ liệu có first_impact_delay ngắn hơn thì bay nhanh hơn cho kịp
@export_range(0.05, 2.0, 0.01) var fall_time: float = 0.3
## Cầu lửa lao tới từ phía người gọi: độ nghiêng so với phương thẳng đứng (độ)
@export_range(0.0, 80.0, 1.0) var fall_tilt_degrees: float = 38.0
## Đời vết nổ dưới chân (s)
@export_range(0.1, 3.0, 0.05) var impact_life: float = 0.9
## Giới hạn kích thước để một quả trên đường dài không phủ cả dải.
@export_range(0.1, 2.0, 0.05) var impact_radius_ratio: float = 0.57
@export_range(0.1, 8.0, 0.05) var max_impact_radius: float = 2.15
@export_range(0, 40) var prewarm_slots: int = 6
## Dải lửa bùng lên / tắt lửa (s)
@export_range(0.01, 2.0, 0.01) var heat_in_time: float = 0.15
@export_range(0.01, 2.0, 0.01) var heat_out_time: float = 0.45
## Cụm lửa tại mỗi điểm chạm: chiếm bấy nhiêu phần bề ngang / đoạn đường của quả đó
@export_range(0.05, 1.0, 0.05) var cluster_spread: float = 0.22
@export_range(0.1, 4.0, 0.05) var cluster_max_spread: float = 0.55
@export_range(0.1, 2.0, 0.05) var cluster_scale: float = 1.15
## Tàn lửa trên mỗi m² dải cháy, kẹp trong khoảng cho phép (giới hạn hạt)
@export_range(0.1, 10.0, 0.1) var embers_per_m2: float = 0.7
@export var ember_amount_range: Vector2i = Vector2i(6, 40)
## Nâng các lớp trên mặt sàn khỏi bị z-fighting (m)
@export_range(0.0, 0.3, 0.005) var lift: float = 0.03

var _data: FireRainData
var _points: PackedVector3Array = PackedVector3Array()
var _landed: PackedByteArray = PackedByteArray()
var _clock: float = 0.0
var _active: bool = false
var _reveal_target: float = 0.0
var _reveal: float = 0.0
var _heat: float = 0.0
var _heat_target: float = 0.0
var _scorch: float = 0.0
var _linger_clock: float = -1.0
var _trail_dir: Vector3 = Vector3.UP
var _bolts: Array[MeshInstance3D] = []
var _impacts: Array[MeshInstance3D] = []
var _impact_ages: PackedFloat32Array = PackedFloat32Array()
var _sparks: Array[CPUParticles3D] = []
var _smokes: Array[CPUParticles3D] = []
var _blasts: Array[CPUParticles3D] = []
var _clusters: Array[CPUParticles3D] = []
## Lưỡi lửa nhỏ bốc nhanh trong mỗi cụm: làm lửa "sống", không chỉ là vài ngọn đứng yên
var _tongues: Array[CPUParticles3D] = []

@onready var _bolt_template: MeshInstance3D = $BoltTemplate
@onready var _impact_template: MeshInstance3D = $ImpactTemplate
@onready var _spark_template: CPUParticles3D = $SparkTemplate
@onready var _smoke_template: CPUParticles3D = $SmokeTemplate
@onready var _blast_template: CPUParticles3D = $BlastTemplate
@onready var _cluster_template: CPUParticles3D = $ClusterTemplate
@onready var _tongue_template: CPUParticles3D = $TongueTemplate
@onready var _strip: MeshInstance3D = $Strip
@onready var _embers: CPUParticles3D = $Embers
@onready var _strip_mat: ShaderMaterial = _strip.material_override as ShaderMaterial
@onready var _bolt_mat: ShaderMaterial = _bolt_template.material_override as ShaderMaterial


func _ready() -> void:
	for template: GeometryInstance3D in [_bolt_template, _impact_template, _spark_template, _smoke_template,
			_blast_template, _cluster_template, _tongue_template]:
		template.hide()
		if template is CPUParticles3D:
			(template as CPUParticles3D).emitting = false
	_reset()
	_ensure_slots(prewarm_slots)


## FireRain.launched
func play(data: FireRainData, points: PackedVector3Array, landed: PackedByteArray) -> void:
	_data = data
	_points = points
	_landed = landed
	_clock = 0.0
	_reveal = 0.0
	_reveal_target = 0.0
	_heat = 0.0
	_heat_target = 0.0
	_scorch = 0.0
	_linger_clock = -1.0
	_ensure_slots(points.size())
	_impact_ages.resize(points.size())
	_impact_ages.fill(-1.0)
	var segment := data.line_length / points.size()
	var radius: float = minf(data.line_width * impact_radius_ratio, max_impact_radius)
	var flame_scale: float = clampf(minf(data.line_width, segment) * 0.60, 0.16, cluster_scale)
	var burst_scale: float = clampf(radius / 1.25, 0.25, 1.45)
	for index: int in points.size():
		_impacts[index].hide()
		_bolts[index].hide()
		_impacts[index].scale = Vector3(radius * 2.0, 1.0, radius * 2.0)
		var cluster: CPUParticles3D = _clusters[index]
		cluster.emission_box_extents = Vector3(minf(data.line_width * cluster_spread, cluster_max_spread),
			0.05, minf(segment * cluster_spread, cluster_max_spread))
		cluster.scale_amount_min = flame_scale * _cluster_template.scale_amount_min
		cluster.scale_amount_max = flame_scale * _cluster_template.scale_amount_max
		var tongue: CPUParticles3D = _tongues[index]
		tongue.emission_box_extents = cluster.emission_box_extents
		tongue.scale_amount_min = flame_scale * _tongue_template.scale_amount_min
		tongue.scale_amount_max = flame_scale * _tongue_template.scale_amount_max
		for burst: CPUParticles3D in [_sparks[index], _smokes[index], _blasts[index]]:
			burst.scale_amount_min = burst_scale * 0.76
			burst.scale_amount_max = burst_scale * 1.22
	# Cầu lửa lao tới từ phía điểm đầu (phía người gọi): đuôi chĩa lên trời, nghiêng về sau đường
	var back := global_basis.z.normalized()
	_trail_dir = (Vector3.UP * cos(deg_to_rad(fall_tilt_degrees)) + back * sin(deg_to_rad(fall_tilt_degrees))).normalized()
	_bolt_mat.set_shader_parameter(&"trail_dir", _trail_dir)
	_strip.scale = Vector3(data.line_width, 1.0, data.line_length)
	_strip.position = Vector3(0.0, lift, 0.0)
	_strip_mat.set_shader_parameter(&"size", Vector2(data.line_width, data.line_length))
	_strip_mat.set_shader_parameter(&"pool_count", float(points.size()))
	_push_strip()
	_strip.show()
	_embers.show()
	_embers.amount = clampi(roundi(data.line_width * data.line_length * embers_per_m2), ember_amount_range.x, ember_amount_range.y)
	_active = true
	set_process(true)


## FireRain.impacted
func impact(index: int, point: Vector3, landed: bool) -> void:
	if index >= _bolts.size():
		return
	_bolts[index].hide()
	# Dải hiện tới hết đoạn của quả này dù quả rơi vào chỗ không có sàn: đường lửa liền mạch
	_reveal_target = maxf(_reveal_target, _data.line_length * float(index + 1) / float(_points.size()))
	_fit_embers()
	if not landed:
		return
	var decal := _impacts[index]
	decal.global_position = point + Vector3.UP * lift * 2.0
	(decal.material_override as ShaderMaterial).set_shader_parameter(&"age", 0.0)
	decal.show()
	_impact_ages[index] = 0.0
	for burst: CPUParticles3D in [_sparks[index], _smokes[index], _blasts[index]]:
		burst.global_position = point + Vector3.UP * 0.15
		burst.show()
		burst.restart()
		burst.emitting = true
	if _data.burn_lifetime > 0.0:
		for flames: CPUParticles3D in [_clusters[index], _tongues[index]]:
			flames.global_position = point + Vector3.UP * 0.05
			flames.global_basis = global_basis
			flames.show()
			flames.restart()
			flames.emitting = true
	# Quả đầu tiên có sàn: dải bắt đầu cháy
	if _heat_target < 1.0 and _linger_clock < 0.0:
		_heat_target = 1.0 if _data.burn_lifetime > 0.0 else 0.0
		_embers.emitting = _data.burn_lifetime > 0.0


## FireRain.burn_started: chắc chắn dải hiện đủ
func burn_start() -> void:
	if _data:
		_reveal_target = _data.line_length
	_fit_embers()


## FireRain.burn_ended: tắt lửa, nguội thành vết xém rồi mờ dần trong linger
func burn_end() -> void:
	_heat_target = 0.0
	_scorch = 1.0
	_embers.emitting = false
	for index in _clusters.size():
		_clusters[index].emitting = false
		_tongues[index].emitting = false
	_linger_clock = 0.0


## FireRain.pool_released
func pool_released() -> void:
	_reset()


func _process(delta: float) -> void:
	if not _active:
		set_process(false)
		return
	_clock += delta
	var busy := false
	busy = _update_bolts() or busy
	busy = _update_impacts(delta) or busy
	_reveal = move_toward(_reveal, _reveal_target, _data.line_length * delta / maxf(_data.impact_spread_time * 0.5, 0.05))
	var heat_speed := 1.0 / (heat_in_time if _heat_target > _heat else heat_out_time)
	_heat = move_toward(_heat, _heat_target, heat_speed * delta)
	if _linger_clock >= 0.0:
		_linger_clock += delta
		_scorch = 1.0 - clampf(_linger_clock / maxf(_data.linger, 0.01), 0.0, 1.0)
	_push_strip()
	var strip_alive := _heat > 0.0 or _scorch > 0.0 or _linger_clock < 0.0
	if not busy and not strip_alive and not _embers.emitting:
		_strip.hide()
		_active = false
		set_process(false)


## Cầu lửa lao xuống theo trail_dir: hiện từ fall giây trước mốc chạm, nhanh dần (như bị ném xuống)
func _update_bolts() -> bool:
	var busy := false
	var fall := minf(fall_time, maxf(_data.first_impact_delay, 0.05))
	for index in _points.size():
		var bolt := _bolts[index]
		var t := (_clock - (_data.get_impact_time(index) - fall)) / fall
		if t < 0.0 or t >= 1.0 or _landed[index] == 0:
			if bolt.visible and t >= 1.0:
				bolt.hide()
			busy = busy or t < 0.0
			continue
		bolt.show()
		bolt.global_position = _points[index] + _trail_dir * (_data.drop_height * (1.0 - t * t)) + Vector3.UP * 0.3
		busy = true
	return busy


func _update_impacts(delta: float) -> bool:
	var busy := false
	for index in _impact_ages.size():
		var age := _impact_ages[index]
		if age < 0.0:
			continue
		age += delta / impact_life
		var decal := _impacts[index]
		if age >= 1.0:
			_impact_ages[index] = -1.0
			decal.hide()
			continue
		_impact_ages[index] = age
		(decal.material_override as ShaderMaterial).set_shader_parameter(&"age", age)
		busy = true
	for index in _sparks.size():
		busy = busy or _sparks[index].emitting or _smokes[index].emitting or _blasts[index].emitting \
			or _clusters[index].emitting or _tongues[index].emitting
	return busy


func _push_strip() -> void:
	_strip_mat.set_shader_parameter(&"reveal", _reveal)
	_strip_mat.set_shader_parameter(&"heat", _heat)
	_strip_mat.set_shader_parameter(&"scorch", _scorch)


## Tàn lửa chỉ bay trên phần dải đã cháy (từ điểm đầu tới quả vừa rơi)
func _fit_embers() -> void:
	var length := clampf(_reveal_target, 0.1, _data.line_length)
	# Trục -Z của FireRain là hướng đường; điểm đầu ở +Z nửa chiều dài
	_embers.position = Vector3(0.0, 0.1, _data.line_length * 0.5 - length * 0.5)
	_embers.emission_box_extents = Vector3(_data.line_width * 0.4, 0.05, length * 0.5)


## Đủ chỗ cho count quả: tạo thêm từ node mẫu (chỉ khi số quả lớn hơn mọi lần trước)
func _ensure_slots(count: int) -> void:
	while _bolts.size() < count:
		_bolts.append(_spawn(_bolt_template) as MeshInstance3D)
		var decal := _spawn(_impact_template) as MeshInstance3D
		# Mỗi vết nổ già đi riêng nên cần material riêng (tạo một lần, dùng lại mọi lần sau)
		var material := (_impact_template.material_override as ShaderMaterial).duplicate() as ShaderMaterial
		material.set_shader_parameter(&"seed", float(_impacts.size()) * 1.37)
		decal.material_override = material
		_impacts.append(decal)
		_sparks.append(_spawn(_spark_template) as CPUParticles3D)
		_smokes.append(_spawn(_smoke_template) as CPUParticles3D)
		_blasts.append(_spawn(_blast_template) as CPUParticles3D)
		_clusters.append(_spawn(_cluster_template) as CPUParticles3D)
		_tongues.append(_spawn(_tongue_template) as CPUParticles3D)


func _spawn(template: Node3D) -> Node3D:
	var copy := template.duplicate() as Node3D
	copy.top_level = true
	copy.hide()
	if copy is CPUParticles3D:
		(copy as CPUParticles3D).emitting = false
	add_child(copy)
	return copy


func _reset() -> void:
	_active = false
	_heat = 0.0
	_scorch = 0.0
	for bolt in _bolts:
		bolt.hide()
	for decal in _impacts:
		decal.hide()
	for group: Array[CPUParticles3D] in [_sparks, _smokes, _blasts, _clusters, _tongues]:
		for particles in group:
			particles.emitting = false
			particles.hide()
	_impact_ages.fill(-1.0)
	_embers.emitting = false
	_embers.hide()
	_strip.hide()
	set_process(false)
