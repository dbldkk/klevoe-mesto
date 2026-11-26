class_name Layout
## Планировка посёлка: кольцевая дорога вокруг озера (эллипс) и места построек.
## Постройки стоят полукругом с южной стороны, дверями к дороге и озеру.
## Угол phi: 0 — юг (к игроку на карте снизу), отрицательные — запад, положительные — восток.

const C := Vector2(-2.6, -25.8)
const AX := 65.0
const AZ := 44.2
const ROAD_W := 7.0

## Места: угол (градусы), отступ от оси дороги наружу (м), размер площадки (полуширина, полуглубина).
const SPOTS := {
	"hospital": [-99.0, 26.0, 4.5, 4.0],
	"house": [-105.0, 9.5, 8.5, 4.5],
	"liquor": [-68.0, 9.2, 5.0, 4.0],
	"casino": [28.0, 13.5, 11.0, 8.0],
	"bus_stop": [-46.0, 6.4, 2.5, 1.5],
	"shop": [-22.0, 11.5, 15.5, 7.0],
	"shop_premium": [-22.0, -11.5, 8.6, 6.0],
	"thimbles": [62.0, 6.0, 2.0, 2.0],
	"garage": [88.0, 8.0, 2.6, 3.2],
	"police": [-130.0, 9.5, 4.5, 4.0],
	"babka": [-94.0, 5.2, 1.4, 1.0],
	"farm": [152.0, 13.0, 13.0, 8.0],
	"pasture": [152.0, 34.0, 12.0, 9.0],
	"club": [-160.0, 13.5, 11.0, 8.5],
	"repair": [96.0, 8.5, 3.2, 3.6],
	"garages": [125.0, 13.0, 8.0, 5.0],
	"ruins": [168.0, 34.0, 8.0, 6.0],
	"chapel": [-117.0, 28.0, 5.0, 4.0],
	"dachas": [-80.0, 22.0, 8.0, 6.0],
	"forest": [48.0, 26.0, 10.0, 8.0],
	"campfire": [8.0, -16.0, 3.0, 3.0],
	"strip_club": [108.0, 16.0, 8.0, 6.5],
}

## Новые места v1.1+. Проверяются тестами на сушу, берег, дорогу и пересечения.
const NEW_POIS := ["garages", "ruins", "chapel", "dachas", "forest", "campfire", "strip_club"]
## Эти площадки не ровняем в ноль: часовня и руины стоят на холме, костёр — на берегу.
const NATURAL := ["chapel", "ruins", "campfire"]
const SHORE_MARGIN := 4.0


## Точка на эллипсе дороги, сдвинутая наружу на off метров (по нормали).
static func ring(phi_deg: float, off := 0.0) -> Vector3:
	var p := deg_to_rad(phi_deg)
	var base := Vector2(C.x + AX * sin(p), C.y + AZ * cos(p))
	var n := normal(phi_deg)
	var q := base + Vector2(n.x, n.z) * off
	return Vector3(q.x, 0.0, q.y)


## Нормаль эллипса наружу.
static func normal(phi_deg: float) -> Vector3:
	var p := deg_to_rad(phi_deg)
	var n := Vector2(sin(p) / AX, cos(p) / AZ).normalized()
	return Vector3(n.x, 0.0, n.y)


## Касательная (по возрастанию угла).
static func tangent(phi_deg: float) -> Vector3:
	var p := deg_to_rad(phi_deg)
	return Vector3(AX * cos(p), 0.0, -AZ * sin(p)).normalized()


## Поворот так, чтобы +Z смотрел внутрь кольца (к дороге и озеру).
static func face_in_yaw(phi_deg: float) -> float:
	var n := -normal(phi_deg)
	return atan2(n.x, n.z)


static var _inv: Array = []


## Обратные преобразования площадок (кеш): [inv, hx, hz].
static func _spots_inv() -> Array:
	if _inv.is_empty():
		for k in SPOTS:
			var s: Array = SPOTS[k]
			_inv.append([xform(k).affine_inverse(), s[2], s[3], k])
	return _inv


static func xform(spot: String) -> Transform3D:
	var s: Array = SPOTS[spot]
	return Transform3D(Basis(Vector3.UP, face_in_yaw(s[0]) + (PI if spot == "shop_premium" else 0.0)), ring(s[0], s[1]))


## Точка в локальных координатах постройки → мир.
static func local_to_world(spot: String, local: Vector3) -> Vector3:
	return xform(spot) * local


## Где появляются игроки: у крыльца дома.
static func spawn() -> Vector3:
	return local_to_world("house", Vector3(0, 0.6, 7.0))


static func spawn_yaw() -> float:
	return face_in_yaw(SPOTS.house[0]) + PI


