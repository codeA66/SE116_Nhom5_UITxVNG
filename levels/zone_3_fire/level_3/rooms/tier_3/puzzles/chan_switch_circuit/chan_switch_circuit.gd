extends ChanCircuit
## Xung có thể mang 0 hoặc 1; nhánh ngắt giữ trạng thái tắt.

const K1_TO_K2: PackedInt32Array = [3, 1, 2]
const K2_TO_K3: PackedInt32Array = [3, 1, 2]
const INVERTED_PINS: PackedInt32Array = [2, 3]
const SELECTOR_COUNT: int = 3

@export var source_track: Node3D
@export var crossed_tracks: Array[Node3D] = []
@export var tracks_before_gate: Array[Node3D] = []
@export var tracks_after_gate: Array[Node3D] = []
@export var receiver_track: Node3D
@export var receiver_zero_track: Node3D
@export var zero_taps: Array[Node3D] = []

@onready var _track_groups: Array[Array] = [crossed_tracks, tracks_before_gate, tracks_after_gate, zero_taps]


func _trace_pulse() -> bool:
	_hide_tracks()
	source_track.show()
	if contacts.size() != SELECTOR_COUNT:
		return false

	var first_port: int = contacts[0].get_selected_port()
	if first_port == 0:
		return false
	crossed_tracks[first_port - 1].show()
	var second_port: int = contacts[1].get_selected_port()
	if second_port != K1_TO_K2[first_port - 1]:
		return false
	tracks_before_gate[second_port - 1].show()
	tracks_after_gate[second_port - 1].show()

	var powered: bool = not INVERTED_PINS.has(second_port)
	var third_port: int = contacts[2].get_selected_port()
	if third_port != K2_TO_K3[second_port - 1]:
		return false
	receiver_track.visible = powered
	receiver_zero_track.visible = not powered
	if not powered:
		zero_taps[third_port - 1].show()
	return powered


func _hide_tracks() -> void:
	source_track.hide()
	receiver_track.hide()
	receiver_zero_track.hide()
	for group: Array in _track_groups:
		for track: Node3D in group:
			track.hide()
