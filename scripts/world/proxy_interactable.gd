extends Interactable
## Зона взаимодействия, которая передаёт вызовы узлу target (созданному из кода).

var target: Node


func get_prompt(player: Node) -> String:
	return target.get_prompt(player) if target and target.has_method("get_prompt") else ""


func interact(player: Node) -> void:
	if target and target.has_method("interact"):
		target.interact(player)


func get_gift_prompt(player: Node) -> String:
	return target.get_gift_prompt(player) if target and target.has_method("get_gift_prompt") else ""


func gift(player: Node) -> void:
	if target and target.has_method("gift"):
		target.gift(player)
