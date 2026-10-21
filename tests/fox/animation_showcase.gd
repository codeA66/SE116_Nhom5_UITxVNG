extends Node3D


func _ready() -> void:
    _capture.call_deferred()


func _capture() -> void:
    var environment := WorldEnvironment.new()
    environment.environment = Environment.new()
    environment.environment.background_mode = Environment.BG_COLOR
    environment.environment.background_color = Color(0.08, 0.095, 0.115)
    environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.environment.ambient_light_color = Color.WHITE
    environment.environment.ambient_light_energy = 0.55
    add_child(environment)
    var floor_mesh := MeshInstance3D.new()
    var plane := PlaneMesh.new()
    plane.size = Vector2(200, 200)
    floor_mesh.mesh = plane
    var floor_material := StandardMaterial3D.new()
    floor_material.albedo_color = Color(0.12, 0.14, 0.17)
    floor_material.roughness = 1.0
    floor_mesh.material_override = floor_material
    floor_mesh.position.y = -0.012
    add_child(floor_mesh)
    var light := DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-50, -30, 0)
    light.light_energy = 0.9
    light.shadow_enabled = true
    add_child(light)
    var player := (load("res://entities/player/player.tscn") as PackedScene).instantiate() as Player
    player.set("preview_sword", true)
    add_child(player)
    player.set_physics_process(false)
    (player.get_node("HUD") as CanvasLayer).visible = false
    var camera := Camera3D.new()
    add_child(camera)
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 2.25
    camera.position = Vector3(3.0, 2.1, 4.5)
    camera.look_at(Vector3(0, 0.85, 0))
    camera.current = true
    camera.reset_physics_interpolation()
    var animation := player.get_node("AnimationPlayer") as AnimationPlayer
    var specs := {&"Idle_Sword": 36, &"Run_Sword": 24}
    for clip: StringName in specs:
        var count: int = specs[clip]
        animation.play(StringName("fox/" + clip))
        animation.speed_scale = 0.0
        var duration := animation.get_animation(StringName("fox/" + clip)).length
        for frame in count:
            animation.seek(duration * frame / count, true)
            await get_tree().process_frame
            await RenderingServer.frame_post_draw
            var image := get_viewport().get_texture().get_image()
            # Ảnh kiểm tra ghi ra user:// để không sinh file rác trong project
            DirAccess.make_dir_recursive_absolute("user://fox_diagnostics/motion")
            image.save_png("user://fox_diagnostics/motion/%s_%02d.png" % [clip, frame])
    print("ANIMATION_SHOWCASE_CAPTURED")
    get_tree().quit()
