extends Node3D
## Посёлок: кольцевая дорога вокруг озера (эллипс из Layout), разметка, бордюры, фонари (горят ночью),
## лавочки у воды, остановка «Озеро», тропинки к дверям и к пирсу, знаки на въезде.

const STEP := 2.0   ## градусов на кусок дороги

## Двери построек (локально): x, z, ширина тропинки.
const DOORS := {"house": [0.0, 3.5, 1.4], "liquor": [-2.0, 3.0, 1.4], "casino": [0.0, 7.0, 2.6],
	"shop": [0.0, 5.5, 3.0], "thimbles": [0.0, 1.6, 1.2]}


func _ready() -> void:
	_road()
	_lamps()
	# Лавочки у воды — между дорогой и озером, смотрят на озеро.
	for phi in [-42.0, -27.0, 30.0, 70.0, 110.0, -125.0, 160.0]:
		var p := Layout.ring(phi, -6.0)
		if Terrain.lake_distance(p.x, p.z).x > 2.5:
			_bench(p, Layout.face_in_yaw(phi))
	_bus_stop(Layout.xform("bus_stop"))
	# Тропинки
	var dirt := Art.tex_world("dirt", 0.5)
	_path(Layout.ring(0.0, -Layout.ROAD_W / 2), Vector3(0, 0, -5.6), 1.6, dirt)
	for k in DOORS:
		var d: Array = DOORS[k]
		var door := Layout.local_to_world(k, Vector3(d[0], 0, d[1]))
		var mat: Material = dirt
		if k == "casino":
			mat = Art.color(Color(0.55, 0.1, 0.12), 0.9)
		elif k == "shop":
			mat = Art.tex_world("asphalt", 0.4)
		_path(door, _road_edge_toward(door), d[2], mat)
	for phi in [140.0, -140.0]:
		_welcome(phi)
	_river_sign()


func _river_sign() -> void:
	var p := Vector3(Terrain.BRIDGE.x + Terrain.BRIDGE_LEN / 2 + 1.5, 0, Terrain.BRIDGE.z + Layout.ROAD_W / 2 + 1.2)
	p.y = Terrain.height(p.x, p.z)
	var n := Node3D.new()
	n.position = p
	add_child(n)
	Build.block(n, Vector3(0, 0.9, 0), Vector3(0.07, 1.8, 0.07), Art.color(Color(0.4, 0.4, 0.42), 0.4, 0.6), true)
	Build.block(n, Vector3(0, 1.85, 0), Vector3(1.9, 0.5, 0.05), Art.color(Color(0.1, 0.35, 0.65)), false)
	Build.text(n, Vector3(0, 1.85, 0.035), "р. Протока · к Дальнему плёсу", 30, Color.WHITE, 0.005)
	Build.text(n, Vector3(0, 1.85, -0.035), "р. Протока", 34, Color.WHITE, 0.005, PI)


## Ближайшая к точке кромка дороги.
func _road_edge_toward(p: Vector3) -> Vector3:
	var best := 0.0
	var bd := INF
	for i in 360:
		var q := Layout.ring(float(i - 180))
		var d := q.distance_squared_to(p)
		if d < bd:
			bd = d
			best = float(i - 180)
	return Layout.ring(best, Layout.ROAD_W / 2 - 0.2)


