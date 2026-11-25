extends Node3D
## Все пустые бутылки в мире. Создаёт и удаляет их только хост,
## MultiplayerSpawner повторяет это у всех. Бутылки сохраняются вместе с миром.

const BOTTLE_SCENE_PATH := "res://scenes/bottle.tscn"
const BOTTLE_SCENE := preload("res://scenes/bottle.tscn")
const MAX_BOTTLES := 80
const MAX_CARRY := 20
## Раз в столько секунд где-нибудь появляется брошенная кем-то бутылка (можно собрать и сдать).
const LITTER_EVERY := 40.0
const LITTER_MAX := 30

@onready var spawner: MultiplayerSpawner = $Spawner
var _counter := 0
var _litter_timer := 10.0
var _litter_rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("bottles")
	spawner.add_spawnable_scene(BOTTLE_SCENE_PATH)
	Net.hosted.connect(_load)
	Saves.before_save.connect(_save)


func _process(delta: float) -> void:
	if not multiplayer.is_server() or not Net.is_online():
		return
	_litter_timer -= delta
	if _litter_timer > 0.0:
		return
	_litter_timer = LITTER_EVERY
	if _bottles().size() >= LITTER_MAX:
		return
	# У дороги, у лавочек, на берегу.
	for attempt in 10:
		var side := 1.0 if _litter_rng.randf() < 0.5 else -1.0
		var p := Layout.ring(_litter_rng.randf_range(-180.0, 180.0), side * _litter_rng.randf_range(4.2, 6.5))
		if _litter_rng.randf() < 0.4:
			var a := _litter_rng.randf() * TAU
			p = Vector3(cos(a) * 39.0, 0, -31.0 + sin(a) * 30.0)
		if Terrain.is_water(p.x, p.z):
			continue
		p.y = Terrain.height(p.x, p.z) + 0.4
		var kinds := [&"empty", &"beer", &"strong_beer", &"port", &"vodka"]
		_spawn(kinds[_litter_rng.randi() % kinds.size()], p, Vector3.ZERO, 0)
		return


func _bottles() -> Array[Bottle]:
	var out: Array[Bottle] = []
	for c in get_children():
		if c is Bottle and not c.is_queued_for_deletion():
			out.append(c)
	return out


# ------------------------------------------------------------ запросы игроков

func request_drop(kind: StringName, pos: Vector3) -> void:
	var vel := Vector3(randf_range(-1, 1), 1.0, randf_range(-1, 1))
	NetUtil.call_server(self, "srv_spawn", [kind, pos, vel, false])


func request_throw(pos: Vector3, vel: Vector3) -> void:
	NetUtil.call_server(self, "srv_spawn", [&"empty", pos, vel, true])


func request_pickup(bottle_name: String) -> void:
	if Inventory.count_of("bottle", &"empty") >= MAX_CARRY:
		Events.notify("Больше бутылок не унести", Color.LIGHT_GRAY)
		return
	NetUtil.call_server(self, "srv_pickup", [bottle_name])


# ------------------------------------------------------------ сервер

@rpc("any_peer", "reliable")
func srv_spawn(kind: StringName, pos: Vector3, vel: Vector3, thrown: bool) -> void:
	if not multiplayer.is_server():
		return
	_spawn(kind, pos, vel, NetUtil.sender(self) if thrown else 0)


func _spawn(kind: StringName, pos: Vector3, vel: Vector3, by: int) -> Bottle:
	var all := _bottles()
	if all.size() >= MAX_BOTTLES:
		all[0].queue_free()
	_counter += 1
	var b: Bottle = BOTTLE_SCENE.instantiate()
	b.name = "B%d_%d" % [_counter, randi() % 10000]
	b.kind = kind
	b.position = pos
	b.thrower = by
	add_child(b, true)
	b.linear_velocity = vel
	b.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
	return b


@rpc("any_peer", "reliable")
func srv_pickup(bottle_name: String) -> void:
	if not multiplayer.is_server():
		return
	var b := get_node_or_null(bottle_name)
	if b is Bottle and not b.is_queued_for_deletion():
		b.queue_free()
		NetUtil.call_peer(self, NetUtil.sender(self), "give_bottle")


@rpc("authority", "reliable")
func give_bottle() -> void:
	if Inventory.add_item("bottle", &"empty", 1):
		Events.notify("Подобрал пустую бутылку (выбери её и ЛКМ — бросить)", Color.LIGHT_GRAY)


## Бутылка попала в игрока.
func on_player_hit(by: int, target: Node) -> void:
	var by_name: String = Net.peer_names.get(by, "Кто-то")
	var target_peer := target.name.to_int()
	NetUtil.call_peer(target, target_peer, "take_hit", [target.BOTTLE_HIT_DAMAGE, by_name])
	NetUtil.call_peer(self, by, "hit_confirmed", [target.player_name])


@rpc("authority", "reliable")
func hit_confirmed(target_name: String) -> void:
	Inventory.stat_add("hits")
	Events.notify("Попал в %s!" % target_name, Color.GOLD)


# ------------------------------------------------------------ сохранение

func _save() -> void:
	var list := []
	for b in _bottles():
		var p := b.global_position
		list.append([snappedf(p.x, 0.01), snappedf(p.y, 0.01), snappedf(p.z, 0.01), String(b.kind)])
	Saves.set_section("bottles", list)


func _load() -> void:
	for b in _bottles():
		b.queue_free()
	var list = Saves.world.get("bottles", [])
	if list is Array:
		for e in list:
			if e is Array and e.size() >= 4:
				_spawn(StringName(e[3]), Vector3(e[0], e[1] + 0.05, e[2]), Vector3.ZERO, 0)
