class_name Npc
extends CharacterBody3D
## NPC dùng chung: đứng một chỗ, quay về phía cáo khi lại gần, bấm tương tác để nói chuyện,
## nói xong mở dịch vụ (NpcService con: nâng cấp, bán bùa, thu tiền qua cổng...).
## Hành vi chạy bằng FSM node (Idle / Talk / Serve). Lời thoại là Resource (Dialogue), chọn theo context + điều kiện.
## Hộp thoại chỉ được tạo lần đầu nói chuyện, mỗi NPC một hộp: nhiều NPC trong một map không đụng nhau,
## không phải sửa player.tscn. Chỉ chạy _physics_process khi cần quay mặt.

## Người chơi bấm nói chuyện (state Idle nhận và chuyển sang Talk)
signal talk_requested(player: Player)
signal conversation_started(player: Player)
signal conversation_ended(player: Player)
## Cáo vào / ra vùng nhìn (null = đã ra)
signal look_target_changed(target: Player)

const CONTEXT_GREETING: StringName = &"greeting"
const CONTEXT_FAREWELL: StringName = &"farewell"

@export var display_name: String = "NPC"
@export var dialogues: Array[Dialogue] = []

@export_group("Tương tác")
@export var talk_prompt: String = "NÓI CHUYỆN"
## Cáo quay mặt về NPC khi bắt đầu nói chuyện
@export var player_faces_npc: bool = true
## Game không dừng khi nói chuyện: cáo bị đánh thì cắt ngang, trả điều khiển ngay
@export var end_on_player_damaged: bool = true
## State về khi bị cắt ngang
@export var interrupt_state: StringName = &"Idle"

@export_group("Quay mặt")
## Quay về phía cáo khi cáo đứng trong vùng nhìn (LookArea)
@export var look_at_player: bool = true
## Tốc độ quay model (càng lớn càng nhanh)
@export var turn_speed: float = 6.0
## Lệch dưới góc này (độ) thì coi như đã quay xong, ngừng xử lý cho đỡ tốn
@export var facing_tolerance_degrees: float = 1.0

@export_group("Hoạt ảnh")
## Để trống nếu model chưa có hoạt ảnh
@export var animation_player: AnimationPlayer
@export var idle_animation: StringName
@export var talk_animation: StringName
## Model nảy nhẹ mỗi câu thoại (tỉ lệ phóng thêm); 0 = tắt
@export_range(0.0, 0.5, 0.01) var talk_bounce: float = 0.06
@export var talk_bounce_time: float = 0.22

@export_group("Giao diện")
@export var dialogue_box_scene: PackedScene = preload("res://ui/dialogue/dialogue_box.tscn")
## Lớp vẽ của hộp thoại, đặt trên HUD
@export var ui_layer: int = 20

## Người đang nói chuyện; null khi rảnh
var current_player: Player
## Cáo đang ở trong vùng nhìn; null khi không có
var look_target: Player

var _pending_context: StringName = CONTEXT_GREETING
var _controls_were_enabled: bool = true
var _ui_layer_node: CanvasLayer
var _dialogue_box: DialogueBox
var _bounce_tween: Tween
var _visual_rest_scale: Vector3 = Vector3.ONE

@onready var visual: Node3D = $Visual
@onready var state_machine: StateMachine = $StateMachine
@onready var _interactable: InteractableComponent = $InteractableComponent
@onready var _look_area: Area3D = $LookArea


func _ready() -> void:
	set_physics_process(false)
	_visual_rest_scale = visual.scale
	_interactable.prompt_text = talk_prompt
	_interactable.interacted.connect(_on_interacted)
	_look_area.body_entered.connect(_on_look_body_entered)
	_look_area.body_exited.connect(_on_look_body_exited)
	if dialogues.is_empty():
		push_warning("%s: NPC chưa có lời thoại nào" % get_path())


func _physics_process(delta: float) -> void:
	state_machine.physics_update(delta)


func _exit_tree() -> void:
	# NPC bị xóa giữa lúc nói chuyện (đổi scene): trả lại điều khiển cho cáo
	end_session()


## Đặt context cho lần nói tiếp theo (state Talk đọc bằng consume_context)
func request_context(context: StringName) -> void:
	_pending_context = context


func consume_context() -> StringName:
	var context := _pending_context
	_pending_context = CONTEXT_GREETING
	return context


## Đoạn thoại hợp lệ có priority cao nhất trong context; null nếu không có
func pick_dialogue(context: StringName) -> Dialogue:
	var best: Dialogue = null
	for dialogue: Dialogue in dialogues:
		if dialogue == null or dialogue.context != context or not dialogue.is_available(self):
			continue
		if best == null or dialogue.priority > best.priority:
			best = dialogue
	return best


