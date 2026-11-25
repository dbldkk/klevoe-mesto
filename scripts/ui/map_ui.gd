extends ModalUi
## Карта посёлка (K): рельеф с тенями, вода по глубине, деревья, кольцевая дорога, крыши построек,
## подписи на плашках (не налезают друг на друга) и все игроки.

## Масштабы: посёлок и вся округа (с протокой и Дальним плёсом).
const ZOOMS := [[Vector2(-3.0, -20.0), 180.0, 2.0], [Vector2(-5.0, -66.0), 300.0, 1.2]]
var CENTER := Vector2(-3.0, -20.0)
var SPAN := 180.0          ## метров по стороне
var RES := 2.0             ## пикселей на метр в картинке
var _zoom := 0
var _texs := {}
var _zoom_btn: Button
const VIEW := 680.0        ## размер карты на экране

## Постройки на карте: место Layout, размер (ширина, глубина), цвет крыши, подпись.
const ROOFS := [["house", Vector2(9, 7), Color(0.62, 0.22, 0.18), "Дом"],
	["liquor", Vector2(8, 6), Color(0.3, 0.2, 0.25), "Бухло & Табак"],
	["casino", Vector2(20, 14), Color(0.55, 0.08, 0.14), "Казино «Золотой карась»"],
	["shop", Vector2(16, 11), Color(0.2, 0.55, 0.3), "«Шестёрочка»"],
	["bus_stop", Vector2(3.4, 1.8), Color(0.25, 0.45, 0.7), "Остановка"],
	["thimbles", Vector2(2.1, 1.9), Color(0.8, 0.2, 0.15), "Напёрстки"],
	["garage", Vector2(4.5, 6.0), Color(0.5, 0.52, 0.56), "Прокат «Нивы»"],
	["police", Vector2(7, 6), Color(0.2, 0.35, 0.65), "Опорный пункт"],
	["farm", Vector2(10, 7), Color(0.6, 0.3, 0.22), "Совхоз «Рассвет»"],
	["club", Vector2(11, 6), Color(0.75, 0.2, 0.15), "Клуб «Огонёк»"],
	["garages", Vector2(8, 5), Color(0.45, 0.45, 0.4), "Гаражный кооператив"],
	["ruins", Vector2(7, 5), Color(0.5, 0.42, 0.32), "Заброшенный колхоз"],
	["chapel", Vector2(4, 3.5), Color(0.7, 0.6, 0.3), "Часовня"],
	["dachas", Vector2(7, 5), Color(0.4, 0.55, 0.3), "Дачи"],
	["forest", Vector2(8, 7), Color(0.2, 0.4, 0.2), "Лесная тропа"],
	["campfire", Vector2(3, 3), Color(0.85, 0.45, 0.15), "Костёр рыбаков"],
	["strip_club", Vector2(7, 5.5), Color(0.75, 0.2, 0.55), "Клуб «Неон»"]]

var _tex: ImageTexture
var _canvas: Control
var _t := 0.0
var _font: Font


func _ready() -> void:
	_setup("map_ui", "", VIEW + 40, Color(0.75, 0.9, 0.6))
	var head := ModalUi.row(10)
	var title := UiKit.label("п. КЛЁВОЕ МЕСТО", 28, Color(0.85, 0.95, 0.7))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_zoom_btn = UiKit.button("Вся округа", _toggle_zoom, 15)
	head.add_child(_zoom_btn)
	head.add_child(UiKit.label("K или Esc — закрыть", 15, Color(1, 1, 1, 0.5)))
	body.add_child(head)
	_canvas = Control.new()
	_canvas.custom_minimum_size = Vector2(VIEW, VIEW)
	_canvas.clip_contents = true
	_canvas.draw.connect(_draw_map)
	body.add_child(_canvas)
	_font = ThemeDB.fallback_font


func open() -> void:
	_apply_zoom()
	_show()


