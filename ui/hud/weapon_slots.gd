extends HBoxContainer


func _ready() -> void:
	GameState.progress_changed.connect(_refresh)
	GameState.progress_replaced.connect(_refresh)
	$BindingRefresh.timeout.connect(_refresh_bindings)
	_refresh()


func _refresh() -> void:
	$SwordSlot.refresh()
	$BowSlot.refresh()
	visible = $SwordSlot.owned or $BowSlot.owned


func _refresh_bindings() -> void:
	# InputMap không phát signal khi action_add_event/action_erase_events được gọi.
	# Chỉ kiểm tra 4 lần/giây khi HUD đang hiện, không dựng lại ô mỗi frame.
	if is_visible_in_tree():
		$SwordSlot.refresh_binding()
		$BowSlot.refresh_binding()
