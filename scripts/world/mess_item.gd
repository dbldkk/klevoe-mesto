class_name MessItem
extends Node3D
## Какашка или лужа. Возраст растёт у хоста; когда истёк срок — исчезает.

@export_enum("poop", "puddle") var kind: String = "poop"
@export var age: float = 0.0
var life: float = 300.0
var _visual: Node3D
var _flies: Array[Node3D] = []
var _t := 0.0


func _ready() -> void:
	life = 300.0 if kind == "poop" else 60.0
	if kind == "poop":
		_visual = ItemModels.build("bait", &"poop")
		_visual.scale = Vector3.ONE * 1.6
		add_child(_visual)
		for i in 3:
			var f := Art.add_mesh(self, Art.sphere(0.012, 4), Art.color(Color(0.05, 0.05, 0.05)), Vector3.ZERO)
			_flies.append(f)
	else:
		_visual = Node3D.new()
		add_child(_visual)
		var m := Art.color(Color(0.95, 0.85, 0.2, 0.55), 0.05)
		Art.add_mesh(_visual, Art.cyl(0.45, 0.45, 0.01, 16), m, Vector3(0, 0.01, 0), Vector3.ZERO, Vector3(1, 1, 0.7))


func _process(delta: float) -> void:
	_t += delta
	for i in _flies.size():
		var a := _t * (3.0 + i) + i * 2.0
		_flies[i].position = Vector3(cos(a) * 0.2, 0.25 + sin(_t * 5.0 + i) * 0.06, sin(a) * 0.2)
	if kind == "puddle":
		var k := clampf(1.0 - age / maxf(life, 1.0), 0.05, 1.0)
		_visual.scale = Vector3(k, 1, k)
	age += delta
	if multiplayer.is_server() and age >= life:
		queue_free()


func get_prompt(_player: Node) -> String:
	return "Подобрать какашку (наживка)" if kind == "poop" else ""


func interact(_player: Node) -> void:
	if kind == "poop":
		get_parent().request_pickup(name)
