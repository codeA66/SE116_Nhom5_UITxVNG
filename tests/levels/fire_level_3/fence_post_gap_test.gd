extends Node
## Cột lan can map Lửa không dính nhau: lan can là thanh không cột (fence_rail_2m) + cột riêng (fence_post)
## đặt cách nhau tối thiểu MIN_GAP (cột rộng 0,5 m). Đo mọi cặp cột (cả tier 1 và tier 2) trên mặt bằng, bỏ cặp lệch cao
## quá MAX_DY (cột ở hai tầng khác nhau). Cũng kiểm không còn model fence_2m cũ (cột dính liền thanh).
## Không cần dựng cảnh chơi. Chạy: godot --headless --path . res://tests/levels/fire_level_3/fence_post_gap_test.tscn

const LEVEL: PackedScene = preload("res://levels/zone_3_fire/level_3/level_3.tscn")
const MIN_GAP: float = 1.25
const MAX_DY: float = 1.2

var _level: Node


func _ready() -> void:
	if GameState.progress_changed.is_connected(SaveManager.save_game):
		GameState.progress_changed.disconnect(SaveManager.save_game)
	if GameState.progress_committed.is_connected(SaveManager.save_game):
		GameState.progress_committed.disconnect(SaveManager.save_game)
	GameState.replace_progress(PlayerProgress.new())
	_level = LEVEL.instantiate()
	add_child(_level)
	_run.call_deferred()


func _run() -> void:
	for _i: int in range(10):
		await get_tree().physics_frame
	var posts: Array[Vector3] = []
	var old_rails: int = 0
	var rails: int = 0
	_collect(_level, posts)
	for n: Node in _level.find_children("*", "Node3D", true, false):
		var f: String = n.scene_file_path.get_file()
		if f == "fence_2m.glb":
			old_rails += 1
		elif f == "fence_rail_2m.glb":
			rails += 1
	var bad: Array[String] = []
	var closest: float = INF
	for i: int in range(posts.size()):
		for j: int in range(i + 1, posts.size()):
			var d: float = Vector2(posts[i].x - posts[j].x, posts[i].z - posts[j].z).length()
			if absf(posts[i].y - posts[j].y) > MAX_DY:
				continue
			closest = minf(closest, d)
			if d < MIN_GAP:
				bad.append("%s <> %s (%.2f m)" % [posts[i], posts[j], d])
	var ok_gap: bool = bad.is_empty()
	print("%s %d cột, %d thanh lan can; cặp cột gần nhất %.2f m (cần >= %.2f), %d cặp quá sát" % ["OK  " if ok_gap else "FAIL", posts.size(), rails, closest, MIN_GAP, bad.size()])
	for line: String in bad.slice(0, 10):
		print("   ", line)
	var ok_old: bool = old_rails == 0
	print("%s không còn model fence_2m cũ (%d)" % ["OK  " if ok_old else "FAIL", old_rails])
	var ok: bool = ok_gap and ok_old
	print("FENCE POST GAP RESULT: %s" % ("OK" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)


func _collect(n: Node, out: Array[Vector3]) -> void:
	if n is Node3D and n.scene_file_path.get_file() == "fence_post.glb":
		out.append((n as Node3D).global_position)
		return
	for c: Node in n.get_children():
		_collect(c, out)
