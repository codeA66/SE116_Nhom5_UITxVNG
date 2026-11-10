class_name AbilityAcquirePhase
extends "res://components/core/state_machine/state.gd"
## Mỗi pha là một State; thêm pha bằng node và phase_order trong dữ liệu.
signal completed
signal entered
const Context = preload("res://components/feedback/loot_beam/ability_acquire/core/ability_acquire_context.gd")
const Renderer = preload("res://components/feedback/loot_beam/ability_acquire/core/ability_acquire_renderer.gd")
const Presentation = preload("res://components/feedback/loot_beam/ability_acquire/ui/ability_acquire_ui.gd")
var context: Context
var renderer: Renderer
var ui: Presentation
var duration: float = 1.0
var auto_finish: bool = true
var elapsed: float = 0.0
var _started: int = 0
## Không để initial_state của FSM phát hiệu ứng lúc chỉ vừa tải scene.
func _ready() -> void:
	set_process(false)
## Context được gán trước khi người chơi có thể tương tác.
func bind(ctx: Context, world: Renderer, overlay: Presentation) -> void:
	context = ctx
	renderer = world
	ui = overlay
## Dùng đồng hồ thực để hitstop không kéo dài chuỗi hoặc làm mất đồng bộ.
func enter(_previous: StringName) -> void:
	if context == null or not context.active: return
	_started = Time.get_ticks_usec()
	elapsed = 0.0
	auto_finish = true
	_phase_enter()
	set_process(true)
	entered.emit()
## Mọi đường chuyển hoặc hủy đều tắt process của state cũ.
func exit() -> void:
	set_process(false)
## Root chạy ALWAYS; actor và thế giới có thể đang pause.
func _process(_delta: float) -> void:
	if not context.active: return
	elapsed = float(Time.get_ticks_usec()-_started)/1000000.0
	var progress: float = clampf(elapsed/maxf(duration,context.data.minimum_time),0.0,1.0)
	_phase_update(progress)
	if auto_finish and elapsed >= maxf(duration,context.data.minimum_time):
		set_process(false)
		completed.emit()
## Pha con chọn thời gian và khởi tạo hình riêng.
func _phase_enter() -> void:
	pass
## Pha con chỉ cập nhật phần hình của mình.
func _phase_update(_progress: float) -> void:
	pass
