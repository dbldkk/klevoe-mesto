extends Node3D
## Жизнь посёлка: гаражный кооператив, руины колхоза, часовня, дачи, лесная тропа,
## костёр рыбаков, животные, столбы, стога, ржавые остовы. Статика — в Static (MeshBaker).

var _t := 0.0


func _ready() -> void:
	var st := Node3D.new()
	st.name = "Static"
	add_child(st)
	_garages(st)
	_ruins(st)
	_chapel(st)
	_dachas(st)
	_forest(st)
	_campfire(st)
	_props(st)
	_animals()
	_pickables()


func _spot(n: Node3D, spot: String) -> Node3D:
	var root := Node3D.new()
	root.name = spot.capitalize()
	root.set_meta("poi_spot", spot)
	root.add_to_group("poi")
	# сначала в дерево — иначе global_transform у сироты это (0,0,0)
	# и snap_to_ground ставит площадку в начало координат.
	n.add_child(root)
	root.transform = Layout.xform(spot)
	var s: Array = Layout.SPOTS[spot]
	Layout.snap_to_ground(root, float(s[2]), float(s[3]))
	if spot not in ["campfire", "forest"]:
		var plinth := Art.color(Color(0.35, 0.32, 0.28), 0.95)
		Build.block(root, Vector3(0, -0.55, 0), Vector3(float(s[2]) * 2.0 + 0.6, 1.1, float(s[3]) * 2.0 + 0.6), plinth, true)
	return root


func _garages(st: Node3D) -> void:
	var g := _spot(st, "garages")
	g.set_meta("poi_name", "Гаражный кооператив")
	var brick := Art.tex_world("plaster", 0.7)
	var metal := Art.tex_world("metal", 0.5)
	Build.block(g, Vector3(0, 0.02, 0), Vector3(14.0, 0.04, 8.0), Art.tex_world("asphalt", 0.35), false)
	for i in 5:
		var x := -5.6 + i * 2.8
		Build.block(g, Vector3(x, 1.1, -1.2), Vector3(2.5, 2.2, 4.4), brick, true)
		Build.block(g, Vector3(x, 2.28, -1.2), Vector3(2.7, 0.1, 4.6), metal, false, Vector3(0.04, 0, 0))
		Build.block(g, Vector3(x, 1.0, 1.05), Vector3(2.2, 1.9, 0.08), Art.color(Color(0.25, 0.28, 0.22), 0.5, 0.4), true)
		Build.block(g, Vector3(x, 1.7, 1.1), Vector3(0.25, 0.08, 0.12), Art.color(Color(0.7, 0.65, 0.3), 0.4, 0.6), false)
	# ржавая «копейка» без колёс
	var wreck := Node3D.new()
	wreck.position = Vector3(6.6, 0, 2.2)
	wreck.rotation.y = 0.4
	g.add_child(wreck)
	_car_wreck(wreck)
	Build.board_sign(g, Vector3(0, 0.0, 4.2), "ГАРАЖНЫЙ КООПЕРАТИВ «МОТОР»", 0.0, Vector2(1.6, 0.4), 2.2)


func _ruins(st: Node3D) -> void:
	var r := _spot(st, "ruins")
	r.set_meta("poi_name", "Заброшенный колхоз")
	var conc := Art.color(Color(0.55, 0.52, 0.48), 0.95)
	var rust := Art.color(Color(0.45, 0.25, 0.12), 0.7, 0.3)
	Build.block(r, Vector3(0, 0.8, -1.5), Vector3(8.0, 1.6, 0.35), conc, true)
	Build.block(r, Vector3(-3.8, 1.2, 0.5), Vector3(0.35, 2.4, 4.5), conc, true)
	Build.block(r, Vector3(3.6, 0.6, 1.0), Vector3(0.35, 1.2, 3.0), conc, true)
	Build.block(r, Vector3(-1.2, 0.15, 1.4), Vector3(2.2, 0.3, 0.8), conc, true, Vector3(0, 0, 0.4))
	Build.cylinder(r, Vector3(2.4, 0.7, 2.2), 0.55, 1.4, rust, true, 10)
	Build.block(r, Vector3(1.0, 0.9, -0.2), Vector3(0.12, 1.8, 0.12), rust, false)
	Build.block(r, Vector3(1.0, 1.85, 0.6), Vector3(0.12, 0.12, 1.8), rust, false)
	_hay(r, Vector3(-5.5, 0, 3.0), 1.1)
	_hay(r, Vector3(-4.2, 0, 4.2), 0.85)
	Build.board_sign(r, Vector3(0, 0.0, 4.6), "КОЛХОЗ «РАССВЕТ» · ЗАБРОШЕН", 0.0, Vector2(1.5, 0.36), 2.0)


