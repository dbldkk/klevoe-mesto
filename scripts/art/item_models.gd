class_name ItemModels
## 3D-модели предметов (из примитивов + текстуры). Одни и те же модели идут
## на полки магазина, в руки персонажу, на землю и в иконки инвентаря.
## Начало координат — снизу по центру, предмет стоит вдоль +Y.


static func build(kind: String, id: StringName, cond: float = 100.0) -> Node3D:
	var root := Node3D.new()
	match kind:
		"rod": _rod(root, id, cond)
		"drink": _bottle(root, GameData.get_drink(id))
		"bottle": _bottle(root, null)
		"bait": _bait(root, id)
		"food": _food(root, id)
		"weapon": _bat(root)
		"smoke": _smokes(root, id)
		"box": _box(root)
		"sack": _sack(root)
		"misc": _misc(root, id)
		"tool":
			if id == &"net":
				_net(root)
			else:
				_flashlight(root)
		"cig": _cig(root)
		"fish":
			var f := GameData.get_fish(id)
			if f:
				var m := FishMesh.build(f)
				m.rotation = Vector3(0, PI / 2, 0)
				m.position.y = 0.1
				root.add_child(m)
	return root


static func _rod(root: Node3D, id: StringName, cond: float) -> void:
	var r := GameData.get_rod(id)
	var c := r.color if r else Color.TAN
	var broken := cond <= 0.0
	var heavy := id == &"sea" or id == &"feeder"
	var bamboo := id == &"bamboo"
	var handle_h := 0.30 if heavy else 0.26
	var blank_len := 1.55 if bamboo else (1.9 if heavy else 1.75)
	var butt_r := 0.018 if heavy else (0.014 if bamboo else 0.012)
	var tip_r := 0.0045 if bamboo else 0.0035
	# Рукоять
	var cork := Art.color(Color(0.62, 0.48, 0.28) if bamboo else Color(0.72, 0.6, 0.4), 0.95)
	Art.add_mesh(root, Art.cyl(butt_r + 0.004, butt_r + 0.006, handle_h, 10), cork, Vector3(0, handle_h * 0.5, 0))
	Art.add_mesh(root, Art.cyl(butt_r + 0.007, butt_r + 0.007, 0.018, 10),
		Art.color(Color(0.15, 0.14, 0.13), 0.5, 0.4), Vector3(0, 0.012, 0))
	# Катушкодержатель
	var seat_y := handle_h + 0.02
	Art.add_mesh(root, Art.cyl(butt_r + 0.002, butt_r, 0.05, 8),
		Art.color(Color(0.35, 0.36, 0.38), 0.4, 0.55), Vector3(0, seat_y, 0))
	_reel(root, Vector3(0, seat_y + 0.01, 0), heavy, not bamboo)
	# Хлыст
	var blank_y := seat_y + 0.04 + blank_len * 0.5
	var tip := Marker3D.new()
	tip.name = "RodTip"
	if broken:
		Art.add_mesh(root, Art.cyl(tip_r * 2.0, butt_r, blank_len * 0.55, 8), Art.color(c, 0.45),
			Vector3(0, seat_y + 0.04 + blank_len * 0.275, 0))
		Art.add_mesh(root, Art.cyl(tip_r, tip_r * 2.0, blank_len * 0.45, 8), Art.color(c, 0.45),
			Vector3(0.22, seat_y + 0.08 + blank_len * 0.7, 0), Vector3(0, 0, -0.85))
		tip.position = Vector3(0.22, seat_y + 0.08 + blank_len * 0.7, 0)
		root.add_child(tip)
	else:
		Art.add_mesh(root, Art.cyl(tip_r, butt_r, blank_len, 8), Art.color(c, 0.35),
			Vector3(0, blank_y, 0))
		# Кольца-пропускники
		var guides := 6 if heavy else (5 if not bamboo else 4)
		var chrome := Art.color(Color(0.82, 0.84, 0.86), 0.25, 0.8)
		for k in guides:
			var t := (k + 1) / float(guides + 1)
			t *= t  # чаще к вершинке
			var y := seat_y + 0.08 + blank_len * t
			var rr := lerpf(butt_r, tip_r, t)
			Art.add_mesh(root, Art.cyl(rr + 0.007, rr + 0.007, 0.005, 8), chrome, Vector3(0, y, 0.01))
			Art.add_mesh(root, Art.cyl(rr + 0.011, rr + 0.009, 0.003, 8), chrome,
				Vector3(0, y, 0.013), Vector3(PI / 2, 0, 0))
		# Тюльпан на кончике
		var tip_y := seat_y + 0.04 + blank_len
		Art.add_mesh(root, Art.cyl(0.006, 0.005, 0.008, 8), chrome, Vector3(0, tip_y, 0.004))
		tip.position = Vector3(0, tip_y + 0.01, 0)
		root.add_child(tip)




