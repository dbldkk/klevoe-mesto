class_name NetUtil
## Короткие помощники для RPC: одинаково работают и у хоста, и у клиента.


## Вызвать метод на сервере (у хоста — просто вызов).
static func call_server(node: Node, method: StringName, args: Array = []) -> void:
	if node.multiplayer.is_server():
		node.callv(method, args)
	else:
		node.callv("rpc_id", [1, method] + args)


## Вызвать метод у конкретного игрока.
static func call_peer(node: Node, peer: int, method: StringName, args: Array = []) -> void:
	if peer == node.multiplayer.get_unique_id():
		node.callv(method, args)
	elif Net.is_online():
		node.callv("rpc_id", [peer, method] + args)


## Вызвать метод у всех (и у себя).
static func call_all(node: Node, method: StringName, args: Array = []) -> void:
	node.callv(method, args)
	if Net.is_online():
		node.callv("rpc", [method] + args)


## Кто прислал текущий RPC (у хоста при прямом вызове — сам хост).
static func sender(node: Node) -> int:
	var s := node.multiplayer.get_remote_sender_id()
	return s if s != 0 else node.multiplayer.get_unique_id()
