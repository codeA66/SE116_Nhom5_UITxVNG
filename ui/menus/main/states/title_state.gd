extends MenuState
## Màn mở đầu: phím / nút tay cầm / chuột bất kỳ -> menu chính.


func enter(previous: StringName) -> void:
	menu.logo.set_layout(MenuLogo.Layout.TITLE, 0.0 if previous.is_empty() else menu.data.logo_move_time)
	menu.title_screen.show_screen(menu.data)


func exit() -> void:
	menu.title_screen.hide_screen(menu.data)


func handle_input(event: InputEvent) -> void:
	var pressed := (event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton) \
			and event.is_pressed() and not event.is_echo()
	if pressed:
		menu.play_sfx(MainMenu.Sfx.CONFIRM)
		state_machine.transition_to(HOME)
