extends Node3D
## Автоматические раздвижные двери «Шестёрочки». Открываются, когда рядом
## кто-то есть (игроки, охранник). Каждый компьютер считает сам по позициям.

const OPEN_DISTANCE := 2.6
const WIDTH := 2.0
const HEIGHT := 2.4

var _left: AnimatableBody3D
var _right: AnimatableBody3D
var _open := 0.0
var _was_want := false


func _ready() -> void:
	_left = _panel(-1)
	_right = _panel(1)


func _panel(side: int) -> AnimatableBody3D:
	var body := AnimatableBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.sync_to_physics = false
	body.position = Vector3(side * WIDTH * 0.25, HEIGHT * 0.5, 0)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(WIDTH * 0.5, HEIGHT, 0.08)
	col.shape = box
	body.add_child(col)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.6, 0.8, 0.9, 0.28)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	glass.metallic = 0.3
	Art.add_mesh(body, Art.box(Vector3(WIDTH * 0.5 - 0.06, HEIGHT - 0.08, 0.03)), glass)
	var frame := Art.color(Color(0.75, 0.76, 0.78), 0.3, 0.7)
	for y in [-1, 1]:
		Art.add_mesh(body, Art.box(Vector3(WIDTH * 0.5, 0.05, 0.06)), frame, Vector3(0, y * (HEIGHT * 0.5 - 0.025), 0))
	for x in [-1, 1]:
		Art.add_mesh(body, Art.box(Vector3(0.05, HEIGHT, 0.06)), frame, Vector3(x * (WIDTH * 0.25 - 0.025), 0, 0))
	Art.add_mesh(body, Art.box(Vector3(0.03, 0.4, 0.1)), frame, Vector3(-side * (WIDTH * 0.25 - 0.1), 0, 0))
	add_child(body)
	return body


func _physics_process(delta: float) -> void:
	var want := false
	for group in ["players", "npc"]:
		for n in get_tree().get_nodes_in_group(group):
			if (n as Node3D).global_position.distance_to(global_position) < OPEN_DISTANCE:
				want = true
				break
	if want != _was_want:
		_was_want = want
		Sfx.play("auto_door", global_position + Vector3.UP, -6.0)
	_open = move_toward(_open, 1.0 if want else 0.0, delta * 2.5)
	var shift := smoothstep(0.0, 1.0, _open) * WIDTH * 0.48
	_left.position.x = -WIDTH * 0.25 - shift
	_right.position.x = WIDTH * 0.25 + shift
