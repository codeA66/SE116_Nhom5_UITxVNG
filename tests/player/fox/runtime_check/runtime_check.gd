extends Node
## Kiểm tra scene thực, không thay đổi tiến trình hoặc file save.

@export var check_main_player: bool = false

var _failed: bool = false


func _ready() -> void:
    _run.call_deferred()


func _check(condition: bool, label: String) -> void:
    if condition:
        print("PASS ", label)
    else:
        push_error("FAIL " + label)
        _failed = true


func _frames(count: int) -> void:
    for index in count:
        await get_tree().physics_frame


func _run() -> void:
    var demo := (load("res://tests/player/fox/fox_demo.tscn") as PackedScene).instantiate()
    if check_main_player:
        var old_player := demo.get_node("Player")
        demo.remove_child(old_player)
        old_player.free()
        var main_player := (load("res://entities/player/player.tscn") as PackedScene).instantiate()
        main_player.set("preview_sword", true)
        main_player.set("preview_dash", true)
        demo.add_child(main_player)
    get_tree().root.add_child(demo)
    get_tree().current_scene = demo
    await _frames(12)
    var player := demo.get_node("Player") as Player
    var animation := player.get_node("AnimationPlayer") as AnimationPlayer
    var skeleton := player.model.find_child("Skeleton3D", true, false) as Skeleton3D
    var sword := player.model.find_child("Sword", true, false) as MeshInstance3D
    var foxy := player as FoxyPlayer
    _check(foxy != null, "player uses FoxyPlayer")
    _check(skeleton != null and skeleton.find_bone(foxy.bow_hand_bone) >= 0, "Foxy rig has bow hand bone")
    _check(sword != null and sword.visible, "preview sword visible without changing save")
    for bow_clip: StringName in [&"foxy/Idle_Bow", &"foxy/Run_Bow", &"foxy/Bow_Shoot"]:
        _check(animation.has_animation(bow_clip), "bow clip " + String(bow_clip))
    for entry: AnimationMarker in foxy.animation_markers.markers:
        var marked := StringName("foxy/" + String(entry.clip))
        _check(animation.has_animation(marked) and animation.get_animation(marked).has_marker(entry.marker), "marker %s on %s" % [entry.marker, entry.clip])
    player.set_physics_process(false)
    for clip: StringName in animation.get_animation_list():
        animation.play(clip)
        animation.seek(0.0, true)
        var first: Array[Quaternion] = []
        var first_positions: Array[Vector3] = []
        for bone in skeleton.get_bone_count():
            first.append(skeleton.get_bone_pose_rotation(bone))
            first_positions.append(skeleton.get_bone_pose_position(bone))
        animation.seek(animation.get_animation(clip).length * 0.27, true)
        var changed := false
        for bone in skeleton.get_bone_count():
            if absf(first[bone].dot(skeleton.get_bone_pose_rotation(bone))) < 0.99999:
                changed = true
            if first_positions[bone].distance_to(skeleton.get_bone_pose_position(bone)) > 0.0001:
                changed = true
        _check(changed, "bone motion " + String(clip))
    player.set_physics_process(true)
    player.state_machine.transition_to(PlayerState.IDLE)
    await _frames(3)
    Input.action_press("move_right")
    await _frames(12)
    _check(player.state_machine.current_state.name == PlayerState.RUN, "movement enters Run")
    Input.action_press("jump")
    await _frames(2)
    _check(player.velocity.y > 0.0, "jump lifts player")
    Input.action_release("jump")
    Input.action_release("move_right")
    await _frames(100)
    _check(player.is_on_floor(), "jump returns to floor")
    Input.action_press("dash")
    await _frames(2)
    _check(player.state_machine.current_state.name == PlayerState.DASH, "dash state")
    Input.action_release("dash")
    await _frames(30)
    player.face_instantly(Vector3.FORWARD)
    var dummy := (load("res://objects/combat/training_dummy/training_dummy.tscn") as PackedScene).instantiate()
    demo.add_child(dummy)
    dummy.global_position = player.global_position + player.get_facing_direction() * 1.1
    await _frames(5)
    var health := dummy.get_node("HealthComponent") as HealthComponent
    var before := health.current_health
    Input.action_press("attack")
    await _frames(2)
    _check(animation.current_animation == &"foxy/Attack_1", "FSM plays first slash")
    Input.action_release("attack")
    # Chờ hết 0.6 s của đòn đánh, cộng phần thời gian bị hitstop làm chậm.
    await _frames(55)
    _check(health.current_health < before, "slash active frames damage target")
    _check(player.state_machine.current_state.name == PlayerState.IDLE, "slash recovers to Idle")
    print("GENERATED_RUNTIME_CHECK ", "FAILED" if _failed else "PASSED")
    if DisplayServer.get_name() != "headless":
        player.teleport(Vector3(-8.0, 0.0, -8.0))
        player.face_instantly(Vector3.BACK)
        var camera := player.get_node("CameraRig/Camera3D") as Camera3D
        camera.global_position = player.global_position + Vector3(3.0, 3.2, 5.0)
        camera.look_at(player.global_position + Vector3.UP * 0.9)
        camera.reset_physics_interpolation()
        await _frames(4)
        await get_tree().process_frame
        await RenderingServer.frame_post_draw
        get_tree().root.get_texture().get_image().save_png("user://fox_preview_game.png")
    get_tree().quit(1 if _failed else 0)

