extends Node3D
## Наш дом: одна кровать, стол, стул, на столе пустая бутылка и фотка собаки.
## Кровать — E: лечь спать. Новый день начинается, когда спят все.
## Дверь — в стене +Z (в сцене дом повёрнут дверью к дороге).

const W := 9.0
const D := 7.0
const H := 3.0
## Ноги на кровати (локально) и куда смотрит голова.
const BED_FOOT := Vector3(-1.4, 0.62, -2.65)
const BED_HEAD_DIR := Vector3(-1, 0, 0)


func _enter_tree() -> void:
	transform = Layout.xform("house")


func _ready() -> void:
	add_to_group("poi")
	set_meta("poi_name", "Дом")
	var wall := Art.tex_world("brick", 0.55)
	var inner := Art.tex_world("wallpaper", 0.45)
	var floor_m := Art.tex_world("planks", 0.5)
	var roof := Art.tex_world("roof", 0.35)
	Build.room(self, W, D, H, wall, inner, floor_m, roof, 1.2, 2.2, 0.0)
	Build.gable_roof(self, W, D, H, roof, Art.tex_world("planks", 0.5), 1.7)
	Build.plinth(self, W, D, 1.2)
	Build.corners(self, W, D, H, Art.color(Color(0.85, 0.82, 0.75), 0.8))
	# печная труба
	Build.block(self, Vector3(-2.2, H + 1.6, -0.9), Vector3(0.55, 1.6, 0.55), Art.tex_world("brick_dark", 0.5), false)
	Build.block(self, Vector3(-2.2, H + 2.45, -0.9), Vector3(0.68, 0.1, 0.68), Art.color(Color(0.3, 0.3, 0.3)), false)
	Build.door(self, Vector3(0, 0, D / 2 - 0.11), 1.2, 2.2)
	# козырёк над дверью
	Build.block(self, Vector3(0, 2.45, D / 2 + 0.45), Vector3(1.9, 0.08, 1.0), Art.tex_world("roof", 0.35), false, Vector3(-0.25, 0, 0))
	for x in [-0.85, 0.85]:
		Build.block(self, Vector3(x, 1.2, D / 2 + 0.85), Vector3(0.08, 2.4, 0.08), Art.tex_world("planks", 0.6), false)
	_yard()
	# Крыльцо и вывеска
	Build.block(self, Vector3(0, 0.04, D / 2 + 0.6), Vector3(2.2, 0.08, 1.2), Art.tex_world("planks", 0.6), false)
	Build.sign(self, Vector3(0, 2.6, D / 2 + 0.02), "sign_house", Vector2(1.6, 0.5), 0.0, 0.2)
	for wpos in [[Vector3(2.6, 1.6, D / 2), 0.0], [Vector3(-2.6, 1.6, D / 2), 0.0], [Vector3(W / 2, 1.6, 0.0), PI / 2]]:
		var win := Build.window(self, wpos[0], Vector2(1.4, 1.0), wpos[1])
		Build.nalichnik(win, Vector2(1.4, 1.0))
	# лёгкий износ у цоколя
	var stain := Art.color(Color(0.28, 0.24, 0.18, 0.35), 1.0)
	for sx in [-3.2, -1.1, 1.4, 3.1]:
		Art.add_mesh(self, Art.box(Vector3(0.9, 0.28, 0.04)), stain, Vector3(sx, 0.22, D / 2 + 0.05))

	Build.lamp(self, Vector3(0, H - 0.4, 0), 1.1, 9.0, Color(1, 0.85, 0.6))
	Art.add_mesh(self, Art.sphere(0.14, 10), Build.glow_mat(Color(1, 0.9, 0.7), 3.0), Vector3(0, H - 0.25, 0))
	_bed()
	_table()
	# Коврик
	Build.block(self, Vector3(0, 0.045, 0.2), Vector3(2.6, 0.01, 1.8), Art.tex("carpet", 1.0), false)
	Build.block(self, Vector3(0, 0.045, D / 2 + 0.05), Vector3(1.0, 0.01, 0.6), Art.color(Color(0.4, 0.3, 0.2)), false)
	# Шкаф
	Build.block(self, Vector3(-3.9, 1.0, 1.6), Vector3(0.7, 2.0, 1.4), Art.tex_world("planks", 0.8), true)


