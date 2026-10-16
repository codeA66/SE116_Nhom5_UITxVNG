extends Node3D


func _ready() -> void:
    _capture.call_deferred()


func _capture() -> void:
    var demo := (load("res://generated/fox_demo.tscn") as PackedScene).instantiate()
    add_child(demo)
    for index in 10:
        await get_tree().physics_frame
    var player := demo.get_node("Player") as Player
    player.teleport(Vector3(-8.0, 0.0, -8.0), Vector3.BACK)
    player.set_physics_process(false)
    var animation := player.get_node("AnimationPlayer") as AnimationPlayer
    var camera := player.get_node("CameraRig/Camera3D") as Camera3D
    var suffix := "before"
    for arg in OS.get_cmdline_user_args():
        suffix = arg
    if suffix == "no_shadow":
        for node in player.model.find_children("*", "MeshInstance3D", true, false):
            var mesh := node as MeshInstance3D
            mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            var material := mesh.get_active_material(0) as BaseMaterial3D
            print("MATERIAL ", material.resource_name, " TRANSPARENCY ", material.transparency)
            for property in material.get_property_list():
                if "shadow" in String(property.name) or "texture_filter" in String(property.name):
                    print(property.name, " = ", material.get(property.name))
    if suffix == "nearest":
        for node in player.model.find_children("*", "MeshInstance3D", true, false):
            var mesh := node as MeshInstance3D
            var material := mesh.get_active_material(0).duplicate() as BaseMaterial3D
            material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
            mesh.material_override = material
            print("CHECK_MESH ", mesh.name, " ALBEDO ", material.albedo_color, " VCOLOR ", material.vertex_color_use_as_albedo)
            var pixels := material.albedo_texture.get_image()
            if pixels.is_compressed():
                pixels.decompress()
            print("TEX ", pixels.get_size(), " MIPS ", pixels.has_mipmaps(), " COLORS ", pixels.get_pixel(0, 0), pixels.get_pixel(1, 0), pixels.get_pixel(2, 0))
            var array_mesh := mesh.mesh as ArrayMesh
            var arrays := array_mesh.surface_get_arrays(0)
            var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
            var values: Dictionary = {}
            for uv in uvs:
                values[str(uv)] = true
            print("UVS ", values.keys())
    for clip in ["Idle_Sword", "Run_Sword"]:
        for time in [0.0, 0.2, 0.4, 0.6]:
            animation.play("fox/" + clip)
            animation.seek(time, true)
            animation.speed_scale = 0.0
            camera.global_position = player.global_position + Vector3(0.0, 38.3, 32.14)
            camera.look_at(player.global_position + Vector3.UP * 0.85)
            camera.reset_physics_interpolation()
            for frame in 3:
                await get_tree().process_frame
            await RenderingServer.frame_post_draw
            var path := "res://generated/diagnostics/%s_%s_%02d.png" % [suffix, clip, int(time * 100)]
            var captured := get_viewport().get_texture().get_image()
            captured.save_png(path)
            var detail := captured.get_region(Rect2i(590, 300, 100, 120))
            detail.resize(400, 480, Image.INTERPOLATE_NEAREST)
            detail.save_png(path.replace(".png", "_detail.png"))
    if suffix == "after":
        var comparison := Image.create(640, 768, false, Image.FORMAT_RGBA8)
        for row in 2:
            var clip := "Idle_Sword" if row == 0 else "Run_Sword"
            for column in 2:
                var version := "before" if column == 0 else "after"
                var image := Image.load_from_file(ProjectSettings.globalize_path("res://generated/diagnostics/%s_%s_20.png" % [version, clip]))
                var crop := image.get_region(Rect2i(590, 300, 100, 120))
                crop.resize(320, 384, Image.INTERPOLATE_NEAREST)
                comparison.blit_rect(crop, Rect2i(0, 0, 320, 384), Vector2i(column * 320, row * 384))
        comparison.save_png("res://generated/diagnostics/import_comparison.png")
    get_tree().quit()

