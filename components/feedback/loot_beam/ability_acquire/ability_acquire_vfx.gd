class_name AbilityAcquireVfx
extends Node3D
## DONE: pha node-FSM, slot cố định, dữ liệu nguyên tố, cleanup cả trước và sau khi trao kỹ năng.
## NOT DONE: audio riêng vẫn cần gán vào dữ liệu nếu muốn phát cue âm thanh.
## NOTES: chỉ nâng model; hình và UI được warmup bằng hệ thống hiện có.
signal phase_started(phase: StringName)
signal burst_peaked
signal finished
signal cancelled(committed: bool)
signal feedback_requested(trauma: float, hold_seconds: float)
signal audio_cue(cue: StringName)
## Nạp renderer trước tuning: probe trên 4.7.2 xác nhận thứ tự ngược giữ 141 resource khi thoát.
const Renderer = preload("res://components/feedback/loot_beam/ability_acquire/core/ability_acquire_renderer.gd")
const Context = preload("res://components/feedback/loot_beam/ability_acquire/core/ability_acquire_context.gd")
const Presentation = preload("res://components/feedback/loot_beam/ability_acquire/ui/ability_acquire_ui.gd")
const Phase = preload("res://components/feedback/loot_beam/ability_acquire/core/ability_acquire_phase.gd")
const Tuning = preload("res://resources/feedback/ability_acquire/ability_acquire_data.gd")
@export_group("Sequence")
@export var data: Tuning = preload("res://resources/feedback/ability_acquire/ability_acquire_default.tres")
@export var source_visual: Node3D
var context: Context
var _active: bool = false
var _phase_order: PackedStringArray
var _sounds: Dictionary[StringName, AudioStreamPlayer] = {}
@onready var renderer: Renderer = $Renderer
@onready var ui: Presentation = $Ui
@onready var _fsm: StateMachine = $StateMachine
## Truyền tuning trước ready của con, không đọc onready của parent từ child.
func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	($Renderer as Renderer).data = data
	($Ui as Presentation).data = data
	add_to_group(ShaderWarmup.SOURCE_GROUP)
## Liên kết một lần; không có phát hiệu ứng ngầm khi scene vừa vào cây.
func _ready() -> void:
	set_process(false)
	context = Context.new()
	context.data = data
	_phase_order = data.phase_order
	for node: Node in _fsm.get_children():
		var phase: Phase = node as Phase
		phase.bind(context,renderer,ui)
		phase.completed.connect(_on_phase_completed.bind(phase.name))
		phase.entered.connect(_on_phase_entered.bind(phase.name))
	ui.close_finished.connect(_finish)
	ui.icon_landed.connect(_on_icon_landed)
	_sounds[&"descend"] = $Audio/Descend
	_sounds[&"gather"] = $Audio/Gather
	_sounds[&"burst"] = $Audio/Burst
	_sounds[&"panel"] = $Audio/Panel
	_sounds[&"icon_land"] = $Audio/IconLand
	$Audio/Descend.stream = data.audio_descend
	$Audio/Gather.stream = data.audio_gather
	$Audio/Burst.stream = data.audio_burst
	$Audio/Panel.stream = data.audio_panel
	$Audio/IconLand.stream = data.audio_icon_land
	if is_instance_valid(source_visual): renderer.prepare_source(source_visual)
## Full sequence giữ cùng API với cách phát pha riêng.
func play(target: Node3D, ability: AbilityData) -> bool:
	if data.phase_order.is_empty(): return false
	return _begin_sequence(target,ability,StringName(data.phase_order[0]))
## Khóa trước khi nâng; người gọi nhận burst_peaked để commit đúng một lần.
func play_lift(target: Node3D, ability: AbilityData) -> bool:
	return _begin_sequence(target,ability,&"Lift")
## Full sequence có thể bắt đầu bằng pha mới từ dữ liệu, API lift vẫn phát đúng pha riêng.
func _begin_sequence(target: Node3D, ability: AbilityData, first_phase: StringName) -> bool:
	if _active or not is_instance_valid(target) or ability == null: return false
	if _fsm.current_state == null: return false
	if not _fsm.get_node_or_null(NodePath(first_phase)) is Phase: return false
	context.begin(target,ability,get_tree())
	_active = true
	target.tree_exiting.connect(_on_target_exiting,CONNECT_ONE_SHOT)
	renderer.bind_actor(target,context.visual,ability)
	ui.begin(ability)
	_go(first_phase)
	return true