static func _reel(root: Node3D, at: Vector3, heavy: bool, spinning: bool) -> void:
	var body_col := Art.color(Color(0.18, 0.18, 0.2) if spinning else Color(0.35, 0.28, 0.18), 0.45, 0.55)
	var spool_col := Art.color(Color(0.55, 0.58, 0.6), 0.35, 0.65)
	var scale := 1.2 if heavy else (1.0 if spinning else 0.85)
	var cx := at.x + 0.045 * scale
	var cy := at.y
	# Лапка
	Art.add_mesh(root, Art.box(Vector3(0.05 * scale, 0.012, 0.012)), body_col, at + Vector3(0.02 * scale, 0, 0))
	# Корпус
	Art.add_mesh(root, Art.cyl(0.028 * scale, 0.03 * scale, 0.034 * scale, 12), body_col,
		Vector3(cx, cy, 0), Vector3(0, 0, PI / 2))
	# Шпуля
	Art.add_mesh(root, Art.cyl(0.022 * scale, 0.022 * scale, 0.028 * scale, 12), spool_col,
		Vector3(cx + 0.01 * scale, cy, 0), Vector3(0, 0, PI / 2))
	# Дужка / ротор
	Art.add_mesh(root, Art.cyl(0.003, 0.003, 0.05 * scale, 6), body_col,
		Vector3(cx, cy + 0.03 * scale, 0), Vector3(0, 0, 0.4))
	# Ручка катушки — крутится при подмотке
	var crank := Node3D.new()
	crank.name = "ReelCrank"
	crank.position = Vector3(cx, cy, 0)
	root.add_child(crank)
	Art.add_mesh(crank, Art.cyl(0.003, 0.003, 0.055 * scale, 6), body_col,
		Vector3(0, 0.028 * scale, 0), Vector3(0, 0, PI / 2))
	Art.add_mesh(crank, Art.sphere(0.01 * scale, 8), Art.color(Color(0.12, 0.12, 0.12), 0.6),
		Vector3(0.028 * scale, 0.028 * scale, 0))