func _chapel(st: Node3D) -> void:
	var c := _spot(st, "chapel")
	c.set_meta("poi_name", "Часовня")
	var stone := Art.tex_world("plaster", 0.9)
	var roof := Art.color(Color(0.28, 0.18, 0.16), 0.8)
	var gold := Art.color(Color(0.78, 0.62, 0.18), 0.4, 0.6)
	Build.block(c, Vector3(0, 1.4, 0), Vector3(4.4, 2.8, 3.6), stone, true)
	Build.block(c, Vector3(0, 3.0, 0), Vector3(4.8, 0.16, 4.0), roof, false, Vector3(0.15, 0, 0))
	Art.add_mesh(c, Art.sphere(0.55, 12), roof, Vector3(0, 3.55, 0), Vector3.ZERO, Vector3(1, 1.3, 1))
	Art.add_mesh(c, Art.cyl(0.05, 0.05, 0.7, 8), gold, Vector3(0, 4.2, 0))
	Art.add_mesh(c, Art.box(Vector3(0.35, 0.05, 0.05)), gold, Vector3(0, 4.35, 0))
	# дверь и свечи
	Build.block(c, Vector3(0, 1.1, 1.82), Vector3(0.9, 2.1, 0.08), Art.color(Color(0.25, 0.16, 0.1)), true)
	Build.lamp(c, Vector3(0, 2.6, 0), 0.7, 6.0, Color(1, 0.85, 0.55), true)
	var hook := _Hook.new()
	hook.kind = "chapel"
	c.add_child(hook)
	Build.talk_area(c, Vector3(0, 1.1, 2.2), Vector3(1.6, 2.0, 1.2), hook)
	Build.board_sign(c, Vector3(0, 0.0, 2.5), "ЧАСОВНЯ", 0.0, Vector2(0.8, 0.32), 2.6)


func _dachas(st: Node3D) -> void:
	var d := _spot(st, "dachas")
	d.set_meta("poi_name", "Дачи")
	var wood := Art.tex_world("planks", 0.6)
	var roof := Art.color(Color(0.45, 0.2, 0.16), 0.85)
	for i in 3:
		var x := -4.5 + i * 4.5
		var z := -1.2 if i != 1 else 1.4
		Build.block(d, Vector3(x, 1.15, z), Vector3(3.2, 2.3, 2.8), wood, true)
		Build.block(d, Vector3(x, 2.45, z), Vector3(3.6, 0.12, 3.2), roof, false, Vector3(0.18, 0, 0))
		Build.block(d, Vector3(x, 1.0, z + 1.45), Vector3(0.7, 1.8, 0.08), Art.color(Color(0.3, 0.2, 0.12)), true)
		# заборчик
		for k in 6:
			Build.block(d, Vector3(x - 1.6 + k * 0.55, 0.45, z + 2.0), Vector3(0.06, 0.9, 0.06), wood, false)
		Build.block(d, Vector3(x, 0.85, z + 2.0), Vector3(3.3, 0.05, 0.05), wood, false)
		# грядка
		Build.block(d, Vector3(x + 1.6, 0.08, z + 2.6), Vector3(1.4, 0.16, 0.8), Art.color(Color(0.35, 0.25, 0.12)), false)
	Build.cylinder(d, Vector3(0, 0.5, 3.6), 0.35, 1.0, Art.color(Color(0.6, 0.6, 0.62), 0.7), true, 10)
	Build.board_sign(d, Vector3(0, 0.0, 4.4), "ДАЧНЫЕ УЧАСТКИ", 0.0, Vector2(1.3, 0.34), 2.1)


