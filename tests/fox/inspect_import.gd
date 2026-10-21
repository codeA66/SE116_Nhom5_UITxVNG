extends SceneTree


func _initialize() -> void:
    var packed := load("res://assets/characters/fox/fox_spirit.glb") as PackedScene
    if packed == null:
        quit(1)
        return
    var model := packed.instantiate()
    root.add_child(model)
    model.print_tree_pretty()
    for node in model.find_children("*", "AnimationPlayer", true, false):
        var player := node as AnimationPlayer
        print("ANIMATION_ROOT ", player.root_node)
        print("CLIPS ", player.get_animation_list())
        var clip := player.get_animation(&"Idle_Sword")
        print("FIRST_TRACK ", clip.track_get_path(0))
    model.queue_free()
    quit()

