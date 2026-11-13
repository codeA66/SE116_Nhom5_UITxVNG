extends MenuState
## Menu chính: Tiếp tục -> hồ sơ gần nhất, Bắt đầu -> hồ sơ, Cài đặt, Thoát. Esc quay về màn mở đầu.


func enter(previous: StringName) -> void:
	menu.logo.set_layout(MenuLogo.Layout.HOME, menu.data.logo_move_time)
	menu.home_screen.set_can_continue(SaveManager.get_continue_slot() > 0)
	var focus: Control = menu.home_screen.get_settings_button() if previous == SETTINGS else null
	menu.home_screen.show_screen(menu.data, focus)
	_link(true)


func exit() -> void:
	_link(false)
	menu.home_screen.hide_screen(menu.data)


func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		menu.play_sfx(MainMenu.Sfx.BACK)
		state_machine.transition_to(TITLE)


func _link(on: bool) -> void:
	link(menu.home_screen.continue_pressed, _on_continue, on)
	link(menu.home_screen.start_pressed, _on_start, on)
	link(menu.home_screen.settings_pressed, _on_settings, on)
	link(menu.home_screen.quit_pressed, _on_quit, on)


func _on_continue() -> void:
	var slot := SaveManager.get_continue_slot()
	if slot > 0:
		menu.start_profile(slot)


func _on_start() -> void:
	menu.play_sfx(MainMenu.Sfx.CONFIRM)
	state_machine.transition_to(PROFILES)


func _on_settings() -> void:
	menu.play_sfx(MainMenu.Sfx.CONFIRM)
	state_machine.transition_to(SETTINGS)


func _on_quit() -> void:
	menu.quit_game()
