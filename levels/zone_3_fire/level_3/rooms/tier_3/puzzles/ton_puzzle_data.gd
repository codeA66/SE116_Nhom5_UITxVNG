class_name TonPuzzleData
extends Resource
## Nhịp và ngưỡng của một lượt mang lửa.

@export_group("Wind")
@export_range(0.1, 15.0, 0.1) var calm_time: float = 1.8
@export_range(0.1, 15.0, 0.1) var gust_time: float = 4.2
@export_range(0.0, 3.0, 0.05) var gust_warning: float = 0.45
@export_group("Flame")
@export_range(0.05, 15.0, 0.05) var exposure_limit: float = 1.6
@export_range(0.0, 1.0, 0.05) var warning_ratio: float = 0.45
@export_range(0.01, 8.0, 0.05) var exposure_recovery: float = 0.65
@export_range(0.05, 10.0, 0.05) var ember_rest_time: float = 1.0
@export_range(0.01, 0.3, 0.01) var ember_intensity: float = 0.06
@export var ember_color: Color = Color(1.0, 0.13, 0.04)
@export var flame_palette: GradientTexture1D


func apply_flame_palette(feedback: FlameFeedback) -> void:
	if flame_palette == null:
		return
	# FlameFeedback đã tạo material riêng cho từng hệ hạt khi vào cây.
	for path: NodePath in [^"Flame", ^"RisingEmbers"]:
		var particles: GPUParticles3D = feedback.get_node(path)
		var material: ParticleProcessMaterial = particles.process_material
		material.color_ramp = flame_palette