## Двор: поленница, огород с грядками, колодец.
func _yard() -> void:
	var wood := Art.color(Color(0.55, 0.4, 0.25), 0.9)
	var logs := Node3D.new()
	logs.position = Vector3(-W / 2 - 0.6, 0, -1.8)
	add_child(logs)
	for row in 4:
		for k in 6 - row:
			Art.add_mesh(logs, Art.cyl(0.12, 0.12, 1.0, 8), Art.color(Color(0.62, 0.45, 0.28).darkened(0.05 * (k % 3)), 0.9),
				Vector3(0, 0.12 + row * 0.21, -0.65 + k * 0.25 + row * 0.12), Vector3(0, 0, PI / 2))
	Build.block(logs, Vector3(0, 1.0, 0), Vector3(1.2, 0.06, 1.8), Art.tex_world("roof", 0.35), false, Vector3(0.15, 0, 0))
	Build.block(logs, Vector3(0, 0.5, 0), Vector3(1.1, 1.0, 1.6), wood, true).visible = false
	# грядки за домом
	var soil := Art.color(Color(0.32, 0.22, 0.14), 0.95)
	var leaf := Art.color(Color(0.3, 0.55, 0.2), 0.8)
	for i in 3:
		var z := -D / 2 - 1.6 - i * 1.3
		Build.block(self, Vector3(1.5, 0.08, z), Vector3(4.0, 0.16, 0.8), soil, false)
		for k in 7:
			Art.add_mesh(self, Art.sphere(0.13, 6), leaf, Vector3(-0.3 + k * 0.6, 0.22, z), Vector3.ZERO, Vector3(1, 0.6, 1))
	# пугало
	var sc := Node3D.new()
	sc.position = Vector3(3.9, 0, -D / 2 - 3.0)
	add_child(sc)
	Build.block(sc, Vector3(0, 0.9, 0), Vector3(0.07, 1.8, 0.07), wood, false)
	Build.block(sc, Vector3(0, 1.45, 0), Vector3(1.1, 0.06, 0.06), wood, false)
	Art.add_mesh(sc, Art.box(Vector3(0.5, 0.55, 0.2)), Art.color(Color(0.6, 0.2, 0.15), 0.9), Vector3(0, 1.3, 0))
	Art.add_mesh(sc, Art.sphere(0.16, 8), Art.color(Color(0.85, 0.78, 0.6), 0.9), Vector3(0, 1.75, 0))
	Art.add_mesh(sc, Art.cyl(0.22, 0.12, 0.12, 10), Art.color(Color(0.4, 0.35, 0.2), 0.9), Vector3(0, 1.9, 0))
	# колодец
	var w := Node3D.new()
	w.position = Vector3(-W / 2 - 1.5, 0, -4.0)
	add_child(w)
	Build.cylinder(w, Vector3(0, 0.4, 0), 0.6, 0.8, Art.tex_world("brick_dark", 0.5), true, 14)
	Art.add_mesh(w, Art.cyl(0.5, 0.5, 0.02, 14), Art.color(Color(0.05, 0.08, 0.1), 0.2), Vector3(0, 0.75, 0))
	for x in [-0.55, 0.55]:
		Build.block(w, Vector3(x, 1.1, 0), Vector3(0.08, 1.4, 0.08), wood, false)
	Build.block(w, Vector3(0, 1.95, 0), Vector3(1.4, 0.06, 0.9), Art.tex_world("roof", 0.35), false, Vector3(0.0, 0, 0.0))
	Art.add_mesh(w, Art.cyl(0.07, 0.07, 1.1, 8), wood, Vector3(0, 1.45, 0), Vector3(0, 0, PI / 2))
	Art.add_mesh(w, Art.cyl(0.12, 0.1, 0.2, 10), Art.color(Color(0.55, 0.55, 0.6), 0.4, 0.6), Vector3(0.2, 1.05, 0))


