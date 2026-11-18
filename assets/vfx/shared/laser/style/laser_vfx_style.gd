class_name LaserVfxStyle
extends Resource
## Giữ vật liệu và thông số hình ảnh dùng chung cho các tượng có cùng kiểu tia.

@export_group("Vật liệu")
@export var beam_material: ShaderMaterial
@export var flare_material: ShaderMaterial
@export var spark_material: ShaderMaterial
@export var charge_motion: ShaderMaterial
@export var muzzle_burst_motion: ParticleProcessMaterial
@export var impact_burst_motion: ParticleProcessMaterial
@export var impact_spark_motion: ParticleProcessMaterial

@export_group("Tia")
@export_range(0.1, 5.0, 0.01) var beam_width_scale: float = 2.05
@export_range(0.1, 1.0, 0.01) var warn_width_ratio: float = 0.32
@export_range(0.01, 0.5, 0.01, "suffix:s") var shutdown_time: float = 0.1
@export var warn_curve: Curve

@export_group("Lóe")
@export_range(0.01, 0.5, 0.01, "suffix:s") var flash_time: float = 0.1
@export_range(0.1, 2.0, 0.01, "suffix:m") var muzzle_flare_size: float = 0.56
@export_range(0.1, 2.0, 0.01, "suffix:m") var impact_flare_size: float = 0.72
@export_range(0.0, 1.0, 0.01) var muzzle_glow: float = 0.12
@export_range(0.0, 1.0, 0.01) var impact_glow: float = 0.39
@export_range(0.0, 1.5, 0.01) var flash_strength: float = 0.96
@export_range(0.01, 0.25, 0.005, "suffix:m") var face_offset: float = 0.07

@export_group("Hạt")
@export_range(1, 12) var charge_amount: int = 10
@export_range(1, 12) var muzzle_burst_amount: int = 6
@export_range(1, 12) var impact_burst_amount: int = 9
@export_range(1, 12) var impact_spark_amount: int = 10
@export_range(0.05, 0.5, 0.01, "suffix:s") var charge_lifetime: float = 0.24
@export_range(0.05, 0.5, 0.01, "suffix:s") var muzzle_burst_lifetime: float = 0.18
@export_range(0.05, 0.5, 0.01, "suffix:s") var impact_burst_lifetime: float = 0.24
@export_range(0.05, 0.5, 0.01, "suffix:s") var impact_spark_lifetime: float = 0.23
