class_name SecretWall
extends StaticBody3D
## Tường giả che lối bí mật (tham khảo Hollow Knight, Zelda: Link's Awakening, Death's Door).
## Gợi ý cho người chơi: gió rò qua khe nứt; chém vào thì bụi rơi, vết nứt loé và có tiếng khác tường thường.
## Thổi Gió trúng (khi mọi nguồn ở Sources đã bật) thì vỡ tung: loé sáng, đá văng, bụi, rung màn hình.
## Vỡ rồi thì làm nguồn mở khoá (signal activated + is_active()) và nhớ qua lần chơi sau bằng persistent_id.
## Hình nằm dưới Visual (thay model không cần sửa code); mảnh vỡ dựng sẵn dưới Debris, không tạo node lúc vỡ.
## Hiệu năng: không có _process; gợi ý và cú vỡ chạy bằng tween + hạt one-shot có giới hạn.

signal hinted
signal activated

## Cờ lưu đã vỡ. Để trống = mỗi lần vào khu tường lại liền
@export var persistent_id: StringName
## Chỉ vỡ khi mọi nguồn (node có activated + is_active()) đã bật; trước đó Thổi Gió chỉ gợi ý
@export var sources: Array[Node] = []
## Vật liệu phát sáng gán cho mesh tên CrackGlow* trong Visual (dải sáng trong khe nứt của model)
@export var crack_material: ShaderMaterial

@export_group("Gợi ý")
## Độ sáng vết nứt khi bị chém / thổi lúc chưa phá được, và thời gian tắt
@export_range(0.0, 4.0, 0.05) var hint_glow: float = 1.6
@export_range(0.05, 2.0, 0.05) var hint_time: float = 0.45
@export_range(0.0, 1.0, 0.01) var hint_trauma: float = 0.08

@export_group("Vỡ")
@export_range(0.1, 4.0, 0.05) var debris_time: float = 1.3
## Quãng văng ngang theo hướng gió và độ cao vọt lên của mảnh đá (m)
@export_range(0.0, 12.0, 0.1) var debris_reach: float = 4.5
@export_range(0.0, 6.0, 0.1) var debris_lift: float = 1.6
@export_range(0.0, 1.0, 0.01) var break_trauma: float = 0.45
@export_range(0.0, 20.0, 0.1) var flash_energy: float = 6.0
@export_range(0.05, 2.0, 0.05) var flash_time: float = 0.5

var is_broken: bool = false

var _glow_tween: Tween

@onready var _shape: CollisionShape3D = $CollisionShape3D
@onready var _visual: Node3D = $Visual
@onready var _leak: GPUParticles3D = $WindLeak
@onready var _hint_dust: GPUParticles3D = $HintDust
@onready var _break_dust: GPUParticles3D = $BreakDust
@onready var _flash: OmniLight3D = $Flash
@onready var _debris: Node3D = $Debris
@onready var _receiver: WindReceiverComponent = $WindReceiver
@onready var _hurtbox: HurtboxComponent = $HurtboxComponent
@onready var _hint_sound: AudioStreamPlayer3D = $HintSound
@onready var _break_sound: AudioStreamPlayer3D = $BreakSound


func _ready() -> void:
	# Tường không phải mục tiêu chiến đấu: bỏ khỏi nhóm soft-lock để kiếm không tự nhắm vào tường
	_hurtbox.remove_from_group(HurtboxComponent.GROUP)
	var glow := _visual.find_child("CrackGlow*", true, false) as GeometryInstance3D
	if glow and crack_material:
		glow.material_override = crack_material
	_flash.light_energy = 0.0
	_debris.hide()
	if not persistent_id.is_empty() and GameState.has_flag(persistent_id):
		_set_broken_state()
		return
	_set_crack_glow(0.0)
	_receiver.pushed.connect(_on_wind)
	_hurtbox.hurt.connect(_on_struck)


## Cho vùng / cổng phía sau: tường đã vỡ
func is_active() -> bool:
	return is_broken