func _bed() -> void:
	var wood := Art.tex_world("planks", 0.9)
	Build.block(self, Vector3(-2.45, 0.25, -2.65), Vector3(2.2, 0.3, 1.2), wood, true)
	Build.block(self, Vector3(-3.6, 0.6, -2.65), Vector3(0.1, 1.0, 1.25), wood, false)
	Build.block(self, Vector3(-2.45, 0.47, -2.65), Vector3(2.1, 0.16, 1.1), Art.color(Color(0.95, 0.95, 0.92), 0.9), false)
	Build.block(self, Vector3(-3.25, 0.6, -2.65), Vector3(0.45, 0.12, 0.8), Art.color(Color(0.98, 0.98, 0.98), 0.9), false)
	Build.block(self, Vector3(-2.0, 0.57, -2.65), Vector3(1.3, 0.06, 1.16), Art.color(Color(0.3, 0.42, 0.7), 0.95), false)
	Build.talk_area(self, Vector3(-2.45, 0.6, -2.65), Vector3(2.2, 1.0, 1.3), self)


func _table() -> void:
	var wood := Art.tex_world("planks", 0.7)
	Build.block(self, Vector3(2.4, 0.74, -2.4), Vector3(1.3, 0.06, 0.85), wood, true)
	for x in [-0.55, 0.55]:
		for z in [-0.35, 0.35]:
			Build.block(self, Vector3(2.4 + x, 0.36, -2.4 + z), Vector3(0.06, 0.72, 0.06), wood, false)
	# Стул
	Build.block(self, Vector3(2.4, 0.45, -1.55), Vector3(0.45, 0.05, 0.45), wood, true)
	Build.block(self, Vector3(2.4, 0.75, -1.33), Vector3(0.45, 0.6, 0.05), wood, false)
	for x in [-0.19, 0.19]:
		for z in [-0.19, 0.19]:
			Build.block(self, Vector3(2.4 + x, 0.22, -1.55 + z), Vector3(0.04, 0.45, 0.04), wood, false)
	# Пустая бутылка
	var bottle := ItemModels.build("bottle", &"empty")
	bottle.position = Vector3(2.05, 0.77, -2.5)
	add_child(bottle)
	# Фотка собаки в рамке
	var frame := Node3D.new()
	frame.position = Vector3(2.65, 0.77, -2.55)
	frame.rotation = Vector3(-0.25, -0.35, 0)
	add_child(frame)
	Art.add_mesh(frame, Art.box(Vector3(0.26, 0.32, 0.02)), Art.color(Color(0.45, 0.28, 0.15), 0.5), Vector3(0, 0.16, 0))
	var q := QuadMesh.new()
	q.size = Vector2(0.22, 0.28)
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://art/textures/dog_photo.png")
	m.roughness = 0.4
	Art.add_mesh(frame, q, m, Vector3(0, 0.16, 0.012))
	Build.talk_area(self, Vector3(2.6, 0.95, -2.5), Vector3(0.4, 0.4, 0.3), _PhotoTalk.new())


## Кровать (E).
func get_prompt(player: Node) -> String:
	return "" if player.sleeping else "Лечь спать"


func interact(player: Node) -> void:
	var foot := to_global(BED_FOOT)
	var dir := (global_basis * BED_HEAD_DIR).normalized()
	player.go_to_bed(foot, dir)


class _PhotoTalk:
	extends Node

	func get_prompt(_p: Node) -> String:
		return "Посмотреть на фотку"

	func interact(_p: Node) -> void:
		Events.notify(["Шарик… Хороший был пёс.", "Шарик бы не одобрил, сколько я пью.",
			"На обороте: «Лучший друг рыбака»."].pick_random(), Color(1, 0.92, 0.75))
