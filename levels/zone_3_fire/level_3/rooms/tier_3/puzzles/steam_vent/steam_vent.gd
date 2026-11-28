class_name SteamVent
extends Area3D
## Timer đổi nhịp hơi; kiểm tra những body đã vào khi miệng phun chuyển sang nguy hiểm.

signal failed(player: Player)

enum Phase { REST, WARNING, ACTIVE, BUILDUP }

@export var source_offset: Vector3 = Vector3(0.0, -7.07, 2.0)

var phase: Phase = Phase.REST
var _data: KhamPuzzleData
var _enabled: bool = false
var _continuous: bool = false
var _players: Array[Player] = []
var _protected_players: Dictionary[Player, HurtboxComponent] = {}

@onready var _timer: Timer = $CycleTimer
@onready var _vfx: HotSteam = $HotSteam
@onready var _sound: AudioStreamPlayer3D = $SteamSound


func _ready() -> void:
	var shape: BoxShape3D = ($CollisionShape3D as CollisionShape3D).shape as BoxShape3D
	_vfx.configure_rising(source_offset, shape.size.y)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_timer.timeout.connect(_advance)
	_vfx.jet_ready.connect(_on_jet_ready)
	set_physics_process(false)
	stop()


func _physics_process(_delta: float) -> void:
	# Chỉ chạy khi có người đang né trong luồng phun; không quét vùng va chạm mỗi frame.
	for player: Player in _players:
		var hurtbox: HurtboxComponent = _protected_players.get(player)
		if hurtbox == null:
			continue
		if not hurtbox.is_invincible():
			_protected_players.erase(player)
			failed.emit(player)
	set_physics_process(not _protected_players.is_empty())


func configure(data: KhamPuzzleData) -> void:
	_data = data


func start_cycle() -> void:
	_clear_protected_players()
	_enabled = true
	_continuous = false
	phase = Phase.REST
	_vfx.set_resting()
	_timer.start(maxf(_data.vent_rest_time, 0.01))


func start_continuous() -> void:
	_enabled = true
	_continuous = true
	_timer.stop()
	_begin_jet()


func stop() -> void:
	_clear_protected_players()
	_enabled = false
	_continuous = false
	_timer.stop()
	phase = Phase.REST
	_vfx.set_resting()
	_sound.stop()


func _advance() -> void:
	if not _enabled:
		return
	match phase:
		Phase.REST:
			phase = Phase.WARNING
			_vfx.set_warning()
			if _sound.stream:
				_sound.play()
			_timer.start(maxf(_data.vent_warning_time, 0.01))
		Phase.WARNING:
			_begin_jet()
		Phase.ACTIVE:
			_clear_protected_players()
			phase = Phase.REST
			_vfx.set_resting()
			_sound.stop()
			_timer.start(maxf(_data.vent_rest_time, 0.01))


func _begin_jet() -> void:
	_clear_protected_players()
	phase = Phase.BUILDUP
	_vfx.set_active()
	if _sound.stream and not _sound.playing:
		_sound.play()


func _on_jet_ready() -> void:
	if not _enabled or phase != Phase.BUILDUP:
		return
	phase = Phase.ACTIVE
	if not _continuous:
		_timer.start(maxf(_data.vent_active_time, 0.01))
	for player: Player in _players:
		if is_instance_valid(player):
			_try_hit(player)


func _on_body_entered(body: Node3D) -> void:
	var player: Player = body as Player
	if player == null or _players.has(player):
		return
	_players.append(player)
	if _enabled and phase == Phase.ACTIVE:
		_try_hit(player)


func _on_body_exited(body: Node3D) -> void:
	_players.erase(body as Player)
	_protected_players.erase(body as Player)
	set_physics_process(not _protected_players.is_empty())


func _try_hit(player: Player) -> void:
	var hurtbox: HurtboxComponent = player.get_node(^"HurtboxComponent") as HurtboxComponent
	if hurtbox.is_invincible():
		_protected_players[player] = hurtbox
		set_physics_process(true)
	else:
		failed.emit(player)


func _clear_protected_players() -> void:
	_protected_players.clear()
	set_physics_process(false)
