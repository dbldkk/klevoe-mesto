class_name Build
## Помощники для постройки зданий из кода: блоки с коллизией, комнаты с проёмом,
## вывески, лампы. Все размеры в метрах, координаты — локальные для parent.

## Блок (меш + коллизия по желанию).
static func block(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, collide := true,
		rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := Art.add_mesh(parent, Art.box(size), mat, pos, rot)
	if collide:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		body.add_child(cs)
		mi.add_child(body)
	return mi


## Цилиндр (меш + коллизия по желанию).
static func cylinder(parent: Node3D, pos: Vector3, r: float, h: float, mat: Material, collide := true,
		seg := 16) -> MeshInstance3D:
	var mi := Art.add_mesh(parent, Art.cyl(r, r, h, seg), mat, pos)
	if collide:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = r
		sh.height = h
		cs.shape = sh
		body.add_child(cs)
		mi.add_child(body)
	return mi


## Комната: пол, 4 стены, проём двери в стене +Z, крыша. Возвращает Node3D.
## w — по X, d — по Z, h — высота стен.
static func room(parent: Node3D, w: float, d: float, h: float, wall: Material, inner: Material,
		floor_mat: Material, roof: Material, door_w := 1.4, door_h := 2.3, door_x := 0.0, t := 0.22) -> Node3D:
	var r := Node3D.new()
	parent.add_child(r)
	# Пол и крыша
	block(r, Vector3(0, 0.02, 0), Vector3(w, 0.04, d), floor_mat, false)
	block(r, Vector3(0, h + 0.12, 0), Vector3(w + 0.5, 0.24, d + 0.5), roof, true)
	block(r, Vector3(0, h - 0.02, 0), Vector3(w - 2 * t, 0.04, d - 2 * t), inner, false)  # потолок
	# Задняя и боковые стены
	_wall(r, Vector3(0, h / 2, -d / 2 + t / 2), Vector3(w, h, t), wall, inner, Vector3(0, 0, 1))
	_wall(r, Vector3(-w / 2 + t / 2, h / 2, 0), Vector3(t, h, d), wall, inner, Vector3(1, 0, 0))
	_wall(r, Vector3(w / 2 - t / 2, h / 2, 0), Vector3(t, h, d), wall, inner, Vector3(-1, 0, 0))
	# Передняя стена с проёмом
	var zf := d / 2 - t / 2
	var left_w := (w / 2 + door_x - door_w / 2)
	var right_w := (w / 2 - door_x - door_w / 2)
	_wall(r, Vector3(-w / 2 + left_w / 2, h / 2, zf), Vector3(left_w, h, t), wall, inner, Vector3(0, 0, -1))
	_wall(r, Vector3(w / 2 - right_w / 2, h / 2, zf), Vector3(right_w, h, t), wall, inner, Vector3(0, 0, -1))
	_wall(r, Vector3(door_x, (h + door_h) / 2, zf), Vector3(door_w, h - door_h, t), wall, inner, Vector3(0, 0, -1))
	return r


static func _wall(r: Node3D, pos: Vector3, size: Vector3, outer: Material, inner: Material, inward: Vector3) -> void:
	block(r, pos, size, outer, true)
	if inner and inner != outer:
		# Тонкий слой отделки внутри.
		var s := size
		var off := Vector3.ZERO
		if absf(inward.x) > 0.5:
			s.x = 0.01
			off.x = inward.x * (size.x / 2 + 0.006)
			s.z -= 0.02
		else:
			s.z = 0.01
			off.z = inward.z * (size.z / 2 + 0.006)
			s.x -= 0.02
		block(r, pos + off, s, inner, false)


## Окно: стекло (вечером светится) + рама.
static func window(parent: Node3D, pos: Vector3, size: Vector2, rot_y := 0.0) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = rot_y
	parent.add_child(n)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.35, 0.5, 0.6, 0.75)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.metallic = 0.5
	glass.roughness = 0.05
	glass.emission_enabled = true
	glass.emission = Color(1.0, 0.82, 0.5)
	glass.emission_energy_multiplier = 0.0
	glass.set_meta("night_glow", 1.6)
	n.add_to_group("night_windows")
	var g := Art.add_mesh(n, Art.box(Vector3(size.x, size.y, 0.05)), glass)
	g.set_meta("glass", true)
	var frame := Art.color(Color(0.92, 0.92, 0.9), 0.6)
	for y in [-1, 1]:
		Art.add_mesh(n, Art.box(Vector3(size.x + 0.1, 0.07, 0.1)), frame, Vector3(0, y * size.y / 2, 0))
	for x in [-1, 0, 1]:
		Art.add_mesh(n, Art.box(Vector3(0.06, size.y, 0.09)), frame, Vector3(x * size.x / 2, 0, 0))
	Art.add_mesh(n, Art.box(Vector3(0.06 if size.x < 1.0 else size.x, 0.05, 0.08)), frame, Vector3(0, size.y * 0.15, 0))
	# отлив под окном
	Art.add_mesh(n, Art.box(Vector3(size.x + 0.22, 0.04, 0.2)), Art.color(Color(0.55, 0.57, 0.6), 0.4, 0.5), Vector3(0, -size.y / 2 - 0.05, 0.07))
	return n


