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
		check(Net.host(18778) == OK, "host listens on test port")
		print("HOST_READY")
	else:
		check(Net.join("127.0.0.1", 18778) == OK, "client starts connection")


func _process(_delta: float) -> void:
	if started == 0 or done:
		return
	var elapsed := Time.get_ticks_msec() - started
	if elapsed > 55000:
		check(false, "co-op test timed out")
		_finish()
		return
	if host_mode:
		if Net.peer_profiles.values().has("qa_coop_client"):
			saw_client = true
		var data := Saves.get_player("qa_coop_client")
		if data.get("inventory", {}).get("money", 0) == 1234:
			check(saw_client, "host registered remote player")
			check(get_tree().get_nodes_in_group("players").size() == 2, "both players replicated on host")
			check(nets._nets.size() == 1, "client connection preserves host nets")
			check(Saves.save_world(), "host saves remote inventory")
			print("SNAPSHOT_STORED")
			# Let client finish and receive its final snapshot.
			done = true
			await get_tree().create_timer(12.0).timeout
			check(Saves.get_player("qa_coop_client").get("inventory", {}).get("money", 0) == 1234,
				"client inventory retained after reconnection")
			_finish()
	else:
		var p := get_tree().get_first_node_in_group("local_player")
		if client_stage == 0 and p and nets._vis.size() == 1:
			check(get_tree().get_nodes_in_group("players").size() == 2, "client sees both players")
			check(nets._vis.values()[0].count == 1, "client receives existing net with catch")
			Inventory.money = 1234
			Net.send_snapshot()
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
			check(Net.join("127.0.0.1", 18778) == OK, "client reconnects")
		elif client_stage == 3 and p:
			check(Inventory.money == 1234, "client receives saved inventory on reconnect")
			_finish()


func _finish() -> void:
	done = true
	if host_mode:
		Net.leave()
		Saves.close_world()
		Saves.delete_world(world_id)
	print("COOP_RESULT: " + ("FAIL" if failed else "PASS"))
	get_tree().quit(1 if failed else 0)
