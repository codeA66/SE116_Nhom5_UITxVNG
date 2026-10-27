class_name PlayerState
extends State
## State dành cho Player: có sẵn tham chiếu player và tên các state.

const IDLE := &"Idle"
const RUN := &"Run"
const JUMP := &"Jump"
const FALL := &"Fall"
const PICK_UP := &"PickUp"
const ATTACK := &"Attack"
const DASH := &"Dash"
const WIND_BLAST := &"WindBlast"
const BOW_AIM := &"BowAim"
const HURT := &"Hurt"
const DEAD := &"Dead"

var player: Player


func _ready() -> void:
	# owner là node gốc của scene (Player), có sẵn trước khi _ready chạy
	player = owner as Player
	assert(player != null, "PlayerState phải nằm trong scene Player")
