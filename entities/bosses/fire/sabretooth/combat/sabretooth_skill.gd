class_name SabretoothSkill
extends FireBossStrike
## Thời gian gốc phục vụ xem clip, thời gian kéo dài phục vụ trình diễn đòn của AI.

@export var title: String
@export var anticipation: Vector2
@export_range(0.0, 1.5, 0.01) var anticipation_extra: float = 0.35
@export var second_anticipation: Vector2
@export_range(0.0, 1.5, 0.01) var second_anticipation_extra: float = 0.0
@export_range(0.0, 0.6, 0.01) var aim_lock_before_active: float = 0.18
@export_range(-90.0, 90.0, 1.0) var aim_offset_degrees: float = 0.0
@export var lunge_window: Vector2
@export_range(0.0, 3.0, 0.01) var recovery_time: float = 0.55
@export var follow_bones: Array[StringName] = []
@export var second_follow_bones: Array[StringName] = []
@export var phase_one_only: bool = false
@export var phase_two_only: bool = false
@export var flight_window: Vector2
@export var follow_authored_yaw: bool = true

var runtime_clip: StringName
var flight_extra: float = 0.0


func retime(source_time: float) -> float:
	var length := anticipation.y - anticipation.x
	var extra := anticipation_extra * clampf((source_time - anticipation.x) / length, 0.0, 1.0) if length > 0.0 else 0.0
	var second_length := second_anticipation.y - second_anticipation.x
	if second_length > 0.0:
		extra += second_anticipation_extra * clampf((source_time - second_anticipation.x) / second_length, 0.0, 1.0)
	var flight_length := flight_window.y - flight_window.x
	if flight_length > 0.0:
		extra += flight_extra * clampf((source_time - flight_window.x) / flight_length, 0.0, 1.0)
	return source_time + extra


func set_flight_duration(seconds: float) -> void:
	flight_extra = maxf(0.0, seconds - (flight_window.y - flight_window.x))


func ai_hit_window_at(time: float) -> Vector2:
	var first := Vector2(retime(active_start), retime(active_end))
	if time >= first.x and time < first.y:
		return first
	if second_hit.y > second_hit.x:
		var second := Vector2(retime(second_hit.x), retime(second_hit.y))
		if time >= second.x and time < second.y:
			return second
	return Vector2.ZERO
