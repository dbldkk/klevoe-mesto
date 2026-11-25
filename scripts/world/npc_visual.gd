class_name NpcVisual
extends Node3D
## Простое «тело» человечка из примитивов (пока нет моделей). Смотрит вдоль -Z.

@export var body_color: Color = Color(0.3, 0.3, 0.35)
@export var hat_color: Color = Color(0.15, 0.15, 0.18)
@export var skin_color: Color = Color(0.93, 0.76, 0.62)
@export var has_hat: bool = true
@export var height_scale: float = 1.0

var _head: Node3D


func _ready() -> void:
	var torso := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.36
	cap.height = 1.5
	cap.material = _mat(body_color)
	torso.mesh = cap
	torso.position.y = 0.75
	add_child(torso)

	_head = Node3D.new()
	_head.position.y = 1.62
	add_child(_head)
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.24
	sphere.height = 0.48
	sphere.material = _mat(skin_color)
	head.mesh = sphere
	_head.add_child(head)
	for x in [-0.09, 0.09]:
		var eye := MeshInstance3D.new()
		var em := BoxMesh.new()
		em.size = Vector3(0.05, 0.05, 0.02)
		em.material = _mat(Color(0.05, 0.05, 0.05))
		eye.mesh = em
		eye.position = Vector3(x, 0.04, -0.23)
		_head.add_child(eye)
	var nose := MeshInstance3D.new()
	var nm := SphereMesh.new()
	nm.radius = 0.05
	nm.height = 0.1
	nm.material = _mat(skin_color.darkened(0.1).lerp(Color.RED, 0.15))
	nose.mesh = nm
	nose.position = Vector3(0, -0.03, -0.25)
	_head.add_child(nose)
	if has_hat:
		var hat := MeshInstance3D.new()
		var hm := CylinderMesh.new()
		hm.top_radius = 0.22
		hm.bottom_radius = 0.26
		hm.height = 0.16
		hm.material = _mat(hat_color)
		hat.mesh = hm
		hat.position.y = 0.2
		_head.add_child(hat)
	scale = Vector3.ONE * height_scale


## Красный нос у пьяных.
func set_nose_red(amount: float) -> void:
	var nose := _head.get_child(3) as MeshInstance3D
	if nose:
		(nose.mesh.material as StandardMaterial3D).albedo_color = skin_color.lerp(Color(0.9, 0.15, 0.15), amount)


func set_head_tilt(x: float, z: float = 0.0) -> void:
	if _head:
		_head.rotation = Vector3(x, 0, z)


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m
