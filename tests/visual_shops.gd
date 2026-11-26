extends Node
func _ready() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("Codex/game-fish-qa"):
		get_tree().quit(98)
		return
	_run.call_deferred()
func shot(file:String) -> void:
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://"+file)
	print("CAPTURE: "+ProjectSettings.globalize_path("user://"+file))
func _run() -> void:
	Saves.volume=0
	Saves.apply_volume()
	Settings.max_fps=60
	var world:Node3D=load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child(world)
	await get_tree().create_timer(2).timeout
	Saves.create_world("qa_shops_visual_%d" % OS.get_process_id())
	Net.host(18792)
	await get_tree().process_frame
	var p:Node3D=get_tree().get_first_node_in_group("local_player")
	p.set_physics_process(false)
	p.set_process(false)
	var cam:=Camera3D.new()
	cam.fov=75
	world.add_child(cam)
	cam.make_current()
	var store:ShopController=world.get_node("ShopPremium")
	p.global_position=store.to_global(Vector3(0,0.2,7))
	cam.global_position=store.to_global(Vector3(16,12,16))
	cam.look_at(Layout.ring(-22)+Vector3.UP)
	await shot("v131-shops-road.png")
	cam.global_position=store.to_global(Vector3(0,2,10))
	cam.look_at(store.to_global(Vector3(0,1.8,0)))
	await shot("v131-premium-front.png")
	p.global_position=store.to_global(Vector3(0,0.2,0))
	cam.global_position=store.to_global(Vector3(0,1.7,0))
	cam.look_at(store.to_global(Vector3(1.6,1.2,4)))
	await shot("v131-two-guards.png")
	Inventory.cart.clear()
	Inventory.theft=Inventory.Theft.NONE
	Inventory.add_to_cart("drink",&"beer",store.price_of("drink",&"beer"),store.spot_key)
	cam.global_position=store.to_global(Vector3(-5.0,1.5,-3.9))
	cam.look_at(store.to_global(Vector3(-5.0,1.2,-4.8)))
	await shot("v131-premium-prices.png")
	Inventory.drop_cart()
	Net.leave()
	print("SHOPS_VISUAL_RESULT: PASS")
	get_tree().quit()