## Mọi nguồn đã bật (đấu trường đã thắng...) thì gió mới phá được
func can_break() -> bool:
	for source: Node in sources:
		if not is_instance_valid(source) or not source.has_method(&"is_active") or not source.call(&"is_active"):
			return false
	return true


## Phá tường từ code (cutscene, test). Bỏ qua điều kiện nguồn
func shatter(direction: Vector3 = Vector3.ZERO) -> void:
	if is_broken:
		return
	if not persistent_id.is_empty():
		GameState.set_flag(persistent_id)
	_set_broken_state()
	_play_break(direction)
	activated.emit()


func _on_wind(impulse: Vector3) -> void:
	if is_broken:
		return
	if can_break():
		shatter(impulse)
	else:
		_hint()


func _on_struck(_info: DamageInfo, _damage_taken: int) -> void:
	if not is_broken:
		_hint()


## Chém / thổi khi chưa phá được: vết nứt loé rồi tắt, bụi rơi, rung rất nhẹ, tiếng "cộc" khác tường thường
func _hint() -> void:
	_set_crack_glow(hint_glow)
	if _glow_tween and _glow_tween.is_valid():
		_glow_tween.kill()
	_glow_tween = create_tween()
	_glow_tween.tween_method(_set_crack_glow, hint_glow, 0.0, hint_time)
	_hint_dust.restart()
	if _hint_sound.stream:
		_hint_sound.play()
	ScreenShake.add_trauma(hint_trauma)
	hinted.emit()


func _set_broken_state() -> void:
	is_broken = true
	_shape.set_deferred(&"disabled", true)
	_receiver.set_deferred(&"monitorable", false)
	_hurtbox.set_deferred(&"monitorable", false)
	_visual.hide()
	_leak.emitting = false
	_leak.hide()


## Mảnh đá văng theo hướng gió rồi rơi và thu nhỏ; xong thì ẩn cả nhóm để không còn lượt vẽ
func _play_break(direction: Vector3) -> void:
	var push := direction
	push.y = 0.0
	push = push.normalized() if push.length() > 0.001 else -global_basis.z
	_debris.show()
	var flight := create_tween().set_parallel()
	var chunks := _debris.get_children()
	for index: int in range(chunks.size()):
		var chunk := chunks[index] as Node3D
		if chunk == null:
			continue
		# Lệch hướng cố định theo thứ tự mảnh: mỗi lần vỡ giống nhau, không cần RNG
		var spread := float(index) / maxf(float(chunks.size() - 1), 1.0) - 0.5
		var side := global_basis.x * spread * debris_reach * 0.6
		var start := chunk.position
		var end := start + _debris.global_basis.inverse() * (push * debris_reach * (0.55 + absf(spread)) + side)
		end.y = -start.y
		flight.tween_method(_fly_chunk.bind(chunk, start, end), 0.0, 1.0, debris_time)
		flight.tween_property(chunk, ^"rotation", chunk.rotation + Vector3(spread * 6.0, 3.0 + spread, spread * 4.0), debris_time)
		flight.tween_property(chunk, ^"scale", Vector3.ONE * 0.05, debris_time * 0.4).set_delay(debris_time * 0.6)
	flight.chain().tween_callback(_debris.hide)
	_break_dust.restart()
	_flash.light_energy = flash_energy
	create_tween().tween_property(_flash, ^"light_energy", 0.0, flash_time)
	if _break_sound.stream:
		_break_sound.play()
	ScreenShake.add_trauma(break_trauma)


## Quỹ đạo parabol: vọt lên debris_lift ở giữa đường rồi rơi xuống mặt sàn
func _fly_chunk(t: float, chunk: Node3D, start: Vector3, end: Vector3) -> void:
	var point := start.lerp(end, 1.0 - pow(1.0 - t, 2.0))
	point.y = lerpf(start.y, end.y, t) + sin(t * PI) * debris_lift
	chunk.position = point


func _set_crack_glow(value: float) -> void:
	if crack_material:
		crack_material.set_shader_parameter(&"crack_glow", value)
