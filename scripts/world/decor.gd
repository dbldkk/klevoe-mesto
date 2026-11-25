extends Node3D
## Деревья, кусты, камни. Генератор с фиксированным seed — у всех игроков одинаково.

@export var tree_count: int = 250
@export var bush_count: int = 170
@export var rock_count: int = 50
@export var seed_value: int = 1337

var _keep_clear: Array = [
	[Vector2(-13, 5.4), 6.5],  # рынок
	[Vector2(0, -5), 4.0],     # начало пирса
	[Vector2(0, 5), 3.0],      # тропинка к пирсу
]


var _bush_mats: Array[StandardMaterial3D] = []


func _ready() -> void:
	add_to_group("decor")
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var bark := Art.tex("bark", 1.0)
	var leaves := Art.tex("leaves", 1.5)
	var birch_bark := _birch_mat()
	var trunk_shape := CylinderShape3D.new()
	trunk_shape.radius = 0.25
	trunk_shape.height = 3.0

	var placed := 0
	var attempts := 0
	while placed < tree_count and attempts < 4000:
		attempts += 1
		var p := Vector2(rng.randf_range(-105, 105), rng.randf_range(-210, 96))
		if not _is_free(p, 4.0):
			continue
		var tree := StaticBody3D.new()
		tree.collision_layer = 1
		tree.collision_mask = 0
		tree.position = Vector3(p.x, Terrain.height(p.x, p.y) - 0.05, p.y)
		tree.rotation.y = rng.randf() * TAU
		var s := rng.randf_range(0.85, 1.5)
		tree.scale = Vector3.ONE * s
		if rng.randf() < 0.65:
			_pine(tree, bark, leaves, rng)
		else:
			_birch(tree, birch_bark, leaves, rng)
		var col := CollisionShape3D.new()
		col.shape = trunk_shape
		col.position.y = 1.5
		tree.add_child(col)
		add_child(tree)
		placed += 1

	# Кусты — гуще у берега (4 оттенка листвы: меньше материалов — меньше вызовов отрисовки)
	for tint in [Color(0.85, 0.95, 0.85), Color(1.0, 1.1, 0.9), Color(0.9, 1.05, 0.95), Color(1.05, 1.0, 0.85)]:
		var bm := leaves.duplicate() as StandardMaterial3D
		bm.albedo_color = tint
		_bush_mats.append(bm)
	placed = 0
	attempts = 0
	while placed < bush_count and attempts < 4000:
		attempts += 1
		var p := Vector2(rng.randf_range(-100, 100), rng.randf_range(-205, 85))
		var d := Terrain.lake_distance(p.x, p.y).x
		if d < 1.5 or not _is_free(p, 2.0):
			continue
		if d > 12.0 and rng.randf() < 0.6:
			continue
		var bush := Node3D.new()
		bush.position = Vector3(p.x, Terrain.height(p.x, p.y), p.y)
		var m: StandardMaterial3D = _bush_mats[rng.randi() % _bush_mats.size()]
		for k in rng.randi_range(3, 5):
			var r := rng.randf_range(0.35, 0.7)
			Art.add_mesh(bush, Art.sphere(r, 10), m,
				Vector3(rng.randf_range(-0.5, 0.5), r * 0.7, rng.randf_range(-0.5, 0.5)), Vector3.ZERO,
				Vector3(1, rng.randf_range(0.7, 1.0), 1))
		add_child(bush)
		placed += 1

	# Камни
	var stone := Art.tex_world("asphalt", 0.6)
	for i in rock_count:
		var p := Vector2(rng.randf_range(-100, 100), rng.randf_range(-205, 85))
		var d := Terrain.lake_distance(p.x, p.y).x
		if not _is_free(p, 1.0) or d < -1.0:
			continue
		var r := rng.randf_range(0.2, 0.7)
		var rock := Art.add_mesh(self, Art.sphere(r, 7), stone,
			Vector3(p.x, Terrain.height(p.x, p.y) + r * 0.2, p.y),
			Vector3(rng.randf(), rng.randf() * TAU, rng.randf()), Vector3(1.3, 0.7, 1.0))
		rock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# На всякий случай вычищаем участок опорного: куст не должен торчать в камере.
	_strip_spot("police", 10.0)
	call_deferred("_strip_station_aabb")


func _pine(tree: Node3D, bark: Material, leaves: Material, rng: RandomNumberGenerator) -> void:
	Art.add_mesh(tree, Art.cyl(0.13, 0.22, 2.0, 8), bark, Vector3(0, 1.0, 0))
	for i in 4:
		Art.add_mesh(tree, Art.cyl(0.0, 1.7 - i * 0.35, 1.5, 9), leaves,
			Vector3(0, 1.8 + i * 0.85, 0), Vector3(0, rng.randf() * TAU, 0))


func _birch(tree: Node3D, bark: Material, leaves: Material, rng: RandomNumberGenerator) -> void:
	Art.add_mesh(tree, Art.cyl(0.09, 0.15, 3.6, 8), bark, Vector3(0, 1.8, 0))
	var m := leaves.duplicate() as StandardMaterial3D
	m.albedo_color = Color(1.25, 1.35, 0.9)
	for k in 5:
		var r := rng.randf_range(0.7, 1.1)
		Art.add_mesh(tree, Art.sphere(r, 10), m,
			Vector3(rng.randf_range(-0.6, 0.6), 3.4 + rng.randf_range(-0.3, 0.8), rng.randf_range(-0.6, 0.6)))


func _birch_mat() -> StandardMaterial3D:
	var img := Image.create(16, 64, false, Image.FORMAT_RGB8)
	var r := RandomNumberGenerator.new()
	r.seed = 9
	for y in 64:
		var dark := r.randf() < 0.12
		for x in 16:
			var c := Color(0.92, 0.92, 0.88) if not dark or x > r.randi_range(6, 14) else Color(0.12, 0.12, 0.1)
			img.set_pixel(x, y, c)
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.roughness = 0.8
	return m


func _is_free(p: Vector2, lake_margin: float) -> bool:
	if Terrain.lake_distance(p.x, p.y).x < lake_margin:
		return false
	if Vector2(p.x - Terrain.ISLAND.x, p.y - Terrain.ISLAND.y).length() < 8.0:
		return false
	if absf(p.x) < 3.0 and p.y > -7.0 and p.y < 20.0:   # тропинка к пирсу
		return false
	if Layout.is_busy(p.x, p.y, 3.5):   # дорога и постройки
		return false
	if Layout.spot_contains("police", p.x, p.y, 8.0):
		return false
	for zone in _keep_clear:
		if p.distance_to(zone[0]) < zone[1]:
			return false
	return true


func _strip_spot(spot: String, pad: float) -> void:
	for c in get_children():
		if c is Node3D and Layout.spot_contains(spot, c.global_position.x, c.global_position.z, pad):
			c.queue_free()

func _strip_station_aabb() -> void:
	var st := get_tree().get_first_node_in_group("police_station") as Node3D
	if st == null:
		return
	for c in get_children():
		if not (c is Node3D):
			continue
		var l: Vector3 = st.to_local((c as Node3D).global_position)
		if absf(l.x) < 8.0 and absf(l.z) < 8.0:
			c.queue_free()