## Расстояние до оси дороги (приблизительно, м).
static func road_distance(x: float, z: float) -> float:
	var dx := (x - C.x) / AX
	var dz := (z - C.y) / AZ
	var e := sqrt(dx * dx + dz * dz)
	if e < 0.001:
		return 999.0
	var r := Vector2(x - C.x, z - C.y).length()
	return absf(r * (1.0 - 1.0 / e))


## 0..1 — насколько точка внутри площадки постройки (с мягким краем margin).
static func flat_factor(x: float, z: float, margin := 3.0) -> float:
	var f := 1.0 - Terrain.smooth(ROAD_W / 2 + 0.5, ROAD_W / 2 + 0.5 + margin, road_distance(x, z))
	for s in _spots_inv():
		if String(s[3]) in NATURAL:
			continue
		var l: Vector3 = s[0] * Vector3(x, 0, z)
		var dd := maxf(absf(l.x) - s[1], absf(l.z) - s[2])
		f = maxf(f, 1.0 - Terrain.smooth(0.0, margin, dd))
	return f


## Точка в площадке постройки (с запасом pad метров).
static func spot_contains(spot: String, x: float, z: float, pad := 0.0) -> bool:
	if not SPOTS.has(spot):
		return false
	var l: Vector3 = xform(spot).affine_inverse() * Vector3(x, 0.0, z)
	var s: Array = SPOTS[spot]
	return absf(l.x) < float(s[2]) + pad and absf(l.z) < float(s[3]) + pad


## Занято ли место (для деревьев, травы).
static func is_busy(x: float, z: float, pad := 1.0) -> bool:
	if road_distance(x, z) < ROAD_W / 2 + pad:
		return true
	for s in _spots_inv():
		var l: Vector3 = s[0] * Vector3(x, 0, z)
		if absf(l.x) < s[1] + pad and absf(l.z) < s[2] + pad:
			return true
	return false


## Минимальная высота земли под площадкой (по сетке углов и центра).
static func min_height(spot: String) -> float:
	var h := 999.0
	for p in footprint_points(spot):
		h = minf(h, Terrain.height(p.x, p.z))
	return h


## Точки контура площадки (центр + 8 по периметру) в мире, y земли не учитывается.
static func footprint_points(spot: String, pad := 0.0) -> Array[Vector3]:
	var s: Array = SPOTS[spot]
	var xf := xform(spot)
	var hx := float(s[2]) + pad
	var hz := float(s[3]) + pad
	var pts: Array[Vector3] = []
	for u in [-1.0, 0.0, 1.0]:
		for v in [-1.0, 0.0, 1.0]:
			pts.append(xf * Vector3(u * hx, 0.0, v * hz))
	return pts


## Поставить узел на минимальную высоту земли под контуром (hx, hz — полуразмеры, м).
static func snap_to_ground(node: Node3D, hx: float, hz: float) -> float:
	# у узла вне дерева global_transform — единичный; берём локальный.
	var xf := node.global_transform if node.is_inside_tree() else node.transform
	var min_h := 999.0
	for u in [-1.0, 0.0, 1.0]:
		for v in [-1.0, 0.0, 1.0]:
			var p: Vector3 = xf * Vector3(u * hx, 0.0, v * hz)
			min_h = minf(min_h, Terrain.height(p.x, p.z))
	if node.is_inside_tree():
		var gp := node.global_position
		gp.y = min_h
		node.global_position = gp
	else:
		var tr := node.transform
		tr.origin.y = min_h
		node.transform = tr
	return min_h


## Пусто — площадка на суше, не на дороге, не пересекается с другими и не в воде.
static func placement_problems(spot: String, shore := SHORE_MARGIN) -> PackedStringArray:
	var out: PackedStringArray = []
	if not SPOTS.has(spot):
		out.append("missing")
		return out
	var wet := 0
	var shore_hits := 0
	var road := 0
	var min_h := 999.0
	for p in footprint_points(spot, 0.4):
		var h := Terrain.height(p.x, p.z)
		var d := Terrain.depth(p.x, p.z)
		var ld := Terrain.lake_distance(p.x, p.z).x
		min_h = minf(min_h, h)
		if d > 0.0 or h < Terrain.WATER_Y + 0.05:
			wet += 1
		if ld < shore:
			shore_hits += 1
		if road_distance(p.x, p.z) < ROAD_W / 2.0 + 0.6:
			road += 1
	if wet > 0:
		out.append("water")
	if shore_hits > 0:
		out.append("shore")
	if road > 0:
		out.append("road")
	# пересечение с другой постройкой (с запасом 1 м)
	var mid := xform(spot).origin
	for k in SPOTS:
		if String(k) == spot:
			continue
		if spot_contains(String(k), mid.x, mid.z, 1.0):
			out.append("overlap:%s" % k)
	return out
