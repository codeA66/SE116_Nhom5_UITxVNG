class_name CharmGiftService
extends NpcService
## Tặng player một bùa sau đoạn thoại (một lần). Đã tặng thì không mở nữa, NPC chỉ nói chuyện.
## Gắn làm con của Npc; NPC khác muốn tặng bùa chỉ cần gắn service này và đổi charm / gift_flag.
## give_directly tắt: chỉ bật gift_flag, bùa rơi ra đất qua FlagReveal(gift_flag) chứa CharmPickup đặt sẵn trong map.

## Đã tặng bùa (charm, gift_flag)
signal gifted(charm: CharmData)

@export var charm: CharmData
## Cờ lưu đã tặng. Lời thoại sau đó chọn theo cờ này (FlagCondition)
@export var gift_flag: StringName
## Bật: cộng thẳng bùa vào túi. Tắt: chỉ bật gift_flag để bùa rơi ra đất (người chơi đi tới nhặt)
@export var give_directly: bool = true
## Câu nói lúc trao bùa ({charm} = tên bùa). Để trống = trao im lặng
@export_multiline var gift_line: String = "Cầm lấy {charm}."


func is_available() -> bool:
	return charm != null and not _already_gifted()


func _on_open() -> void:
	if give_directly:
		GameState.add_charm(charm)
	GameState.set_flag(gift_flag)
	gifted.emit(charm)
	if gift_line.is_empty():
		finish()
		return
	var line := DialogueLine.new()
	line.text = gift_line.format({"charm": charm.display_name})
	var lines: Array[DialogueLine] = [line]
	var result: int = await npc.say(lines)
	finish(result == DialogueBox.RESULT_CANCELLED)


func _already_gifted() -> bool:
	if not gift_flag.is_empty() and GameState.has_flag(gift_flag):
		return true
	# Bùa rơi ra đất: vẫn tặng (cho rơi) dù đã có sẵn, để người chơi thấy rõ
	return give_directly and GameState.owns_charm(charm.id)
