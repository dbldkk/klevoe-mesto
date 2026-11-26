extends Node
## Run in an isolated QA profile. This node survives the normal world reload.
const CYCLES := 6
var start_msec := 0

func _ready() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name")).begins_with("Codex/game-fish-qa"):
		get_tree().quit(98)
		return
	_run.call_deferred()

func _run() -> void:
	start_msec = Time.get_ticks_msec()
	var tree := get_tree()
	tree.create_timer(210).timeout.connect(func(): tree.quit(96))
	Saves.fullscreen = false
	Settings.max_fps = 60
	Settings.apply_display()
	var world: Node = load("res://scenes/world.tscn").instantiate()
	tree.root.add_child(world)
	tree.current_scene = world
	await tree.create_timer(1.0).timeout
	var file := ""
	var peaks: Array[float] = []
	var saved_money := -1
	for cycle in CYCLES:
		if cycle == 0:
			assert(Saves.create_world("qa_endurance_%d" % OS.get_process_id()) == "")
			file = Saves.world_file
		else:
			assert(Saves.load_world(file))
		assert(Net.host(18950) == OK)
		await tree.create_timer(1.0).timeout
		var p := tree.get_first_node_in_group("local_player")
		if saved_money >= 0:
			assert(Inventory.money == saved_money)
		var shop := tree.get_first_node_in_group("shop") as Node3D
		p.global_position = shop.to_global(Vector3(0,0.2,3))
		var item := shop.get_node("Item0_beer")
		Inventory.money = 1000 + cycle
		item.interact(p)
		shop.get_node("Cashier").interact(p)
		assert(Inventory.cart.is_empty())
		await tree.create_timer(1.0).timeout
		var clinic := tree.get_first_node_in_group("clinic") as Node3D
		p.global_position = clinic.to_global(Vector3(0,0.2,4))
		var m := p.get_node("Mischief")
		m.on_drink(&"samogon")
		clinic.interact(p)
		assert(Inventory.blindness == 0)
		m.prank_mermaid()
		await tree.create_timer(2.0).timeout
		m.start_ragdoll()
		if cycle % 2 == 0:
			await tree.create_timer(3.0).timeout
			var station := tree.get_first_node_in_group("police_station")
			station.jail(1,"проверка стабильности")
			assert(p.is_jailed())
		peaks.append(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0)
		var previous: WeakRef = weakref(tree.current_scene)
		saved_money = Inventory.money
		Net.exit_to_menu()
		await tree.create_timer(2.0).timeout
		assert(previous.get_ref() == null)
		assert(not Net.is_online() and tree.get_first_node_in_group("local_player") == null)
		assert(tree.get_nodes_in_group("npc_voice").is_empty())
		print("ENDURANCE_CYCLE ",cycle+1,"/",CYCLES," static_mib=",peaks[-1])
	print("ENDURANCE_PASS renderer=",RenderingServer.get_current_rendering_method()," elapsed_s=",(Time.get_ticks_msec()-start_msec)/1000.0)
	Net.quit_game()