## Деревенские наличники: резная рамка, «кокошник» сверху и ставни.
static func nalichnik(win: Node3D, size: Vector2, color := Color(0.95, 0.95, 0.92), shutter := Color(0.2, 0.42, 0.6)) -> void:
	var m := Art.color(color, 0.6)
	var sh := Art.color(shutter, 0.7)
	var hw := size.x / 2 + 0.12
	var hh := size.y / 2 + 0.12
	for x in [-hw, hw]:
		Art.add_mesh(win, Art.box(Vector3(0.12, size.y + 0.3, 0.04)), m, Vector3(x, 0, 0.06))
	Art.add_mesh(win, Art.box(Vector3(size.x + 0.42, 0.12, 0.05)), m, Vector3(0, -hh, 0.06))
	# кокошник: ступеньки + «солнышко»
	for k in 3:
		Art.add_mesh(win, Art.box(Vector3(size.x + 0.5 - k * 0.35, 0.09, 0.05)), m, Vector3(0, hh + 0.05 + k * 0.09, 0.06))
	Art.add_mesh(win, Art.cyl(0.11, 0.11, 0.04, 12), m, Vector3(0, hh + 0.35, 0.06), Vector3(PI / 2, 0, 0))
	Art.add_mesh(win, Art.cyl(0.06, 0.06, 0.05, 10), sh, Vector3(0, hh + 0.35, 0.07), Vector3(PI / 2, 0, 0))
	# ставни (открыты) с ромбиком
	for sd in [-1.0, 1.0]:
		var x: float = sd * (hw + 0.08 + size.x / 4)
		Art.add_mesh(win, Art.box(Vector3(size.x / 2, size.y + 0.1, 0.04)), sh, Vector3(x, 0, 0.05))
		Art.add_mesh(win, Art.box(Vector3(0.12, 0.12, 0.05)), m, Vector3(x, 0, 0.06), Vector3(0, 0, PI / 4))
		for y in [-1.0, 1.0]:
			Art.add_mesh(win, Art.box(Vector3(size.x / 2 - 0.06, 0.04, 0.05)), m, Vector3(x, y * (size.y / 2 - 0.02), 0.06))


