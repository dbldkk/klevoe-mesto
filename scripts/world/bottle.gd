class_name Bottle
extends RigidBody3D
## Пустая бутылка. Физику считает хост, остальные только видят результат.
## Брошенная бутылка помнит, кто её кинул, — до первого удара.

## Чем была бутылка (для цвета). &"empty" — подобранная и брошенная.
@export var kind: StringName = &"empty"

var thrower: int = 0       ## peer id бросившего (только на сервере)
var _speed := 0.0


func _ready() -> void:
	var model := ItemModels.build("drink" if GameData.get_drink(kind) else "bottle", kind)
	model.position.y = -0.1
	add_child(model)

	if multiplayer.is_server():
		contact_monitor = true
		max_contacts_reported = 4
		body_entered.connect(_on_body_entered)
	else:
		freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		freeze = true


func _physics_process(_delta: float) -> void:
	if multiplayer.is_server():
		_speed = linear_velocity.length()


func _on_body_entered(other: Node) -> void:
	if thrower == 0:
		return
	var by := thrower
	thrower = 0
	if _speed < 4.0:
		return
	Sfx.play("bottle_clink", global_position)
	var manager := get_parent()
	if other.is_in_group("players") and other.name.to_int() != by:
		manager.on_player_hit(by, other)
	elif other.has_method("on_bottle_hit"):
		other.on_bottle_hit(by)
	elif other.get_parent() and other.get_parent().has_method("on_bottle_hit"):
		other.get_parent().on_bottle_hit(by)


# Подсказки для взгляда (через зону Pickup).
func get_prompt(_player: Node) -> String:
	return "Подобрать пустую бутылку"


func interact(_player: Node) -> void:
	get_parent().request_pickup(name)
