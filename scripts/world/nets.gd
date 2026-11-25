extends Node3D
## Сети-путанки (браконьерство). Ставишь сеть в воду — со временем в неё набивается рыба,
## потом вытаскиваешь (E). Чужую тоже можно вытащить — вместе с уловом. Список сетей держит хост,
## клиентам рассылается упрощённый вид. Рыбнадзор (Inspector) снимает сети и штрафует хозяев.

const FILL_EVERY := 40.0     ## раз в столько секунд — шанс, что попадётся рыба
const FILL_CHANCE := 0.6
const MAX_FISH := 10
const SAVE_KEY := "nets"

var _nets: Array = []        ## сервер: {id, owner, peer, pos: Vector3, fish: [[id, kg]]}
var _next_id := 1
var _t := 0.0
var _vis := {}               ## id -> Node3D (у всех)
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("nets")
	_rng.randomize()
	Net.hosted.connect(_load)
	Saves.before_save.connect(_save)
	multiplayer.peer_connected.connect(func(_id: int) -> void: _broadcast())


func _load() -> void:
	_nets.clear()
	_next_id = 1
	var d := Saves.get_section(SAVE_KEY)
	for n in d.get("list", []):
		_nets.append({"id": _next_id, "owner": String(n[0]), "peer": 0,
			"pos": Vector3(float(n[1]), Terrain.WATER_Y, float(n[2])), "fish": n[3]})
		_next_id += 1
	_broadcast()


func _save() -> void:
	var list := []
	for n in _nets:
		list.append([n.owner, n.pos.x, n.pos.z, n.fish])
	Saves.set_section(SAVE_KEY, {"list": list})


# ------------------------------------------------------------ ставим / снимаем (клиент)

## Игрок с сетью в руках жмёт ЛКМ: ставим перед собой, если там вода.
func try_place(p: Node3D) -> void:
	var fwd: Vector3 = p.look_dir()
	fwd.y = 0.0
	fwd = fwd.normalized()
	var at: Vector3 = p.global_position + fwd * 3.5
	if Terrain.depth(at.x, at.z) < 0.8:
		Events.notify("Сеть ставят в воду поглубже — подойди к краю или зайди на лодке", Color.LIGHT_GRAY)
		return
	for n in _vis.values():
		if (n as Node3D).global_position.distance_to(at) < 6.0:
			Events.notify("Тут уже стоит сеть", Color.LIGHT_GRAY)
			return
	if not Inventory.remove_item("tool", &"net", 1):
		return
	Sfx.play("splash", at, -6.0)
	Events.notify("Поставил сеть. Через пару часов проверь… и не попадись рыбнадзору", Color(0.8, 0.9, 0.7))
	NetUtil.call_server(self, "srv_place", [at.x, at.z, p.player_name])


@rpc("any_peer", "reliable")
func srv_place(x: float, z: float, owner_name: String) -> void:
	if not multiplayer.is_server():
		return
	_nets.append({"id": _next_id, "owner": owner_name, "peer": NetUtil.sender(self),
		"pos": Vector3(x, Terrain.WATER_Y, z), "fish": []})
	_next_id += 1
	_broadcast()


@rpc("any_peer", "reliable")
func srv_request() -> void:
	if multiplayer.is_server():
		_broadcast()


func pull(id: int) -> void:
	NetUtil.call_server(self, "srv_pull", [id])


@rpc("any_peer", "reliable")
func srv_pull(id: int) -> void:
	if not multiplayer.is_server():
		return
	var i := _index(id)
	if i < 0:
		return
	var n: Dictionary = _nets[i]
	_nets.remove_at(i)
	_broadcast()
	NetUtil.call_peer(self, NetUtil.sender(self), "pulled", [n.fish, n.owner])
	var insp := get_tree().get_first_node_in_group("inspector")
	if insp:
		insp.call("saw_poacher", NetUtil.sender(self), n.pos)


@rpc("authority", "reliable")
func pulled(fish: Array, owner_name: String) -> void:
	Inventory.add_item("tool", &"net", 1, false)
	var me := get_tree().get_first_node_in_group("local_player")
	var mine: bool = me != null and me.player_name == owner_name
	if fish.is_empty():
		Events.notify("Сеть пустая. Одна тина", Color.LIGHT_GRAY)
		return
	var kg := 0.0
	for f in fish:
		Inventory.add_fish(StringName(f[0]), float(f[1]))
		kg += float(f[1])
	Inventory.stat_add("net_fish", fish.size())
	Events.notify("%s: %d рыб, %.1f кг!" % ["Улов из сети" if mine else "Чужая сеть (%s)" % owner_name, fish.size(), kg], Color(0.6, 1.0, 0.6))
	Sfx.play("splash_big", me.global_position if me else Vector3.ZERO, -6.0)


