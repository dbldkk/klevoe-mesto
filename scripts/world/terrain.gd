class_name Terrain
extends StaticBody3D
## Рельеф: холмы, озеро с заливом и островом. Высота считается одной функцией,
## поэтому у всех игроков мир одинаковый. ShoreMovement помогает выйти на берег
## по всему контуру, сохраняя столкновения с рельефом и постройками.

## Границы мира (v0.8 — мир вытянут на север: протока и Дальний плёс).
const X0 := -110
const X1 := 110
const Z0 := -215
const Z1 := 100
const HALF := 100   ## старое значение, для совместимости
const WATER_Y := -0.4
const LAKE_C := Vector2(0.0, -31.0)
const LAKE_SX := 1.35
## Во сколько раз озеро больше исходной формы (v0.6 — увеличено).
const LAKE_SCALE := 1.3
const ISLAND := Vector2(9.1, -36.2)
## Дальний плёс — большое глубокое озеро за дорогой, соединено протокой.
const FAR_C := Vector2(-6.0, -152.0)
const FAR_SX := 1.45
const FAR_ISLANDS := [Vector3(16.0, -156.0, 7.0), Vector3(-38.0, -146.0, 4.5)]
const RIVER := [Vector2(-2.6, -44.0), Vector2(-2.6, -80.0), Vector2(-9.0, -99.0), Vector2(-8.0, -122.0)]
const RIVER_W := 5.4
## Мост: центр (там, где дорога пересекает протоку), длина по дороге, высота настила.
const BRIDGE := Vector3(-2.6, 1.45, -70.0)
const BRIDGE_LEN := 14.0

const SHADER := """
shader_type spatial;
uniform sampler2D grass_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D sand_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float water_y = -0.4;
varying vec3 wpos;
varying vec3 wnorm;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	vec2 uv = wpos.xz * 0.22;
	vec3 grass = texture(grass_tex, uv).rgb;
	vec3 grass2 = texture(grass_tex, uv * 0.23 + vec2(0.37, 0.11)).rgb;
	grass = mix(grass, grass2 * vec3(1.05, 1.0, 0.85), 0.35);
	vec3 sand = texture(sand_tex, uv * 0.8).rgb;
	vec3 dirt = texture(dirt_tex, uv * 0.6).rgb;
	float h = wpos.y - water_y;
	float slope = 1.0 - clamp(wnorm.y, 0.0, 1.0);
	float sand_k = 1.0 - smoothstep(0.08, 0.34, h);
	vec3 c = mix(grass, sand, sand_k);
	c = mix(c, dirt, smoothstep(0.25, 0.55, slope) * 0.85);
	c = mix(c, dirt * 0.7, 1.0 - smoothstep(-1.2, -0.2, h));
	ALBEDO = c * vec3(0.82, 0.86, 0.8);
	ROUGHNESS = 0.95;
}
"""


static func smooth(a: float, b: float, x: float) -> float:
	var t := clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## Расстояние до берега (меньше 0 — внутри воды) и угол. Вода = старое озеро + протока + Дальний плёс.
static func lake_distance(x: float, z: float) -> Vector2:
	var a := _near_lake(x, z)
	var r := _river_distance(x, z)
	var f := _far_distance(x, z)
	var d := _smin(_smin(a.x, r, 3.0), f.x, 3.0)
	var th: float = a.y if a.x < f.x else f.y
	return Vector2(d, th)


## Только ближнее (старое) озеро.
static func _near_lake(x: float, z: float) -> Vector2:
	# Форма задана в «исходном» масштабе — растягиваем от центра озера.
	x = LAKE_C.x + (x - LAKE_C.x) / LAKE_SCALE
	z = LAKE_C.y + (z - LAKE_C.y) / LAKE_SCALE
	var r0 := _lake_distance_raw(x, z)
	return Vector2(r0.x * LAKE_SCALE, r0.y)


