extends Node
## Render QA: Godot capture_preview.tscn -- --output-dir <absolute folder>.
var _scene: Node3D
var _output: String = "user://"

func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var index: int = args.find("--output-dir")
	if index >= 0 and index + 1 < args.size(): _output = args[index + 1]
	_capture.call_deferred()

func _capture() -> void:
	_scene = (load("res://tests/new_enemy_test/new_enemy_test.tscn") as PackedScene).instantiate() as Node3D
	add_child(_scene)
	var camera: Camera3D = _scene.get_node("OverviewCamera") as Camera3D
	camera.look_at(Vector3(0, 0, -1)); camera.make_current()
	await _shot("new_enemy_arena_preview")
	var bear: WildEnemy = _scene.get_node("ArmoredPolarBear") as WildEnemy
	var chief: WildEnemy = _scene.get_node("MonkeySquad/Chieftain") as WildEnemy
	var grunt: WildEnemy = _scene.get_node("MonkeySquad/Grunt1") as WildEnemy
	for actor: WildEnemy in [bear, chief, grunt]:
		actor.set_physics_process(false)
		actor.state_machine.transition_to(&"Idle")
		actor.sensor.monitoring = false
	bear.position = Vector3(-4, 0, 0); chief.position = Vector3.ZERO; grunt.position = Vector3(3.4, 0, 0)
	var player: FoxyPlayer = _scene.get_node("Player") as FoxyPlayer
	player.set_physics_process(false); player.position = Vector3(6, 0, 0)
	_scene.get_node("Cover/Mesh").hide()
	for node: Node in [_scene.get_node("MonkeySquad/Grunt2"), _scene.get_node("MonkeySquad/Grunt3")]:
		node.set_physics_process(false); (node as Node3D).hide()
	camera.position = Vector3(8, 5, 14); camera.size = 14; camera.look_at(Vector3(.5, 1, 0))
	_scene.get_node("HUD").hide()
	for layer: Node in player.find_children("*", "CanvasLayer", true, false): (layer as CanvasLayer).hide()
	await _shot("new_enemy_models_preview")
	# Render cả ba shader VFX để bắt lỗi chỉ xuất hiện trên renderer thật.
	chief.hide(); grunt.hide(); player.position = Vector3(-1, 0, 2)
	camera.position = Vector3(8, 8, 14); camera.size = 15; camera.look_at(Vector3(0, 0, 1))
	for skill: EnemySkillData in bear.wildlife.skills:
		bear.target = player
		var hazard: EnemyHazard = bear.emitter.emit_skill(skill, Vector3.BACK)
		hazard.set_physics_process(false)
		hazard.visual.call(&"seek", 1.2 if skill.skill_id != &"claw" else 1.5)
		await _shot("new_enemy_" + String(skill.skill_id) + "_preview")
		if skill.skill_id == &"claw":
			hazard.visual.call(&"seek", 2.12)
			await _shot("new_enemy_claw_impact_preview")
		bear.emitter.cancel_all()
	print("ENEMY_PREVIEW_CAPTURED: ", _output)
	_scene.queue_free()
	await get_tree().process_frame
	get_tree().quit()

func _shot(filename: String) -> void:
	for frame: int in 10: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_output.path_join(filename + ".png"))