func _forest(st: Node3D) -> void:
	var f := _spot(st, "forest")
	f.set_meta("poi_name", "Лесная тропа")
	var dirt := Art.color(Color(0.38, 0.28, 0.16), 0.98)
	# тропинка наружу
	Build.block(f, Vector3(0, 0.03, 0), Vector3(2.2, 0.05, 14.0), dirt, false)
	var trunk := Art.color(Color(0.28, 0.18, 0.1), 0.95)
	var leaf := Art.color(Color(0.22, 0.38, 0.16), 0.95)
	for i in 10:
		var ang := i * 0.7
		var p := Vector3(sin(ang) * (3.5 + i * 0.3), 0, -6 + i * 1.3 + cos(ang))
		if absf(p.x) < 1.2:
			p.x += 2.2 * signf(p.x + 0.01)
		Art.add_mesh(f, Art.cyl(0.18, 0.22, 2.4, 8), trunk, p + Vector3(0, 1.2, 0))
		Art.add_mesh(f, Art.sphere(1.1, 10), leaf, p + Vector3(0, 2.6, 0), Vector3.ZERO, Vector3(1.2, 0.8, 1.2))
	# пенёк
	Art.add_mesh(f, Art.cyl(0.28, 0.3, 0.4, 10), trunk, Vector3(1.8, 0.2, 2.0))
	Build.board_sign(f, Vector3(0, 0.0, 7.2), "ТРОПА · ГРИБЫ И ЯГОДЫ", 0.0, Vector2(1.5, 0.34), 1.6)


func _campfire(st: Node3D) -> void:
	var c := _spot(st, "campfire")
	c.set_meta("poi_name", "Костёр рыбаков")
	# брёвна и огонь
	var wood := Art.color(Color(0.32, 0.2, 0.1), 0.95)
	for i in 4:
		var a := i * TAU / 4.0
		Art.add_mesh(c, Art.cyl(0.06, 0.06, 0.7, 6), wood, Vector3(cos(a) * 0.15, 0.08, sin(a) * 0.15), Vector3(0.4, a, 0.2))
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1, 0.45, 0.1)
	glow.emission_enabled = true
	glow.emission = Color(1, 0.4, 0.05)
	glow.emission_energy_multiplier = 4.0
	Art.add_mesh(c, Art.sphere(0.18, 10), glow, Vector3(0, 0.25, 0), Vector3.ZERO, Vector3(1, 1.4, 1))
	var fire := OmniLight3D.new()
	fire.light_color = Color(1, 0.55, 0.2)
	fire.light_energy = 2.2
	fire.omni_range = 8.0
	fire.position = Vector3(0, 0.5, 0)
	c.add_child(fire)
	# два рыбака у огня
	for i in 2:
		var m := CharacterModel.new()
		m.position = Vector3(-0.9 + i * 1.8, 0, 0.9)
		m.rotation.y = PI + (0.3 if i == 0 else -0.3)
		m.hat = CharacterModel.Hat.BEANIE if i == 0 else CharacterModel.Hat.USHANKA
		m.shirt = Color(0.4, 0.28, 0.18) if i == 0 else Color(0.2, 0.3, 0.25)
		c.add_child(m)
	Build.block(c, Vector3(0, 0.15, -0.8), Vector3(0.7, 0.08, 0.35), wood, false)  # доска с уловом
	Art.add_mesh(c, Art.capsule(0.04, 0.28), Art.color(Color(0.6, 0.55, 0.4)), Vector3(0.1, 0.22, -0.8), Vector3(0, 0, 1.2))
	var hook := _Hook.new()
	hook.kind = "camp"
	c.add_child(hook)
	Build.talk_area(c, Vector3(0, 1.0, 0), Vector3(3.0, 2.0, 3.0), hook)
	Build.board_sign(c, Vector3(1.6, 0.0, 1.6), "РЫБАКИ", PI / 5.0, Vector2(0.7, 0.28), 1.2)


func _props(st: Node3D) -> void:
	# столбы ЛЭП вдоль дороги — не на площадках построек
	var post := Art.color(Color(0.35, 0.35, 0.38), 0.6, 0.4)
	var wire := Art.color(Color(0.15, 0.15, 0.16), 0.5, 0.3)
	var angles := [-20.0, 8.0, 40.0, 75.0, 140.0, -150.0, -115.0, -85.0]
	var poles: Array[Vector3] = []
	for a in angles:
		var p := Layout.ring(a, 5.2)
		var n := Node3D.new()
		p.y = Terrain.height(p.x, p.z)
		n.position = p
		st.add_child(n)
		Art.add_mesh(n, Art.cyl(0.08, 0.08, 7.0, 8), post, Vector3(0, 3.5, 0))
		Art.add_mesh(n, Art.box(Vector3(1.6, 0.06, 0.06)), post, Vector3(0, 6.6, 0))
		poles.append(p + Vector3(0, 6.6, 0))
		# изоляторы
		for s in [-0.7, 0.7]:
			Art.add_mesh(n, Art.sphere(0.06, 6), Art.color(Color(0.8, 0.8, 0.75)), Vector3(s, 6.6, 0))
	# стога у фермы, чуть в стороне
	var hay_root := Node3D.new()
	hay_root.position = Layout.ring(148.0, 24.0)
	hay_root.position.y = Terrain.height(hay_root.position.x, hay_root.position.z)
	st.add_child(hay_root)
	_hay(hay_root, Vector3(0, 0, 0), 1.3)
	_hay(hay_root, Vector3(2.4, 0, 1.1), 1.0)
	# ещё один остов у кооператива со стороны дороги
	var w := Node3D.new()
	w.position = Layout.ring(118.0, 8.5)
	w.position.y = Terrain.height(w.position.x, w.position.z)
	w.rotation.y = Layout.face_in_yaw(118.0) + 0.6
	st.add_child(w)
	_car_wreck(w)