func _apply_zoom() -> void:
	var z: Array = ZOOMS[_zoom]
	CENTER = z[0]
	SPAN = z[1]
	RES = z[2]
	if not _texs.has(_zoom):
		_texs[_zoom] = ImageTexture.create_from_image(_render())
	_tex = _texs[_zoom]
	_zoom_btn.text = "Посёлок" if _zoom == 1 else "Вся округа"


func _toggle_zoom() -> void:
	_zoom = 1 - _zoom
	_apply_zoom()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("map"):
		get_viewport().set_input_as_handled()
		close()
		return
	super._unhandled_input(event)


func _process(delta: float) -> void:
	if visible:
		_t += delta
		_canvas.queue_redraw()


# ------------------------------------------------------------ картинка местности

func _w(px: float, py: float) -> Vector2:
	return CENTER + Vector2(px / RES - SPAN / 2, py / RES - SPAN / 2)


func _render() -> Image:
	var n := int(SPAN * RES)
	var hs := PackedFloat32Array()
	hs.resize(n * n)
	for py in n:
		for px in n:
			var w := _w(px, py)
			hs[py * n + px] = Terrain.height(w.x, w.y)
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var light := Vector3(-0.6, 0.75, -0.4).normalized()
	for py in n:
		for px in n:
			var h := hs[py * n + px]
			var hx := hs[py * n + mini(px + 1, n - 1)] - hs[py * n + maxi(px - 1, 0)]
			var hz := hs[mini(py + 1, n - 1) * n + px] - hs[maxi(py - 1, 0) * n + px]
			var nrm := Vector3(-hx * RES * 1.6, 2.0, -hz * RES * 1.6).normalized()
			var shade := clampf(nrm.dot(light) * 1.25, 0.55, 1.15)
			var c: Color
			if h < Terrain.WATER_Y:
				var d := clampf((Terrain.WATER_Y - h) / 4.5, 0.0, 1.0)
				c = Color(0.42, 0.7, 0.82).lerp(Color(0.1, 0.28, 0.52), d)
				if d < 0.06:
					c = c.lerp(Color(0.85, 0.93, 0.95), 0.5)   # кромка
			elif h < Terrain.WATER_Y + 0.22:
				c = Color(0.86, 0.8, 0.6) * shade
			else:
				var k := clampf(h / 1.2, 0.0, 1.0)
				c = Color(0.42, 0.6, 0.3).lerp(Color(0.58, 0.68, 0.36), k) * shade
			img.set_pixel(px, py, Color(c.r, c.g, c.b))
	_paint_trees(img)
	_paint_road(img)
	_paint_bridge(img)
	_paint_paths(img)
	return img


func _to_px(x: float, z: float) -> Vector2i:
	return Vector2i(int((x - CENTER.x + SPAN / 2) * RES), int((z - CENTER.y + SPAN / 2) * RES))


func _disc(img: Image, c: Vector2i, r: int, col: Color, alpha := 1.0) -> void:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dy * dy <= r * r:
				var p := c + Vector2i(dx, dy)
				if p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height():
					img.set_pixelv(p, img.get_pixelv(p).lerp(col, alpha))


func _paint_trees(img: Image) -> void:
	var decor := get_tree().root.get_node_or_null("World/Decor")
	if decor == null:
		return
	for t in decor.get_children():
		if t is StaticBody3D:
			var p := (t as Node3D).global_position
			var c := _to_px(p.x, p.z)
			_disc(img, c + Vector2i(2, 2), 4, Color(0.15, 0.25, 0.12), 0.35)   # тень
			_disc(img, c, 4, Color(0.2, 0.42, 0.2))
			_disc(img, c + Vector2i(-1, -1), 2, Color(0.32, 0.55, 0.28))