func _road() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw := Layout.ROAD_W / 2
	var n := int(360.0 / STEP)
	var curb := Art.color(Color(0.75, 0.75, 0.72), 0.9)
	var paint := Art.color(Color(0.95, 0.95, 0.9), 0.7)
	for i in n:
		var a := -180.0 + i * STEP
		var b := a + STEP
		var mid := Layout.ring(a + STEP / 2)
		if Terrain.on_bridge(mid.x, mid.z):
			_bridge_piece(a, b)
			continue
		var a0 := _on_ground(Layout.ring(a, -hw))
		var a1 := _on_ground(Layout.ring(a, hw))
		var b0 := _on_ground(Layout.ring(b, -hw))
		var b1 := _on_ground(Layout.ring(b, hw))
		for v in [a0, b1, a1, a0, b0, b1]:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(v.x, v.z) * 0.25)
			st.add_vertex(v)
		# бордюры
		for side in [-1.0, 1.0]:
			var p := (Layout.ring(a, side * (hw + 0.1)) + Layout.ring(b, side * (hw + 0.1))) / 2
			var t := Layout.ring(b, side * (hw + 0.1)) - Layout.ring(a, side * (hw + 0.1))
			Build.block(self, _on_ground(p) + Vector3.UP * 0.05, Vector3(0.2, 0.16, t.length() + 0.05), curb, false,
				Vector3(0, atan2(t.x, t.z), 0))
		# прерывистая разметка: через кусок
		if i % 2 == 0:
			var p := (Layout.ring(a) + Layout.ring(b)) / 2
			var t := Layout.ring(b) - Layout.ring(a)
			Build.block(self, _on_ground(p) + Vector3.UP * 0.008, Vector3(0.14, 0.01, t.length() * 0.55), paint, false,
				Vector3(0, atan2(t.x, t.z), 0))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var asphalt := Art.tex_world("asphalt", 0.35).duplicate() as StandardMaterial3D
	asphalt.albedo_color = Color(0.6, 0.6, 0.63)
	asphalt.roughness = 0.85
	mi.material_override = asphalt
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## Кусок моста через протоку: настил из досок, перила, сваи в воду.
func _bridge_piece(a: float, b: float) -> void:
	var wood := Art.tex_world("planks", 0.7)
	var dark := Art.color(Color(0.32, 0.24, 0.17), 0.9)
	var pa := Layout.ring(a)
	var pb := Layout.ring(b)
	var t := pb - pa
	var yaw := atan2(t.x, t.z)
	var c := (pa + pb) / 2
	var y := Terrain.BRIDGE.y
	Build.block(self, Vector3(c.x, y - 0.12, c.z), Vector3(Layout.ROAD_W + 0.6, 0.24, t.length() + 0.08), wood, true, Vector3(0, yaw, 0))
	var side_v := Layout.normal((a + b) / 2)
	for sd in [-1.0, 1.0]:
		var e: Vector3 = c + side_v * sd * (Layout.ROAD_W / 2 + 0.2)
		Build.block(self, Vector3(e.x, y + 0.5, e.z), Vector3(0.1, 0.08, t.length() + 0.08), dark, false, Vector3(0, yaw, 0))
		Build.block(self, Vector3(e.x, y + 0.25, e.z), Vector3(0.12, 1.0, t.length() + 0.08), dark, true, Vector3(0, yaw, 0)).visible = false
		Build.block(self, Vector3(e.x, y + 0.27, e.z), Vector3(0.1, 0.55, 0.1), dark, false)
		Build.block(self, Vector3(e.x, Terrain.WATER_Y - 1.0, e.z), Vector3(0.28, 2.9, 0.28), dark, false)


## Точка дороги над рельефом (чуть выше, чтобы трава/земля не проступали).
func _on_ground(p: Vector3) -> Vector3:
	p.y = maxf(Terrain.height(p.x, p.z), 0.0) + 0.06
	return p


func _lamps() -> void:
	var i := 0
	var phi := -180.0
	while phi < 180.0:
		var side := 1.0 if i % 2 == 0 else -1.0
		var p := Layout.ring(phi, side * (Layout.ROAD_W / 2 + 0.7))
		if not Layout.is_busy(p.x, p.z, -0.6):
			if Terrain.lake_distance(p.x, p.z).x > 1.0:
				_lamp_post(p, Layout.face_in_yaw(phi) + (PI if side > 0 else 0.0))
		phi += 17.0
		i += 1


func _welcome(phi: float) -> void:
	var sign := Node3D.new()
	sign.position = Layout.ring(phi, Layout.ROAD_W / 2 + 1.5)
	var t := Layout.tangent(phi)
	sign.rotation.y = atan2(t.x, t.z)
	add_child(sign)
	Build.block(sign, Vector3(0, 1.0, 0), Vector3(0.08, 2.0, 0.08), Art.color(Color(0.4, 0.4, 0.42), 0.4, 0.6), true)
	Build.block(sign, Vector3(0, 2.2, 0), Vector3(2.6, 0.7, 0.05), Art.color(Color(0.12, 0.3, 0.6)), false)
	Build.text(sign, Vector3(0, 2.2, 0.035), "п. КЛЁВОЕ МЕСТО", 52, Color.WHITE, 0.006)
	Build.text(sign, Vector3(0, 2.2, -0.035), "п. КЛЁВОЕ МЕСТО", 52, Color.WHITE, 0.006, PI)


