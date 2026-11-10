extends NpcService
## Service thử trong sân Lửa: hỏi kèm lựa chọn (khung mà gác cổng / cửa hàng sẽ dùng để xác nhận trả tiền).
## Chỉ để thử NPC dùng chung, không phải service thật của game.

@export var question: String = "(Chữ tạm) Ngươi muốn nghe thêm chuyện không?"
@export var options: PackedStringArray = PackedStringArray(["Có", "Không"])
## Câu đáp cho từng lựa chọn (cùng thứ tự với options)
@export var replies: Array[DialogueLine] = []

## Lựa chọn cuối cùng (test đọc lại); -1 = thoát
var last_choice: int = -2


func _on_open() -> void:
	var choice: int = await npc.ask(question, options)
	last_choice = choice
	if not is_active():
		return
	if choice == DialogueBox.RESULT_CANCELLED:
		finish(true)
		return
	if choice >= 0 and choice < replies.size() and replies[choice] != null:
		var reply: Array[DialogueLine] = [replies[choice]]
		await npc.say(reply)
	finish()
