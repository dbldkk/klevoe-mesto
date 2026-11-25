extends Node3D
## Корень игрового мира. Сервер создаёт игроков после регистрации
## (там, где они вышли в прошлый раз). MultiplayerSpawner повторяет это у всех.

const PLAYER_SCENE_PATH := "res://scenes/player.tscn"
const PLAYER_SCENE := preload("res://scenes/player.tscn")

@onready var players: Node3D = $Players
@onready var spawner: MultiplayerSpawner = $PlayerSpawner


func _ready() -> void:
	var guide := CanvasLayer.new()
	guide.set_script(preload("res://scripts/ui/guide_ui.gd"))
	add_child(guide)
	spawner.add_spawnable_scene(PLAYER_SCENE_PATH)
	Net.player_registered.connect(_on_player_registered)
	Net.server_lost.connect(_on_server_lost)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	Settings.apply_world.call_deferred()
	_bake_static()


## Оптимизация: склеиваем неподвижные кусочки построек, деревьев и улицы (см. MeshBaker).
const BAKE := ["Decor", "Street", "Shop", "Casino", "LiquorStore", "House", "Club", "Farm", "PoliceStation",
	"Market", "Garage", "BusStop", "RepairJob", "Babka", "InspectorPost", "Pier", "Thimbles"]


func _bake_static() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var t0 := Time.get_ticks_msec()
	var n := 0
	for name in BAKE:
		var node := get_node_or_null(name) as Node3D
		if node:
			n += MeshBaker.bake(node)
	print("MeshBaker: склеено %d мешей за %d мс" % [n, Time.get_ticks_msec() - t0])


func _on_player_registered(id: int, data: Dictionary) -> void:
	if players.has_node(str(id)):
		return
	var p := PLAYER_SCENE.instantiate()
	p.name = str(id)
	var sp0 := Layout.spawn()
	var sp: Array = data.get("_spawn", [sp0.x, sp0.y, sp0.z, 0.0])
	p.position = Vector3(sp[0], sp[1], sp[2])
	p.rotation.y = sp[3]
	players.add_child(p, true)
	if id != multiplayer.get_unique_id():
		var who: String = Net.peer_names.get(id, "Игрок")
		_announce("%s %s" % [who, "вернулся" if data.has("inventory") else "присоединился"])


func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.is_server():
		return
	var p := players.get_node_or_null(str(id))
	if p:
		_announce("%s вышел" % p.player_name)
		p.queue_free()


func _announce(text: String) -> void:
	NetUtil.call_all(self, "announce", [text])


@rpc("authority", "reliable")
func announce(text: String) -> void:
	Events.notify(text, Color.LIGHT_GREEN)


func _on_server_lost() -> void:
	Events.ui_open = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().reload_current_scene()