## Фонарь: плафон выносится в сторону −Z (поворот yaw).
func _lamp_post(p: Vector3, yaw: float) -> void:
	var n := Node3D.new()
	n.position = p
	n.rotation.y = yaw
	add_child(n)
	var metal := Art.color(Color(0.3, 0.32, 0.34), 0.4, 0.7)
	Build.cylinder(n, Vector3(0, 2.4, 0), 0.07, 4.8, metal, true, 8)
	Build.block(n, Vector3(0, 4.75, -0.6), Vector3(0.08, 0.08, 1.3), metal, false)
	var bulb := Build.glow_mat(Color(1.0, 0.85, 0.55), 0.0)
	bulb.set_meta("night_glow", 4.0)
	var b := Art.add_mesh(n, Art.box(Vector3(0.35, 0.1, 0.5)), bulb, Vector3(0, 4.68, -1.15))
	b.add_to_group("night_bulbs")
	Build.lamp(n, Vector3(0, 4.4, -1.15), 2.2, 13.0, Color(1.0, 0.8, 0.5), true)


func _bench(p: Vector3, rot: float) -> void:
	var n := Node3D.new()
	n.position = p + Vector3(0, Terrain.height(p.x, p.z), 0)
	n.rotation.y = rot
	add_child(n)
	var wood := Art.tex_world("planks", 0.6)
	var iron := Art.color(Color(0.15, 0.15, 0.15), 0.5, 0.6)
	Build.block(n, Vector3(0, 0.45, 0), Vector3(1.8, 0.06, 0.45), wood, true)
	Build.block(n, Vector3(0, 0.8, -0.22), Vector3(1.8, 0.35, 0.05), wood, false, Vector3(-0.15, 0, 0))
	for x in [-0.75, 0.75]:
		Build.block(n, Vector3(x, 0.22, 0), Vector3(0.06, 0.44, 0.45), iron, false)
	Build.block(n, Vector3(1.15, 0.35, 0), Vector3(0.35, 0.7, 0.35), Art.color(Color(0.2, 0.35, 0.2), 0.6, 0.3), true)  # урна


func _bus_stop(t: Transform3D) -> void:
	var n := Node3D.new()
	n.transform = t
	add_child(n)
	var metal := Art.color(Color(0.25, 0.45, 0.65), 0.4, 0.5)
	var glass := Art.glass(Color(0.6, 0.75, 0.85, 0.35))
	Build.block(n, Vector3(0, 0.03, -0.6), Vector3(3.4, 0.06, 1.8), Art.tex_world("asphalt", 0.4), false)
	Build.block(n, Vector3(0, 1.2, -1.4), Vector3(3.2, 2.2, 0.05), glass, true)
	for x in [-1.6, 1.6]:
		Build.block(n, Vector3(x, 1.2, -0.6), Vector3(0.06, 2.4, 1.6), glass, true)
	Build.block(n, Vector3(0, 2.45, -0.6), Vector3(3.5, 0.1, 1.9), metal, true)
	Build.block(n, Vector3(0, 0.45, -1.15), Vector3(2.6, 0.06, 0.35), Art.tex_world("planks", 0.6), true)
	Build.block(n, Vector3(1.9, 1.3, 0.3), Vector3(0.06, 2.6, 0.06), metal, true)
	Build.block(n, Vector3(1.9, 2.35, 0.3), Vector3(0.7, 0.6, 0.04), Art.color(Color(0.95, 0.85, 0.1)), false)
	Build.text(n, Vector3(1.9, 2.47, 0.33), "А", 44, Color(0.1, 0.1, 0.1), 0.005)
	Build.text(n, Vector3(1.9, 2.25, 0.33), "ОЗЕРО", 30, Color(0.1, 0.1, 0.1), 0.005)
	Build.text(n, Vector3(0, 2.15, -1.36), "Автобус: пн, ср, пт… когда-нибудь", 26, Color(0.95, 0.95, 0.95), 0.005)


func _path(a: Vector3, b: Vector3, width: float, mat: Material) -> void:
	## Кусками по 1.5 м — чтобы тропинка лежала на рельефе.
	var d := b - a
	var len := Vector2(d.x, d.z).length()
	var yaw := atan2(d.x, d.z)
	var n := maxi(1, ceili(len / 1.5))
	for i in n:
		var c := a + d * ((i + 0.5) / n)
		var y := Terrain.height(c.x, c.z)
		if y < Terrain.WATER_Y:
			continue
		Build.block(self, Vector3(c.x, y + 0.02, c.z), Vector3(width, 0.04, len / n + 0.05), mat, false, Vector3(0, yaw, 0))