static func _smin(a: float, b: float, k: float) -> float:
	var h := clampf(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
	return b * (1.0 - h) + a * h - k * h * (1.0 - h)


static func _river_distance(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var best := 1e9
	for i in RIVER.size() - 1:
		var a: Vector2 = RIVER[i]
		var b: Vector2 = RIVER[i + 1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best - (RIVER_W + 0.6 * sin(z * 0.21) + 0.4 * sin(z * 0.53 + 1.0))


static func _far_distance(x: float, z: float) -> Vector2:
	var dx := (x - FAR_C.x) / FAR_SX
	var dz := z - FAR_C.y
	var th := atan2(dz, dx)
	var r := 40.0 + 4.0 * sin(2.0 * th + 1.0) + 3.0 * sin(3.0 * th + 0.4) + 1.6 * sin(5.0 * th + 2.0)
	var d := sqrt(dx * dx + dz * dz) - r
	# Северо-восточный залив «Сомовья яма»
	var bx := (x - 36.0) / 1.3
	var bz := z + 182.0
	d = _smin(d, sqrt(bx * bx + bz * bz) - 12.0, 6.0)
	return Vector2(d * 1.2, th)


## На Дальнем плёсе (а не в ближнем озере / протоке).
static func is_far(x: float, z: float) -> bool:
	return _far_distance(x, z).x < 2.0


## Точка на мосту (по ней едет транспорт, хотя под ней вода).
static func on_bridge(x: float, z: float) -> bool:
	return absf(x - BRIDGE.x) < BRIDGE_LEN / 2 + 0.5 and absf(z - BRIDGE.z) < Layout.ROAD_W / 2 + 0.3


static func _lake_distance_raw(x: float, z: float) -> Vector2:
	var dx := (x - LAKE_C.x) / LAKE_SX
	var dz := z - LAKE_C.y
	var th := atan2(dz, dx)
	var dist := sqrt(dx * dx + dz * dz)
	var r := 19.0 + 2.6 * sin(2.0 * th + 0.5) + 2.0 * sin(3.0 * th + 1.7) + 1.2 * sin(5.0 * th + 0.3)
	var d1 := dist - r
	# Залив на запад
	var bx := (x + 27.0) / 1.6
	var bz := z + 21.0
	var d2 := sqrt(bx * bx + bz * bz) - (7.0 + 1.2 * sin(atan2(bz, bx) * 3.0))
	var k := 4.0
	var hh := clampf(0.5 + 0.5 * (d2 - d1) / k, 0.0, 1.0)
	var d := d2 * (1.0 - hh) + d1 * hh - k * hh * (1.0 - hh)
	return Vector2(d, th)


static func height(x: float, z: float) -> float:
	var ld := lake_distance(x, z)
	var d := ld.x
	var th := ld.y
	var w := 2.2 + 4.5 * (0.5 + 0.5 * sin(th * 2.0 + 2.2))
	var h: float
	if d < 0.0:
		h = -3.4 * smooth(0.0, w, -d) - 1.6 * smooth(w, w + 9.0, -d)
		if z < -100.0:
			h -= 3.4 * smooth(10.0, 30.0, -d)   # плёс глубже (до 8 м)
	else:
		var hills := (0.55 * sin(x * 0.07) * cos(z * 0.06) + 0.3 * sin(x * 0.13 + z * 0.11)
			+ 0.2 * cos(x * 0.21 - z * 0.17) + 1.05) * 0.6
		h = hills * smooth(2.0, 12.0, d) + 0.18 * exp(-pow(d / 2.5, 2.0))
	# Остров
	var di := Vector2(x - ISLAND.x, z - ISLAND.y).length() / LAKE_SCALE
	if di < 5.5:
		h = maxf(h, 0.5 - 0.75 * pow(maxf(di - 2.5, 0.0), 1.25))
	for isl in FAR_ISLANDS:
		var dfi := Vector2(x - isl.x, z - isl.y).length()
		if dfi < isl.z + 4.0:
			h = maxf(h, 0.7 - 0.6 * pow(maxf(dfi - isl.z * 0.55, 0.0), 1.2))
	# Ровные площадки: рынок у пирса, дорога и постройки посёлка (Layout)
	var flat := _rect(x, z, -13, 5.4, 4.5, 3.5)
	if h > 0.0:
		flat = maxf(flat, Layout.flat_factor(x, z))
	h *= 1.0 - flat
	# Насыпь к мосту через протоку
	var bdx := absf(x - BRIDGE.x)
	var bdz := absf(z - BRIDGE.z)
	if bdx < 18.0 and bdz < 9.0 and d > 0.2:
		var e := BRIDGE.y * (1.0 - smooth(BRIDGE_LEN / 2 + 0.6, BRIDGE_LEN / 2 + 9.0, bdx)) * (1.0 - smooth(Layout.ROAD_W / 2 + 0.6, Layout.ROAD_W / 2 + 4.0, bdz))
		h = maxf(h, e - 0.02)
	return h


static func _rect(x: float, z: float, cx: float, cz: float, hx: float, hz: float, m: float = 4.0) -> float:
	var dd := maxf(absf(x - cx) - hx, absf(z - cz) - hz)
	return 1.0 - smooth(0.0, m, dd)


static func is_water(x: float, z: float) -> bool:
	return height(x, z) < WATER_Y - 0.05


static func depth(x: float, z: float) -> float:
	return maxf(WATER_Y - height(x, z), 0.0)


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	_build_collision()
	_build_mesh()


var _hs := PackedFloat32Array()


func _build_collision() -> void:
	var nx := X1 - X0 + 1
	var nz := Z1 - Z0 + 1
	_hs.resize(nx * nz)
	for iz in nz:
		for ix in nx:
			_hs[iz * nx + ix] = height(X0 + ix, Z0 + iz)
	var shape := HeightMapShape3D.new()
	shape.map_width = nx
	shape.map_depth = nz
	shape.map_data = _hs
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3((X0 + X1) / 2.0, 0, (Z0 + Z1) / 2.0)
	add_child(col)


func _build_mesh() -> void:
	var n := X1 - X0 + 1
	var nz := Z1 - Z0 + 1
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz in nz:
		for ix in n:
			var x := float(X0 + ix)
			var z := float(Z0 + iz)
			st.set_uv(Vector2(x, z) * 0.2)
			st.add_vertex(Vector3(x, _hs[iz * n + ix], z))
	for iz in nz - 1:
		for ix in n - 1:
			var i := iz * n + ix
			st.add_index(i)
			st.add_index(i + 1)
			st.add_index(i + n)
			st.add_index(i + 1)
			st.add_index(i + n + 1)
			st.add_index(i + n)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var sh := Shader.new()
	sh.code = SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("grass_tex", load("res://art/textures/grass.png"))
	mat.set_shader_parameter("sand_tex", load("res://art/textures/sand.png"))
	mat.set_shader_parameter("dirt_tex", load("res://art/textures/dirt.png"))
	mat.set_shader_parameter("water_y", WATER_Y)
	mi.material_override = mat
	add_child(mi)
