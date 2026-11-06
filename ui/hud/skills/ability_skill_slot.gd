@tool
class_name AbilitySkillSlot
extends SkillSlot
## Ô kỹ năng mở khóa (wind blast, ...): rỗng khi chưa có kỹ năng trong tiến trình.
signal acquire_pulse_requested(accent: Color)

## Trùng AbilityData.id của kỹ năng (vd. WindBlastData.ID = &"wind_blast")
@export var ability_id: StringName = &""
var acquisition_pending: bool = false

## Đăng ký target công khai thay vì buộc hiệu ứng biết cấu trúc riêng của HUD.
func _ready() -> void:
	super._ready()
	if not Engine.is_editor_hint(): add_to_group(&"ability_acquire_target")

## Trì hoãn icon mới tới lúc đường bay chạm ô, không thay trạng thái kỹ năng thật.
func set_acquisition_pending(pending: bool) -> void:
	acquisition_pending = pending
	refresh()

## HUD phát signal để lớp trình diễn vẽ glow ở đúng hệ tọa độ canvas.
func notify_acquired(accent: Color) -> void:
	acquire_pulse_requested.emit(accent)


## Icon tạm chờ đường bay, còn kỹ năng thật đã mở khóa tại cú bùng.
func is_available() -> bool:
	return GameState.has_ability(ability_id) and not acquisition_pending


## Cooldown vẫn do SkillSlot xử lý, việc nhận kỹ năng không tạo bộ đếm riêng.
func is_ready() -> bool:
	return true


## Player phát skill_cooldown_started cho mọi kỹ năng: chỉ nhận của kỹ năng ô này
func on_skill_cooldown(skill_id: StringName, duration: float) -> void:
	if skill_id == ability_id:
		start_cooldown(duration)
