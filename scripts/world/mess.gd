extends Node3D
## Отходы жизнедеятельности: какашки и лужи. Создаёт и убирает хост.
## Лужа высыхает за минуту, какашка исчезает за 5 минут (если её не подобрали на наживку).

const POOP_PATH := "res://scenes/poop.tscn"
const PUDDLE_PATH := "res://scenes/puddle.tscn"
const POOP := preload("res://scenes/poop.tscn")
const PUDDLE := preload("res://scenes/puddle.tscn")
const POOP_LIFE := 300.0
const PUDDLE_LIFE := 60.0
const MAX_ITEMS := 60

@onready var spawner: MultiplayerSpawner = $Spawner
var _counter := 0


func _ready() -> void:
	add_to_group("mess")
	spawner.add_spawnable_scene(POOP_PATH)
	spawner.add_spawnable_scene(PUDDLE_PATH)
	Net.hosted.connect(_load)
	Saves.before_save.connect(_save)


func request_poop(pos: Vector3) -> void:
	NetUtil.call_server(self, "srv_spawn", ["poop", pos, 0.0])


func request_puddle(pos: Vector3) -> void:
	NetUtil.call_server(self, "srv_spawn", ["puddle", pos, 0.0])


func request_pickup(node_name: String) -> void:
	NetUtil.call_server(self, "srv_pickup", [node_name])


@rpc("any_peer", "reliable")
func srv_spawn(kind: String, pos: Vector3, age: float) -> void:
	if multiplayer.is_server():
		_spawn(kind, pos, age)


func _spawn(kind: String, pos: Vector3, age: float) -> void:
	var items := get_children().filter(func(c): return c is MessItem)
	if items.size() >= MAX_ITEMS:
		items[0].queue_free()
	_counter += 1
	var n: MessItem = (POOP if kind == "poop" else PUDDLE).instantiate()
	n.name = "M%d_%d" % [_counter, randi() % 10000]
	n.position = Vector3(pos.x, Terrain.height(pos.x, pos.z) + 0.01 if absf(pos.y - Terrain.height(pos.x, pos.z)) < 0.6 else pos.y, pos.z)
	n.age = age
	add_child(n, true)


@rpc("any_peer", "reliable")
func srv_pickup(node_name: String) -> void:
	if not multiplayer.is_server():
		return
	var n := get_node_or_null(node_name)
	if n is MessItem and n.kind == "poop" and not n.is_queued_for_deletion():
		n.queue_free()
		NetUtil.call_peer(self, NetUtil.sender(self), "give_poop")


@rpc("authority", "reliable")
func give_poop() -> void:
	if Inventory.add_item("bait", &"poop", 1):
		Events.notify("Подобрал какашку. Крупная рыба такое любит…", Color(0.8, 0.65, 0.4))


func _save() -> void:
	var list := []
	for c in get_children():
		if c is MessItem and c.kind == "poop":
			list.append([c.position.x, c.position.y, c.position.z, c.age])
	Saves.set_section("poops", list)


func _load() -> void:
	for c in get_children():
		if c is MessItem:
			c.queue_free()
	var list = Saves.world.get("poops", [])
	if list is Array:
		for e in list:
			if e is Array and e.size() >= 4:
				_spawn("poop", Vector3(e[0], e[1], e[2]), float(e[3]))
