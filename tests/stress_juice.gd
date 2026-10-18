extends Node
## Đo hiệu năng hiệu ứng chiến đấu trong Level 1: 5 quái bị chém liên tục 10 s so với 5 s không chém.
## Cần cửa sổ thật (draw call chỉ có khi có renderer):
##   godot --path . --resolution 1280x720 res://tests/stress_juice.tscn
## Tắt vsync để ms/frame phản ánh tải thật. APPDATA/LOCALAPPDATA nên trỏ vào .godot/...

const LEVEL_SCENE: PackedScene = preload("res://levels/zone_1_wind/level_1/level_1.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemies/enemy_1/enemy_1.tscn")
const SLASH_1: AttackData = preload("res://resources/attacks/sword_slash_1.tres")
const SLASH_3: AttackData = preload("res://resources/attacks/sword_slash_3.tres")
const ENEMY_COUNT := 5
const BASELINE_SECONDS := 5.0
const STRESS_SECONDS := 10.0
## Chu kỳ chém: mỗi quái bị đánh mỗi HIT_PERIOD giây, player vung kiếm mỗi SLASH_PERIOD giây
const HIT_PERIOD := 0.25
const SLASH_PERIOD := 0.3
const ENEMY_RING_RADIUS := 2.2
## Số hạt tối đa mỗi hiệu ứng (khai báo trong scene)
const PARTICLES_HIT_SPARK := 15
const PARTICLES_BLOOD := 16
const PARTICLES_DEATH := 23
const PARTICLES_SLASH := 6

var _level: Node3D
var _player: Player
var _enemies: Array[Enemy] = []


class Stats extends RefCounted:
	var frames: int = 0
	var frame_ms_sum: float = 0.0
	var frame_ms_max: float = 0.0
	var script_ms_sum: float = 0.0
	var physics_ms_sum: float = 0.0
	var draw_sum: float = 0.0
	var draw_max: float = 0.0
	var particles_max: int = 0


func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	GameState.replace_progress(PlayerProgress.new())
	_level = LEVEL_SCENE.instantiate() as Node3D
	add_child(_level)
	await get_tree().physics_frame
	_player = _level.get_node("Player") as Player
	_player.teleport(Vector3(0.0, 0.2, 4.0))
	await _wait(1.5)
	for i in ENEMY_COUNT:
		var enemy := ENEMY_SCENE.instantiate() as Enemy
		var angle := TAU * float(i) / float(ENEMY_COUNT)
		enemy.position = _player.global_position + Vector3(sin(angle), 0.0, cos(angle)) * ENEMY_RING_RADIUS
		_level.add_child(enemy)
		_enemies.append(enemy)
	await _wait(0.5)
	for enemy in _enemies:
		enemy.health.max_health = 1000000
		enemy.health.heal_full()
		enemy.set_physics_process(false)
		enemy.hurtbox.invincibility_time = 0.0
	# Khởi động pool: nở tới mức dùng thật trước khi đo (không tính vào "rò node")
	await _run_phase("warmup", 2.0, true)
	var nodes_before := _count(CombatFx)
	var tree_nodes_before := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var baseline := await _run_phase("baseline", BASELINE_SECONDS, false)
	var stress := await _run_phase("stress", STRESS_SECONDS, true)
	var nodes_after := _count(CombatFx)
	var tree_nodes_after := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	_report("BASELINE (không chém)", baseline)
	_report("STRESS (5 quái chém liên tục)", stress)
	print("RESULT frame_ms: %.3f -> %.3f (+%.3f ms/frame); draw call TB: %.0f -> %.0f (+%.0f), tối đa %.0f -> %.0f" % [
		baseline.frame_ms_sum / baseline.frames, stress.frame_ms_sum / stress.frames,
		stress.frame_ms_sum / stress.frames - baseline.frame_ms_sum / baseline.frames,
		baseline.draw_sum / baseline.frames, stress.draw_sum / stress.frames,
		stress.draw_sum / stress.frames - baseline.draw_sum / baseline.frames, baseline.draw_max, stress.draw_max])
	print("RESULT node CombatFx trước/sau: %d / %d; node cả cây trước/sau: %d / %d" % [nodes_before, nodes_after, tree_nodes_before, tree_nodes_after])
	print("RESULT hạt đồng thời tối đa (ước tính theo pool): %d; vết máu tối đa %d" % [stress.particles_max, CombatFx.get_blood_stains().get_capacity()])
	get_tree().quit()


