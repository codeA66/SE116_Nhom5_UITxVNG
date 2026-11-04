class_name BearVictoryPassage
extends Node3D
## Dùng đúng cờ trận gấu của tier 2; không phụ thuộc tên / vòng đời node gấu.
@export var required_flag: StringName = &"level_1.enc_bear_miniboss"
@export var leaves: Array[Node3D] = []
@export var collision: CollisionShape3D
@export_range(0.1, 5.0, 0.1) var open_duration: float = 1.2
@export var slide_distance: float = 4.0
var opened: bool = false

func _ready() -> void:
	if GameState.has_flag(required_flag): _open(false)
	else: GameState.progress_changed.connect(_check)

func _check() -> void:
	if not opened and GameState.has_flag(required_flag):
		GameState.progress_changed.disconnect(_check); _open(true)

func _open(animated: bool) -> void:
	opened = true; collision.set_deferred("disabled",true)
	if not animated:
		for leaf: Node3D in leaves: leaf.hide()
		return
	var tween: Tween = create_tween().set_parallel()
	for index: int in leaves.size():
		var leaf: Node3D = leaves[index]
		tween.tween_property(leaf,"position:x",leaf.position.x+(-slide_distance if index==0 else slide_distance),open_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.chain().tween_callback(func() -> void:
		for leaf: Node3D in leaves: leaf.hide())
