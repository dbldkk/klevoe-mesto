extends Node

func _ready() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("Codex/game-fish-qa"):
		get_tree().quit(98)
		return
	_run.call_deferred()

func capture(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://"+file)
	print("CAPTURE: "+ProjectSettings.globalize_path("user://"+file))

func _run() -> void:
	Saves.volume = 0
	Saves.apply_volume()
	Settings.max_fps = 60
	var world := (load("res://scenes/world.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(world)
	await get_tree().create_timer(2).timeout
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1600,900))
	Settings.apply_display()
	Saves.delete_world("qa_new_visual")
	Saves.create_world("qa_new_visual")
	Net.host(18782)
	await get_tree().process_frame
	var p := get_tree().get_first_node_in_group("local_player")
	p.set_physics_process(false)
	p.set_process(false)
	var camera := Camera3D.new()
	camera.fov = 75
	world.add_child(camera)
	camera.make_current()
	var club := world.get_node("StripClub")
	p.global_position = club.to_global(Vector3(0,0.2,3.2))
	camera.global_position = club.to_global(Vector3(0,1.65,3.5))
	camera.look_at(club.to_global(Vector3(0,1.9,-2.6)))
	await get_tree().create_timer(0.6).timeout
	await capture("v13-neon.png")
	club.get_node("BarService").interact(p)
	await get_tree().create_timer(0.3).timeout
	await capture("v13-bar.png")
	get_tree().get_first_node_in_group("store_ui").close()
	var clinic := world.get_node("Clinic")
	p.global_position = clinic.to_global(Vector3(0,0.2,4))
	camera.global_position = clinic.to_global(Vector3(8,4.5,11))
	camera.look_at(clinic.to_global(Vector3(0,1.5,0)))
	await get_tree().create_timer(0.3).timeout
	await capture("v13-clinic.png")
	var m: PlayerMischief = p.get_node("Mischief")
	Inventory.blindness = 1
	m.wear_bucket()
	var goose := world.get_node("Goose")
	goose.set_physics_process(false)
	goose.target_peer = multiplayer.get_unique_id()
	m.prank_mermaid()
	await get_tree().create_timer(1).timeout
	get_tree().get_first_node_in_group("radial_menu").open()
	await get_tree().create_timer(0.2).timeout
	await capture("v13-actions.png")
	get_tree().get_first_node_in_group("radial_menu").close()
	m.remove_bucket()
	Inventory.blindness = 0
	m.answer_prank(false)
	await get_tree().create_timer(1.6).timeout
	Inventory.add_fish(&"perch",1.2)
	m.offer_fish(Inventory.basket.back())
	await get_tree().create_timer(0.2).timeout
	await capture("v13-talking-fish.png")
	m._panel.close()
	var ragdoll := ComicRagdoll.new()
	world.add_child(ragdoll)
	ragdoll.global_position = clinic.to_global(Vector3(0,1,5))
	await get_tree().create_timer(0.5).timeout
	await capture("v13-ragdoll.png")
	Net.leave()
	Saves.close_world()
	Saves.delete_world("qa_new_visual")
	print("MISCHIEF_VISUAL_RESULT: PASS")
	get_tree().quit()