func _run_phase(label: String, seconds: float, slash: bool) -> Stats:
	var stats := Stats.new()
	var elapsed := 0.0
	var hit_timer := 0.0
	var slash_timer := 0.0
	var toggle := false
	var last_us := Time.get_ticks_usec()
	var hitbox := _player.get_node("Model/Hitbox") as HitboxComponent
	while elapsed < seconds:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		var frame_ms := float(now - last_us) / 1000.0
		last_us = now
		var dt := frame_ms / 1000.0
		elapsed += dt
		if slash:
			hit_timer += dt
			slash_timer += dt
			if slash_timer >= SLASH_PERIOD:
				slash_timer = 0.0
				toggle = not toggle
				hitbox.deactivate()
				hitbox.activate(SLASH_3 if toggle else SLASH_1)
			if hit_timer >= HIT_PERIOD:
				hit_timer = 0.0
				for enemy in _enemies:
					var away := (enemy.global_position - _player.global_position)
					away.y = 0.0
					enemy.hurtbox.set_invincible(0.0)
					enemy.hurtbox.receive_hit(DamageInfo.new(1, DamageInfo.Type.PHYSICAL, away.normalized() * 9.0, _player))
		_apply_hide()
		stats.frames += 1
		stats.frame_ms_sum += frame_ms
		stats.frame_ms_max = maxf(stats.frame_ms_max, frame_ms)
		stats.script_ms_sum += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		stats.physics_ms_sum += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		var draws := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		stats.draw_sum += draws
		stats.draw_max = maxf(stats.draw_max, draws)
		var particles := CombatFx.get_hit_pool().get_active_count() * PARTICLES_HIT_SPARK + CombatFx.get_blood_pool().get_active_count() * PARTICLES_BLOOD + CombatFx.get_death_pool().get_active_count() * PARTICLES_DEATH
		stats.particles_max = maxi(stats.particles_max, particles + PARTICLES_SLASH)
	hitbox.deactivate()
	print("PHASE %s xong" % label)
	return stats


func _report(label: String, s: Stats) -> void:
	print("%s: %d frame, ms/frame TB %.3f (max %.3f), script ms TB %.3f, physics ms TB %.3f, draw call TB %.0f (max %.0f), hạt đồng thời tối đa %d" % [
		label, s.frames, s.frame_ms_sum / s.frames, s.frame_ms_max, s.script_ms_sum / s.frames, s.physics_ms_sum / s.frames,
		s.draw_sum / s.frames, s.draw_max, s.particles_max])


func _count(node: Node) -> int:
	var total := 1
	for child in node.get_children():
		total += _count(child)
	return total


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


## Thử nghiệm cô lập: JUICE_HIDE = danh sách (hit, blood, stains, death, slash) ẩn đi để xem phần nào tốn GPU nhất
func _apply_hide() -> void:
	var hide_list := OS.get_environment("JUICE_HIDE")
	if hide_list.is_empty():
		return
	var parts := hide_list.split(",")
	if "hit" in parts:
		_hide_children(CombatFx.get_hit_pool())
	if "blood" in parts:
		_hide_children(CombatFx.get_blood_pool())
	if "death" in parts:
		_hide_children(CombatFx.get_death_pool())
	if "stains" in parts:
		CombatFx.get_blood_stains().visible = false
	if "slash" in parts:
		_player.get_node("SlashTrail").visible = false


func _hide_children(pool: Node) -> void:
	for child in pool.get_children():
		(child as Node3D).visible = false
