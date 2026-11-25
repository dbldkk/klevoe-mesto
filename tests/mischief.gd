extends Node

var passed := 0
var failed := 0

func check(ok: bool, message: String) -> void:
	if ok:
		passed += 1
		print("PASS: "+message)
	else:
		failed += 1
		push_error("FAIL: "+message)

func _ready() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("Codex/game-fish-qa"):
		get_tree().quit(98)
		return
	get_tree().create_timer(150).timeout.connect(func() -> void: get_tree().quit(99))
	_run.call_deferred()

func _run() -> void:
	var world := (load("res://scenes/world.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var id := "qa_mischief_%d" % OS.get_process_id()
	Saves.create_world(id)
	check(Net.host(18781)==OK,"host starts")
	await get_tree().process_frame
	var player := get_tree().get_first_node_in_group("local_player")
	var m: PlayerMischief = player.get_node("Mischief")
	check(m != null,"local player receives mischief controller")
	var clinic: VillageClinic = get_tree().get_first_node_in_group("clinic")
	check(Layout.placement_problems("hospital").is_empty(),"hospital footprint is dry and clear: "+str(Layout.placement_problems("hospital")))
	var radial := get_tree().get_first_node_in_group("radial_menu")
	Inventory.reset()
	m.on_drink(&"samogon")
	check(Inventory.blindness==1.0 and radial.can_do("doctor"),"moonshine causes blindness and exposes doctor help")
	var snapshot := Inventory.to_dict().duplicate(true)
	Inventory.reset()
	Inventory.from_dict(snapshot)
	check(Inventory.blindness==1.0,"blindness persists through save and load")
	player.global_position = clinic.to_global(Vector3(0,0.2,4))
	clinic.interact(player)
	check(Inventory.blindness==0 and Inventory.health>=80,"hospital cures blindness for free")
	check(not radial.can_do("doctor"),"doctor emergency action hidden after treatment")
	Inventory.add_item("tool",&"bucket")
	Inventory.remove_item("tool",&"bucket")
	m.wear_bucket()
	check(m.bucket_left>0 and radial.can_do("bucket"),"bucket blocks sight and can be removed")
	m.remove_bucket()
	check(m.bucket_left==0 and Inventory.count_of("tool",&"bucket")==1,"removing bucket returns item")
	Inventory.add_fish(&"perch",1.2)
	m.offer_fish(Inventory.basket.back())
	check(Inventory.basket.back().get("talking",false),"talking fish tagged in basket")
	var fish_snapshot := Inventory.to_dict().duplicate(true)
	Inventory.from_dict(fish_snapshot)
	check(Inventory.basket.back().get("talking",false),"talking fish persists across saves")
	m._talking_entry = Inventory.basket.back()
	var count := Inventory.basket.size()
	m.release_fish()
	check(Inventory.basket.size()==count-1,"releasing talking fish removes exactly one fish")
	Inventory.add_fish(&"perch",1.2)
	m.offer_fish(Inventory.basket.back())
	Inventory.money = 500
	m.fry_fish()
	check(Inventory.money==150 and Inventory.basket.is_empty(),"frying witness applies one 350-ruble fine")
	m.fry_fish()
	check(Inventory.money==150,"repeated callback cannot fine player twice")
	var club: NeonClub = world.get_node("StripClub")
	Inventory.money = 2000
	player.global_position = club.to_global(Vector3(0,0.2,6.4))
	club.interact(player)
	check(club._is_inside(player) and Inventory.money==1800,"Neon entry charges cover once")
	club.interact(player)
	check(not club._is_inside(player) and Inventory.money==1800,"Neon exit is free")
	player.global_position = club.to_global(Vector3(0,0.2,2.8))
	club._private_dance(player)
	var private_money := Inventory.money
	club._private_dance(player)
	check(Inventory.money==private_money and club._private_t>0,"private show cannot double-charge")
	club._process(4.2)
	check(not Events.ui_open,"private show restores controls")
	var tips: Array[Node] = []
	for child in club.get_children():
		if child is Interactable and child.get("dancer_idx") != null and child.dancer_idx>=0:
			tips.append(child)
	check(tips.size()==3,"all three tips are Interactable objects")
	var tip: Node3D = tips[1]
	player.global_position = club.to_global(Vector3(-1.6,0.2,-0.3))
	var from: Vector3 = player.global_position+Vector3.UP*1.5
	var query := PhysicsRayQueryParameters3D.create(from,tip.global_position,17)
	query.collide_with_areas = true
	await get_tree().physics_frame
	var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(query)
	check(not hit.is_empty() and hit.collider is Interactable and hit.collider==tip,"player ray reaches a dancer tip zone")
	club._open_tip(1)
	var tip_money := Inventory.money
	club._confirm_tip(50)
	check(Inventory.money==tip_money-50 and club._flourish[1]>0,"dancer tip applies payment and flourish")
	var bar := club.get_node("BarService")
	bar.interact(player)
	var store := get_tree().get_first_node_in_group("store_ui")
	check(store.visible,"Neon bar opens store UI")
	store.close()
	# Shoreline safety, recovery and stable model anchors.
	for npc in get_tree().get_nodes_in_group("npc"):
		if npc is CharacterBody3D:
			var original: Vector3 = NpcMotion.safe_point(npc.global_position)
			npc.set_meta("land_motion",{"safe":original,"check":0.0})
			npc.global_position = Vector3(0,-3,-31)
			NpcMotion.move(npc,1.0/60.0)
			check(npc.global_position.distance_to(original)<0.2,"recover submerged NPC: "+str(npc.name))
	var raised := CharacterModel.new()
	raised.position = Vector3(0,1.3,0)
	world.add_child(raised)
	raised._process(0.25)
	check(is_equal_approx(raised.position.y,1.3),"animation preserves elevated model anchor on slow frames")
	raised.queue_free()
	var goose: AngryGoose = get_tree().get_first_node_in_group("goose")
	goose.set_physics_process(false)
	goose.target_peer = multiplayer.get_unique_id()
	Inventory.goose_loot = [{"kind":"bait","id":"worm","count":2}]
	var worms := Inventory.count_of("bait",&"worm")
	var bread := Inventory.count_of("bait",&"bread")
	goose.pay_off()
	check(Inventory.count_of("bait",&"bread")==bread-1,"goose bribe charges one confirmed piece of bread")
	goose.pay_off()
	check(Inventory.count_of("bait",&"bread")==bread-1,"repeated goose bribe cannot charge again")
	check(goose.target_peer==0 and Inventory.goose_loot.is_empty() and Inventory.count_of("bait",&"worm")==worms+2,"goose accepts bribe and returns loot")
	Inventory.goose_loot = [{"kind":"food","id":"crackers","count":1}]
	snapshot = Inventory.to_dict().duplicate(true)
	Inventory.from_dict(snapshot)
	check(Inventory.goose_loot.size()==1,"stolen goods survive saving")
	m.return_loot()
	# Physical gag has actual bodies and joints, then is cleaned up.
	var prop := ComicRagdoll.new()
	world.add_child(prop)
	check(prop.bodies.size()==6 and prop.get_children().filter(func(c):return c is PinJoint3D).size()==5,"ragdoll uses six physics bodies and five joints")
	prop.queue_free()
	Inventory.drunk = 100
	check(m.try_rocket() and m.stunt_left>0 and Inventory.drunk<99,"100-percent drunkenness launches safe rocket flight")
	m._tick_stunt(4.1)
	check(m.stunt_left==0 and player.global_position.is_finite() and player.global_position.y>Terrain.WATER_Y,"rocket finishes on dry safe landing")
	check(not m.try_rocket(),"rocket cooldown prevents repeated launch")
	var mayhem: VillageMayhem = get_tree().get_first_node_in_group("village_mayhem")
	mayhem.show_pollution(Vector3(0,Terrain.WATER_Y,-31),75)
	check(mayhem.is_polluted(Vector3(0,0,-31)) and not mayhem.is_polluted(Vector3(20,0,-31)),"pollution has a local bounded radius")
	mayhem._process(76)
	check(mayhem.patches.is_empty(),"pollution expires without permanent fishing lock")
	m.prank_mermaid()
	check(is_instance_valid(m._prank_model),"mermaid inspector appears")
	m.answer_prank(false)
	check(not is_instance_valid(m._prank_model),"asking for credentials dismisses prank without losing catch")
	# Audio modes and delayed callback cancellation.
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	wav.data = PackedByteArray([0,0,0,0,0,0,0,0])
	Sfx._play_voice(wav,Vector3.ZERO,0)
	check(not get_tree().get_nodes_in_group("npc_voice").is_empty(),"voice playback is tracked")
	get_tree().get_first_node_in_group("pause_menu").open()
	await get_tree().process_frame
	check(get_tree().get_nodes_in_group("npc_voice").is_empty(),"pause removes playing voice nodes")
	get_tree().get_first_node_in_group("pause_menu").close()
	check(Sfx.speaker_for("Баба Зоя: привет")=="zoya" and Sfx.speaker_for("Ника: спасибо")=="nika","speaker identity survives dialogue UI")
	check(Sfx.voice_stream("fish",PlayerMischief.FISH_PLEA)!=null and Sfx.voice_stream("fish",PlayerMischief.FISH_INSULT)!=null,"talking fish has recorded Chatterbox audio")
	Sfx.babble(Vector3.ZERO,"m",60)
	Sfx.stop_voices()
	await get_tree().create_timer(1.1).timeout
	check(get_tree().get_nodes_in_group("npc_voice").is_empty(),"old delayed babble cannot resume after stop")
	# Exact slot odds over all 216 symbol combinations.
	var wins := 0.0
	var total := 0.0
	for a in CasinoDealer.REELS:
		for b in CasinoDealer.REELS:
			for c in CasinoDealer.REELS:
				var weight: float = a[1]*b[1]*c[1]
				total += weight
				if CasinoDealer._slot_mult([a[0],b[0],c[0]])>0:
					wins += weight
	check(is_equal_approx(wins/total,0.353158),"slot win probability is 35.3158 percent")
	var snack := PlayerMischief.SkySnack.new()
	world.add_child(snack)
	var food := Inventory.count_of("food",&"cheburek")
	snack.collect()
	snack.collect()
	check(snack.taken and Inventory.count_of("food",&"cheburek")==food+1,"surprise gift cannot be collected twice")
	await _test_giant(player)
	Net.leave()
	Saves.close_world()
	Saves.delete_world(id)
	world.queue_free()
	await get_tree().process_frame
	print("MISCHIEF_RESULT: %d passed, %d failed" % [passed,failed])
	get_tree().quit(0 if failed==0 else 1)

func _test_giant(player: Node) -> void:
	var f: FishingController = player.fishing
	var caught := 0
	for kg in [30.0,50.0,70.0]:
		for seed_value in [1,2,3,4]:
			Inventory.reset()
			Inventory.slots[0] = {"kind":"rod","id":&"sea","count":1,"cond":100.0}
			Inventory.drunk = 60
			Inventory.equipped_bait = &"worm"
			f._rng.seed = seed_value
			f._cast_bait = &"worm"
			f._cast_rod_slot = Inventory.held_rod_slot()
			f._land_pos = player.global_position+Vector3(0,0,-27)
			f._hooked_fish = GameData.get_fish(&"tsar")
			f._hooked_kg = kg
			f._hook()
			for frame in 7200:
				Input.action_release("move_left")
				Input.action_release("move_right")
				if f.dash_dir<0:
					Input.action_press("move_right")
				elif f.dash_dir>0:
					Input.action_press("move_left")
				if f.jump_time>0 or f.tension>84:
					Input.action_release("fish_action")
				else:
					Input.action_press("fish_action")
				f._update_fight(1.0/60.0,false)
				if f.state!=FishingController.State.FIGHT:
					break
			var success := Inventory.basket.any(func(e):return e.id==&"tsar")
			caught += 1 if success else 0
			check(success,"Poseidon lands Tsar %.0f kg, seed %d" % [kg,seed_value])
			f.cancel()
			Input.action_release("fish_action")
			Input.action_release("move_left")
			Input.action_release("move_right")
			Sfx.stop_world_audio()
			await get_tree().process_frame
	check(caught==12,"all twelve skill-controlled giant fights succeed")
