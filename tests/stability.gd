extends Node

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name")).begins_with("Codex/game-fish-qa"):
		get_tree().quit(98)
		return
	get_tree().create_timer(40.0).timeout.connect(func(): get_tree().quit(96))
	var world = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child(world)
	await get_tree().create_timer(2.0).timeout
	var saves = get_tree().root.get_node("Saves")
	var net = get_tree().root.get_node("Net")
	var settings = get_tree().root.get_node("Settings")
	settings.max_fps = 0
	settings.vsync = false
	settings.quality = 2
	settings.grass = 1.0
	saves.volume = 0
	saves.apply_volume()
	saves.fullscreen = false
	settings.apply_display()
	get_tree().root.size = Vector2i(1280,720)
	saves.create_world("qa_stability_%d" % OS.get_process_id())
	var st = get_tree().get_first_node_in_group("police_station")
	var old_cell: Vector3 = st.to_global(Vector3(-2.3, 0.1, -1.9))
	saves.set_player(saves.profile_id, {"pos": [old_cell.x, old_cell.y, old_cell.z]})
	if net.host(18942) != OK:
		get_tree().quit(97)
		return
	await get_tree().physics_frame
	var p = get_tree().get_first_node_in_group("local_player")
	var old_save_recovered: bool = p.global_position.distance_to(st.exit_point()) < 0.3
	print("LEGACY_CELL_SAVE_RECOVERED ",old_save_recovered)
	p.global_position = Layout.spawn()
	var dig = get_tree().get_first_node_in_group("jail_dig")
	var officers = get_tree().get_nodes_in_group("police")
	for i in range(2):
		officers[i].global_position=p.global_position + Vector3(1+i*0.2,0,0)
		officers[i].report(1,"проверка КПЗ")
	await get_tree().create_timer(1.2).timeout
	var escorts: int = officers.filter(func(o): return o.state==2).size()
	print("ESCORTS ",escorts)
	var arrest = get_tree().get_first_node_in_group("bribe_ui")
	arrest._send("surrender",0,{})
	await get_tree().physics_frame
	var first_arrest: Vector3 = p.global_position
	var overlapping: bool = p.test_move(p.global_transform, Vector3.ZERO, null, 0.001, true)
	print("JAILED ",p.is_jailed()," local ",st.to_local(first_arrest)," overlapping ",overlapping)
	var ok: bool = old_save_recovered and escorts == 1 and p.is_jailed() and not overlapping
	if p.has_method("position_for_save"):
		net.send_snapshot()
		var saved_position: Array = saves.get_player(saves.profile_id).get("pos", [])
		ok = ok and saved_position.size() == 3 and Vector3(saved_position[0], saved_position[1], saved_position[2]).distance_to(st.exit_point()) < 0.01
		var fine_money: int = Inventory.money
		st.jail(1, "повторное задержание")
		ok = ok and Inventory.money == fine_money
	var shape = p.get_node("Collision")
	print("BODY_SHAPE ",shape.position," radius ",shape.shape.radius)
	await get_tree().create_timer(0.25).timeout
	print("AFTER_SETTLE ",st.to_local(p.global_position)," floor ",p.is_on_floor()," focus ",p.focus)
	if p.has_method("position_for_save"):
		ok = ok and p.is_on_floor() and p.focus == dig
		var previous_strokes: int = dig._dug
		# Press the same action as the player. The duty NPC keeps its normal schedule.
		var deadline := Time.get_ticks_msec() + 9000
		while fmod(Time.get_ticks_msec() / 1000.0 + 1.7, 8.0) > 2.0 and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
		var previous_left: float = p.jail_left()
		Input.action_press("interact")
		dig.interact(p)
		await get_tree().create_timer(1.5).timeout
		Input.action_release("interact")
		ok = ok and previous_left - p.jail_left() > 6.0 and dig._dug == previous_strokes + 1
		print("DIG_LEFT ",p.jail_left())
	for spec in [["cell", p.global_position, dig.global_position + Vector3.UP*0.7],["village",Vector3(-44,0.08,14),Vector3(-28,1,17)]]:
		p.global_position=spec[1]
		p.velocity=Vector3.ZERO
		p.head_pitch=-0.35 if spec[0]=="cell" else -0.06
		p.look_at(Vector3(spec[2].x,p.global_position.y,spec[2].z))
		for _i in range(90):
			await get_tree().process_frame
		var dt: Array[float]=[]
		var draws=0.0
		for _i in range(220):
			var start=Time.get_ticks_usec()
			await get_tree().process_frame
			dt.append((Time.get_ticks_usec()-start)/1000.0)
			draws+=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		dt.sort()
		print("MEASURE ",spec[0]," median_ms=",dt[110]," p95_ms=",dt[209]," draws=",draws/220.0)
	if p.has_method("position_for_save"):
		p._jail_t = 0.3
		await get_tree().create_timer(0.5).timeout
		ok = ok and not p.is_jailed() and p.global_position.distance_to(st.exit_point()) < 0.5
		print("STABILITY_RESULT ", "PASS" if ok else "FAIL")
	net.leave()
	get_tree().quit(0 if ok else 1)
