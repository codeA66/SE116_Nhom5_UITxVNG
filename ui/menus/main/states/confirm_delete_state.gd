extends MenuState
## Hộp xác nhận xóa phủ lên màn hồ sơ. Có -> xóa ô; Không / Esc -> giữ nguyên.


func enter(_previous: StringName) -> void:
	menu.profiles_screen.set_interactive(false)
	menu.confirm_screen.setup(menu.pending_delete_slot, menu.data)
	menu.confirm_screen.show_screen(menu.data)
	_link(true)


func exit() -> void:
	_link(false)
	menu.confirm_screen.hide_screen(menu.data)


func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		_on_cancelled()


func _link(on: bool) -> void:
	link(menu.confirm_screen.confirmed, _on_confirmed, on)
	link(menu.confirm_screen.cancelled, _on_cancelled, on)


func _on_confirmed() -> void:
	SaveManager.delete_slot(menu.pending_delete_slot)
	menu.play_sfx(MainMenu.Sfx.DELETE)
	state_machine.transition_to(PROFILES)


func _on_cancelled() -> void:
	menu.play_sfx(MainMenu.Sfx.BACK)
	state_machine.transition_to(PROFILES)
