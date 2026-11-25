class_name FishMesh
## Генератор низкополигональной рыбы: тело, хвост, плавники, глаза, окраска по виду.
## Длина модели — 1 единица вдоль -Z (голова впереди). Масштабируй под вес.

static var _cache: Dictionary = {}

const RINGS := 14
const SEG := 10


static func build(f: FishData) -> Node3D:
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh(f)
	mi.material_override = Art.vertex_color_mat()
	root.add_child(mi)
	# Глаза
	var eye_m := Art.color(Color(0.05, 0.05, 0.05), 0.2)
	var h := 0.17 * f.body_height
	for side in [-1.0, 1.0]:
		Art.add_mesh(root, Art.sphere(0.028, 8), eye_m, Vector3(side * h * 0.42, h * 0.25, -0.4))
		Art.add_mesh(root, Art.sphere(0.04, 8), Art.color(Color(0.95, 0.9, 0.7), 0.3),
			Vector3(side * h * 0.38, h * 0.25, -0.395))
	if f.pattern == FishData.Pattern.DARK:
		# Усы сома
		for side in [-1.0, 1.0]:
			Art.add_mesh(root, Art.cyl(0.004, 0.008, 0.35, 4), Art.color(Color(0.15, 0.15, 0.13)),
				Vector3(side * 0.06, -0.01, -0.55), Vector3(1.2, side * 0.6, 0))
	return root


static func _mesh(f: FishData) -> ArrayMesh:
	if _cache.has(f.id):
		return _cache[f.id]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var H := 0.17 * f.body_height
	var body_len := 0.78
	# Кольца тела вдоль Z (от головы z=-0.5 к хвосту)
	var rings := []
	for i in RINGS + 1:
		var t := float(i) / RINGS
		var z := -0.5 + t * body_len
		var prof := pow(sin(PI * clampf(t * 0.92 + 0.04, 0.0, 1.0)), 0.75)
		if t < 0.15:
			prof = lerpf(0.25, prof, t / 0.15)
		var hh := H * prof
		var ww := hh * 0.42
		var ring := []
		for j in SEG:
			var a := TAU * j / SEG
			var p := Vector3(cos(a) * ww, sin(a) * hh, z)
			ring.append(p)
		rings.append(ring)
	for i in RINGS:
		for j in SEG:
			var j2 := (j + 1) % SEG
			var a: Vector3 = rings[i][j]
			var b: Vector3 = rings[i][j2]
			var c: Vector3 = rings[i + 1][j]
			var d: Vector3 = rings[i + 1][j2]
			_tri(st, f, a, c, b, H)
			_tri(st, f, b, c, d, H)
	# Носик
	var nose := Vector3(0, H * 0.05, -0.53)
	for j in SEG:
		_tri(st, f, nose, rings[0][j], rings[0][(j + 1) % SEG], H)
	# Хвост
	var tz := -0.5 + body_len
	var fin := f.fin_color
	_fin(st, fin, Vector3(0, 0, tz - 0.02), Vector3(0, H * 0.95, tz + 0.22), Vector3(0, H * 0.15, tz + 0.12))
	_fin(st, fin, Vector3(0, 0, tz - 0.02), Vector3(0, -H * 0.15, tz + 0.12), Vector3(0, -H * 0.95, tz + 0.22))
	# Спинной плавник
	_fin(st, fin, Vector3(0, H * 0.92, -0.12), Vector3(0, H * 1.45, 0.02), Vector3(0, H * 0.85, 0.12))
	if f.id == &"perch" or f.id == &"zander" or f.id == &"ruffe":
		_fin(st, fin, Vector3(0, H * 0.95, -0.25), Vector3(0, H * 1.5, -0.18), Vector3(0, H * 0.95, -0.08))
	# Брюшные плавники
	for side in [-1.0, 1.0]:
		_fin(st, fin, Vector3(side * H * 0.3, -H * 0.6, -0.18), Vector3(side * H * 0.7, -H * 1.05, -0.08),
			Vector3(side * H * 0.25, -H * 0.75, -0.02))
	st.generate_normals()
	var mesh := st.commit()
	_cache[f.id] = mesh
	return mesh


static func _color_at(f: FishData, p: Vector3, H: float) -> Color:
	var up := clampf((p.y / maxf(H, 0.001)) * 0.5 + 0.5, 0.0, 1.0)
	var c := f.belly_color.lerp(f.body_color, smoothstep(0.25, 0.7, up))
	var t := (p.z + 0.5) / 0.78
	match f.pattern:
		FishData.Pattern.STRIPES:
			if sin(t * 34.0) > 0.35 and up > 0.35:
				c = c.darkened(0.45)
		FishData.Pattern.SPOTS:
			var n := sin(p.z * 61.0) * sin(p.y * 83.0 + p.x * 40.0)
			if n > 0.55 and up > 0.25:
				c = c.lightened(0.4)
		FishData.Pattern.GOLD:
			c = c.lightened(0.15 * sin(t * 20.0) + 0.05)
		FishData.Pattern.DARK:
			if sin(p.z * 25.0 + p.y * 30.0) > 0.6:
				c = c.darkened(0.25)
	if t > 0.9:
		c = c.lerp(f.fin_color, 0.4)
	return c


static func _tri(st: SurfaceTool, f: FishData, a: Vector3, b: Vector3, c: Vector3, H: float) -> void:
	for p in [a, b, c]:
		st.set_color(_color_at(f, p, H))
		st.add_vertex(p)


static func _fin(st: SurfaceTool, col: Color, a: Vector3, b: Vector3, c: Vector3) -> void:
	for tri in [[a, b, c], [a, c, b]]:
		for p in tri:
			st.set_color(col)
			st.add_vertex(p)