## Двускатная крыша над комнатой (вид; коллизия — плоская плита из room()).
## Скаты вдоль X, фронтоны на боковых стенах ±X. wall_mat — для фронтонов.
static func gable_roof(parent: Node3D, w: float, d: float, h: float, roof: Material, gable: Material, rise := 1.4, over := 0.45) -> void:
	var half := d / 2 + over
	var slope := sqrt(half * half + rise * rise)
	var ang := atan2(rise, half)
	for sd in [-1.0, 1.0]:
		block(parent, Vector3(0, h + 0.24 + rise / 2, sd * half / 2), Vector3(w + over * 2, 0.12, slope), roof, false, Vector3(sd * ang, 0, 0))
	# конёк
	block(parent, Vector3(0, h + 0.3 + rise, 0), Vector3(w + over * 2 + 0.04, 0.12, 0.22), Art.color(Color(0.3, 0.2, 0.15), 0.8), false)
	# фронтоны — лесенкой из брусков
	var steps := 7
	for sx in [-1.0, 1.0]:
		for k in steps:
			var y0 := h + 0.24 + rise * k / steps
			var wz := d * (1.0 - float(k) / steps)
			block(parent, Vector3(sx * (w / 2 - 0.11), y0 + rise / steps / 2, 0), Vector3(0.2, rise / steps + 0.01, wz), gable, false)
	# водосток
	var tin := Art.color(Color(0.62, 0.64, 0.66), 0.35, 0.7)
	for sd in [-1.0, 1.0]:
		block(parent, Vector3(0, h + 0.18, sd * (half + 0.05)), Vector3(w + over * 2, 0.08, 0.1), tin, false)
	block(parent, Vector3(w / 2 + over - 0.1, (h + 0.18) / 2, d / 2 + over + 0.05), Vector3(0.08, h + 0.18, 0.08), tin, false)


## Цоколь вокруг стен (вид), с разрывом под дверь в стене +Z.
static func plinth(parent: Node3D, w: float, d: float, door_w: float, door_x := 0.0, height := 0.32, mat: Material = null) -> void:
	if mat == null:
		mat = Art.color(Color(0.45, 0.45, 0.47), 0.9)
	var t := 0.06
	block(parent, Vector3(0, height / 2, -d / 2 - t / 2), Vector3(w + 2 * t, height, t), mat, false)
	for sx in [-1.0, 1.0]:
		block(parent, Vector3(sx * (w / 2 + t / 2), height / 2, 0), Vector3(t, height, d), mat, false)
	var lw := w / 2 + door_x - door_w / 2
	var rw := w / 2 - door_x - door_w / 2
	block(parent, Vector3(-w / 2 + lw / 2 - t / 2, height / 2, d / 2 + t / 2), Vector3(lw + t, height, t), mat, false)
	block(parent, Vector3(w / 2 - rw / 2 + t / 2, height / 2, d / 2 + t / 2), Vector3(rw + t, height, t), mat, false)


## Угловые пилястры (вид).
static func corners(parent: Node3D, w: float, d: float, h: float, mat: Material) -> void:
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			block(parent, Vector3(sx * (w / 2 + 0.02), h / 2, sz * (d / 2 + 0.02)), Vector3(0.16, h, 0.16), mat, false)


## Вывеска-картинка из art/textures.
static func sign(parent: Node3D, pos: Vector3, tex: String, size: Vector2, rot_y := 0.0, glow := 0.4) -> MeshInstance3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://art/textures/%s.png" % tex)
	m.roughness = 0.6
	if glow > 0.0:
		m.emission_enabled = true
		m.emission_texture = m.albedo_texture
		m.emission_energy_multiplier = glow
	var q := QuadMesh.new()
	q.size = size
	var mi := Art.add_mesh(parent, q, m, pos, Vector3(0, rot_y, 0))
	return mi


static func text(parent: Node3D, pos: Vector3, txt: String, size := 48, color := Color.WHITE,
		px := 0.006, rot_y := 0.0, billboard := false) -> Label3D:
	var l := Label3D.new()
	l.text = txt
	l.font_size = size
	l.pixel_size = px
	l.modulate = color
	l.outline_size = 10
	l.outline_modulate = Color(0, 0, 0, 0.7)
	l.position = pos
	l.rotation.y = rot_y
	if billboard:
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(l)
	return l


