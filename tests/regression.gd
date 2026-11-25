extends Node

var failed := 0
var passed := 0


func check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("PASS: " + message)
	else:
		failed += 1
		push_error("FAIL: " + message)


func _ready() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("Codex/game-fish-qa"):
		push_error("Tests require an isolated QA user directory; see tests/README.txt")
		get_tree().quit(98)
		return
	get_tree().create_timer(90.0).timeout.connect(func() -> void: get_tree().quit(99))
	_run.call_deferred()


func fill() -> void:
	Inventory.reset()
	Inventory.slots.fill(null)
	for i in Inventory.SLOTS:
		Inventory.slots[i] = {"kind": "rod", "id": &"bamboo", "count": 1, "cond": 100.0}
	Inventory.money = 100000


func _run() -> void:
	# Shopping: actual pack sizes, mixed stacks, no loss on failed payment.
	fill()
	Inventory.slots[26] = null
	Inventory.cart = [{"kind": "rod", "id": &"bamboo"}]
	check(Inventory.pay_cart() and Inventory.slots[26] != null, "last free slot accepts one rod")
	fill()
	Inventory.slots[26] = {"kind": "bait", "id": &"bread", "count": 1}
	Inventory.cart = [{"kind": "bait", "id": &"bread"}]
	check(Inventory.pay_cart() and Inventory.count_of("bait", &"bread") > 1, "full backpack accepts a matching stack")
	fill()
	Inventory.slots[26] = null
	Inventory.cart = [{"kind": "drink", "id": &"beer"}, {"kind": "food", "id": &"crackers"}]
	var before := Inventory.to_dict().duplicate(true)
	check(not Inventory.pay_cart(), "mixed products need two free slots")
	check(Inventory.to_dict() == before and Inventory.cart.size() == 2, "failed checkout preserves money, items and cart")
	fill()
	Inventory.slots[26] = {"kind": "smoke", "id": &"cigs", "count": 30}
	Inventory.cart = [{"kind": "smoke", "id": &"cigs"}]
	check(not Inventory.pay_cart(), "a whole cigarette pack must fit")
	Inventory.slots[25] = null
	check(Inventory.pay_cart() and Inventory.count_of("smoke", &"cigs") == 50, "pack splits between existing and new stacks")
	check(not Inventory.add_item("drink", &"missing") and not Inventory.add_item("bait", &"bread", -2), "invalid additions rejected")
	check(not Inventory.remove_item("bait", &"bread", -2), "negative removal rejected")
	check(not Inventory.add_item("tool", &"cigs"), "misc item kind must match")
	Inventory.reset()
	Inventory.add_fish(&"perch", 1.25)
	var snapshot := Inventory.to_dict().duplicate(true)
	Inventory.from_dict(snapshot)
	check(Inventory.to_dict() == snapshot, "inventory and records survive round trip")
	Inventory.remove_item("bait", &"bread", Inventory.get_bait_count(&"bread"))
	var observed_bait: Array = []
	var bait_listener := func() -> void: observed_bait.append(Inventory.equipped_bait)
	Inventory.changed.connect(bait_listener)
	Inventory._auto_bait()
	Inventory.changed.disconnect(bait_listener)
	check(observed_bait.back() == &"worm", "HUD notified after automatic bait switch")
	# Save twice, damage primary, recover backup, then save again without destroying it.
	var save_name := "qa_%d" % OS.get_process_id()
	check(Saves.create_world(save_name) == "", "create world on disk")
	Saves.set_section("probe", {"value": 1})
	check(Saves.save_world(), "replace primary and create backup")
	Saves.set_section("probe", {"value": 2})
	check(Saves.save_world(), "replace existing backup")
	var path := Saves.WORLDS_DIR + save_name + ".json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{broken")
	f.close()
	Saves.close_world()
	check(Saves.load_world(save_name) and Saves.get_section("probe").get("value") == 1, "damaged primary recovers previous valid state")
	check(Saves.save_world(), "recovered world saves successfully")
	check(Saves._read_json(path + ".bak").get("probe", {}).get("value") == 1, "recovery preserves good backup")
	DirAccess.remove_absolute(path)
	check(Saves.list_worlds().any(func(w): return w.file == save_name), "backup-only world remains in menu")
	check(Saves.load_world(save_name), "backup-only world loads")
	check(not Saves.load_world("../escape"), "world path stays in worlds directory")
	Saves.close_world()
	Saves.delete_world(save_name)
	check(not FileAccess.file_exists(path + ".bak"), "deleting a world removes its backup")
	# Real world integration: host, persisted nets, rod switching, modal behavior.
	Inventory.reset()
	var world_scene := load("res://scenes/world.tscn") as PackedScene
	var world := world_scene.instantiate()
	get_tree().root.add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var world_id := "qa_world_%d" % OS.get_process_id()
	check(Saves.create_world(world_id) == "", "integration world created")
	Saves.set_section("nets", {"list": [["QA Fisher", 0.0, 0.0, [["perch", 1.0]]]]})
	check(Net.host(18777) == OK, "ENet host starts")
	await get_tree().process_frame
	var nets := get_tree().get_first_node_in_group("nets")
	check(nets._nets.size() == 1 and nets._vis.size() == 1, "saved net and catch restored when hosting")
	var player := get_tree().get_first_node_in_group("local_player")
	check(player != null, "host player spawned")
	var guide := get_tree().get_first_node_in_group("guide_ui")
	var pause := get_tree().get_first_node_in_group("pause_menu")
	pause.open()
	guide.open("pause_menu")
	guide.close()
	check(Events.ui_open and pause.visible, "closing guide preserves pause and mouse state")
	pause.close()
	Inventory.select(0)
	var fishing: FishingController = player.fishing
	fishing._try_start_charge()
	check(fishing.state == FishingController.State.CHARGING, "fishing charge starts with starter gear")
	var bread := Inventory.get_bait_count(&"bread")
	var worms := Inventory.get_bait_count(&"worm")
	Inventory.equip_bait(&"worm")
	fishing._hooked_fish = GameData.get_fish(&"perch")
	fishing._hooked_kg = 0.5
	fishing._hook()
	check(Inventory.get_bait_count(&"bread") == bread - 1 and Inventory.get_bait_count(&"worm") == worms,
		"hook consumes bait from cast rather than newly selected bait")
	fishing.cancel()
	fishing._try_start_charge()
	Inventory.add_item("rod", &"telescopic")
	Inventory.move_slot(0, 6)
	Inventory.move_slot(5, 0)
	fishing._update_local(0.01)
	check(fishing.state == FishingController.State.IDLE, "swapping rods cancels active cast")
	Inventory.select(6)
	fishing._try_start_charge()
	Events.ui_open = true
	fishing._update_local(0.01)
	check(fishing.state == FishingController.State.IDLE, "opening UI cancels charging instead of casting")
	var original_file := Saves.world_file
	Saves.world_file = "missing/subdirectory"
	await Net.exit_to_menu()
	check(Net.is_online() and not Net._exiting and pause.visible, "failed save prevents leaving the world")
	Saves.world_file = original_file
	Events.ui_open = false
	Net.leave()
	Saves.close_world()
	Saves.delete_world(world_id)
	world.queue_free()
	await get_tree().process_frame
	print("RESULT: %d passed, %d failed" % [passed, failed])
	get_tree().quit(0 if failed == 0 else 1)
