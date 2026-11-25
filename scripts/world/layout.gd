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
	"house": [-105.0, 9.5, 8.5, 4.5],
	"liquor": [-68.0, 9.2, 5.0, 4.0],
	"casino": [28.0, 13.5, 11.0, 8.0],
	"bus_stop": [-46.0, 6.4, 2.5, 1.5],
	"shop": [-22.0, 11.5, 15.5, 7.0],
	"thimbles": [62.0, 6.0, 2.0, 2.0],
	"garage": [88.0, 8.0, 2.6, 3.2],
	"police": [-130.0, 9.5, 4.5, 4.0],
	"babka": [-94.0, 5.2, 1.4, 1.0],
	"farm": [152.0, 13.0, 13.0, 8.0],
	"pasture": [152.0, 34.0, 12.0, 9.0],
	"club": [-160.0, 13.5, 11.0, 8.5],
	"repair": [96.0, 8.5, 3.2, 3.6],
}


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
			_inv.append([xform(k).affine_inverse(), s[2], s[3]])
	return _inv


static func xform(spot: String) -> Transform3D:
	var s: Array = SPOTS[spot]
	return Transform3D(Basis(Vector3.UP, face_in_yaw(s[0])), ring(s[0], s[1]))


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
