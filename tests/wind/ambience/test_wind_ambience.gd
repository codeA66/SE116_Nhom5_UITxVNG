extends Node3D
## Sân thử LightShaft + AmbientWind ở góc camera game (FOV 30, cúi 50 độ, cách 32 m).
## Tham số sau "--": --case=<tên> chọn bộ thông số, --out=<thư mục tuyệt đối> chụp ảnh rồi thoát.
## Các case: default, tall_wide, one, twenty, density0, strong_wind, small_radius, near, near_nofade, none.

const CAMERA_DISTANCE := 32.0
const CAMERA_PITCH_DEGREES := 50.0
const ORBIT_RADIUS := 5.0
const ORBIT_SPEED := 0.6
const CAPTURE_TIMES: Array[float] = [1.5, 2.3, 3.1]

var _case: String = "default"
var _out_dir: String = ""
var _elapsed: float = 0.0
var _capture_index: int = 0
var _orbit: bool = true
var _camera_distance: float = CAMERA_DISTANCE
var _freeze_camera: bool = false

@onready var _player: Node3D = $Player
@onready var _camera: Camera3D = $Camera3D
@onready var _shaft: LightShaft = $LightShaft
@onready var _shaft_small: LightShaft = $LightShaftSmall
@onready var _wind: AmbientWind = $AmbientWind


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--case="):
			_case = argument.trim_prefix("--case=")
		elif argument.begins_with("--out="):
			_out_dir = argument.trim_prefix("--out=")
	_apply_case()
	print("[ambience] case=%s shafts=%d streaks=%d leaves=%d" % [_case, _shaft.shaft_count,
		roundi(_wind.streak_count * _wind.density), roundi(_wind.leaf_count * _wind.density)])


func _process(delta: float) -> void:
	_elapsed += delta
	if _orbit:
		var angle := _elapsed * ORBIT_SPEED
		_player.global_position = Vector3(cos(angle), 0.0, sin(angle)) * ORBIT_RADIUS + Vector3(0.0, 0.6, 0.0)
	if not (_freeze_camera and _elapsed > 0.1):
		var pitch := deg_to_rad(CAMERA_PITCH_DEGREES)
		_camera.global_position = _player.global_position + Vector3(0.0, sin(pitch), cos(pitch)) * _camera_distance
		_camera.look_at(_player.global_position)
	if _out_dir.is_empty() or _capture_index >= CAPTURE_TIMES.size():
		return
	if _elapsed >= CAPTURE_TIMES[_capture_index]:
		_capture()


func _capture() -> void:
	var image := get_viewport().get_texture().get_image()
	var path := _out_dir.path_join("%s_%d.png" % [_case, _capture_index])
	image.save_png(path)
	print("[ambience] saved %s draw_calls=%d objects=%d fps=%d" % [path,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		Performance.get_monitor(Performance.TIME_FPS)])
	_capture_index += 1
	if _case == "follow_check":
		_player.global_position += Vector3(4.0, 0.0, 2.0)
	if _capture_index >= CAPTURE_TIMES.size():
		get_tree().quit()


func _apply_case() -> void:
	match _case:
		"tall_wide":
			_shaft.height = 30.0
			_shaft.width = 6.0
			_shaft.tilt_degrees = 60.0
			_shaft.spread = 14.0
		"one":
			_shaft.shaft_count = 1
			_shaft.width = 0.15
			_shaft.tilt_degrees = 0.0
		"twenty":
			_shaft.shaft_count = 20
			_shaft.spread = 10.0
			_wind.streak_count = AmbientWind.MAX_STREAKS
			_wind.leaf_count = AmbientWind.MAX_LEAVES
		"density0":
			_wind.density = 0.0
			_shaft.dust_density = 0.0
			_shaft.ripple_strength = 0.0
		"strong_wind":
			_wind.wind_direction = Vector3(-0.3, 0.2, 1.0)
			_wind.wind_speed = 30.0
			_wind.streak_length = 10.0
			_wind.streak_width = 0.2
			_wind.coverage_radius = 40.0
		"small_radius":
			_wind.coverage_radius = 4.0
			_wind.height_min = 3.0
			_wind.height_max = 0.2
		"near", "near_nofade":
			_orbit = false
			_player.global_position = Vector3(-1.0, 0.6, -2.0)
			_camera_distance = 7.0
			if _case == "near_nofade":
				_shaft.near_fade_start = 0.0
				_shaft.near_fade_end = 0.0
		"follow_check":
			# Gió đứng yên, camera cố định: dời player giữa hai ảnh, vệt trong phần giao hai vùng phủ phải đứng yên
			_orbit = false
			_freeze_camera = true
			_wind.wind_speed = 0.0
			_wind.streak_lifetime = 10.0
			_wind.leaf_lifetime = 20.0
			_wind.leaf_flutter = 0.0
			_wind.leaf_tumble_speed = 0.0
			_wind.vertical_follow_rate = 0.0
		"none":
			_shaft.visible = false
			_shaft_small.visible = false
			_wind.visible = false
