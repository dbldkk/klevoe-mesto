extends Node

func _ready() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("Codex/game-fish-qa"):
		get_tree().quit(98)
		return
	_run.call_deferred()

func _run() -> void:
	Settings.quality = 2
	Settings.grass = 1.0
	var world := (load("res://scenes/world.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(world)
	await get_tree().create_timer(2.0).timeout
	Saves.delete_world("qa_perf")
	Saves.create_world("qa_perf")
	Net.host(18780)
	await get_tree().process_frame
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	Settings.vsync = false
	Settings.max_fps = 0
	Settings.apply_display()
	var p := get_tree().get_first_node_in_group("local_player")
	for spec in [["village", Layout.spawn(), Layout.xform("shop").origin],
		["neon", world.get_node("StripClub").to_global(Vector3(0, 0.2, 2.5)), world.get_node("StripClub").to_global(Vector3(0, 2, -2.8))]]:
		p.global_position = spec[1]
		p.velocity = Vector3.ZERO
		p.fp_camera.look_at(spec[2])
		p.set_physics_process(false)
		for i in 90:
			await get_tree().process_frame
		var frames: Array[float] = []
		var process_ms := 0.0
		var physics_ms := 0.0
		var draws := 0.0
		for i in 180:
			var before := Time.get_ticks_usec()
			await get_tree().process_frame
			frames.append(float(Time.get_ticks_usec() - before) / 1000.0)
			process_ms += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			physics_ms += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
			draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		frames.sort()
		print("PERF: " + JSON.stringify({"scene":spec[0], "median_ms":frames[90], "p95_ms":frames[171],
			"process_ms":process_ms / 180.0,"physics_ms":physics_ms / 180.0,"draw_calls":draws / 180.0,
			"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT)}))
	Net.leave()
	Saves.close_world()
	Saves.delete_world("qa_perf")
	get_tree().quit()