## Табличка на доске (и столбе): читается с дорожки, не заслоняет камеру.
## Высота букв ограничена, текст подгоняется под ширину доски.
static func board_sign(parent: Node3D, pos: Vector3, txt: String, rot_y := 0.0,
		board_size := Vector2(1.05, 0.46), post_h := 1.55,
		color := Color(1.0, 0.92, 0.55), with_post := true) -> Node3D:
	var root := Node3D.new()
	root.name = "BoardSign"
	root.position = pos
	root.rotation.y = rot_y
	parent.add_child(root)
	var wood := Art.tex_world("planks", 0.8)
	var dark := Art.color(Color(0.28, 0.2, 0.12), 0.9)
	if with_post:
		cylinder(root, Vector3(0, post_h * 0.5, 0), 0.035, post_h, dark, true, 8)
	var face_y := post_h if with_post else 0.0
	# Рамка чуть больше самой доски.
	block(root, Vector3(0, face_y, 0), Vector3(board_size.x + 0.05, board_size.y + 0.05, 0.03), dark, false)
	block(root, Vector3(0, face_y, 0.012), Vector3(board_size.x, board_size.y, 0.03), wood, true)
	var px := 0.0032
	var font := 36
	var max_h := board_size.y * 0.52
	var max_w := board_size.x * 0.9
	while font * px > max_h and font > 16:
		font -= 2
	while float(txt.length()) * float(font) * px * 0.58 > max_w and px > 0.0016:
		px *= 0.9
	var front := text(root, Vector3(0, face_y, 0.032), txt, font, color, px)
	front.outline_size = 8
	var back := text(root, Vector3(0, face_y, -0.02), txt, font, color, px, PI)
	back.outline_size = 8
	root.set_meta("sign_font", font)
	root.set_meta("sign_px", px)
	return root


## Лампа. night_only — включается только вечером (уличные фонари).
static func lamp(parent: Node3D, pos: Vector3, energy := 1.2, rng := 8.0, color := Color(1, 0.9, 0.75),
		night_only := false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.add_to_group("lamp_lights")
	l.position = pos
	l.light_energy = energy
	l.omni_range = rng
	l.light_color = color
	l.shadow_enabled = false
	parent.add_child(l)
	if night_only:
		l.add_to_group("night_lights")
		l.set_meta("energy", energy)
	return l


## Светящийся материал (неон, лампочки).
static func glow_mat(c: Color, energy := 2.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


## Зона «смотришь и жмёшь E», которая передаёт вызовы узлу target.
static func talk_area(parent: Node3D, pos: Vector3, size: Vector3, target: Node = null) -> Area3D:
	var a: Area3D = load("res://scripts/world/proxy_interactable.gd").new()
	a.position = pos
	a.set("target", target if target else parent)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	a.add_child(cs)
	parent.add_child(a)
	return a


## Человечек (только вид).
static func person(parent: Node3D, pos: Vector3, rot_y: float, skin: Dictionary, face: String, fat := false) -> CharacterModel:
	var m := CharacterModel.new()
	m.position = pos
	m.rotation.y = rot_y
	m.fat = fat
	parent.add_child(m)
	m.apply_skin(skin)
	m.set_face(face)
	return m


## Дверь в проёме: pos — низ середины проёма, w — ширина проёма. double — две створки.
static func door(parent: Node3D, pos: Vector3, w: float, h: float, double := false, color := Color(0.45, 0.3, 0.18)) -> void:
	var script := load("res://scripts/world/swing_door.gd")
	var leaves := [[-w / 2, false, w]] if not double else [[-w / 2, false, w / 2], [w / 2, true, w / 2]]
	for l in leaves:
		var d: Node3D = script.new()
		d.position = pos + Vector3(l[0], 0, 0)
		d.width = l[2]
		d.height = h - 0.02
		d.mirror = l[1]
		d.color = color
		parent.add_child(d)