func _index(id: int) -> int:
	for i in _nets.size():
		if _nets[i].id == id:
			return i
	return -1


# ------------------------------------------------------------ для рыбнадзора (сервер)

func nets_near(p: Vector3, r: float) -> Array:
	var out := []
	for n in _nets:
		if Vector2(n.pos.x - p.x, n.pos.z - p.z).length() < r:
			out.append(n)
	return out


func confiscate(id: int) -> Dictionary:
	var i := _index(id)
	if i < 0:
		return {}
	var n: Dictionary = _nets[i]
	_nets.remove_at(i)
	_broadcast()
	return n


# ------------------------------------------------------------ рыба набивается (сервер)

func _process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	_t += delta
	if _t < FILL_EVERY:
		return
	_t = 0.0
	var changed := false
	for n in _nets:
		if n.fish.size() < MAX_FISH and _rng.randf() < FILL_CHANCE:
			var zone := "deep" if Terrain.depth(n.pos.x, n.pos.z) > 3.6 else "open"
			if Terrain.is_far(n.pos.x, n.pos.z):
				zone = "far_" + zone
			var f := GameData.roll_fish(&"worm", _rng, 0.0, zone)
			if f.rarity >= FishData.Rarity.LEGENDARY:
				continue
			n.fish.append([String(f.id), GameData.roll_weight(f, _rng, 0.0, zone)])
			changed = true
	if changed:
		_broadcast()


func _broadcast() -> void:
	if not multiplayer.is_server():
		return
	var lite := []
	for n in _nets:
		lite.append([n.id, n.pos.x, n.pos.z, n.owner, n.fish.size()])
	NetUtil.call_all(self, "show_nets", [lite])


# ------------------------------------------------------------ вид (у всех)

@rpc("authority", "call_remote", "reliable")
func show_nets(lite: Array) -> void:
	var keep := {}
	for e in lite:
		var id: int = e[0]
		keep[id] = true
		var v: NetVisual = _vis.get(id)
		if v == null:
			v = NetVisual.new()
			v.nets = self
			v.net_id = id
			add_child(v)
			v.global_position = Vector3(float(e[1]), Terrain.WATER_Y, float(e[2]))
			_vis[id] = v
		v.owner_name = e[3]
		v.count = e[4]
	for id in _vis.keys():
		if not keep.has(id):
			_vis[id].queue_free()
			_vis.erase(id)


class NetVisual extends Node3D:
	var nets: Node
	var net_id := 0
	var owner_name := ""
	var count := 0
	var _floats: Array[Node3D] = []
	var _t := randf() * 10.0

	func _ready() -> void:
		var orange := Art.color(Color(1.0, 0.45, 0.1), 0.6)
		var white := Art.color(Color(0.95, 0.95, 0.9), 0.6)
		var yaw := randf() * TAU
		for i in 7:
			var f := Node3D.new()
			f.position = Vector3(cos(yaw), 0, sin(yaw)) * (i - 3) * 0.9
			add_child(f)
			Art.add_mesh(f, Art.sphere(0.09, 8), orange if i % 2 == 0 else white, Vector3(0, 0.02, 0), Vector3.ZERO, Vector3(1, 0.7, 1))
			_floats.append(f)
		# вешка с тряпкой
		var end := Vector3(cos(yaw), 0, sin(yaw)) * 3.0
		Art.add_mesh(self, Art.cyl(0.025, 0.025, 1.4, 6), Art.color(Color(0.45, 0.35, 0.22)), end + Vector3(0, 0.5, 0))
		Art.add_mesh(self, Art.box(Vector3(0.3, 0.2, 0.01)), Art.color(Color(0.8, 0.15, 0.1)), end + Vector3(0.15, 1.1, 0))
		Build.talk_area(self, Vector3(0, 0.2, 0), Vector3(3.2, 1.6, 3.2), self)
		var a := Build.talk_area(self, end + Vector3(0, 0.6, 0), Vector3(1.4, 1.6, 1.4), self)
		a.name = "End"

	func _process(delta: float) -> void:
		_t += delta
		for i in _floats.size():
			_floats[i].position.y = sin(_t * 1.6 + i * 0.8) * 0.03

	func get_prompt(p: Node) -> String:
		var mine: bool = p.player_name == owner_name
		if mine:
			return "E — вытащить сеть (%s)" % ("пусто" if count == 0 else "что-то бьётся" if count < 4 else "тяжёлая!")
		return "Чья-то сеть (%s). E — вытащить себе" % owner_name

	func interact(_p: Node) -> void:
		nets.pull(net_id)
