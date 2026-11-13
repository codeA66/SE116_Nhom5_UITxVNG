class_name WindTornadoVfx
extends Node3D
## Hình của Lốc xoáy: cột lốc cao gồm dải gió xoắn + các vòng xoáy theo tầng + vệt bụi bay quanh,
## mặt đất có vòng hút và nhánh xoắn trôi vào tâm; lúc nổ cột co lại rồi bung vòng sóng xung kích + chớp sáng.
## Node con của WindTornado nên tự đi theo lốc. Mesh dựng một lần, dùng chung cho mọi lốc trong pool.
## Nghe launched -> play(), burst -> collapse(); WindTornado gọi pool_released() khi trả về pool.

const MIN_RADIUS := 0.001

@export_group("Column")
## Chiều cao cột = bán kính hút * hệ số này, kẹp trong [min_height, max_height] để lốc nhỏ vẫn thấy, lốc lớn không cao quá màn
@export var height_per_radius: float = 1.0
@export var min_height: float = 1.4
@export var max_height: float = 4.5
@export var top_radius_ratio: float = 0.42
@export var min_top_radius: float = 0.35
@export var max_top_radius: float = 2.2
## Tốc độ xoay cơ bản (rad/s); mỗi lớp dải nhân thêm hệ số riêng
@export var spin_speed: float = 7.0
@export var wobble: float = 0.06

@export_group("Timing")
@export var spin_up_time: float = 0.18
## Cột co lại trước khi bung nổ
@export var collapse_time: float = 0.1
@export var shock_time: float = 0.42
@export var flash_time: float = 0.18
## Lúc nổ, thân lốc bung ra tới bấy nhiêu lần bán kính miệng rồi tan (nhìn như gió văng ra)
@export var explode_spread: float = 2.4

static var _strand_mesh: ArrayMesh
static var _ring_mesh: ArrayMesh
static var _debris_mesh: ArrayMesh

var _age: float = 0.0
## < 0 = chưa nổ
var _burst_age: float = -1.0
var _end_time: float = 0.0
var _height: float = 1.0
var _top_radius: float = 1.0
var _materials: Array[ShaderMaterial] = []

@onready var _funnel: Node3D = $Funnel
@onready var _strands: MeshInstance3D = $Funnel/Strands
@onready var _rings: MeshInstance3D = $Funnel/Rings
@onready var _debris: MeshInstance3D = $Funnel/Debris
@onready var _ground: MeshInstance3D = $Ground
@onready var _flash: MeshInstance3D = $Flash
@onready var _ground_material: ShaderMaterial = _ground.material_override
@onready var _flash_material: ShaderMaterial = _flash.material_override
@onready var _loop_audio: AudioStreamPlayer3D = $LoopAudio
@onready var _burst_audio: AudioStreamPlayer3D = $BurstAudio


func _ready() -> void:
	_build_meshes()
	_strands.mesh = _strand_mesh
	_rings.mesh = _ring_mesh
	_debris.mesh = _debris_mesh
	for visual: MeshInstance3D in [_strands, _rings, _debris]:
		var material := visual.material_override as ShaderMaterial
		material.set_shader_parameter(&"spin", spin_speed)
		material.set_shader_parameter(&"wobble", wobble)
		_materials.append(material)
		# Mesh xoay trong shader nên AABB phải bao cả vòng quay + độ lắc
		visual.custom_aabb = AABB(Vector3(-1.4, -0.1, -1.4), Vector3(2.8, 1.3, 2.8))
	pool_released()


func play(data: WindTornadoData) -> void:
	pool_released()
	var pull := maxf(data.pull_radius, MIN_RADIUS)
	var blast := maxf(data.burst_radius, MIN_RADIUS)
	_height = clampf(pull * height_per_radius, min_height, max_height)
	_top_radius = clampf(pull * top_radius_ratio, min_top_radius, max_top_radius)
	# Hiệu ứng nổ phải tắt trước khi lốc trả về pool
	_end_time = minf(collapse_time + shock_time, maxf(data.linger * 0.95, 0.05))
	var extent := maxf(pull, blast) * 1.1 + 0.3
	_ground.scale = Vector3(extent, 1.0, extent)
	_ground_material.set_shader_parameter(&"extent", extent)
	_ground_material.set_shader_parameter(&"pull_radius", pull)
	_ground_material.set_shader_parameter(&"burst_radius", blast)
	_flash.scale = Vector3.ONE * clampf(blast * 0.9, 0.6, 4.0)
	_flash.position.y = _height * 0.35
	visible = true
	_apply(0.0)
	set_process(true)
	if _loop_audio.stream:
		_loop_audio.play()


func collapse(_at: Vector3) -> void:
	if not visible:
		return
	_burst_age = 0.0
	_loop_audio.stop()
	if _burst_audio.stream:
		_burst_audio.play()


func pool_released() -> void:
	visible = false
	set_process(false)
	_age = 0.0
	_burst_age = -1.0
	if is_node_ready():
		_loop_audio.stop()
		_burst_audio.stop()
		_apply(0.0)


