class_name AngryGoose
extends CharacterBody3D

@export var target_peer := 0
var _home := Vector3.ZERO
var _scan := 0.0
var _peck := 0.0
var _honk := 0.0
var _chase := 0.0
var _cooldown := 0.0
var _neck: Node3D
var _label: Label3D

func _ready() -> void:
	add_to_group("goose")
	add_to_group("npc")
	collision_layer = 8
	collision_mask = 1
	_home = NpcMotion.safe_point(Layout.ring(-43,5))
	global_position = _home
	var cs := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 1.1
	cs.position.y = 0.55
	cs.shape = shape
	add_child(cs)
	Art.add_mesh(self,Art.sphere(0.37,12),Art.color(Color(0.93,0.93,0.88)),Vector3(0,0.4,0),Vector3.ZERO,Vector3(1,0.8,1.5))
	_neck = Node3D.new()
	_neck.position = Vector3(0,0.45,-0.35)
	add_child(_neck)
	Art.add_mesh(_neck,Art.capsule(0.1,0.6),Art.color(Color(0.95,0.95,0.9)),Vector3(0,0.3,0))
	Art.add_mesh(_neck,Art.sphere(0.15,8),Art.color(Color(0.96,0.96,0.9)),Vector3(0,0.65,0))
	Art.add_mesh(_neck,Art.box(Vector3(0.12,0.08,0.23)),Art.color(Color(1,0.5,0.05)),Vector3(0,0.61,-0.18))
	for side in [-1,1]:
		Art.add_mesh(_neck,Art.sphere(0.025,6),Art.color(Color(0.1,0.02,0.02)),Vector3(side*0.12,0.68,-0.06))
		Art.add_mesh(self,Art.box(Vector3(0.16,0.05,0.25)),Art.color(Color(1,0.5,0.05)),Vector3(side*0.15,0.05,0))
	_label = Build.text(self,Vector3(0,1.55,0),"ГУСЬ · местный авторитет",32,Color(1,0.9,0.6),0.006,0,true)
	Build.talk_area(self,Vector3(0,0.6,-0.1),Vector3(1.2,1.6,1.2),self)
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var cfg := SceneReplicationConfig.new()
	for prop in [":position",":rotation",":target_peer"]:
		cfg.add_property(NodePath(prop))
	sync.replication_config = cfg
	sync.replication_interval = 0.1
	add_child(sync)

func get_prompt(_p: Node) -> String:
	return "Откупиться хлебом и забрать украденное" if target_peer == multiplayer.get_unique_id() else "Гусь смотрит на карманы. Не провоцируй"

func interact(_p: Node) -> void:
	if target_peer == multiplayer.get_unique_id():
		pay_off()

func pay_off() -> void:
	if target_peer != multiplayer.get_unique_id():
		return
	var offer := "bread" if Inventory.count_of("bait",&"bread")>0 else ("money" if Inventory.money>=15 else "pity")
	NetUtil.call_server(self,"srv_calm",[offer])

@rpc("any_peer","reliable")
func srv_calm(offer: String) -> void:
	if not multiplayer.is_server() or NetUtil.sender(self) != target_peer:
		return
	if offer not in ["bread","money","pity"]:
		return
	NetUtil.call_peer(self,target_peer,"returned",[offer])
	target_peer = 0
	_cooldown = 100
	_chase = 0

@rpc("authority","reliable")
func returned(offer := "") -> void:
	if offer == "bread":
		Inventory.remove_item("bait",&"bread",1)
	elif offer == "money":
		Inventory.money = maxi(0,Inventory.money-15)
		Inventory.changed.emit()
	elif offer == "pity":
		Events.notify("Гусь оценил твоё финансовое положение и сам ушёл за хлебом.",Color.PALE_GREEN,false)
	var m := get_tree().get_first_node_in_group("mischief")
	if m:
		m.return_loot()
	Events.notify("Гусь вернул награбленное: «ГА». Мирный договор подписан хлебом.",Color.PALE_GREEN,false)

@rpc("authority","reliable")
func pecked() -> void:
	var m := get_tree().get_first_node_in_group("mischief")
	if m:
		m.goose_peck()

func _physics_process(delta: float) -> void:
	if not Net.is_online():
		return
	_neck.rotation.x = sin(Time.get_ticks_msec()*0.008)*0.14 if target_peer else 0.0
	if not multiplayer.is_server():
		return
	_scan -= delta
	_peck -= delta
	_honk -= delta
	_cooldown = maxf(_cooldown-delta,0)
	var actor := get_tree().root.get_node_or_null("World/Players/%d" % target_peer) as Node3D
	if _scan <= 0:
		_scan = 0.5
		if actor == null and _cooldown <= 0:
			for p in get_tree().get_nodes_in_group("players"):
				if p.global_position.distance_to(global_position)<7 and not p.sleeping and not p.hidden:
					target_peer = p.name.to_int()
					actor = p
					_chase = 0
					break
	var goal := _home
	if actor:
		_chase += delta
		goal = actor.global_position
		if _chase > 150 or actor.sleeping or actor.hidden or actor.pose == "ko":
			NetUtil.call_peer(self,target_peer,"returned",[])
			target_peer = 0
			_cooldown = 80
		elif actor.global_position.distance_to(global_position)<1.6 and _peck<=0:
			_peck = 8
			NetUtil.call_peer(self,target_peer,"pecked",[])
		if _honk<=0:
			_honk = 3
			NetUtil.call_all(self,"honk",[])
		if goal.distance_to(global_position)>12:
			var a := rad_to_deg(atan2((global_position.x-Layout.C.x)/Layout.AX,(global_position.z-Layout.C.y)/Layout.AZ))
			var b := rad_to_deg(atan2((goal.x-Layout.C.x)/Layout.AX,(goal.z-Layout.C.y)/Layout.AZ))
			var d := wrapf(b-a,-180,180)
			if absf(d)>9:
				goal = Layout.ring(a+signf(d)*7,1.0)
	var dir := goal-global_position
	dir.y = 0
	var speed := 5.4 if target_peer else 1.4
	var desired := dir.normalized()*speed if dir.length()>0.5 else Vector3.ZERO
	velocity.x = desired.x
	velocity.z = desired.z
	velocity.y = -0.5 if is_on_floor() else velocity.y-9.8*delta
	if desired.length()>0.1:
		rotation.y = lerp_angle(rotation.y,atan2(-desired.x,-desired.z),minf(delta*8,1))
	NpcMotion.move(self,delta)

@rpc("authority","reliable")
func honk() -> void:
	Sfx.play("goose",global_position,-2,0.15)