func _hay(parent: Node3D, pos: Vector3, scale := 1.0) -> void:
	var m := Art.color(Color(0.72, 0.6, 0.22), 0.98)
	Art.add_mesh(parent, Art.cyl(0.7 * scale, 0.85 * scale, 1.1 * scale, 10), m, pos + Vector3(0, 0.55 * scale, 0))
	Art.add_mesh(parent, Art.sphere(0.8 * scale, 10), m, pos + Vector3(0, 1.15 * scale, 0), Vector3.ZERO, Vector3(1, 0.6, 1))


func _car_wreck(n: Node3D) -> void:
	var rust := Art.color(Color(0.42, 0.22, 0.12), 0.75, 0.2)
	var dark := Art.color(Color(0.12, 0.12, 0.13), 0.8)
	Build.block(n, Vector3(0, 0.35, 0), Vector3(1.6, 0.5, 3.4), rust, true)
	Build.block(n, Vector3(0, 0.85, -0.3), Vector3(1.5, 0.5, 1.6), rust, false)
	for z in [-1.1, 1.1]:
		for x in [-0.75, 0.75]:
			Art.add_mesh(n, Art.cyl(0.22, 0.22, 0.14, 8), dark, Vector3(x, 0.22, z), Vector3(0, 0, PI / 2))


func _animals() -> void:
	# собаки, кошки, куры — бродят в радиусе, в динамической ветке (не в Static)
	var specs := [
		["dog", Layout.local_to_world("shop", Vector3(8, 0, 6)), 6.0, Color(0.35, 0.25, 0.15)],
		["dog", Layout.local_to_world("house", Vector3(-6, 0, 5)), 5.0, Color(0.2, 0.2, 0.22)],
		["cat", Layout.local_to_world("babka", Vector3(2, 0, 2)), 3.0, Color(0.7, 0.55, 0.3)],
		["cat", Layout.local_to_world("club", Vector3(6, 0, 4)), 4.0, Color(0.15, 0.15, 0.16)],
		["chicken", Layout.local_to_world("dachas", Vector3(2, 0, 3)), 4.0, Color(0.85, 0.75, 0.45)],
		["chicken", Layout.local_to_world("dachas", Vector3(-2, 0, 2)), 4.0, Color(0.8, 0.55, 0.2)],
		["chicken", Layout.local_to_world("farm", Vector3(8, 0, 6)), 5.0, Color(0.9, 0.85, 0.7)],
	]
	for s in specs:
		var a := _Wanderer.new()
		a.kind = String(s[0])
		a.home = s[1]
		a.radius = s[2]
		a.tint = s[3]
		a.home.y = Terrain.height(a.home.x, a.home.z)
		a.position = a.home
		a.name = String(s[0]).capitalize()
		add_child(a)


func _pickables() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1101
	for i in 8:
		var local := Vector3(rng.randf_range(-4.5, 4.5), 0, rng.randf_range(-6.0, 6.0))
		if absf(local.x) < 1.0:
			local.x = 1.6 * signf(local.x + 0.01)
		var p := _Pick.new()
		p.item_id = &"mushroom" if i % 2 == 0 else &"berry"
		p.position = Layout.local_to_world("forest", local)
		p.position.y = Terrain.height(p.position.x, p.position.z)
		p.name = "Pickable_%d" % i
		add_child(p)