func _paint_road(img: Image) -> void:
	var phi := -180.0
	while phi < 180.0:
		var p := Layout.ring(phi)
		var c := _to_px(p.x, p.z)
		_disc(img, c, int(Layout.ROAD_W / 2 * RES) + 1, Color(0.85, 0.85, 0.8))
		phi += 1.0
	phi = -180.0
	while phi < 180.0:
		var p := Layout.ring(phi)
		_disc(img, _to_px(p.x, p.z), int(Layout.ROAD_W / 2 * RES) - 1, Color(0.36, 0.37, 0.4))
		phi += 1.0
	phi = -180.0
	var i := 0
	while phi < 180.0:
		if i % 6 < 3:
			var p := Layout.ring(phi)
			_disc(img, _to_px(p.x, p.z), 0, Color(0.95, 0.95, 0.9))
		phi += 0.35
		i += 1


func _paint_bridge(img: Image) -> void:
	var b := Terrain.BRIDGE
	var x := b.x - Terrain.BRIDGE_LEN / 2
	while x < b.x + Terrain.BRIDGE_LEN / 2:
		_disc(img, _to_px(x, b.z), int(Layout.ROAD_W / 2 * RES), Color(0.6, 0.42, 0.25))
		x += 0.5


func _paint_paths(img: Image) -> void:
	# Тропинка к пирсу и пирс
	var a := Layout.ring(0.0, -Layout.ROAD_W / 2)
	var steps := 60
	for k in steps:
		var p := a.lerp(Vector3(0, 0, -5.0), k / float(steps))
		_disc(img, _to_px(p.x, p.z), 2, Color(0.55, 0.45, 0.32))
	for z in range(-14, -4):
		for x in [-1.0, 0.0, 1.0]:
			_disc(img, _to_px(x, float(z)), 2, Color(0.55, 0.38, 0.22))
	# Рынок
	for x in range(-15, -10):
		for z in [4.9, 5.9]:
			_disc(img, _to_px(float(x), z), 2, Color(0.25, 0.45, 0.8))


# ------------------------------------------------------------ рисование поверх

func _m(p: Vector3) -> Vector2:
	return Vector2((p.x - CENTER.x + SPAN / 2) / SPAN, (p.z - CENTER.y + SPAN / 2) / SPAN) * VIEW


func _draw_map() -> void:
	if _tex:
		_canvas.draw_texture_rect(_tex, Rect2(Vector2.ZERO, Vector2(VIEW, VIEW)), false)
	var taken: Array[Rect2] = []
	# Крыши построек
	for r in ROOFS:
		if not Layout.SPOTS.has(r[0]):
			continue
		var t := Layout.xform(r[0])
		var sz: Vector2 = r[1]
		var pts := PackedVector2Array()
		for c in [Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(1, 0, 1), Vector3(-1, 0, 1)]:
			pts.append(_m(t * Vector3(c.x * sz.x / 2, 0, c.z * sz.y / 2)))
		var shadow := PackedVector2Array()
		for p in pts:
			shadow.append(p + Vector2(3, 3))
		_canvas.draw_colored_polygon(shadow, Color(0, 0, 0, 0.3))
		_canvas.draw_colored_polygon(pts, r[2])
		_canvas.draw_polyline(pts + PackedVector2Array([pts[0]]), (r[2] as Color).lightened(0.35), 1.5)
		taken.append(_bounds(pts))
	# Подписи: постройки + остальные места (рынок, пирс, фандомат…)
	var labels: Array = []
	for r in ROOFS:
		labels.append([Layout.xform(r[0]).origin, r[3], r[2]])
	var seen := {}
	for r in ROOFS:
		seen[r[3]] = true
	for n in get_tree().get_nodes_in_group("poi"):
		if not n is Node3D or not n.has_meta("poi_name"):
			continue
		var nm: String = n.get_meta("poi_name")
		if seen.has(nm) or nm.begins_with("Казино") or nm == "Дом" or nm == "Бухло & Табак":
			continue
		seen[nm] = true
		labels.append([(n as Node3D).global_position, nm, Color(0.95, 0.75, 0.3)])
	for l in labels:
		_label(l[0], l[1], l[2], taken)
	_players()
	_compass()


