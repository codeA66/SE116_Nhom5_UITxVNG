class_name TonAshenGale
extends Node3D
## Điều phối lượt phòng Tốn. Mỗi cơ chế tự phục hồi trạng thái ban đầu.

signal activated
signal seal_released(seal_id: StringName)

const FORWARD_HINT: String = "Có thứ gì đó ở phía trước"
const SEAL_ID: StringName = &"ton"
const SEAL_FLAG: StringName = &"level_3.t3_seal_ton"
const DEFAULT_DATA: TonPuzzleData = preload("res://levels/zone_3_fire/level_3/rooms/tier_3/puzzles/ton_puzzle_data.tres")

@export var data: TonPuzzleData = DEFAULT_DATA
@export var seal_flag: StringName = SEAL_FLAG
@export_range(0.5, 8.0, 0.1) var forward_hint_duration: float = 3.0

var _player: Player
var _stations: Array[TonFlameStation] = []
var _screens: Array[TonWindScreen] = []
var _elapsed: float = 0.0
var _gust: bool = false
var _warning: bool = false
var _complete: bool = false
var _reset_pending: bool = false

@onready var _flame: TonCarriedFlame = $CarriedFlame
@onready var _restart: Marker3D = $Restart
@onready var _presence: Area3D = $Presence
@onready var _fall: Area3D = $Fall
@onready var _required_torch: TonFlameStation = $Stations/ReturnTorch
@onready var _gem: SealGem = $Stations/Seal/TonGem
@onready var _entry_gate: StaticBody3D = $EntryGate
@onready var _false_trail_torch: TonFlameStation = $Stations/FalseTrailTorch
@onready var _forward_hint: WorldHint = $Stations/FalseTrailTorch/ForwardHint
@onready var _return_interaction: InteractableComponent = $ReturnPortal/Interactable
@onready var _return_arrival: Marker3D = $ReturnArrival


func _ready() -> void:
	if data == null:
		data = DEFAULT_DATA
	for child: Node in $Stations.get_children():
		var station := child as TonFlameStation
		if station:
			_stations.append(station)
			station.configure(_can_transfer)
			station.used.connect(_on_transferred)
	for child: Node in $WindClusters.get_children():
		var screen := child as TonWindScreen
		if screen:
			_screens.append(screen)
	_presence.body_entered.connect(_on_entered)
	_presence.body_exited.connect(_on_exited)
	_fall.body_entered.connect(_on_fell)
	_flame.extinguished.connect(_request_reset)
	_return_interaction.interacted.connect(_on_return_interacted)
	var gem_placed_flag: StringName = StringName(String(seal_flag) + "_placed")
	_gem.configure_reward(seal_flag, gem_placed_flag)
	var zone: ZoneRoot = get_parent() as ZoneRoot
	if zone:
		zone.player_spawned.connect(_gem.set_carrier)
		_gem.set_carrier(zone.get_node_or_null(^"Player") as Player)
	GameState.progress_replaced.connect(_restore_progress)
	_restore_progress()


func _exit_tree() -> void:
	_disconnect_player()


func _physics_process(delta: float) -> void:
	if _reset_pending or not is_instance_valid(_player):
		return
	var calm := maxf(data.calm_time, 0.1)
	_elapsed = fposmod(_elapsed + delta, calm + maxf(data.gust_time, 0.1))
	var gust := _elapsed >= calm
	var warning := not gust and _elapsed >= calm - data.gust_warning
	if gust != _gust or warning != _warning:
		_gust = gust
		_warning = warning
		for screen: TonWindScreen in _screens:
			screen.update_gust(gust, warning)
	var exposed: bool = false
	var sample := _player.wind_receiver.global_position if _player.wind_receiver else _player.global_position
	if gust:
		for screen: TonWindScreen in _screens:
			if not screen.get_wind_at(sample).is_zero_approx():
				exposed = true
				break
	_flame.advance(delta, exposed)


func is_active() -> bool:
	return _complete


func _can_transfer(player: Player, station: TonFlameStation) -> bool:
	if _complete or _reset_pending or player != _player:
		return false
	if station.role == TonFlameStation.Role.SOURCE:
		return not _flame.is_carried_by(player)
	if station.role == TonFlameStation.Role.SEAL and not _required_torch.is_lit():
		return false
	return _flame.is_carried_by(player) and not station.is_lit()


func _on_transferred(player: Player, station: TonFlameStation) -> void:
	match station.role:
		TonFlameStation.Role.SOURCE:
			_flame.kindle(player, data)
			_set_gate(_entry_gate, false)
			for screen: TonWindScreen in _screens:
				screen.reset(true)
			set_physics_process(true)
		TonFlameStation.Role.TORCH:
			station.set_lit(true)
			if station == _false_trail_torch:
				_forward_hint.flash(FORWARD_HINT, forward_hint_duration)
		TonFlameStation.Role.SEAL:
			_complete = true
			_flame.clear()
			for screen: TonWindScreen in _screens:
				screen.reset(false)
			set_physics_process(false)
			station.set_lit(true)
			GameState.set_flag(seal_flag)
			activated.emit()
			seal_released.emit(SEAL_ID)


func _on_return_interacted(actor: Node3D) -> void:
	var player: Player = actor as Player
	if player == null or player != _player or _reset_pending:
		return
	SceneManager.warp_player(player, _return_arrival.global_position, _return_arrival.global_basis.z)


func _on_entered(body: Node3D) -> void:
	var player := body as Player
	if player == null or _player == player:
		return
	_player = player
	_gem.set_carrier(player)
	player.combat_action_committed.connect(_flame.register_action)
	player.state_machine.state_changed.connect(_on_player_state_changed)


func _on_exited(body: Node3D) -> void:
	if body != _player:
		return
	_disconnect_player()
	if not _complete:
		_reset_attempt()


func _disconnect_player() -> void:
	if is_instance_valid(_player):
		_player.combat_action_committed.disconnect(_flame.register_action)
		_player.state_machine.state_changed.disconnect(_on_player_state_changed)
	_player = null


func _on_player_state_changed(_previous: StringName, next: StringName) -> void:
	if next == PlayerState.DASH:
		_flame.put_out()


func _on_fell(body: Node3D) -> void:
	if body == _player:
		_request_reset()


func _request_reset() -> void:
	if _reset_pending or not is_instance_valid(_player):
		return
	_reset_pending = true
	_perform_reset.call_deferred(_player)


func _perform_reset(player: Player) -> void:
	if is_instance_valid(player):
		if not _complete:
			_reset_attempt()
		player.health.heal_full()
		if player.wind_receiver:
			player.wind_receiver.clear_push()
		player.teleport(_restart.global_position, _restart.global_basis.z)
	_reset_pending = false


func _reset_attempt() -> void:
	set_physics_process(false)
	_forward_hint.cancel_flash()
	_elapsed = 0.0
	_gust = false
	_warning = false
	_flame.clear()
	for screen: TonWindScreen in _screens:
		screen.reset(false)
	for station: TonFlameStation in _stations:
		station.set_lit(station.role == TonFlameStation.Role.SOURCE)
	_set_gate(_entry_gate, true)


func _restore_progress() -> void:
	_complete = GameState.has_flag(seal_flag)
	_reset_attempt()
	if _complete:
		_set_gate(_entry_gate, false)
		for station: TonFlameStation in _stations:
			station.set_lit(true)


func _set_gate(gate: StaticBody3D, closed: bool) -> void:
	gate.visible = closed
	gate.set_deferred(&"collision_layer", 1 if closed else 0)
