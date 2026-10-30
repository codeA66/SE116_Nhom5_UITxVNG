class_name MovementDustComponent
extends Node3D
## Bụi dưới chân: phụt đều khi đang chạy trên đất, bung một nắm ra sau lưng khi vừa vào state lướt (dash...).
## Nghe state_changed của StateMachine nên chỉ chạy _physics_process lúc đang ở state chạy.
## Tên state cấu hình bằng @export: gắn cho quái / boss chỉ cần đổi danh sách, không sửa code.

@export var body: CharacterBody3D
@export var state_machine: StateMachine
## State có bụi chân đều khi đang di chuyển trên đất
@export var run_states: Array[StringName] = [&"Run"]
## State bung bụi một lần lúc vừa vào (chỉ khi đang đứng trên đất)
@export var burst_states: Array[StringName] = [&"Dash"]
## Tốc độ ngang tối thiểu (m/s) mới có bụi chạy: vừa nhích chân hay đang phanh thì không phụt bụi
@export var min_run_speed: float = 2.5

@onready var _run_dust: GPUParticles3D = $RunDust
@onready var _burst_dust: GPUParticles3D = $BurstDust


func _ready() -> void:
	if body == null:
		body = owner as CharacterBody3D
	if body == null or state_machine == null:
		push_error("%s cần body (CharacterBody3D) và state_machine" % get_path())
		set_physics_process(false)
		return
	state_machine.state_changed.connect(_on_state_changed)
	set_physics_process(false)


func _physics_process(_delta: float) -> void:
	var speed := Vector2(body.velocity.x, body.velocity.z).length()
	_run_dust.emitting = body.is_on_floor() and speed >= min_run_speed


func _on_state_changed(_from: StringName, to: StringName) -> void:
	var running := to in run_states
	set_physics_process(running)
	if not running:
		_run_dust.emitting = false
	if to in burst_states and body.is_on_floor():
		_play_burst()


func _play_burst() -> void:
	var horizontal := Vector3(body.velocity.x, 0.0, body.velocity.z)
	if not horizontal.is_zero_approx():
		# Trục -Z của node nhìn theo hướng lướt nên bụi (bắn theo +Z cục bộ) phụt ra sau lưng
		_burst_dust.global_basis = Basis.looking_at(horizontal.normalized())
		_burst_dust.reset_physics_interpolation()
	_burst_dust.restart()
