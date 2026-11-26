extends Node

var host_mode := false
var done := false
var saw_client := false
var failed := false
var world_id := "qa_coop"
var nets: Node
var started := 0
var second_connection := false
var client_stage := 0
var phase_start := 0


func check(condition: bool, message: String) -> void:
	print(("PASS: " if condition else "FAIL: ") + message)
	failed = failed or not condition


func _ready() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("Codex/game-fish-qa"):
		push_error("Tests require an isolated QA user directory; see tests/README.txt")
		get_tree().quit(98)
		return
	host_mode = "--qa-host" in OS.get_cmdline_user_args()
	Saves.profile_id = "qa_coop_host" if host_mode else "qa_coop_client"
	Net.player_name = "QA Host" if host_mode else "QA Client"
	var world := (load("res://scenes/world.tscn") as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(world)
	_begin.call_deferred()


func _begin() -> void:
	await get_tree().process_frame
	nets = get_tree().get_first_node_in_group("nets")
	started = Time.get_ticks_msec()
	if host_mode:
		Saves.delete_world(world_id)
		check(Saves.create_world(world_id) == "", "host creates isolated world")
		Saves.set_section("nets", {"list": [["QA Host", 0.0, 0.0, [["perch", 1.0]]]]})
		check(Net.host(18931) == OK, "host listens on test port")
		get_tree().get_first_node_in_group("village_mayhem").show_pollution(Vector3(0,Terrain.WATER_Y,-31),75)
		Net.player_registered.connect(func(peer: int,_data: Dictionary) -> void:
			if peer!=1:
				var goose := get_tree().get_first_node_in_group("goose")
				goose.set_physics_process(false)
				goose.global_position = NpcMotion.safe_point(Layout.spawn()+Vector3(3,0,0))
				goose.target_peer = peer
				for key in ["Shop","ShopPremium"]:
					var store: ShopController = get_tree().root.get_node("World/"+key)
					store._rng.seed=42
					store.guard.set_physics_process(false)
					store.guard.state=Guard.State.CHASE
					store.guard._target_peer=1
					store.sentry.cover_post()
					store.sentry._timer=600)
		print("HOST_READY")
	else:
		check(Net.join("127.0.0.1", 18931) == OK, "client starts connection")


func _process(_delta: float) -> void:
	if started == 0 or done:
		return
	var elapsed := Time.get_ticks_msec() - started
	if elapsed > 90000:
		check(false, "co-op test timed out")
		_finish()
		return
	if host_mode:
		if Net.peer_profiles.values().has("qa_coop_client"):
			saw_client = true
		var data := Saves.get_player("qa_coop_client")
		if not second_connection and data.get("inventory", {}).get("money", 0) == 1234:
			second_connection = true
			check(saw_client, "host registered remote player")
			check(get_tree().get_nodes_in_group("players").size() == 2, "both players replicated on host")
			check(nets._nets.size() == 1, "client connection preserves host nets")
			check(Saves.save_world(), "host saves remote inventory")
			check(data.inventory.get("blindness",0)==1.0,"host saves remote blindness")
			print("SNAPSHOT_STORED")
			# Let client finish and receive its final snapshot.
			await get_tree().create_timer(0.4).timeout
			check(not get_tree().root.get_node("World/VillageMayhem").get_children().filter(func(n):return n is ComicRagdoll).is_empty(),"client ragdoll event arrives on host")
		if second_connection and bool(data.get("inventory",{}).get("stats",{}).get("qa_reconnected",false)):
			done = true
			await get_tree().create_timer(1.2).timeout
			check(Saves.get_player("qa_coop_client").get("inventory", {}).get("money", 0) == 1234,
				"client inventory retained after reconnection")
			_finish()
	else:
		var p := get_tree().get_first_node_in_group("local_player")
		var goose := get_tree().get_first_node_in_group("goose")
		if client_stage == 0 and p and nets._vis.size() == 1 and goose.target_peer==multiplayer.get_unique_id():
			check(get_tree().get_nodes_in_group("players").size() == 2, "client sees both players")
			check(nets._vis.values()[0].count == 1, "client receives existing net with catch")
			check(get_tree().get_first_node_in_group("clinic")!=null,"client has clinic")
			check(get_tree().get_first_node_in_group("goose")!=null,"client has synchronized goose")
			check(goose.global_position.distance_to(NpcMotion.safe_point(Layout.spawn()+Vector3(3,0,0)))<0.5,"client receives goose position and target from server")
			check(get_tree().get_first_node_in_group("village_mayhem").patches.size()==1,"late client receives active water pollution")
			client_stage = -1
			await _test_shop_security(p)
			await _test_remote_jail(p)
			Inventory.money = 1234
			Inventory.blindness = 1.0
			Net.send_snapshot()
			var mischief := p.get_node("Mischief")
			mischief.start_ragdoll()
			client_stage = 1
			phase_start = Time.get_ticks_msec()
		elif client_stage == 1 and Time.get_ticks_msec() - phase_start > 1200:
			client_stage = 2
			Net.leave()
			Saves.close_world()
			get_tree().root.get_node("World").queue_free()
			await get_tree().process_frame
			Inventory.reset()
			var world := (load("res://scenes/world.tscn") as PackedScene).instantiate()
			get_tree().root.add_child(world)
			await get_tree().process_frame
			nets = get_tree().get_first_node_in_group("nets")
			client_stage = 3
			check(Net.join("127.0.0.1", 18931) == OK, "client reconnects")
		elif client_stage == 3 and p:
			client_stage = 4
			check(Inventory.money == 1234, "client receives saved inventory on reconnect")
			check(Inventory.blindness==1.0,"client receives saved blindness on reconnect")
			Inventory.stats["qa_reconnected"] = true
			Net.send_snapshot()
			await get_tree().create_timer(0.3).timeout
			_finish()


func _finish() -> void:
	done = true
	if host_mode:
		Net.leave()
		Saves.close_world()
		Saves.delete_world(world_id)
	print("COOP_RESULT: " + ("FAIL" if failed else "PASS"))
	get_tree().quit(1 if failed else 0)


func _test_shop_security(p: Node3D) -> void:
	for key in ["Shop","ShopPremium"]:
		var store:ShopController=get_tree().root.get_node("World/"+key)
		check(store.guard.state==Guard.State.CHASE,"client receives mobile guard chase in "+key)
		check(store.is_inside(store.sentry.global_position),"client sees sentry at post in "+key)
		Inventory.cart.clear()
		Inventory.theft=Inventory.Theft.NONE
		Inventory.money=2000
		p.global_position=store.to_global(Vector3(0,0.2,3))
		Inventory.add_to_cart("drink",&"beer",store.price_of("drink",&"beer"),store.spot_key)
		await get_tree().physics_frame
		await get_tree().physics_frame
		p.global_position=store.to_global(Vector3(0,0.2,7))
		await get_tree().create_timer(0.8).timeout
		check(Inventory.cart.is_empty() and Inventory.money==1700,"server sentry intercepts second thief while partner pursues first in "+key)
		check(store.guard.state==Guard.State.CHASE and store.is_inside(store.sentry.global_position),"both guard roles preserved on client in "+key)


func _test_remote_jail(p: Node3D) -> void:
	request_test_arrest.rpc_id(1)
	var deadline := Time.get_ticks_msec() + 4000
	while not p.is_jailed() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	var station := get_tree().get_first_node_in_group("police_station")
	check(p.is_jailed() and station.is_in_cell(p.global_position), "host arrest reaches the remote player")
	check(p.position_for_save().distance_to(station.exit_point()) < 0.01, "co-op arrest saves the station exit")
	if p.is_jailed():
		p._jail_t = 0.3
		await get_tree().create_timer(0.5).timeout
	check(not p.is_jailed() and p.global_position.distance_to(station.exit_point()) < 0.5,
		"remote player leaves the cell at the end of the timer")


@rpc("any_peer", "reliable")
func request_test_arrest() -> void:
	if not multiplayer.is_server():
		return
	var station := get_tree().get_first_node_in_group("police_station")
	station.jail(multiplayer.get_remote_sender_id(), "проверка КПЗ в кооперативе")
