extends Control


func _ready() -> void:
	GameState.progress_changed.connect(_refresh)
	GameState.progress_replaced.connect(_refresh)
	_refresh()


func _refresh() -> void:
	$SwordSlot.refresh()
	$BowSlot.refresh()
