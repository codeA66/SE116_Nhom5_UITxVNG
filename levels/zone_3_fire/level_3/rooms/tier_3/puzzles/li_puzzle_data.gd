class_name LiPuzzleData
extends Resource
## Cấu hình câu đố Ly, dùng chung cho gương, tia và khóa nung.

@export_group("Tia lửa")
@export_range(0.1, 300.0, 0.1) var beam_distance: float = 60.0
@export_range(1, 32, 1) var max_reflections: int = 8
@export_range(0.005, 0.5, 0.005) var beam_radius: float = 0.045
@export_range(0.001, 0.2, 0.001) var surface_offset: float = 0.02
@export_flags_3d_physics var collision_mask: int = 1
@export var beam_color: Color = Color(1.0, 0.3, 0.035)
@export_range(0.0, 8.0, 0.1) var beam_emission: float = 2.0

@export_group("Gương")
## Mỗi đích có một hướng chuẩn và các hướng lệch để người chơi thử.
@export var angle_offsets: PackedFloat32Array = PackedFloat32Array([-45.0, 0.0, 45.0, 90.0])
@export var initial_steps: PackedInt32Array = PackedInt32Array([0, 0, 0])
@export_range(1, 16, 1) var mirror_step_count: int = 4
@export_range(0.05, 2.0, 0.05) var mirror_turn_time: float = 0.35

@export_group("Chuyển lượt")
@export_range(0.1, 5.0, 0.05) var stage_transition_time: float = 0.8
@export_range(3.0, 15.0, 0.1) var stage_sink_depth: float = 5.0

@export_group("Phản hồi cửa")
@export var gate_locked_color: Color = Color(1.0, 0.025, 0.01)
@export_range(0.1, 5.0, 0.05) var gate_pulse_period: float = 1.2
@export_range(0.0, 8.0, 0.05) var gate_pulse_min_energy: float = 0.15
@export_range(0.0, 8.0, 0.05) var gate_pulse_max_energy: float = 1.8
@export_range(0.0, 1.0, 0.05) var gate_plate_glow_scale: float = 0.35

@export_group("Nung khóa")
@export_range(0.05, 15.0, 0.05) var melt_time: float = 2.0
@export var cold_color: Color = Color(0.19, 0.075, 0.075)
@export var hot_color: Color = Color(1.0, 0.55, 0.08)
@export_range(0.0, 8.0, 0.1) var heat_emission: float = 2.0

@export_group("Tiến độ")
@export var tutorial_flag: StringName = &"level_3.t3_ly_tutorial"
@export var completed_flag: StringName = &"level_3.t3_seal_ly"
## Cờ các lượt trung gian; lượt cuối dùng completed_flag để liên kết với trung tâm.
@export var stage_flags: PackedStringArray = PackedStringArray(["level_3.t3_ly_pedestal"])
@export var seal_id: StringName = &"ly"
