class_name CameraCutsceneState
extends State
## State của cutscene camera: có sẵn tham chiếu cutscene và tên các state.

const IDLE := &"Idle"
const INTRO := &"Intro"
const HOLD := &"Hold"
const OUTRO := &"Outro"
const DONE := &"Done"

var cutscene: CameraCutscene


func _ready() -> void:
	cutscene = owner as CameraCutscene
	assert(cutscene != null, "CameraCutsceneState phải nằm trong scene CameraCutscene")


## Player bước vào vùng kích hoạt
func on_player_entered(_player: Player) -> void:
	pass


## Nội suy êm hai đầu (smootherstep): khởi động và dừng mềm, kiểu chuyển động máy quay
static func ease_camera(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)
