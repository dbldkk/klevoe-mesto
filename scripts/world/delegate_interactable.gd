extends Interactable
## Зона взаимодействия, которая передаёт всё родителю (NPC, игроку, бутылке).


func get_prompt(player: Node) -> String:
	var p := get_parent()
	return p.get_prompt(player) if p.has_method("get_prompt") else ""


func interact(player: Node) -> void:
	var p := get_parent()
	if p.has_method("interact"):
		p.interact(player)


func get_gift_prompt(player: Node) -> String:
	var p := get_parent()
	return p.get_gift_prompt(player) if p.has_method("get_gift_prompt") else ""


func gift(player: Node) -> void:
	var p := get_parent()
	if p.has_method("gift"):
		p.gift(player)
