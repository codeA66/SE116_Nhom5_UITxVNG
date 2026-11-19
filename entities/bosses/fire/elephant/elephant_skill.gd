class_name ElephantSkill
extends FireBossStrike

enum Kind { RAIN, SWEEP, STOMP, CHARGE }

@export var kind: Kind
@export var title: String
@export var followup: StringName
@export var windups: Array[Vector2]
@export_range(0.1, 1.0, 0.05) var windup_speed: float = 0.65
@export var cast_frame: float = 0.55
@export var followup_duration: float = 4.0
@export var run_lead_time: float = 2.0
@export var first_hold_frame: float = 0.0
@export var first_hold_duration: float = 0.0
@export var effect_radius: float = 4.5
