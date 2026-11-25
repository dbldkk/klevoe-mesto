extends Node3D
## Казино «Золотой карась»: рулетка с крупье и три автомата, у каждого — свой человек,
## который принимает ставку (деньгами или любой вещью) и назначает выигрыш.

const W := 20.0
const D := 14.0
const H := 4.5

var _wheel: Node3D
var _bulbs: Array[StandardMaterial3D] = []
var _t := 0.0


func _enter_tree() -> void:
	transform = Layout.xform("casino")


func _ready() -> void:
	add_to_group("poi")
	set_meta("poi_name", "Казино")
	var wall := Art.tex_world("brick", 0.5).duplicate() as StandardMaterial3D
	wall.albedo_color = Color(0.85, 0.5, 0.55)
	var inner := Art.color(Color(0.25, 0.06, 0.1), 0.8)
	Build.room(self, W, D, H, wall, inner, Art.tex_world("carpet", 0.35), Art.tex_world("roof", 0.3), 2.2, 2.8, 0.0)
	Build.door(self, Vector3(0, 0, D / 2 - 0.11), 2.2, 2.8, true, Color(0.55, 0.1, 0.12))
	# Фасад: вывеска, лампочки, колонны
	Build.sign(self, Vector3(0, 3.55, D / 2 + 0.03), "sign_casino", Vector2(8.0, 1.7), 0.0, 1.6)
	for i in 24:
		var m := Build.glow_mat(Color(1.0, 0.8, 0.3), 2.5)
		_bulbs.append(m)
		var x := -4.3 + i * (8.6 / 23.0)
		Art.add_mesh(self, Art.sphere(0.07, 6), m, Vector3(x, 4.5, D / 2 + 0.08))
		Art.add_mesh(self, Art.sphere(0.07, 6), m, Vector3(x, 2.62, D / 2 + 0.08))
	for x in [-1.6, 1.6]:
		Build.block(self, Vector3(x, 1.4, D / 2 + 0.25), Vector3(0.35, 2.8, 0.35), Art.color(Color(0.85, 0.7, 0.3), 0.3, 0.6), true)
	Build.block(self, Vector3(0, 0.05, D / 2 + 1.5), Vector3(3.0, 0.1, 3.0), Art.color(Color(0.6, 0.08, 0.12)), false)
	Build.lamp(self, Vector3(0, 3.2, D / 2 + 1.5), 1.6, 9.0, Color(1.0, 0.7, 0.4), true)
	# Внутри: люстры
	for x in [-5.0, 0.0, 5.0]:
		Build.lamp(self, Vector3(x, H - 0.7, 0), 1.4, 11.0, Color(1.0, 0.85, 0.6))
		Art.add_mesh(self, Art.sphere(0.22, 12), Build.glow_mat(Color(1.0, 0.85, 0.55), 0.9), Vector3(x, H - 0.45, 0))
		Art.add_mesh(self, Art.cyl(0.02, 0.02, 0.4, 6), Art.color(Color(0.8, 0.65, 0.3), 0.3, 0.7), Vector3(x, H - 0.2, 0))
	_roulette()
	_slots()
	_bar()


func _roulette() -> void:
	var t := Node3D.new()
	t.position = Vector3(0, 0, -1.0)
	add_child(t)
	Build.block(t, Vector3(0, 0.45, 0), Vector3(3.6, 0.9, 1.8), Art.color(Color(0.35, 0.2, 0.1), 0.5), true)
	Build.block(t, Vector3(0, 0.91, 0), Vector3(3.4, 0.03, 1.6), Art.tex("felt", 1.0), false)
	_wheel = Node3D.new()
	_wheel.position = Vector3(-1.1, 0.96, 0)
	_wheel.set_meta("no_bake", true)
	t.add_child(_wheel)
	Art.add_mesh(_wheel, Art.cyl(0.55, 0.6, 0.1, 37), Art.color(Color(0.35, 0.2, 0.08), 0.4), Vector3.ZERO)
	for i in 37:
		var a := TAU * i / 37.0
		var col := Color(0.1, 0.6, 0.15) if i == 0 else (Color(0.8, 0.08, 0.08) if i % 2 == 1 else Color(0.06, 0.06, 0.06))
		Art.add_mesh(_wheel, Art.box(Vector3(0.09, 0.02, 0.12)), Art.color(col, 0.4), Vector3(cos(a) * 0.45, 0.06, sin(a) * 0.45), Vector3(0, -a, 0))
	Art.add_mesh(_wheel, Art.cyl(0.08, 0.12, 0.14, 12), Art.color(Color(0.85, 0.7, 0.3), 0.3, 0.7), Vector3(0, 0.08, 0))
	# Сетка ставок на сукне
	for i in 12:
		for j in 3:
			var n := i * 3 + j + 1
			var red := n in [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]
			Art.add_mesh(t, Art.box(Vector3(0.14, 0.005, 0.14)), Art.color(Color(0.75, 0.1, 0.1) if red else Color(0.08, 0.08, 0.08), 0.6),
				Vector3(-0.2 + i * 0.15, 0.93, -0.25 + j * 0.16))
	var croupier: CasinoDealer = load("res://scripts/world/npc/casino_dealer.gd").new()
	croupier.name = "Croupier"
	croupier.game = "roulette"
	croupier.dealer_name = "Аркадий"
	croupier.face = "croupier"
	croupier.skin_data = {"shirt": 8, "pants": 1, "skin": 0, "hat": 4, "hat_color": 0, "face": 0}
	croupier.position = Vector3(0, 0, -2.4)
	croupier.rotation.y = PI
	croupier.picky = 0.35
	add_child(croupier)