class _Wanderer extends Node3D:
	var kind := "dog"
	var home := Vector3.ZERO
	var radius := 4.0
	var tint := Color(0.4, 0.3, 0.2)
	var _target := Vector3.ZERO
	var _wait := 0.0

	func _ready() -> void:
		_target = home
		var m := tint
		match kind:
			"dog":
				Art.add_mesh(self, Art.capsule(0.12, 0.45), Art.color(m), Vector3(0, 0.28, 0), Vector3(1.2, 0, 0))
				Art.add_mesh(self, Art.sphere(0.12, 8), Art.color(m), Vector3(0, 0.32, -0.28))
				Art.add_mesh(self, Art.cyl(0.025, 0.025, 0.22, 6), Art.color(m), Vector3(0, 0.22, 0.28), Vector3(0.6, 0, 0))
			"cat":
				Art.add_mesh(self, Art.capsule(0.08, 0.28), Art.color(m), Vector3(0, 0.16, 0), Vector3(1.2, 0, 0))
				Art.add_mesh(self, Art.sphere(0.08, 8), Art.color(m), Vector3(0, 0.2, -0.16))
				Art.add_mesh(self, Art.box(Vector3(0.03, 0.06, 0.02)), Art.color(m), Vector3(-0.04, 0.27, -0.16))
				Art.add_mesh(self, Art.box(Vector3(0.03, 0.06, 0.02)), Art.color(m), Vector3(0.04, 0.27, -0.16))
			"chicken":
				Art.add_mesh(self, Art.sphere(0.09, 8), Art.color(m), Vector3(0, 0.16, 0), Vector3.ZERO, Vector3(1, 0.8, 1.1))
				Art.add_mesh(self, Art.sphere(0.055, 8), Art.color(m), Vector3(0, 0.24, -0.08))
				Art.add_mesh(self, Art.box(Vector3(0.02, 0.03, 0.05)), Art.color(Color(0.85, 0.25, 0.1)), Vector3(0, 0.24, -0.13))

	func _process(delta: float) -> void:
		_wait -= delta
		if _wait <= 0.0 or global_position.distance_to(_target) < 0.25:
			var ang := randf() * TAU
			_target = home + Vector3(cos(ang), 0, sin(ang)) * randf_range(0.4, radius)
			_wait = randf_range(1.5, 5.0)
		var dir := _target - global_position
		dir.y = 0
		if dir.length() > 0.05:
			var nxt := global_position + dir.normalized() * 0.7 * delta
			nxt.y = Terrain.height(nxt.x, nxt.z)
			global_position = nxt
			rotation.y = atan2(dir.x, dir.z)


class _Pick extends Area3D:
	var item_id: StringName = &"mushroom"

	func _ready() -> void:
		collision_layer = 16
		collision_mask = 0
		var cs := CollisionShape3D.new()
		var sh := SphereShape3D.new()
		sh.radius = 0.7
		cs.shape = sh
		add_child(cs)
		if item_id == &"mushroom":
			Art.add_mesh(self, Art.cyl(0.015, 0.02, 0.07, 8), Art.color(Color(0.85, 0.8, 0.7)), Vector3(0, 0.04, 0))
			Art.add_mesh(self, Art.sphere(0.07, 10), Art.color(Color(0.65, 0.32, 0.16)), Vector3(0, 0.09, 0), Vector3.ZERO, Vector3(1.2, 0.5, 1.2))
		else:
			for i in 4:
				var a := i * TAU / 4.0
				Art.add_mesh(self, Art.sphere(0.025, 8), Art.color(Color(0.55, 0.08, 0.14)), Vector3(cos(a) * 0.05, 0.04, sin(a) * 0.05))
			Art.add_mesh(self, Art.sphere(0.03, 6), Art.color(Color(0.2, 0.45, 0.12)), Vector3(0, 0.07, 0))

	func get_prompt(_player: Node) -> String:
		var f := GameData.get_food(item_id)
		return "Собрать: %s" % (f.display_name if f else String(item_id))

	func interact(_player: Node) -> void:
		if Inventory.add_item("food", item_id):
			Sfx.play("sack", global_position, -10.0)
			queue_free()
		else:
			Events.notify("В инвентаре нет места", Color.TOMATO)


class _Hook extends Node3D:
	var kind := ""

	func get_prompt(_player: Node) -> String:
		if kind == "camp":
			return "Погреться у костра"
		if kind == "chapel":
			return "Поставить свечку"
		return ""

	func interact(_player: Node) -> void:
		if kind == "camp":
			Events.notify("Рыбаки кивают: «Садись, сейчас уху доварим.»", Color(1, 0.85, 0.5))
			if Inventory.health < 100.0:
				Inventory.health = minf(Inventory.health + 4.0, 100.0)
				Inventory.changed.emit()
		elif kind == "chapel":
			Events.notify("Свечка затеплилась. Тихо и спокойно.", Color(1.0, 0.9, 0.6))
			Sfx.play("lighter", global_position, -8.0)
