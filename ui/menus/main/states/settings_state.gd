extends MenuState
## Khung cài đặt (chưa có nội dung). Quay lại / Esc -> menu chính.


func enter(_previous: StringName) -> void:
	menu.logo.set_layout(MenuLogo.Layout.HIDDEN, menu.data.logo_move_time)
	menu.settings_screen.show_screen(menu.data)
	link(menu.settings_screen.back_pressed, _on_back, true)


func exit() -> void:
	link(menu.settings_screen.back_pressed, _on_back, false)
	menu.settings_screen.hide_screen(menu.data)


func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		_on_back()


func _on_back() -> void:
	menu.play_sfx(MainMenu.Sfx.BACK)
	state_machine.transition_to(HOME)
