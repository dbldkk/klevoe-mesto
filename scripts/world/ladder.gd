extends Node3D
## Лестница у пирса: если упал в воду — подплыви и нажми E.

@export var top_point: Vector3 = Vector3(0, 0.3, 1.0)


func get_prompt(player: Node) -> String:
	return "Вылезти по лестнице" if player.swimming else ""


func interact(player: Node) -> void:
	if player.swimming:
		player.climb_to(to_global(top_point))