static func _bottle(root: Node3D, d: DrinkData) -> void:
	var col := d.bottle_color if d else Color(0.2, 0.45, 0.25)
	var glass := Art.glass(col)
	var shape := d.shape if d else 0
	match shape:
		0:  # пивная
			Art.add_mesh(root, Art.cyl(0.035, 0.036, 0.15, 12), glass, Vector3(0, 0.075, 0))
			Art.add_mesh(root, Art.cyl(0.015, 0.035, 0.06, 12), glass, Vector3(0, 0.18, 0))
			Art.add_mesh(root, Art.cyl(0.014, 0.015, 0.05, 8), glass, Vector3(0, 0.235, 0))
			Art.add_mesh(root, Art.cyl(0.016, 0.016, 0.012, 8), Art.color(Color(0.85, 0.75, 0.2), 0.3, 0.8), Vector3(0, 0.265, 0))
			if d:
				Art.add_mesh(root, Art.cyl(0.0365, 0.0365, 0.07, 16), Art.label(String(d.id)), Vector3(0, 0.08, 0))
		1:  # винная
			Art.add_mesh(root, Art.cyl(0.036, 0.036, 0.19, 12), glass, Vector3(0, 0.095, 0))
			Art.add_mesh(root, Art.cyl(0.014, 0.036, 0.05, 12), glass, Vector3(0, 0.215, 0))
			Art.add_mesh(root, Art.cyl(0.013, 0.014, 0.08, 8), glass, Vector3(0, 0.28, 0))
			Art.add_mesh(root, Art.cyl(0.015, 0.015, 0.04, 8), Art.color(Color(0.5, 0.05, 0.08), 0.5), Vector3(0, 0.31, 0))
			Art.add_mesh(root, Art.cyl(0.0365, 0.0365, 0.09, 16), Art.label(String(d.id)), Vector3(0, 0.09, 0))
		2:  # водочная
			Art.add_mesh(root, Art.cyl(0.04, 0.04, 0.2, 12), glass, Vector3(0, 0.1, 0))
			Art.add_mesh(root, Art.cyl(0.018, 0.04, 0.04, 12), glass, Vector3(0, 0.22, 0))
			Art.add_mesh(root, Art.cyl(0.016, 0.018, 0.06, 8), glass, Vector3(0, 0.27, 0))
			Art.add_mesh(root, Art.cyl(0.019, 0.019, 0.03, 8), Art.color(Color(0.75, 0.75, 0.78), 0.3, 0.8), Vector3(0, 0.31, 0))
			Art.add_mesh(root, Art.cyl(0.0405, 0.0405, 0.09, 16), Art.label(String(d.id)), Vector3(0, 0.1, 0))
		_:  # пузатая
			Art.add_mesh(root, Art.sphere(0.06, 14), glass, Vector3(0, 0.07, 0), Vector3.ZERO, Vector3(1, 1.1, 0.7))
			Art.add_mesh(root, Art.cyl(0.015, 0.02, 0.09, 8), glass, Vector3(0, 0.17, 0))
			Art.add_mesh(root, Art.cyl(0.018, 0.018, 0.03, 8), Art.color(Color(0.3, 0.18, 0.08)), Vector3(0, 0.225, 0))
			Art.add_mesh(root, Art.box(Vector3(0.08, 0.05, 0.003)), Art.label(String(d.id)), Vector3(0, 0.07, -0.043))


static func _can(root: Node3D, label: String, r: float, h: float) -> void:
	Art.add_mesh(root, Art.cyl(r, r, h, 16), Art.label(label), Vector3(0, h / 2, 0))
	Art.add_mesh(root, Art.cyl(r * 0.98, r * 0.98, 0.006, 16), Art.color(Color(0.75, 0.75, 0.78), 0.3, 0.8), Vector3(0, h, 0))


static func _bait(root: Node3D, id: StringName) -> void:
	match id:
		&"bread":
			Art.add_mesh(root, Art.capsule(0.06, 0.3), Art.color(Color(0.78, 0.55, 0.28)), Vector3(0, 0.06, 0), Vector3(0, 0, PI / 2), Vector3(1, 0.8, 1))
			for k in 4:
				Art.add_mesh(root, Art.box(Vector3(0.012, 0.02, 0.1)), Art.color(Color(0.6, 0.4, 0.18)), Vector3(-0.08 + k * 0.055, 0.105, 0), Vector3(0, 0.4, 0))
		&"corn": _can(root, "corn", 0.045, 0.1)
		&"worm": _can(root, "worms", 0.05, 0.08)
		&"maggot":
			Art.add_mesh(root, Art.box(Vector3(0.1, 0.06, 0.07)), Art.label("maggots"), Vector3(0, 0.03, 0))
		&"dough":
			Art.add_mesh(root, Art.cyl(0.045, 0.045, 0.08, 14), Art.label("dough"), Vector3(0, 0.04, 0))
			Art.add_mesh(root, Art.cyl(0.047, 0.047, 0.02, 14), Art.color(Color(0.8, 0.3, 0.1)), Vector3(0, 0.09, 0))
		&"sausage":
			for k in 3:
				Art.add_mesh(root, Art.capsule(0.022, 0.16), Art.color(Color(0.92, 0.58, 0.55)), Vector3(-0.05 + k * 0.05, 0.022, 0), Vector3(PI / 2, 0, 0))
		&"poop":
			var m := Art.color(Color(0.35, 0.22, 0.1), 0.6)
			Art.add_mesh(root, Art.sphere(0.07, 10), m, Vector3(0, 0.04, 0), Vector3.ZERO, Vector3(1, 0.55, 1))
			Art.add_mesh(root, Art.sphere(0.052, 10), m, Vector3(0, 0.085, 0), Vector3.ZERO, Vector3(1, 0.6, 1))
			Art.add_mesh(root, Art.sphere(0.034, 8), m, Vector3(0, 0.12, 0), Vector3.ZERO, Vector3(1, 0.7, 1))
			Art.add_mesh(root, Art.cyl(0.0, 0.02, 0.04, 6), m, Vector3(0.005, 0.15, 0), Vector3(0, 0, 0.3))
		_:
			Art.add_mesh(root, Art.box(Vector3(0.1, 0.06, 0.07)), Art.color(Color.GRAY), Vector3(0, 0.03, 0))


