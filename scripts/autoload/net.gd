extends Node
## Сеть (автозагрузка Net). Хост = сервер + игрок.
##
## Порядок подключения:
## 1. Клиент подключается и шлёт хосту свой id профиля (register).
## 2. Хост находит игрока в сохранении мира и отправляет ему его вещи (apply_player).
## 3. Хост создаёт персонажа там, где игрок вышел в прошлый раз (сигнал player_registered).
## Каждые несколько секунд клиент отправляет хосту свежие данные (store_player),
## хост периодически записывает мир на диск.

signal hosted
signal joined
signal join_failed
signal server_lost
signal player_registered(peer_id: int, data: Dictionary)

const DEFAULT_PORT := 7777
const MAX_CLIENTS := 7
const SNAPSHOT_INTERVAL := 4.0
const AUTOSAVE_INTERVAL := 45.0

var player_name: String = "Рыбак"
var last_message: String = ""
## Только на сервере: peer id -> id профиля
var peer_profiles: Dictionary = {}
## Только на сервере: peer id -> имя
var peer_names: Dictionary = {}

## Где появится наш персонаж (присылает хост).
var spawn_position := Vector3.ZERO
var spawn_rotation := 0.0

var _registered := false
var _snapshot_timer := 0.0
var _autosave_timer := AUTOSAVE_INTERVAL
var _exiting := false


func _ready() -> void:
	get_tree().auto_accept_quit = false
	player_name = Saves.profile_name
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


func is_online() -> bool:
	var p := multiplayer.multiplayer_peer
	return p != null and not (p is OfflineMultiplayerPeer) \
		and p.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func host(port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	peer_profiles.clear()
	peer_names.clear()
	_autosave_timer = AUTOSAVE_INTERVAL
	hosted.emit()
	_register(1, Saves.profile_id, player_name)
	return OK


func join(address: String, port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	return OK


func leave() -> void:
	Sfx.stop_world_audio()
	_registered = false
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	peer_profiles.clear()
	peer_names.clear()


## Безопасно сохраниться и выйти в главное меню.
func exit_to_menu() -> void:
	if _exiting:
		return
	_exiting = true
	send_snapshot()
	if multiplayer.is_server():
		if not Saves.save_world():
			_exit_failed()
			return
	await get_tree().create_timer(0.3).timeout
	leave()
	Saves.close_world()
	Events.ui_open = false
	_exiting = false
	get_tree().reload_current_scene()


func quit_game() -> void:
	if _exiting:
		return
	_exiting = true
	if _registered:
		send_snapshot()
		if multiplayer.is_server():
			if not Saves.save_world():
				_exit_failed()
				return
		else:
			await get_tree().create_timer(0.3).timeout
	get_tree().quit()


func _exit_failed() -> void:
	_exiting = false
	var pause := get_tree().get_first_node_in_group("pause_menu")
	if pause:
		pause.open()


# ------------------------------------------------------------ регистрация

func _on_connected() -> void:
	joined.emit()
	register.rpc_id(1, Saves.profile_id, player_name)


@rpc("any_peer", "reliable")
func register(pid: String, pname: String) -> void:
	if multiplayer.is_server():
		_register(multiplayer.get_remote_sender_id(), pid, pname)


func _register(peer: int, pid: String, pname: String) -> void:
	if peer_profiles.has(peer):
		return
	# Две копии игры с одним профилем — второй даём отдельный id.
	if pid in peer_profiles.values():
		pid = "%s#%d" % [pid, peer]
	peer_profiles[peer] = pid
	peer_names[peer] = pname
	var data := Saves.get_player(pid).duplicate(true)
	var pos := Layout.spawn() + Vector3(randf_range(-2.0, 2.0), 0, randf_range(-1.0, 1.0))
	var saved = data.get("pos")
	if saved is Array and saved.size() == 3 and float(saved[1]) > -5.0:
		pos = Vector3(saved[0], float(saved[1]) + 0.3, saved[2])
	data["_spawn"] = [pos.x, pos.y, pos.z, float(data.get("rot", Layout.spawn_yaw()))]
	if peer == multiplayer.get_unique_id():
		_apply_player(data)
	else:
		apply_player.rpc_id(peer, data, Saves.world_display_name())
	player_registered.emit(peer, data)


@rpc("authority", "reliable")
func apply_player(data: Dictionary, world_name: String) -> void:
	Saves.world = {"name": world_name}
	_apply_player(data)


func _apply_player(data: Dictionary) -> void:
	_registered = true
	_snapshot_timer = SNAPSHOT_INTERVAL
	var sp0 := Layout.spawn()
	var sp: Array = data.get("_spawn", [sp0.x, sp0.y, sp0.z, 0.0])
	spawn_position = Vector3(sp[0], sp[1], sp[2])
	spawn_rotation = sp[3]
	if data.has("inventory"):
		Inventory.from_dict(data.inventory)
		Events.notify("С возвращением, %s!" % player_name, Color.PALE_GREEN)
	else:
		Inventory.reset()
		Events.notify("Добро пожаловать в мир «%s»!" % Saves.world_display_name(), Color.PALE_GREEN)


func profile_of(peer: int) -> String:
	return peer_profiles.get(peer, "")


# ------------------------------------------------------------ снимки игроков

func _process(delta: float) -> void:
	if not _registered or not is_online():
		return
	_snapshot_timer -= delta
	if _snapshot_timer <= 0.0:
		_snapshot_timer = SNAPSHOT_INTERVAL
		send_snapshot()
	if multiplayer.is_server():
		_autosave_timer -= delta
		if _autosave_timer <= 0.0:
			_autosave_timer = AUTOSAVE_INTERVAL
			Saves.save_world()


func send_snapshot() -> void:
	if not _registered or not is_online():
		return
	var data := {"name": player_name, "inventory": Inventory.to_dict()}
	var p := get_tree().get_first_node_in_group("local_player") as Node3D
	if p:
		var save_pos: Vector3 = p.global_position
		var m := p.get_node_or_null("Mischief")
		if m and m.stunt_left > 0:
			save_pos = m._landing
		data["pos"] = [save_pos.x, save_pos.y, save_pos.z]
		data["rot"] = p.rotation.y
	if multiplayer.is_server():
		_store(multiplayer.get_unique_id(), data)
	else:
		store_player.rpc_id(1, data)


@rpc("any_peer", "reliable")
func store_player(data: Dictionary) -> void:
	if multiplayer.is_server():
		_store(multiplayer.get_remote_sender_id(), data)


func _store(peer: int, data: Dictionary) -> void:
	var pid := profile_of(peer)
	if pid != "":
		Saves.set_player(pid, data)


# ------------------------------------------------------------ события

func _on_peer_disconnected(peer: int) -> void:
	if multiplayer.is_server():
		Saves.save_world()
		peer_profiles.erase(peer)
		peer_names.erase(peer)


func _on_connection_failed() -> void:
	leave()
	join_failed.emit()


func _on_server_disconnected() -> void:
	leave()
	Saves.close_world()
	last_message = "Хост вышел из игры"
	server_lost.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()


## Локальные IP (чтобы хост мог сказать другу, куда подключаться).
func local_ips() -> Array[String]:
	var out: Array[String] = []
	for ip in IP.get_local_addresses():
		if ip.begins_with("192.168.") or ip.begins_with("10.") or ip.begins_with("172.") \
				or ip.begins_with("26."):  # 26.x — Radmin VPN
			out.append(ip)
	return out
