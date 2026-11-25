extends Node3D
## Трава: пучки из скрещённых полосок, MultiMesh по чанкам 16×16 м, шевелится от ветра.
## Дальние чанки не рисуются (visibility range). Не растёт в воде, на дороге и у построек.

@export var per_chunk: int = 1600
@export var view_distance: float = 42.0
@export var seed_value: int = 77

const CHUNK := 16.0
const AREA := 92.0
const AREA_Z0 := -204.0   ## на севере — до Дальнего плёса

const SHADER := """
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;
uniform vec3 base_color : source_color = vec3(0.2, 0.33, 0.1);
uniform vec3 tip_color : source_color = vec3(0.52, 0.66, 0.26);
uniform float wind = 0.12;
varying float h;
void vertex() {
	h = UV.y;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float s = sin(TIME * 1.7 + wp.x * 0.35 + wp.z * 0.27) + 0.5 * sin(TIME * 3.1 + wp.x * 0.9);
	VERTEX.x += s * wind * h * h;
	VERTEX.z += s * wind * 0.6 * h * h;
	NORMAL = vec3(0.0, 1.0, 0.0);
}
void fragment() {
	if (!FRONT_FACING) { NORMAL = -NORMAL; }
	vec3 c = mix(base_color, tip_color, h) * COLOR.rgb;
	ALBEDO = c;
	ROUGHNESS = 0.95;
}
"""


func _ready() -> void:
	per_chunk = int(per_chunk * Settings.grass)
	view_distance *= [0.6, 0.85, 1.0, 1.4][Settings.quality]
	if per_chunk <= 10:
		return
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER
	mat.shader = sh
	var mesh := _blade_mesh()
	mesh.surface_set_material(0, mat)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var cx := -AREA
	while cx < AREA:
		var cz := AREA_Z0
		while cz < AREA:
			_chunk(Vector2(cx, cz), mesh, rng)
			cz += CHUNK
		cx += CHUNK


func _blade_mesh() -> ArrayMesh:
	## Пучок из 5 тонких острых травинок, немного наклонённых в разные стороны.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := RandomNumberGenerator.new()
	r.seed = 5
	for k in 5:
		var a := r.randf() * TAU
		var side := Vector3(cos(a), 0, sin(a)) * 0.025
		var base := Vector3(r.randf_range(-0.08, 0.08), 0, r.randf_range(-0.08, 0.08))
		var h := r.randf_range(0.22, 0.38)
		var lean := Vector3(-sin(a), 0, cos(a)) * r.randf_range(0.03, 0.1)
		var v := [base - side, base + side, base + lean + Vector3(0, h, 0)]
		var uv := [Vector2(0, 0), Vector2(1, 0), Vector2(0.5, 1)]
		for i in 3:
			st.set_uv(uv[i])
			st.set_normal(Vector3.UP)
			st.add_vertex(v[i])
	return st.commit()


func _ok(x: float, z: float) -> bool:
	var ld := Terrain.lake_distance(x, z).x
	if ld < 0.6:
		return false
	if Layout.is_busy(x, z, 0.4):
		return false
	if absf(x + 13.0) < 5.0 and absf(z - 5.4) < 4.0:   # рынок
		return false
	if absf(x) < 1.0 and z < 19.0 and z > -6.0:        # тропинка к пирсу
		return false
	return true


func _chunk(origin: Vector2, mesh: Mesh, rng: RandomNumberGenerator) -> void:
	var xforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for i in per_chunk:
		var x := origin.x + rng.randf() * CHUNK
		var z := origin.y + rng.randf() * CHUNK
		if not _ok(x, z):
			continue
		var y := Terrain.height(x, z)
		var s := rng.randf_range(0.7, 1.25)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.3), s))
		xforms.append(Transform3D(b, Vector3(x - origin.x - CHUNK / 2, y - 0.02, z - origin.y - CHUNK / 2)))
		var tint := rng.randf_range(0.8, 1.15)
		colors.append(Color(tint, tint * rng.randf_range(0.95, 1.08), tint * 0.9))
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_color(i, colors[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.position = Vector3(origin.x + CHUNK / 2, 0, origin.y + CHUNK / 2)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = view_distance
	mmi.visibility_range_end_margin = 6.0
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(mmi)