static func _food(root: Node3D, id: StringName) -> void:
	match id:
		&"noodles":
			Art.add_mesh(root, Art.cyl(0.05, 0.04, 0.1, 14), Art.label("noodles"), Vector3(0, 0.05, 0))
			Art.add_mesh(root, Art.cyl(0.051, 0.051, 0.005, 14), Art.color(Color(0.95, 0.95, 0.9)), Vector3(0, 0.1, 0))
		&"crackers":
			Art.add_mesh(root, Art.box(Vector3(0.12, 0.16, 0.04)), Art.label("crackers"), Vector3(0, 0.08, 0), Vector3.ZERO, Vector3(1, 1, 1))
		&"cheburek":
			Art.add_mesh(root, Art.cyl(0.09, 0.09, 0.03, 16), Art.color(Color(0.85, 0.62, 0.3)), Vector3(0, 0.015, 0), Vector3.ZERO, Vector3(1, 1, 0.6))
		&"shawarma":
			Art.add_mesh(root, Art.capsule(0.04, 0.2), Art.color(Color(0.92, 0.85, 0.65)), Vector3(0, 0.1, 0))
			Art.add_mesh(root, Art.cyl(0.042, 0.042, 0.08, 12), Art.color(Color(0.95, 0.95, 0.95), 0.4), Vector3(0, 0.04, 0))
		&"seeds":
			Art.add_mesh(root, Art.box(Vector3(0.1, 0.14, 0.03)), Art.label("seeds"), Vector3(0, 0.07, 0))


static func _bat(root: Node3D) -> void:
	var wood := Art.color(Color(0.74, 0.54, 0.32), 0.55)
	Art.add_mesh(root, Art.cyl(0.018, 0.018, 0.25, 10), Art.color(Color(0.1, 0.1, 0.1), 0.8), Vector3(0, 0.125, 0))
	Art.add_mesh(root, Art.cyl(0.024, 0.024, 0.02, 10), Art.color(Color(0.1, 0.1, 0.1)), Vector3(0, 0.005, 0))
	Art.add_mesh(root, Art.cyl(0.045, 0.02, 0.6, 12), wood, Vector3(0, 0.55, 0))
	Art.add_mesh(root, Art.sphere(0.045, 12), wood, Vector3(0, 0.85, 0), Vector3.ZERO, Vector3(1, 0.5, 1))


static func _smokes(root: Node3D, id: StringName) -> void:
	Art.add_mesh(root, Art.box(Vector3(0.06, 0.09, 0.025)), Art.label(String(id)), Vector3(0, 0.045, 0))
	Art.add_mesh(root, Art.box(Vector3(0.061, 0.02, 0.026)), Art.color(Color(0.95, 0.95, 0.95)), Vector3(0, 0.08, 0))


static func _cig(root: Node3D) -> void:
	Art.add_mesh(root, Art.cyl(0.005, 0.005, 0.07, 6), Art.color(Color(0.95, 0.95, 0.92)), Vector3(0, 0.035, 0))
	Art.add_mesh(root, Art.cyl(0.0055, 0.0055, 0.02, 6), Art.color(Color(0.85, 0.55, 0.25)), Vector3(0, 0.005, 0))
	var ember := StandardMaterial3D.new()
	ember.albedo_color = Color(1, 0.4, 0.1)
	ember.emission_enabled = true
	ember.emission = Color(1, 0.35, 0.05)
	ember.emission_energy_multiplier = 3.0
	Art.add_mesh(root, Art.cyl(0.0052, 0.0052, 0.006, 6), ember, Vector3(0, 0.072, 0))


