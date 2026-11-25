class_name ComicRagdoll
extends Node3D
## Short-lived articulated physics prop. The player recovers after the gag.

var torso: RigidBody3D
var bodies: Array[RigidBody3D] = []
var palette: Dictionary = {}

func _ready() -> void:
	var shirt := Art.color(palette.get("shirt",Color(0.35,0.45,0.32)))
	var skin := Art.color(palette.get("skin",Color(0.9,0.72,0.56)))
	torso = _part(Vector3(0,1.0,0),Vector3(0.48,0.6,0.3),shirt,4)
	_part(Vector3(0,1.55,0),Vector3(0.3,0.3,0.3),skin,1)
	for side in [-1,1]:
		_part(Vector3(side*0.42,1.1,0),Vector3(0.18,0.6,0.18),shirt,1)
		_part(Vector3(side*0.14,0.4,0),Vector3(0.2,0.7,0.22),Art.color(palette.get("pants",Color(0.2,0.22,0.26))),1.5)
	for b in bodies:
		b.apply_central_impulse(Vector3(randf_range(-1.4,1.4),2,randf_range(-1.2,1.2)))
		b.apply_torque_impulse(Vector3(randf_range(-2,2),1,randf_range(-2,2)))
	get_tree().create_timer(5).timeout.connect(queue_free)

func _part(pos: Vector3,size: Vector3,mat: Material,mass_value: float) -> RigidBody3D:
	var b := RigidBody3D.new()
	b.mass = mass_value
	b.collision_layer = 0
	b.collision_mask = 1
	b.position = pos
	b.continuous_cd = true
	add_child(b)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	b.add_child(shape)
	Art.add_mesh(b,Art.box(size),mat)
	if torso:
		var joint := PinJoint3D.new()
		joint.position = pos.lerp(torso.position,0.5)
		add_child(joint)
		joint.node_a = joint.get_path_to(torso)
		joint.node_b = joint.get_path_to(b)
		joint.exclude_nodes_from_collision = true
	bodies.append(b)
	return b
