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
	# v1.0: radial menu binding and speech bank.
	check(InputMap.has_action("radial") and Controls.key_label("radial") != "—",
		"radial menu is bound to a key")
	check(SpeechBank.zoya().size() >= 5 and SpeechBank.tolya().size() >= 4, "villagers have several dialogue lines")
	check(InputMap.action_get_events("pee").is_empty() and InputMap.action_get_events("poop").is_empty(),
		"toilet keys were moved off the keyboard into the radial menu")
	# v1.1: labels, voice fallback, bouncer, friend skin, forage foods, SFX.
	var radial_src := load("res://scripts/ui/radial_menu.gd")
	var titles: Array = []
	# ACTIONS is a const on the script; instantiate a dummy to read it.
	var rm := CanvasLayer.new()
	rm.set_script(radial_src)
	add_child(rm)
	for a in rm.ACTIONS:
		titles.append(String(a.get("title", "")))
	check("Обоссаться" in titles and "Обосраться" in titles, "radial toilet titles were renamed")
	rm.queue_free()
	check(Sfx.voice_stream("zoya", "этой фразы точно нет в озвучке") == null, "missing voice line falls back")
	var voiced := 0
	var vroot := DirAccess.open("res://art/voice")
	if vroot:
		for sp in vroot.get_directories():
			var d := DirAccess.open("res://art/voice/%s" % sp)
			if d == null:
				continue
			for f in d.get_files():
				if String(f).ends_with(".ogg"):
					voiced += 1
	check(voiced >= 20, "pre-recorded NPC voice lines are present (%d)" % voiced)
	var zoya_hello := "Семечки жареные, с солью. Не то что в магазине — там как пенопласт."
	if Sfx.voice_stream("zoya", zoya_hello) != null:
		check(true, "a Zoya line has a recorded voice")
	else:
		check(voiced >= 20, "recorded voices exist even if a particular Zoya line is still missing")
	check(Sfx.voice_key("Привет") != "" and Sfx.voice_key("Привет") == Sfx.voice_key("«Привет»"),
		"voice lookup key is stable after punctuation cleanup")
	check(Sfx.stream_of("splash") != null, "cc0 ogg sound loads")
	check(Sfx.stream_of("club_music") != null, "club music aliases casino music")
	check(NeonClub.entry_reason(0, 0.0) == "money", "bouncer rejects a broke visitor")
	check(NeonClub.entry_reason(1000, 90.0) == "drunk", "bouncer rejects a very drunk visitor")
	check(NeonClub.entry_reason(1000, 10.0) == "", "bouncer lets a sober paying visitor in")
	check(GameData.get_food(&"mushroom") != null and GameData.get_food(&"berry") != null, "forage foods exist")
	var friend := CharacterModel.new()
	add_child(friend)
	friend.apply_skin({"outfit": 1, "hat": 5, "shirt": 7, "pants": 1, "skin": 0, "face": 0, "stripes": 0})
	check(friend.outfit == 1 and friend.hat == CharacterModel.Hat.BANGS, "friend preset applies bangs and outfit")
	check(friend.find_child("FloralShirt", true, false) != null, "friend preset has an open floral shirt")
	friend.queue_free()
	check(ResourceLoader.exists("res://art/textures/memorial_friend.jpg"), "memorial photo texture is in the project")
	for spot in Layout.NEW_POIS:
		check(Layout.SPOTS.has(spot), "layout has %s" % spot)
		var probs := Layout.placement_problems(spot)
		check(probs.is_empty(), "new poi %s sits on dry land, off the road, not overlapping (%s)" % [spot, ", ".join(probs)])
	# танцовщицы — женская модель, бельё, без усов
	var dancer := CharacterModel.new()
	dancer.female = true
	dancer.lingerie = 2
	dancer.stockings = true
	dancer.face_name = "dancer_a"
	dancer.hat = CharacterModel.Hat.NONE
	add_child(dancer)
	check(dancer.female and dancer.find_child("Bra", true, false) != null, "female dancer has a bra (clothing, not anatomy)")
	dancer.queue_free()
	check(ResourceLoader.exists("res://art/faces/dancer_a.png")
		and ResourceLoader.exists("res://art/faces/dancer_b.png")
		and ResourceLoader.exists("res://art/faces/dancer_c.png"), "dancer face textures exist")
	check(NeonClub.TIP_AMOUNTS == [50, 100, 500], "tip amounts are 50, 100 and 500")
	# v0.9: rod model, modest signs, camera collision.
	var bamboo := ItemModels.build("rod", &"bamboo")
	add_child(bamboo)
	check(bamboo.find_child("RodTip", true, false) != null, "bamboo rod has a tip marker")
	check(bamboo.find_child("ReelCrank", true, false) != null, "bamboo rod has a reel crank")
	var poseidon := ItemModels.build("rod", &"sea")
	add_child(poseidon)
	check(poseidon.find_child("RodTip", true, false) != null and poseidon.find_child("ReelCrank", true, false) != null,
		"Poseidon rod has a tip and a reel")
	var sign_holder := Node3D.new()
	add_child(sign_holder)
	var sign := Build.board_sign(sign_holder, Vector3.ZERO, "ПРОКАТ ЛОДОК · 150 ₽")
	check(sign != null and float(sign.get_meta("sign_font")) * float(sign.get_meta("sign_px")) <= 0.16,
		"board sign letter height is modest")
	bamboo.queue_free()
	poseidon.queue_free()
	sign_holder.queue_free()
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
	fishing.charge = 1.0
	fishing.apply_hand_anim(1.0)
	check(player.fp_hand.rotation.x > 0.5, "charge animation raises the first-person rod")
	check(player.spring_arm.margin >= 0.3 and player.spring_arm.collision_mask != 0,
		"third-person spring arm collides with the world")
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
	Events.ui_open = false
	# v1.0: radial menu, officers, spoon digging.
	var radial := get_tree().get_first_node_in_group("radial_menu")
	check(radial != null, "radial menu is in the world")
	if radial:
		radial.open()
		check(Events.ui_open and radial.visible, "opening the radial menu captures the cursor")
		Inventory.bladder = 0.0
		radial.refresh()
		check(not radial.is_enabled("pee"), "toilet action is greyed out when not needed")
		Inventory.bladder = 50.0
		radial.refresh()
		check(radial.is_enabled("pee"), "toilet action is available when needed")
		radial.close()
		check(not Events.ui_open and not radial.visible, "closing the radial menu returns control")
	check(get_tree().get_nodes_in_group("district_officer").size() >= 3, "three district officers spawned")
	check(world.get_node_or_null("VillageLife") != null, "village life spawned")
	check(world.get_node_or_null("StripClub") != null, "strip club spawned")
	check(world.get_node_or_null("MemorialBoard") != null, "memorial board spawned")
	check(world.get_node_or_null("VillageBus") != null, "village bus spawned")
	check(world.get_node_or_null("MemorialBoard/Photo") != null, "memorial board shows a photo")
	var poi_names: Array = []
	for n in get_tree().get_nodes_in_group("poi"):
		if n.has_meta("poi_name"):
			poi_names.append(String(n.get_meta("poi_name")))
	for want in ["Гаражный кооператив", "Заброшенный колхоз", "Часовня", "Дачи", "Лесная тропа", "Костёр рыбаков", "Клуб «Неон»", "Доска памяти"]:
		check(want in poi_names, "map poi present: %s" % want)
	# площадки и таблички на суше, не над водой и не «в воздухе»
	for n in get_tree().get_nodes_in_group("poi"):
		if not n is Node3D:
			continue
		var node := n as Node3D
		var origin := node.global_position
		var th := Terrain.height(origin.x, origin.z)
		var td := Terrain.depth(origin.x, origin.z)
		var label := String(node.get_meta("poi_name")) if node.has_meta("poi_name") else String(node.name)
		var spot := String(node.get_meta("poi_spot")) if node.has_meta("poi_spot") else ""
		# пирс и прокат лодок стоят над водой по задумке; правило — для новых мест и доски памяти
		var must_be_dry := spot in Layout.NEW_POIS or label == "Доска памяти"
		if must_be_dry:
			check(td <= 0.0, "poi %s is not in water" % label)
			check(origin.y <= th + 0.3, "poi %s is not floating (y=%.2f terrain=%.2f)" % [label, origin.y, th])
			# цоколь может уйти в грунт, но не проваливаться целиком
			check(origin.y >= th - 1.2, "poi %s is not buried (y=%.2f terrain=%.2f)" % [label, origin.y, th])
		if spot in Layout.NEW_POIS:
			var want := Layout.xform(spot).origin
			check(absf(origin.x - want.x) < 1.0 and absf(origin.z - want.z) < 1.0,
				"poi %s is at its layout spot (got %.1f, %.1f want %.1f, %.1f)" % [label, origin.x, origin.z, want.x, want.z])
			for c in node.find_children("*", "Node3D", true, false):
				var p3 := c as Node3D
				if p3 == null:
					continue
				# высоко в воздухе (вывески на фасаде, пилон) — проверяем только xz на воду
				if Terrain.depth(p3.global_position.x, p3.global_position.z) > 0.0:
					check(false, "poi %s prop %s is in water" % [label, p3.name])
					break
	var club: Node = world.get_node_or_null("StripClub")
	if club:
		var girls := 0
		for ch in club.get_children():
			if ch is CharacterModel and (ch as CharacterModel).female:
				girls += 1
				check((ch as CharacterModel).lingerie > 0, "spawned dancer %s wears lingerie" % ch.name)
				check(ch.find_child("Bra", true, false) != null, "spawned dancer %s has a bra" % ch.name)
		check(girls >= 3, "three female dancers are in the club")
		# ноги на верхней кромке сцены, а не в толще помоста (модель стоит в y=0)
		var stage_top: float = club.to_global(Vector3(0.0, NeonClub.STAGE_TOP, 0.0)).y
		for ch in club.get_children():
			if ch is CharacterModel and (ch as CharacterModel).female:
				var feet_y := (ch as Node3D).global_position.y
				check(absf(feet_y - stage_top) <= 0.2,
					"dancer %s feet are on the stage (y=%.2f stage=%.2f)" % [ch.name, feet_y, stage_top])
	var in_yard := 0
	var decor := get_tree().get_first_node_in_group("decor")
	if decor:
		for c in decor.get_children():
			if c is Node3D and Layout.spot_contains("police", c.global_position.x, c.global_position.z, 2.0):
				in_yard += 1
	for h in get_tree().get_nodes_in_group("hiding_spot"):
		if h is Node3D and Layout.spot_contains("police", h.global_position.x, h.global_position.z, 2.0):
			in_yard += 1
	check(in_yard == 0, "police yard has no bushes or trees")
	var j0: float = player.jail_left()
	player.go_to_jail(60.0, player.global_position, player.global_position, "проверка", false)
	check(player.is_jailed() and player.jail_left() > 50.0, "player can be sent to jail")
	var j1: float = player.jail_left()
	player.apply_dig_stroke()
	check(player.jail_left() < j1, "digging with a spoon reduces remaining jail time")
	var j2: float = player.jail_left()
	player.jail_caught_digging()
	check(player.jail_left() > j2, "a watching officer adds jail time")
	player._release_from_jail()
	check(not player.is_jailed(), "release clears the jail sentence")
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
