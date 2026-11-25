extends Node


func _ready() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("Codex/game-fish-qa"):
		get_tree().quit(98)
		return
	_run.call_deferred()


func capture(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://" + file)
	print("CAPTURE: " + ProjectSettings.globalize_path("user://" + file))


func _run() -> void:
	var world := (load("res://scenes/world.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(world)
	await get_tree().create_timer(2.0).timeout
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1600, 900))
	Settings.max_fps = 60
	Settings.apply_display()
	Saves.delete_world("qa_visual")
	Saves.create_world("qa_visual")
	Net.host(18779)
	await get_tree().create_timer(3.0).timeout
	await capture("qa-world.png")
	get_tree().get_first_node_in_group("pause_menu").open()
	get_tree().get_first_node_in_group("guide_ui").open("pause_menu")
	await get_tree().create_timer(0.5).timeout
	await capture("qa-guide.png")
	Net.leave()
	Saves.close_world()
	Saves.delete_world("qa_visual")
	print("VISUAL_RESULT: PASS")
	get_tree().quit()
