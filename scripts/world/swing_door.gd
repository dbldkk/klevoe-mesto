extends Node3D
## Распашная дверь: сама открывается внутрь, когда рядом человек (игрок или NPC), и закрывается.
## Узел = петля. Полотно ширины width уходит в +X (или −X, если mirror).

@export var width: float = 1.0
@export var height: float = 2.1
@export var mirror: bool = false
@export var color: Color = Color(0.45, 0.3, 0.18)
## Угол открытия (рад) и радиус «чувствует человека».
@export var open_angle: float = 1.65
@export var sense: float = 1.9

var _body: AnimatableBody3D
var _angle := 0.0
var _was_open := false
var _check := 0.0
var _want := false


func _ready() -> void:
	_body = AnimatableBody3D.new()
	_body.collision_layer = 1
	_body.collision_mask = 0
	_body.sync_to_physics = false
	add_child(_body)
	var sx := -1.0 if mirror else 1.0
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(width - 0.04, height - 0.04, 0.06)
	cs.shape = sh
	cs.position = Vector3(sx * width / 2, height / 2, 0)
	_body.add_child(cs)
	var wood := Art.tex_world("planks", 0.7).duplicate() as StandardMaterial3D
	wood.albedo_color = color
	wood.uv1_world_triplanar = false
	Art.add_mesh(_body, Art.box(Vector3(width - 0.04, height - 0.04, 0.06)), wood, cs.position)
	# Ручка и филёнки
	var brass := Art.color(Color(0.85, 0.7, 0.3), 0.3, 0.8)
	for side in [-1.0, 1.0]:
		Art.add_mesh(_body, Art.box(Vector3(0.03, 0.03, 0.14)), brass, Vector3(sx * (width - 0.12), 1.0, 0.07 * side))
	var panel := wood.duplicate() as StandardMaterial3D
	panel.albedo_color = color.darkened(0.2)
	for y in [0.55, 1.45]:
		for side in [-1.0, 1.0]:
			Art.add_mesh(_body, Art.box(Vector3(width * 0.6, 0.6, 0.01)), panel, Vector3(sx * width / 2, y, 0.035 * side))


func _physics_process(delta: float) -> void:
	_check -= delta
	if _check <= 0.0:
		_check = 0.15
		_want = false
		var c := to_global(Vector3((-1.0 if mirror else 1.0) * width / 2, 1.0, 0))
		for n in get_tree().get_nodes_in_group("players"):
			if (n as Node3D).global_position.distance_to(c) < sense + 0.6 and not n.hidden:
				_want = true
				break
		if not _want:
			for n in get_tree().get_nodes_in_group("npc"):
				if n is Node3D and (n as Node3D).global_position.distance_to(c) < sense:
					_want = true
					break
	var target := open_angle if _want else 0.0
	_angle = move_toward(_angle, target, delta * (3.2 if _want else 2.2))
	_body.rotation.y = _angle * (-1.0 if mirror else 1.0)
	if _want != _was_open and absf(_angle - target) > 0.2:
		_was_open = _want
		var sfx := get_node_or_null("/root/Sfx")
		if sfx:
			sfx.play("door_open" if _want else "door_close", global_position + Vector3(0, 1, 0), -6.0)
