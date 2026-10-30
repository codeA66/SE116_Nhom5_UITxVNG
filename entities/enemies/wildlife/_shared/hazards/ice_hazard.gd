extends EnemyHazard
## Hitbox theo các hàng tinh thể thật, cùng nhịp mọc và vỡ với shader.
const SECTION_COUNT: int = 11
@export var collision_padding: float = 0.12
var _sections: Array[CollisionShape3D] = []
var _bounds: Array[AABB] = []
var _births: Array[float] = []
var _deaths: Array[float] = []
var _settled: Array[bool] = []
var _growth_time: float = 0.5

func _ready() -> void:
	_build_sections()
	super()

func pool_released() -> void:
	super()
	_settled.fill(false)
	for section: CollisionShape3D in _sections: section.set_deferred(&"disabled", true)

func _build_sections() -> void:
	var config: Resource = visual.get(&"style") as Resource
	_growth_time = maxf(float(config.get(&"growth_time")), 0.001)
	var path_length: float = float(config.get(&"path_length")) * absf(visual.scale.x)
	var shatter_time: float = float(config.get(&"shatter_time"))
	var batches: Dictionary = visual.get(&"batch_data") as Dictionary
	var mesh: ArrayMesh = visual.get(&"crystal_mesh") as ArrayMesh
	var crystal_bounds: AABB = mesh.get_aabb()
	_bounds.resize(SECTION_COUNT); _births.resize(SECTION_COUNT); _deaths.resize(SECTION_COUNT)
	_settled.resize(SECTION_COUNT); _settled.fill(false)
	var populated: Array[bool] = []; populated.resize(SECTION_COUNT); populated.fill(false)
	_births.fill(INF)
	# Cả tinh thể phụ và cụm peak đều góp vào kích thước; không dùng hộp ước lượng.
	for layer: String in ["CrystalCore", "SecondaryShards"]:
		var instances: Array = batches[layer]
		for entry: Dictionary in instances:
			var u: float = (entry["data"] as Color).b
			var index: int = clampi(roundi(u * (SECTION_COUNT - 1)), 0, SECTION_COUNT - 1)
			var transform_value: Transform3D = visual.transform * (entry["transform"] as Transform3D)
			var box: AABB = transform_value * crystal_bounds
			_bounds[index] = _bounds[index].merge(box) if populated[index] else box
			populated[index] = true
			_births[index] = minf(_births[index], u * _growth_time)
			_deaths[index] = maxf(_deaths[index], shatter_time + u * 0.12 + 0.16)
	for index: int in SECTION_COUNT:
		assert(populated[index])
		var box: AABB = _bounds[index].grow(maxf(collision_padding, 0.0))
		# Nối khe giữa hai hàng, giữ hitbox liên tục dọc đường băng đã mọc.
		var near_z: float = minf(box.position.z, maxf(0.0, (float(index) - 0.5) / (SECTION_COUNT - 1) * path_length))
		var far_z: float = maxf(box.end.z, (float(index) + 0.5) / (SECTION_COUNT - 1) * path_length)
		box = AABB(Vector3(box.position.x, 0.0, near_z), Vector3(box.size.x, maxf(box.end.y, 0.2), far_z - near_z))
		_bounds[index] = box
		var section: CollisionShape3D = _shape if index == 0 else CollisionShape3D.new()
		section.shape = BoxShape3D.new()
		section.disabled = true
		if index > 0: hitbox.add_child(section)
		_sections.append(section)
	active_end = _deaths.max()

func _update_hitbox() -> void:
	for index: int in _sections.size():
		var section: CollisionShape3D = _sections[index]
		if age >= _deaths[index] or age <= _births[index]:
			if not section.disabled: section.disabled = true
			continue
		if _settled[index]: continue
		var growth: float = smoothstep(_births[index], _births[index] + 0.15, age)
		section.disabled = growth <= 0.02 or age >= _deaths[index]
		if section.disabled: continue
		var box: AABB = _bounds[index]
		var size_value: Vector3 = box.size * Vector3(pow(growth, 0.6), growth, pow(growth, 0.6))
		(section.shape as BoxShape3D).size = size_value
		section.position = Vector3(box.get_center().x, size_value.y * 0.5, box.get_center().z)
		_settled[index] = is_equal_approx(growth, 1.0)
