class_name FerryFareService
extends NpcService
## Mỗi instance giữ một lượt gọi, để hai bến dùng cùng dịch vụ mà không dùng chung trạng thái.

signal activated

enum FareResult { PAID, INSUFFICIENT, ALREADY_CALLED, INVALID }

@export_group("Phí")
@export var currency: CurrencyData = preload("res://resources/player/currency/soul_jade.tres")
@export_range(0, 999, 1, "or_greater") var price: int = 3

@export_group("Bến")
## Phát tín hiệu khi đèn vừa được nâng tới đỉnh, kể cả khi hội thoại đã bị cắt ngang.
@export_range(0.0, 3.0, 0.01) var call_delay: float = 0.0
@export var call_animation: StringName = &"Call_Ferry"

@export_group("Hội thoại")
@export var question: String = "Gọi thuyền qua bến bên kia? Phí {price} {currency}."
@export var pay_option: String = "Trả {price}"
@export var decline_option: String = "Thôi"
@export var insufficient_line: String = "Cáo còn thiếu {missing} {currency}."
@export var approaching_line: String = "Thuyền đang tới. Chờ ở mép bến nhé."
@export var docked_line: String = "Thuyền đã cập bến. Lên boong là đi được."
@export var departed_line: String = "Thuyền đã rời bến rồi."
@export var unavailable_line: String = "Bến tạm ngừng nhận khách."
## Kể ngay sau khi gọi thuyền nếu người chơi chưa nghe đoạn này.
@export var after_call_story: Dialogue

var _called: bool = false
var _session: int = 0


## Tách kết quả giao dịch khỏi hội thoại để đường gọi chỉ có một nơi trừ tiền.
func try_pay_fare() -> FareResult:
	if _called:
		return FareResult.ALREADY_CALLED
	if currency == null or currency.id.is_empty() or price < 0:
		return FareResult.INVALID
	# Đánh dấu trước vì spend_currency phát signal đồng bộ cho các hệ thống khác.
	_called = true
	if not GameState.spend_currency(currency.id, price):
		_called = false
		return FareResult.INSUFFICIENT
	if call_delay > 0.0:
		create_tween().tween_callback(activated.emit).set_delay(call_delay)
	else:
		activated.emit()
	return FareResult.PAID


## Trạng thái của chuyến tồn tại lâu hơn phiên nói chuyện do NpcService quản lý.
func has_called() -> bool:
	return _called


## Nói lại sau khi trả chỉ đọc trạng thái thuyền, tránh hỏi hoặc trừ tiền lần hai.
func _on_open() -> void:
	_session += 1
	var session: int = _session
	if _called:
		await _say(_status_line(), session)
		return
	if _get_ferry() == null or currency == null:
		await _say(unavailable_line, session)
		return
	var choice: int = await npc.ask(_format(question), PackedStringArray([_format(pay_option), decline_option]))
	if session != _session:
		return
	if choice != 0:
		finish(choice == DialogueBox.RESULT_CANCELLED)
		return
	match try_pay_fare():
		FareResult.PAID:
			npc.play_animation(call_animation)
			await _say(_status_line(), session, after_call_story)
		FareResult.INSUFFICIENT:
			await _say(_format(insufficient_line), session)
		FareResult.ALREADY_CALLED:
			await _say(_status_line(), session)
		FareResult.INVALID:
			await _say(unavailable_line, session)


## Bỏ qua kết quả await cũ nếu Base NPC đã đóng phiên vì bị đánh hoặc chuyển trạng thái.
func _on_close() -> void:
	_session += 1


## Nối câu báo trạng thái với đoạn truyện, giữ hộp thoại nhận phím F suốt phiên.
func _say(text: String, session: int, story: Dialogue = null) -> void:
	var line := DialogueLine.new()
	line.text = text
	var lines: Array[DialogueLine] = [line]
	if story and not story.is_available(npc):
		story = null
	if story:
		lines.append_array(story.lines)
	var result: int = await npc.say(lines)
	if session == _session:
		if result == DialogueBox.RESULT_DONE and story:
			GameState.set_flag(story.flag_on_finish)
		finish(result == DialogueBox.RESULT_CANCELLED)


## Đọc FSM của thuyền để câu báo vẫn đúng khi người chơi nói giữa lúc cập bến.
func _status_line() -> String:
	var ferry: SkyFerry = _get_ferry()
	if ferry == null:
		return unavailable_line
	match ferry.state_machine.current_state.name:
		SkyFerryState.WAITING:
			return docked_line
		SkyFerryState.TRAVELLING, SkyFerryState.ARRIVED:
			return departed_line
	return approaching_line


## SkyFerry tự nối vào call_source khi vào cây. Dùng đúng mối nối đó để tránh gán hai tham chiếu có thể lệch nhau.
func _get_ferry() -> SkyFerry:
	for connection: Dictionary in activated.get_connections():
		var callback: Callable = connection["callable"]
		var ferry: SkyFerry = callback.get_object() as SkyFerry
		if ferry != null and ferry.call_source == self:
			return ferry
	return null


## Dùng tên tiền từ resource để hội thoại khớp tên trên HUD và túi đồ.
func _format(text: String) -> String:
	return text.format({
		"price": price,
		"currency": currency.display_name,
		"missing": maxi(price - GameState.get_currency(currency.id), 0),
	})

