extends Node
## Драки: игрок бьёт кулаком или битой — сервер проверяет и раздаёт урон.
## Цели: другие игроки, охранник, Дядя Толя, наперсточник (у кого есть on_melee_hit).


func _ready() -> void:
	add_to_group("combat")


## Вызывает бьющий игрок.
func request_hit(target: Node, damage: float) -> void:
	NetUtil.call_server(self, "srv_hit", [str(target.get_path()), damage])


@rpc("any_peer", "reliable")
func srv_hit(path: String, damage: float) -> void:
	if not multiplayer.is_server():
		return
	var by := NetUtil.sender(self)
	var attacker := get_tree().get_root().get_node_or_null("World/Players/%d" % by) as Node3D
	var target := get_node_or_null(NodePath(path)) as Node3D
	if attacker == null or target == null:
		return
	if attacker.global_position.distance_to(target.global_position) > 4.5:
		return
	damage = clampf(damage, 0.0, 40.0)
	var who: String = Net.peer_names.get(by, "Кто-то")
	if target.is_in_group("players"):
		var victim := target.name.to_int()
		if victim == by:
			return
		NetUtil.call_peer(target, victim, "take_melee", [damage, who])
	elif target.has_method("on_melee_hit"):
		target.on_melee_hit(by, damage)
	else:
		return
	NetUtil.call_peer(self, by, "hit_confirmed", [_name_of(target)])
	# Драку может увидеть участковый или бабка.
	var police := get_tree().get_first_node_in_group("police")
	if police and not target.is_in_group("police"):
		police.witness(by, "драка", attacker.global_position)


func _name_of(n: Node) -> String:
	if n.is_in_group("players"):
		return n.player_name
	if n.has_method("display_name"):
		return n.display_name()
	return "цель"


@rpc("authority", "reliable")
func hit_confirmed(_target_name: String) -> void:
	Inventory.stat_add("hits")
	var me := get_tree().get_first_node_in_group("local_player")
	var bat: bool = me != null and me.held_kind == "weapon"
	Sfx.play("bat_hit" if bat else "punch", me.global_position + Vector3.UP if me else null)


## Сервер сообщает бьющему, что он кого-то вырубил.
func report_knockout(by: int, text: String) -> void:
	NetUtil.call_peer(self, by, "ko_confirmed", [text])


@rpc("authority", "reliable")
func ko_confirmed(text: String) -> void:
	Inventory.stat_add("knockouts")
	Events.notify(text, Color.GOLD)
