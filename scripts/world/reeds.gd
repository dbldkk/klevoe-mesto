class_name Reeds
extends Node3D
## Заросли камыша и кувшинок на мелководье. Закинул сюда — клюёт крупнее,
## но тащить тяжелее: рыба цепляется за траву, и удочка изнашивается быстрее.

const CLUSTER_RADIUS := 3.2

static var _zones: Array[Vector2] = []


## Центры зарослей (одинаковые у всех — считаются от формы озера).
static func zones() -> Array[Vector2]:
	if not _zones.is_empty():
		return _zones
	var angles := [0.35, 1.2, 2.15, 2.7, 3.5, 4.3, 5.05, 5.75]
	for a in angles:
		# Идём от центра озера наружу, ищем мелководье глубиной ~0.8 м.
		var dir := Vector2(cos(a) * Terrain.LAKE_SX, sin(a))
		for step in range(0, 400):
			var r := 40.0 - step * 0.1
			var p := Terrain.LAKE_C + dir * r
			var dpt := Terrain.depth(p.x, p.y)
			if dpt > 0.7 and dpt < 1.1:
				if _far_from_pier(p):
					_zones.append(p)
				break
	# Отдельно — заросли в западном заливе.
	_zones.append(Vector2(-37.7, -18.6))
	# Дальний плёс: заросли по кругу на мелководье и в протоке.
	for a in [0.2, 0.9, 1.7, 2.4, 3.1, 3.8, 4.6, 5.4]:
		var dir := Vector2(cos(a) * Terrain.FAR_SX, sin(a))
		for step in range(0, 600):
			var r := 70.0 - step * 0.1
			var p := Terrain.FAR_C + dir * r
			var dpt := Terrain.depth(p.x, p.y)
			if dpt > 0.7 and dpt < 1.1:
				_zones.append(p)
				break
	_zones.append(Vector2(-7.5, -92.0))
	return _zones


static func _far_from_pier(p: Vector2) -> bool:
	return not (absf(p.x) < 5.0 and p.y > -17.0 and p.y < -3.0)


static func in_zone(p: Vector3) -> bool:
	for z in zones():
		if Vector2(p.x, p.z).distance_to(z) < CLUSTER_RADIUS + 0.4:
			return true
	return false


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var blade := QuadMesh.new()
	blade.size = Vector2(0.12, 1.0)
	var bmat := StandardMaterial3D.new()
	bmat.albedo_texture = load("res://art/textures/reeds.png")
	bmat.albedo_color = Color(0.85, 0.95, 0.7)
	bmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	bmat.roughness = 0.9
	blade.material = bmat
	var cattail := Art.capsule(0.03, 0.18)
	cattail.material = Art.color(Color(0.38, 0.24, 0.12))
	var pad := Art.cyl(0.32, 0.32, 0.01, 10)
	pad.material = Art.color(Color(0.2, 0.45, 0.2), 0.6)
	var flower := Art.sphere(0.07, 8)
	flower.material = Art.color(Color(1.0, 0.85, 0.9), 0.5)

	var blades: Array[Transform3D] = []
	var tails: Array[Transform3D] = []
	var pads: Array[Transform3D] = []
	var flowers: Array[Transform3D] = []
	for z in zones():
		for i in 90:
			var off := Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * CLUSTER_RADIUS
			var p := z + off
			var ground := Terrain.height(p.x, p.y)
			if ground > Terrain.WATER_Y + 0.3:
				continue
			var h := rng.randf_range(1.2, 2.2)
			var b := Basis(Vector3.UP, rng.randf() * TAU).rotated(Vector3(1, 0, 0), rng.randf_range(-0.12, 0.12))
			b = b.scaled(Vector3(1, h, 1))
			blades.append(Transform3D(b, Vector3(p.x, ground + h * 0.5, p.y)))
			blades.append(Transform3D(b.rotated(Vector3.UP, PI / 2), Vector3(p.x, ground + h * 0.5, p.y)))
			if rng.randf() < 0.25:
				tails.append(Transform3D(Basis(), Vector3(p.x, ground + h + 0.05, p.y)))
		for i in 14:
			var off := Vector2.from_angle(rng.randf() * TAU) * (CLUSTER_RADIUS + rng.randf() * 2.0)
			var p := z + off
			if Terrain.depth(p.x, p.y) < 0.3:
				continue
			var s := rng.randf_range(0.6, 1.2)
			pads.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, 1, s)),
				Vector3(p.x, Terrain.WATER_Y + 0.02, p.y)))
			if rng.randf() < 0.3:
				flowers.append(Transform3D(Basis().scaled(Vector3(1, 0.6, 1)), Vector3(p.x, Terrain.WATER_Y + 0.06, p.y)))
	_multimesh(blade, blades)
	_multimesh(cattail, tails)
	_multimesh(pad, pads)
	_multimesh(flower, flowers)


func _multimesh(mesh: Mesh, xforms: Array[Transform3D]) -> void:
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