func _slots() -> void:
	var dealers := [["Валера", "dealer_m", {"shirt": 3, "pants": 1, "skin": 1, "hat": 1, "hat_color": 1}, 0.2],
		["Жанна", "dealer_f", {"shirt": 6, "pants": 1, "skin": 4, "hat": 0, "hat_color": 4}, 0.45],
		["Стас", "dealer_m", {"shirt": 2, "pants": 0, "skin": 2, "hat": 2, "hat_color": 3}, 0.3]]
	for i in 3:
		var x := -7.5 + i * 3.0
		var mach := Node3D.new()
		mach.position = Vector3(x, 0, -6.2)
		add_child(mach)
		_slot_machine(mach, i)
		var dl = load("res://scripts/world/npc/casino_dealer.gd").new()
		dl.name = "Slots%d" % i
		dl.game = "slots"
		dl.dealer_name = dealers[i][0]
		dl.face = dealers[i][1]
		dl.skin_data = dealers[i][2]
		dl.picky = dealers[i][3]
		dl.position = Vector3(x + 1.0, 0, -5.6)
		dl.rotation.y = PI - 0.6
		add_child(dl)


func _slot_machine(m: Node3D, idx: int) -> void:
	var colors := [Color(0.75, 0.1, 0.1), Color(0.15, 0.3, 0.75), Color(0.6, 0.45, 0.1)]
	Build.block(m, Vector3(0, 0.9, 0), Vector3(0.9, 1.8, 0.7), Art.color(colors[idx], 0.35, 0.4), true)
	Build.block(m, Vector3(0, 1.85, 0.05), Vector3(0.95, 0.25, 0.75), Build.glow_mat(Color(1, 0.85, 0.3), 1.8), false)
	Build.block(m, Vector3(0, 1.25, 0.36), Vector3(0.7, 0.45, 0.02), Build.glow_mat(Color(0.75, 0.9, 1.0), 1.0), false)
	for k in 3:
		Art.add_mesh(m, Art.box(Vector3(0.18, 0.3, 0.01)), Art.color(Color(0.97, 0.97, 0.95)), Vector3(-0.22 + k * 0.22, 1.25, 0.375))
	Build.block(m, Vector3(0, 0.8, 0.4), Vector3(0.8, 0.08, 0.15), Art.color(Color(0.2, 0.2, 0.2), 0.3, 0.6), false)
	Art.add_mesh(m, Art.cyl(0.02, 0.02, 0.5, 6), Art.color(Color(0.8, 0.8, 0.82), 0.2, 0.8), Vector3(0.5, 1.25, 0.1))
	Art.add_mesh(m, Art.sphere(0.07, 8), Art.color(Color(0.9, 0.1, 0.1), 0.3), Vector3(0.5, 1.52, 0.1))
	Build.text(m, Vector3(0, 1.85, 0.43), ["ДЖЕКПОТ", "777", "КАРАСЬ"][idx], 40, Color(0.3, 0.05, 0.05), 0.005)


func _bar() -> void:
	var wood := Art.tex_world("planks", 0.6)
	Build.block(self, Vector3(6.5, 0.55, -4.5), Vector3(5.0, 1.1, 0.7), wood, true)
	Build.block(self, Vector3(6.5, 1.12, -4.5), Vector3(5.1, 0.05, 0.8), Art.color(Color(0.1, 0.1, 0.1), 0.2, 0.3), false)
	var shelf := load("res://scripts/world/shop/shop_item.gd")
	for j in 3:
		var it: Node3D = shelf.new()
		it.kind = "drink"
		it.item_id = [&"cognac", &"champagne", &"vodka"][j]
		it.facings = 6
		it.spacing = 0.18
		it.decor_only = true
		it.position = Vector3(5.0 + j * 1.5, 1.6, -6.7)
		add_child(it)
	Build.block(self, Vector3(6.5, 1.58, -6.7), Vector3(5.0, 0.04, 0.4), wood, false)
	Build.board_sign(self, Vector3(6.5, 2.55, -6.82), "БАР", 0.0, Vector2(0.7, 0.32), 0.0, Color(1, 0.85, 0.45), false)
	for x in [-6.0, 6.0]:
		Build.block(self, Vector3(x, 0.4, 3.0), Vector3(1.2, 0.8, 1.2), Art.color(Color(0.3, 0.05, 0.08), 0.6), true)


func _process(delta: float) -> void:
	_t += delta
	if _wheel:
		_wheel.rotation.y += delta * 0.8
	for i in _bulbs.size():
		_bulbs[i].emission_energy_multiplier = 3.0 if int(_t * 4.0 + i) % 3 == 0 else 0.6
