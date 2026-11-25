class_name VillageMayhem
extends Node3D

const POLLUTION_LIFE := 75.0
var patches: Array[Dictionary] = []
var _cooldowns: Dictionary = {}

func _ready() -> void:
	add_to_group("village_mayhem")
	Net.player_registered.connect(func(peer: int,_data: Dictionary) -> void:
		if multiplayer.is_server() and peer != 1:
			for patch in patches:
				NetUtil.call_peer(self,peer,"show_pollution",[patch.pos,patch.life]))
	var bucket := _BucketPickup.new()
	add_child(bucket)
	bucket.global_position = NpcMotion.safe_point(Layout.local_to_world("house",Vector3(3,0,5)))
	var fire := _FireTalk.new()
	add_child(fire)
	fire.global_position = NpcMotion.safe_point(Layout.xform("campfire").origin)+Vector3.UP

func _process(delta: float) -> void:
	for i in range(patches.size()-1,-1,-1):
		patches[i].life -= delta
		if patches[i].life <= 0:
			patches[i].view.queue_free()
			patches.remove_at(i)

func is_polluted(p: Vector3) -> bool:
	for patch in patches:
		if Vector2(p.x-patch.pos.x,p.z-patch.pos.z).length()<7:
			return true
	return false

func pollute(p: Vector3) -> void:
	NetUtil.call_server(self,"srv_pollute",[p])

@rpc("any_peer","reliable")
func srv_pollute(p: Vector3) -> void:
	if not multiplayer.is_server() or not p.is_finite():
		return
	var peer := NetUtil.sender(self)
	var actor := get_tree().root.get_node_or_null("World/Players/%d" % peer) as Node3D
	if actor == null or actor.global_position.distance_to(p)>6 or Terrain.depth(p.x,p.z)<1.0:
		return
	var now := Time.get_ticks_msec()*0.001
	if now-float(_cooldowns.get(peer,-100))<30:
		return
	_cooldowns[peer] = now
	NetUtil.call_all(self,"show_pollution",[p,POLLUTION_LIFE])

@rpc("authority","reliable")
func show_pollution(p: Vector3,life: float) -> void:
	if patches.size()>=8:
		patches[0].view.queue_free()
		patches.remove_at(0)
	var view := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 6.5
	disc.bottom_radius = 6.5
	disc.height = 0.015
	disc.radial_segments = 32
	view.mesh = disc
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.28,0.14,0.035,0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	view.material_override = mat
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(view)
	view.global_position = Vector3(p.x,Terrain.WATER_Y+0.09,p.z)
	patches.append({"pos":p,"life":life,"view":view})
	var local := get_tree().get_first_node_in_group("local_player") as Node3D
	if local and local.global_position.distance_to(p)<60:
		Events.notify("С берега: «ФУУУ!» Рыба объявила санитарный час. Здесь 75 секунд не клюёт.",Color.ORANGE,false)
		Sfx.say(Vector3.ZERO,"old","Фу! Вы там совсем обалдели? В озере же рыба!","fish")

func request_ragdoll(p: Vector3) -> void:
	NetUtil.call_server(self,"srv_ragdoll",[p])

@rpc("any_peer","reliable")
func srv_ragdoll(p: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var peer := NetUtil.sender(self)
	var actor := get_tree().root.get_node_or_null("World/Players/%d" % peer) as Node3D
	if actor == null or not p.is_finite() or actor.global_position.distance_to(p)>5:
		return
	var now := Time.get_ticks_msec()*0.001
	var key := "ragdoll_%d" % peer
	if now-float(_cooldowns.get(key,-100))<5:
		return
	_cooldowns[key] = now
	NetUtil.call_all(self,"show_ragdoll",[peer,p])

@rpc("authority","reliable")
func show_ragdoll(peer: int,p: Vector3) -> void:
	if peer == multiplayer.get_unique_id():
		return
	var prop := ComicRagdoll.new()
	add_child(prop)
	prop.global_position = p
	var actor := get_tree().root.get_node_or_null("World/Players/%d" % peer)
	if actor:
		actor.model.visible = false
		var actor_ref: WeakRef = weakref(actor)
		get_tree().create_timer(2.6).timeout.connect(func() -> void:
			var current: Node = actor_ref.get_ref()
			if current:
				current.model.visible = true)

class _BucketPickup extends Interactable:
	func _ready() -> void:
		var cs := CollisionShape3D.new()
		var sh := SphereShape3D.new()
		sh.radius = 0.65
		cs.shape = sh
		add_child(cs)
		add_child(ItemModels.build("tool",&"bucket"))
	func get_prompt(_p: Node) -> String:
		return "Ведро «Депутат». Взять — E. Уронить — из инвентаря"
	func interact(_p: Node) -> void:
		if Inventory.count_of("tool",&"bucket")>0:
			Events.notify("Одного ведра на голову достаточно.",Color.LIGHT_GRAY,false)
		elif Inventory.add_item("tool",&"bucket"):
			Sfx.play("metal_click",global_position,-8)

class _FireTalk extends Interactable:
	func _ready() -> void:
		var cs := CollisionShape3D.new()
		var sh := SphereShape3D.new()
		sh.radius = 0.8
		cs.shape = sh
		add_child(cs)
	func _entry() -> Dictionary:
		for fish in Inventory.basket:
			if fish.get("talking",false):
				return fish
		return {}
	func get_prompt(_p: Node) -> String:
		return "Зажарить рыбу-говоруна (она называет себя свидетелем)" if not _entry().is_empty() else "У костра пахнет ухой"
	func interact(_p: Node) -> void:
		var entry := _entry()
		var mischief := get_tree().get_first_node_in_group("mischief")
		if mischief and not entry.is_empty():
			mischief._talking_entry = entry
			mischief.fry_fish()
		else:
			Events.notify("Рыбаки: «Хочешь ухи — садись. Хочешь совета — тоже садись, сейчас начнётся». ",Color.PALE_GREEN,false)
