extends MenuState
## Chọn hồ sơ: chọn ô -> vào game (ô trống = hành trình mới); Xóa -> hộp xác nhận; Esc -> menu chính.


func enter(previous: StringName) -> void:
	menu.profiles_screen.refresh(menu.data, menu.registry)
	menu.profiles_screen.set_interactive(true)
	if previous == CONFIRM_DELETE:
		# Hộp xác nhận chỉ phủ lên trên: màn hồ sơ vẫn đang hiện, chỉ trả focus về ô vừa thao tác
		menu.profiles_screen.get_slot_button(menu.pending_delete_slot).grab_focus.call_deferred()
	else:
		menu.logo.set_layout(MenuLogo.Layout.HIDDEN, menu.data.logo_move_time)
		menu.profiles_screen.show_screen(menu.data)
	_link(true)


func exit() -> void:
	_link(false)


func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		_on_back()


func _link(on: bool) -> void:
	link(menu.profiles_screen.slot_chosen, _on_slot_chosen, on)
	link(menu.profiles_screen.delete_requested, _on_delete_requested, on)
	link(menu.profiles_screen.back_pressed, _on_back, on)


func _on_slot_chosen(slot: int) -> void:
	_link(false)
	menu.start_profile(slot)


func _on_delete_requested(slot: int) -> void:
	menu.pending_delete_slot = slot
	menu.play_sfx(MainMenu.Sfx.CONFIRM)
	state_machine.transition_to(CONFIRM_DELETE)


func _on_back() -> void:
	menu.play_sfx(MainMenu.Sfx.BACK)
	menu.profiles_screen.hide_screen(menu.data)
	state_machine.transition_to(HOME)