## Cho phép preview nhảy sang pha nhưng không tạo lại node.
func play_gather() -> void:
	_go(&"Gather")
## Cho phép công cụ preview phát đỉnh bằng đúng đường của full sequence.
func play_burst() -> void:
	_go(&"Burst")
## Chuyển sang hạ xuống bằng cùng node FSM.
func play_settle() -> void:
	_go(&"Settle")
## Hủy là đồng bộ: thoát state, tắt hình, trả model/control/pause, không chờ tween.
func stop_all() -> void:
	if not _active: return
	var committed: bool = context.committed
	_cleanup()
	cancelled.emit(committed)
## API kiểm tra không đếm node UI tồn tại sẵn như hiệu ứng còn sống.
func is_idle() -> bool:
	return not _active and renderer.get_active_slot_count() == 0 and not ui.is_processing()
## HUD/test dùng API public thay vì bấm vào label hoặc biến riêng.
func close_reveal() -> void:
	ui.request_close()
## Cung cấp cả book proxy, instancing và canvas material cho warmup hiện có.
func get_shader_warmup_sources() -> Array[Node]:
	return [renderer,ui] if is_node_ready() else []
## Scene thoát giữa chừng vẫn trả lại pause/control, không để game kẹt.
func _exit_tree() -> void:
	if _active: _cleanup()
## Chuỗi chỉ dispatch theo dữ liệu thứ tự, hành vi nằm trong từng State.
func _on_phase_completed(phase_name: StringName) -> void:
	if not _active: return
	var index: int = _phase_order.find(String(phase_name))
	if index < 0 or index + 1 >= _phase_order.size(): _finish()
	else: _go(StringName(_phase_order[index+1]))
## Một nơi phát cue và commit, không gắn tên nguyên tố.
func _on_phase_entered(phase_name: StringName) -> void:
	if phase_name == &"Lift": _audio(&"descend")
	elif phase_name == &"Gather": _audio(&"gather")
	elif phase_name == &"Burst":
		_audio(&"burst")
		if not context.committed:
			context.committed = true
			burst_peaked.emit()
		feedback_requested.emit(data.shake,data.hitstop)
		ScreenShake.add_trauma(data.shake*clampf(data.burst_intensity,0.0,data.maximum_intensity))
	elif phase_name == &"Reveal": _audio(&"panel")
	phase_started.emit(phase_name)
## Target có thể bị gỡ khi đổi scene; callback không được giữ một player cũ.
func _on_target_exiting() -> void:
	stop_all()
## Icon tới HUD mới phát âm thanh chốt.
func _on_icon_landed() -> void:
	_audio(&"icon_land")
## Stream trống vẫn có signal để hệ audio ngoài gắn về sau.
func _audio(cue: StringName) -> void:
	audio_cue.emit(cue)
	var sound: AudioStreamPlayer = _sounds.get(cue)
	if sound != null and sound.stream != null: sound.play()
## Cổng duy nhất để chuyển pha, bỏ qua lời gọi sau khi hủy.
func _go(phase_name: StringName) -> void:
	if _active: _fsm.transition_to(phase_name)
## Dọn trước rồi mới báo người gọi xóa pickup.
func _finish() -> void:
	if not _active: return
	_cleanup()
	finished.emit()
	GameState.unlock_tutorial(&"inventory")
## Không dùng tween/timer chạy tiếp sau lượt; mọi thứ được trả đồng bộ.
func _cleanup() -> void:
	_active = false
	if _fsm.current_state != null: _fsm.current_state.exit()
	if is_instance_valid(context.actor) and context.actor.tree_exiting.is_connected(_on_target_exiting):
		context.actor.tree_exiting.disconnect(_on_target_exiting)
	ui.stop_all()
	renderer.restore_source(context.committed)
	for sound: AudioStreamPlayer in _sounds.values(): sound.stop()
	context.restore(get_tree())
