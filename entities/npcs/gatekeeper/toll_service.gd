class_name TollService
extends NpcService
## Thu tiền qua cổng: hỏi giá kèm lựa chọn Trả / Thôi. Đủ tiền -> trừ tiền, bật cờ (lưu), mở lối.
## Thiếu tiền vẫn hỏi (người chơi biết giá), bấm Trả thì bị từ chối. Trả một lần là mở mãi.
## Giá / tiền / cờ là của từng cổng: nhiều cổng trong một map không đụng nhau.

## Đã trả xong (cổng / cầu khác có thể nối thêm vào đây)
signal paid

@export var data: TollData
@export var currency: CurrencyData = preload("res://resources/player/currency/soul_jade.tres")
@export var price: int = 50
## Cờ lưu "đã trả" của RIÊNG cổng này, ví dụ "zone_1_wind.tier_2.toll". Trống = không lưu (chỉ để thử)
@export var paid_flag: StringName

var _paid_this_session: bool = false


func _ready() -> void:
	if paid_flag.is_empty():
		push_warning("%s: TollService chưa có paid_flag, trả tiền xong sẽ không được lưu" % get_path())


func is_available() -> bool:
	return not is_paid()


func is_paid() -> bool:
	return _paid_this_session or (not paid_flag.is_empty() and GameState.has_flag(paid_flag))


func _on_open() -> void:
	var keeper := npc as Gatekeeper
	var choice: int = await npc.ask(_format(data.question), PackedStringArray([_format(data.pay_option), _format(data.decline_option)]))
	if not is_active():
		return
	if choice == DialogueBox.RESULT_CANCELLED:
		finish(true)
		return
	if choice != 0:
		await _say(data.decline_lines)
		finish()
		return
	if not GameState.spend_currency(currency.id, maxi(price, 0)):
		if keeper:
			keeper.play_one_shot(data.refuse_animation)
		await _say(data.refuse_lines)
		finish()
		return
	_paid_this_session = true
	GameState.set_flag(paid_flag)
	paid.emit()
	if keeper:
		keeper.play_one_shot(data.accept_animation)
	await _say(data.thanks_lines, data.after_payment_story)
	if not is_active():
		return
	npc.close_dialogue()
	if keeper:
		await keeper.open_passage(true)
	finish()


func _say(lines: Array[DialogueLine], story: Dialogue = null) -> void:
	if not is_active():
		return
	var formatted: Array[DialogueLine] = []
	for line: DialogueLine in lines:
		if line == null:
			continue
		var copy := DialogueLine.new()
		copy.speaker = line.speaker
		copy.text = _format(line.text)
		formatted.append(copy)
	if story and not story.is_available(npc):
		story = null
	if story:
		formatted.append_array(story.lines)
	if formatted.is_empty():
		return
	var result: int = await npc.say(formatted)
	if is_active() and story and result == DialogueBox.RESULT_DONE:
		GameState.set_flag(story.flag_on_finish)


func _format(text: String) -> String:
	var name_text := currency.display_name if currency else ""
	var have := GameState.get_currency(currency.id) if currency else 0
	return tr(text).format({"price": price, "currency": name_text, "have": have})
