class_name SpikeField
extends MultiMeshInstance3D
## Rải kín mũi chông trên mặt chữ nhật bằng một MultiMesh duy nhất (1 draw call).

@export_group("Bố cục")
@export var area_size: Vector2 = Vector2(38.8, 38.8)
@export_range(0.3, 4.0, 0.05) var spacing: float = 1.0
@export_range(0.0, 1.0, 0.01) var jitter: float = 0.18
@export_range(0.0, 25.0, 0.5) var max_tilt_degrees: float = 6.0
@export var seed_value: int = 1337

@export_group("Hình dáng chông")
@export_range(0.05, 1.0, 0.01) var spike_radius: float = 0.18
@export_range(0.2, 4.0, 0.05) var spike_height: float = 1.4
@export_range(0.0, 0.6, 0.02) var height_variation: float = 0.22
@export_range(3, 12, 1) var radial_segments: int = 6
@export var spike_material: Material


func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rebuild()


## Tạo lại lưới chông theo thông số xuất hiện tại.
func rebuild() -> void:
	var step: float = maxf(spacing, 0.2)
	var cols: int = maxi(int(floor(area_size.x / step)), 1)
	var rows: int = maxi(int(floor(area_size.y / step)), 1)
	var total: int = cols * rows

	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = spike_radius
	cone.height = spike_height
	cone.radial_segments = radial_segments
	cone.rings = 1
	cone.material = spike_material

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = cone
	mm.instance_count = total

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var half_x: float = area_size.x * 0.5
	var half_z: float = area_size.y * 0.5
	var start_x: float = -float(cols - 1) * step * 0.5
	var start_z: float = -float(rows - 1) * step * 0.5
	var max_tilt: float = deg_to_rad(max_tilt_degrees)
	var idx: int = 0

	for r: int in range(rows):
		for c: int in range(cols):
			var px: float = clampf(start_x + float(c) * step + rng.randf_range(-jitter, jitter), -half_x, half_x)
			var pz: float = clampf(start_z + float(r) * step + rng.randf_range(-jitter, jitter), -half_z, half_z)
			var h_scale: float = 1.0 + rng.randf_range(-height_variation, height_variation)
			var tilt_x: float = rng.randf_range(-max_tilt, max_tilt)
			var tilt_z: float = rng.randf_range(-max_tilt, max_tilt)
			var yaw: float = rng.randf_range(0.0, TAU)
			var spike_basis := Basis.from_euler(Vector3(tilt_x, yaw, tilt_z)).scaled(Vector3(1.0, h_scale, 1.0))
			# Giữ đáy mũi chông nằm ở mặt cục bộ y = 0 dù nghiêng hay co giãn
			var origin := Vector3(px, spike_height * h_scale * 0.5, pz)
			mm.set_instance_transform(idx, Transform3D(spike_basis, origin))
			idx += 1

	multimesh = mm