## Service đầu tiên đang mở được; null = NPC chỉ nói chuyện
func get_service() -> NpcService:
	for child in get_children():
		var service := child as NpcService
		if service and service.is_available():
			return service
	return null


func is_busy() -> bool:
	return current_player != null


## Bắt đầu buổi nói chuyện: khóa điều khiển cáo, tắt gợi ý tương tác
func begin_session(player: Player) -> void:
	if player == null or current_player == player:
		return
	end_session()
	current_player = player
	_controls_were_enabled = player.controls_enabled
	player.set_controls_enabled(false)
	_interactable.enabled = false
	if player_faces_npc:
		var to_npc := global_position - player.global_position
		player.face_instantly(Vector3(to_npc.x, 0.0, to_npc.z))
	if end_on_player_damaged and player.health:
		player.health.damaged.connect(_on_player_damaged)
	conversation_started.emit(player)


## Kết thúc buổi nói chuyện: đóng hộp thoại, trả điều khiển
func end_session() -> void:
	if current_player == null:
		return
	var player := current_player
	current_player = null
	_pending_context = CONTEXT_GREETING
	close_dialogue()
	if is_instance_valid(player):
		if player.health and player.health.damaged.is_connected(_on_player_damaged):
			player.health.damaged.disconnect(_on_player_damaged)
		player.set_controls_enabled(_controls_were_enabled)
	_interactable.enabled = true
	conversation_ended.emit(player)


## Đọc một chuỗi câu; trả DialogueBox.RESULT_DONE hoặc RESULT_CANCELLED (bấm thoát)
func say(lines: Array[DialogueLine]) -> int:
	var box := get_dialogue_box()
	box.play_lines(lines, display_name)
	return await box.finished


## Hỏi kèm lựa chọn; trả chỉ số đã chọn hoặc DialogueBox.RESULT_CANCELLED
func ask(question: String, options: PackedStringArray) -> int:
	var box := get_dialogue_box()
	box.ask(question, display_name, options)
	pulse()
	return await box.finished


func close_dialogue() -> void:
	if _dialogue_box:
		_dialogue_box.close()


func get_dialogue_box() -> DialogueBox:
	if _dialogue_box == null:
		_ui_layer_node = CanvasLayer.new()
		_ui_layer_node.layer = ui_layer
		add_child(_ui_layer_node)
		_dialogue_box = dialogue_box_scene.instantiate() as DialogueBox
		_ui_layer_node.add_child(_dialogue_box)
		_dialogue_box.line_started.connect(pulse.unbind(1))
	return _dialogue_box


## Quay model dần về phía điểm; trả true khi đã quay xong
func turn_toward(point: Vector3, delta: float) -> bool:
	var offset := point - global_position
	if Vector2(offset.x, offset.z).is_zero_approx():
		return true
	var target_angle := atan2(offset.x, offset.z)
	visual.rotation.y = lerp_angle(visual.rotation.y, target_angle, 1.0 - exp(-turn_speed * delta))
	return absf(angle_difference(visual.rotation.y, target_angle)) <= deg_to_rad(facing_tolerance_degrees)


func play_animation(animation: StringName) -> void:
	if animation_player and not animation.is_empty() and animation_player.has_animation(animation):
		animation_player.play(animation)


## Nảy nhẹ model (mỗi câu thoại) cho NPC có cảm giác đang nói
func pulse() -> void:
	if talk_bounce <= 0.0:
		return
	if _bounce_tween and _bounce_tween.is_valid():
		_bounce_tween.kill()
	visual.scale = _visual_rest_scale * Vector3(1.0 - talk_bounce * 0.5, 1.0 + talk_bounce, 1.0 - talk_bounce * 0.5)
	_bounce_tween = create_tween()
	_bounce_tween.tween_property(visual, "scale", _visual_rest_scale, maxf(talk_bounce_time, 0.01)) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_interacted(interactor: Node3D) -> void:
	var player := interactor as Player
	if player == null or is_busy():
		return
	talk_requested.emit(player)


func _on_player_damaged(_amount: int) -> void:
	if is_busy():
		state_machine.transition_to(interrupt_state)


func _on_look_body_entered(body: Node3D) -> void:
	var player := body as Player
	if player == null:
		return
	look_target = player
	look_target_changed.emit(player)


func _on_look_body_exited(body: Node3D) -> void:
	if body != look_target:
		return
	look_target = null
	look_target_changed.emit(null)