func _bounds(pts: PackedVector2Array) -> Rect2:
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	return r


## Плашка с текстом: пробуем места вокруг точки, берём первое свободное.
func _label(world: Vector3, text: String, col: Color, taken: Array[Rect2]) -> void:
	var at := _m(world)
	var fs := 14
	var size := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs) + Vector2(14, 6)
	# Сначала — наружу от озера (подписи не лезут на воду).
	var out := (at - _m(Vector3(Layout.C.x, 0, Layout.C.y))).normalized()
	var tries := [out * 26.0, Vector2(0, -24), Vector2(0, 24), Vector2(-size.x / 2 - 14, 0), Vector2(size.x / 2 + 14, 0),
		out * 46.0, Vector2(0, -44), Vector2(0, 44), out * 66.0]
	var rect := Rect2()
	for o in tries:
		var c: Vector2 = at + o
		rect = Rect2(c - size / 2, size)
		var ok := rect.position.x > 2 and rect.position.y > 2 and rect.end.x < VIEW - 2 and rect.end.y < VIEW - 2
		for t in taken:
			if ok and t.grow(2).intersects(rect):
				ok = false
		if ok:
			break
	rect.position = rect.position.clamp(Vector2(2, 2), Vector2(VIEW - 2, VIEW - 2) - rect.size)
	taken.append(rect)
	var anchor := rect.get_center()
	_canvas.draw_line(at, anchor, Color(0, 0, 0, 0.55), 1.5)
	_canvas.draw_circle(at, 4.0, Color(0.1, 0.1, 0.1))
	_canvas.draw_circle(at, 2.8, col.lightened(0.3))
	var sb := UiKit.box(Color(0.06, 0.08, 0.1, 0.88), 6, 0)
	sb.border_color = col
	sb.border_width_left = 3
	_canvas.draw_style_box(sb, rect)
	_canvas.draw_string(_font, rect.position + Vector2(9, size.y - 7), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


func _players() -> void:
	var me := get_tree().get_first_node_in_group("local_player") as Node3D
	for p in get_tree().get_nodes_in_group("players"):
		var pp := p as Node3D
		var m := _m(pp.global_position)
		var mine := pp == me
		var col := Color(0.3, 1.0, 0.45) if mine else Color(0.45, 0.8, 1.0)
		var fwd := -pp.global_basis.z
		var dir := Vector2(fwd.x, fwd.z).normalized()
		var side := Vector2(-dir.y, dir.x)
		var s := 10.0 + (sin(_t * 6.0) * 1.5 if mine else 0.0)
		var tri := PackedVector2Array([m + dir * s, m - dir * s * 0.6 + side * s * 0.65, m - dir * s * 0.6 - side * s * 0.65])
		_canvas.draw_colored_polygon(tri, col)
		_canvas.draw_polyline(tri + PackedVector2Array([tri[0]]), Color(0, 0, 0, 0.8), 1.5)
		var nm: String = "Я" if mine else str(p.player_name)
		var sz := _font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 13) + Vector2(10, 4)
		var r := Rect2(m + Vector2(12, -sz.y / 2), sz)
		_canvas.draw_style_box(UiKit.box(Color(0, 0, 0, 0.7), 4, 0), r)
		_canvas.draw_string(_font, r.position + Vector2(5, sz.y - 5), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)


func _compass() -> void:
	var c := Vector2(VIEW - 34, 34)
	_canvas.draw_circle(c, 22, Color(0, 0, 0, 0.5))
	_canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -18), c + Vector2(6, 2), c + Vector2(-6, 2)]), Color(0.9, 0.3, 0.25))
	_canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(0, 18), c + Vector2(6, -2), c + Vector2(-6, -2)]), Color(0.9, 0.9, 0.9))
	_canvas.draw_string(_font, c + Vector2(-5, -24), "С", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
