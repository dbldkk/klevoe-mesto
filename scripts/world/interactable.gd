class_name Interactable
extends Area3D
## Всё, на что можно навести взгляд и нажать E (взять/говорить) или G (угостить).
## Игрок пускает луч из глаз по слою 5 ("interact").

const LAYER := 16


func _init() -> void:
	collision_layer = LAYER
	collision_mask = 0
	monitoring = false


## Текст подсказки для E. Пустая строка — E недоступно.
func get_prompt(_player: Node) -> String:
	return ""


func interact(_player: Node) -> void:
	pass


## Текст подсказки для G. Пустая строка — G недоступно.
func get_gift_prompt(_player: Node) -> String:
	return ""


func gift(_player: Node) -> void:
	pass
