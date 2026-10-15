class_name InteractableComponent
extends Area3D
## Gắn vào vật tương tác được (vũ khí, rương, cửa, NPC...).
## InteractorComponent chọn vật gần nhất thì hiện gợi ý; người chơi bấm interact thì phát signal.

signal interacted(interactor: Node3D)

@export var prompt_text: String = "[E] Tương tác"
## Node hiển thị gợi ý, có thể để trống
@export var prompt: Label3D

var enabled: bool = true


func _ready() -> void:
	monitoring = false
	monitorable = true
	if prompt:
		prompt.text = prompt_text
	set_focused(false)


func set_prompt_text(text: String) -> void:
	prompt_text = text
	if prompt:
		prompt.text = text


func set_focused(focused: bool) -> void:
	if prompt:
		prompt.visible = focused and enabled


func interact(interactor: Node3D) -> void:
	if not enabled:
		return
	interacted.emit(interactor)