static func _sack(root: Node3D) -> void:
	var m := Art.color(Color(0.78, 0.7, 0.5), 0.95)
	Art.add_mesh(root, Art.sphere(0.25, 12), m, Vector3(0, 0.2, 0), Vector3.ZERO, Vector3(1.0, 0.85, 0.75))
	Art.add_mesh(root, Art.cyl(0.07, 0.12, 0.12, 8), m, Vector3(0, 0.44, 0))
	Art.add_mesh(root, Art.cyl(0.075, 0.075, 0.03, 8), Art.color(Color(0.45, 0.3, 0.2)), Vector3(0, 0.42, 0))
	Build.text(root, Vector3(0, 0.2, 0.19), "КОМБИКОРМ", 30, Color(0.25, 0.3, 0.6), 0.004)


static func _box(root: Node3D) -> void:
	Art.add_mesh(root, Art.box(Vector3(0.5, 0.36, 0.38)), Art.color(Color(0.72, 0.56, 0.36), 0.95), Vector3(0, 0.18, 0))
	Art.add_mesh(root, Art.box(Vector3(0.505, 0.05, 0.385)), Art.color(Color(0.85, 0.8, 0.6)), Vector3(0, 0.3, 0))
	Art.add_mesh(root, Art.box(Vector3(0.2, 0.12, 0.003)), Art.color(Color(0.15, 0.15, 0.15)), Vector3(0, 0.16, -0.192))


static func _net(root: Node3D) -> void:
	var mesh := Art.color(Color(0.55, 0.55, 0.45), 0.9)
	Art.add_mesh(root, Art.sphere(0.12, 10), mesh, Vector3(0, 0.09, 0), Vector3.ZERO, Vector3(1.2, 0.75, 1.0))
	for i in 4:
		Art.add_mesh(root, Art.sphere(0.025, 6), Art.color(Color(1.0, 0.45, 0.1)), Vector3(cos(i * 1.6) * 0.11, 0.12 + 0.03 * (i % 2), sin(i * 1.6) * 0.09))


static func _misc(root: Node3D, id: StringName) -> void:
	if id == &"brine":
		var glass := Art.color(Color(0.75, 0.85, 0.6, 0.55), 0.15)
		glass = glass.duplicate()
		glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		Art.add_mesh(root, Art.cyl(0.055, 0.055, 0.16, 14), glass, Vector3(0, 0.08, 0))
		Art.add_mesh(root, Art.cyl(0.05, 0.05, 0.1, 12), Art.color(Color(0.55, 0.7, 0.3, 0.9), 0.4), Vector3(0, 0.06, 0))
		Art.add_mesh(root, Art.capsule(0.018, 0.08), Art.color(Color(0.25, 0.45, 0.15)), Vector3(0.015, 0.07, 0), Vector3(0, 0, 0.3))
		Art.add_mesh(root, Art.cyl(0.058, 0.058, 0.02, 14), Art.color(Color(0.75, 0.75, 0.7), 0.3, 0.8), Vector3(0, 0.17, 0))
		return
	if id == &"sugar":
		Art.add_mesh(root, Art.box(Vector3(0.12, 0.18, 0.08)), Art.color(Color(0.96, 0.96, 0.94), 0.9), Vector3(0, 0.09, 0))
		Art.add_mesh(root, Art.box(Vector3(0.122, 0.06, 0.082)), Art.color(Color(0.2, 0.35, 0.75)), Vector3(0, 0.12, 0))
	else:
		Art.add_mesh(root, Art.box(Vector3(0.09, 0.05, 0.06)), Art.color(Color(0.9, 0.75, 0.2), 0.6), Vector3(0, 0.025, 0))
		Art.add_mesh(root, Art.box(Vector3(0.092, 0.015, 0.062)), Art.color(Color(0.7, 0.15, 0.1)), Vector3(0, 0.04, 0))


static func _flashlight(root: Node3D) -> void:
	Art.add_mesh(root, Art.cyl(0.025, 0.025, 0.16, 12), Art.color(Color(0.15, 0.15, 0.17), 0.4, 0.6), Vector3(0, 0.08, 0))
	Art.add_mesh(root, Art.cyl(0.04, 0.028, 0.05, 12), Art.color(Color(0.2, 0.2, 0.22), 0.3, 0.7), Vector3(0, 0.18, 0))
	Art.add_mesh(root, Art.cyl(0.035, 0.035, 0.005, 12), Build.glow_mat(Color(1, 0.95, 0.7), 1.5), Vector3(0, 0.206, 0))