func _process(delta: float) -> void:
	_age += delta
	if _burst_age >= 0.0:
		_burst_age += delta
		if _burst_age >= _end_time:
			visible = false
			set_process(false)
			return
	_apply(delta)


func _apply(_delta: float) -> void:
	var rise := smoothstep(0.0, spin_up_time, _age)
	var squeeze := 0.0
	var shock := -1.0
	var flash := 0.0
	if _burst_age >= 0.0:
		squeeze = clampf(_burst_age / maxf(collapse_time, 0.001), 0.0, 1.0)
		var after := _burst_age - collapse_time * 0.6
		if after >= 0.0:
			shock = clampf(after / maxf(shock_time, 0.001), 0.0, 1.0)
			flash = 1.0 - clampf(after / maxf(flash_time, 0.001), 0.0, 1.0)
	# Mọc từ đất lên lúc thả, co thắt về tâm trước khi nổ
	# Sau khi co lại: thân bung ngang, thấp xuống và tan
	var blow := clampf(shock / 0.75, 0.0, 1.0) if shock >= 0.0 else 0.0
	var radius_k := lerpf(0.45, 1.0, rise) * lerpf(1.0, 0.35, squeeze) * lerpf(1.0, explode_spread / 0.35, blow)
	var height_k := lerpf(0.2, 1.0, rise) * lerpf(1.0, 0.6, squeeze) * lerpf(1.0, 0.35, blow)
	_funnel.scale = Vector3(_top_radius * radius_k, maxf(_height * height_k, 0.001), _top_radius * radius_k)
	_funnel.visible = blow < 1.0
	var column_alpha := rise * (1.0 - blow * blow)
	for material in _materials:
		material.set_shader_parameter(&"time", _age)
		material.set_shader_parameter(&"alpha", column_alpha)
	_ground_material.set_shader_parameter(&"time", _age)
	_ground_material.set_shader_parameter(&"intensity", rise * (1.0 - squeeze))
	_ground_material.set_shader_parameter(&"shock", shock)
	_flash.visible = flash > 0.0
	_flash_material.set_shader_parameter(&"strength", flash)


## Dựng mesh một lần cho mọi lốc (dữ liệu tĩnh): không gian đơn vị cao 1, bán kính miệng 1
static func _build_meshes() -> void:
	if _strand_mesh:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# Dải xoắn chính: từ chân hẹp xoắn lên miệng rộng
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var strand_count := 5
	for i in strand_count:
		var offset := float(i) / float(strand_count)
		_add_strand(st, 1.15, 0.0, 1.0, 0.12, 0.3, false, offset, rng.randf(), rng.randf_range(0.9, 1.15), 48)
	_strand_mesh = st.commit()
	# Vòng xoáy theo tầng: cung dẹt nằm ngang, xoay nhanh hơn thân
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for y: float in [0.2, 0.42, 0.64, 0.84, 0.98]:
		_add_strand(st, 0.72, y, y, 0.07, 0.09, true, rng.randf(), rng.randf(), rng.randf_range(1.5, 2.0), 32, 1.12)
	_ring_mesh = st.commit()
	# Vệt bụi ngắn bay quanh ngoài thân
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 12:
		var y0 := rng.randf_range(0.05, 0.8)
		_add_strand(st, 0.22, y0, y0 + rng.randf_range(0.08, 0.18), 0.025, 0.035, false, rng.randf(), rng.randf(), rng.randf_range(1.2, 1.5), 10, rng.randf_range(1.25, 1.45))
	_debris_mesh = st.commit()


## Bán kính phễu theo độ cao (0..1): chân hẹp, loe dần lên miệng
static func _funnel_radius(y: float) -> float:
	return 0.16 + 0.84 * pow(clampf(y, 0.0, 1.0), 1.3)


## Một dải xoắn quanh trục Y. radial_band = dải nằm ngang (bề rộng theo bán kính) thay vì đứng.
## COLOR.r = pha nét, COLOR.g = hệ số tốc độ xoay (shader đọc)
static func _add_strand(st: SurfaceTool, turns: float, y0: float, y1: float, w0: float, w1: float, radial_band: bool,
		offset: float, phase: float, speed: float, segments: int, radius_scale: float = 1.0) -> void:
	var color := Color(phase, speed, 0.0, 1.0)
	var previous_a := Vector3.ZERO
	var previous_b := Vector3.ZERO
	for i in segments + 1:
		var t := float(i) / float(segments)
		var y := lerpf(y0, y1, t)
		var angle := (offset + t * turns) * TAU
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		var center := direction * _funnel_radius(y) * radius_scale + Vector3.UP * y
		var spread := (direction if radial_band else Vector3.UP) * lerpf(w0, w1, t) * 0.5
		var a := center - spread
		var b := center + spread
		if i > 0:
			var t0 := float(i - 1) / float(segments)
			for vertex: Array in [[previous_a, t0, 0.0], [previous_b, t0, 1.0], [a, t, 0.0], [previous_b, t0, 1.0], [b, t, 1.0], [a, t, 0.0]]:
				st.set_color(color)
				st.set_uv(Vector2(vertex[1], vertex[2]))
				st.add_vertex(vertex[0])
		previous_a = a
		previous_b = b
