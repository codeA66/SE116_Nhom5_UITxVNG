extends WildSkillAttack
## Cửa sổ hitbox và VFX cùng bắt đầu ở đúng nhịp quét tay của clip.
var _combo: ClawComboSkillData
var _window: int = 0
var _opened: bool = false

func enter(previous: StringName) -> void:
	super(previous)
	_combo = _skill as ClawComboSkillData
	assert(_combo != null)
	_window = 0
	_opened = false

func _update_melee(_previous: float) -> void:
	if not _skill.melee_enabled: return
	while _window < _combo.hit_windows.size():
		var span: Vector2 = _combo.hit_windows[_window]
		if _elapsed >= span.y:
			_actor.hitbox.deactivate()
			_window += 1
			_opened = false
			continue
		if _elapsed >= span.x and not _opened:
			_opened = true
			_actor.hitbox.activate(_skill, (span.y-span.x)/_speed_scale)
		return
