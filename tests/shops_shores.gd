extends Node
var passed := 0
var failed := 0
func check(ok: bool, message: String) -> void:
	if ok:
		passed += 1
		print("PASS: " + message)
	else:
		failed += 1
		push_error("FAIL: " + message)

func _ready() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("Codex/game-fish-qa"):
		get_tree().quit(98)
		return
	_run.call_deferred()

func _run() -> void:
	var world := (load("res://scenes/world.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	Saves.create_world("qa_shops_%d" % OS.get_process_id())
	check(Net.host(18789) == OK, "host starts")
	await get_tree().physics_frame
	var player := get_tree().get_first_node_in_group("local_player")
	var cheap: ShopController = world.get_node("Shop")
	var premium: ShopController = world.get_node("ShopPremium")
	check(get_tree().get_nodes_in_group("shop").size() == 2, "two functioning shops")
	check(Layout.placement_problems("shop_premium").is_empty(), "premium footprint dry and clear: " + str(Layout.placement_problems("shop_premium")))
	var road := Layout.ring(-22.0)
	var normal := Layout.normal(-22.0)
	check((cheap.global_position-road).dot(normal)>0 and (premium.global_position-road).dot(normal)<0,"shops stand on opposite sides of road")
	check(cheap.global_basis.z.dot(premium.global_basis.z)<-0.99,"entrances face each other")
	for store in [cheap,premium]:
		check(store.guards().size()==2 and store.sentry.stays_inside and not store.guard.stays_inside,store.shop_title+": mobile guard and sentry")
		store.guard.state=Guard.State.WATCH
		store.sentry.state=Guard.State.WATCH
		check(store.detection_chance(1,false,0)>store.guard.spot_chance(1,false,0),store.shop_title+": two guards improve detection")
		store.guard.state=Guard.State.KO
		check(not store.is_closed(),store.shop_title+": one knockout does not close store")
		store.sentry.state=Guard.State.KO
		check(store.is_closed(),store.shop_title+": both knocked out closes store")
		store.guard.state=Guard.State.WATCH
		store.sentry.state=Guard.State.WATCH
		player.global_position=store.to_global(Vector3(0,0.2,9))
		store.guard.start_chase(1,0,400)
		store.sentry.start_chase(1,2)
		check(store.guard.is_chasing() and not store.sentry.is_chasing() and store.responder()==null,store.shop_title+": sentry never joins outdoor pursuit")
		check(store.detection_chance(1,false,0)>=0.89,store.shop_title+": sentry remains alert during pursuit")
		var home:Vector3=store.sentry.global_position
		for tick in 120:
			await get_tree().physics_frame
		check(store.is_inside(store.sentry.global_position) and home.distance_to(store.sentry.global_position)<0.5,store.shop_title+": sentry physically remains at post")
		store.guard.state=Guard.State.WATCH
	for item in cheap.get_children():
		if item.get_script()==load("res://scripts/world/shop/shop_item.gd"):
			var other:=premium.get_node(NodePath(str(item.name)))
			check(other.price()==ceili(item.price()*1.6),"premium shelf price "+str(item.item_id))
	Inventory.reset()
	Inventory.money=100000
	var price:=premium.price_of("drink",&"beer")
	check(Inventory.add_to_cart("drink",&"beer",price,premium.spot_key),"premium goods enter cart")
	check(Inventory.cart_total()==price,"cart retains shelf price")
	check(not Inventory.add_to_cart("drink",&"beer",cheap.price_of("drink",&"beer"),cheap.spot_key),"cannot mix unpaid goods from two stores")
	var before:=Inventory.money
	cheap.get_node("Cashier").interact(player)
	check(Inventory.money==before and Inventory.cart.size()==1,"wrong checkout cannot clear premium cart")
	premium.get_node("Cashier").interact(player)
	check(Inventory.money==before-price and Inventory.cart.is_empty(),"premium checkout charges shelf price exactly")
	# Test real player controller against every contour, not a second copy of its movement.
	Inventory.reset()
	player.get_node("Mischief").set_process(false)
	player.get_node("Mischief").set_physics_process(false)
	player.set_physics_process(false)
	var samples:Array[Dictionary]=[]
	for z in range(Terrain.Z0+4,Terrain.Z1-4,3):
		for x in range(Terrain.X0+4,Terrain.X1-4,3):
			var dep:=Terrain.depth(x,z)
			if dep<1.5 or dep>2.4:
				continue
			var gradient:=Vector3(Terrain.height(x+0.3,z)-Terrain.height(x-0.3,z),0,Terrain.height(x,z+0.3)-Terrain.height(x,z-0.3)).normalized()
			if gradient.length_squared()<0.5:
				continue
			var start:=Vector3(x,Terrain.WATER_Y-1.3,z)
			var end:=start+gradient*7.0
			if Terrain.height(end.x,end.z)<Terrain.WATER_Y+0.02:
				continue
			samples.append({"start":start,"direction":gradient})
	print("SHORE_SAMPLES ",samples.size())
	# Run all actual controller routes with fixed simulation frames for speed.
	for i in samples.size():
		var sample:Dictionary=samples[i]
		var start:Vector3=sample.start
		var direction:Vector3=sample.direction
		player.global_position=start
		player.velocity=Vector3.ZERO
		player.swimming=false
		player.rotation.y=atan2(-direction.x,-direction.z)
		Events.ui_open=false
		Input.action_press("move_forward")
		var escaped:=false
		for tick in 240:
			await get_tree().physics_frame
			player._physics_process(1.0/60.0)
			if Terrain.depth(player.global_position.x,player.global_position.z)<=0.01 and player.global_position.y>=Terrain.WATER_Y and not player.swimming:
				escaped=true
				break
		Input.action_release("move_forward")
		check(escaped,"shore route %d from %s -> %s" % [i,start,player.global_position])
	player.set_physics_process(true)
	Net.leave()
	await get_tree().process_frame
	print("SHOPS_SHORES_RESULT: %d passed, %d failed" % [passed,failed])
	get_tree().quit(0 if failed==0 else 1)
