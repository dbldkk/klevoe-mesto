class_name Art
## Материалы и текстуры (с кешем, чтобы не плодить копии).

static var _cache: Dictionary = {}


## Материал с текстурой из res://art/textures/<name>.png
static func tex(name: String, uv_scale: float = 1.0, roughness: float = 0.9) -> StandardMaterial3D:
	var key := "t:%s:%s" % [name, uv_scale]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://art/textures/%s.png" % name)
	m.uv1_scale = Vector3(uv_scale, uv_scale, uv_scale)
	m.albedo_color = Color(0.93, 0.92, 0.9)
	m.roughness = clampf(roughness + 0.06, 0.0, 1.0)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_cache[key] = m
	return m


## Материал с текстурой, натянутой по мировым координатам (для стен, полов разного размера).
static func tex_world(name: String, scale: float = 0.5, roughness: float = 0.9) -> StandardMaterial3D:
	var key := "w:%s:%s" % [name, scale]
	if _cache.has(key):
		return _cache[key]
	var m := tex(name, 1.0, roughness).duplicate() as StandardMaterial3D
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(scale, scale, scale)
	_cache[key] = m
	return m


## Однотонный материал.
static func color(c: Color, roughness: float = 0.8, metallic: float = 0.0) -> StandardMaterial3D:
	var key := "c:%s:%s:%s" % [c.to_html(), roughness, metallic]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.from_hsv(c.h, clampf(c.s * 0.86, 0.0, 1.0), clampf(c.v * 0.97, 0.0, 1.0), c.a)
	m.roughness = clampf(roughness + 0.04, 0.0, 1.0)
	m.metallic = metallic
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cache[key] = m
	return m


## Стекло бутылки.
static func glass(c: Color) -> StandardMaterial3D:
	var key := "g:%s" % c.to_html()
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c.r, c.g, c.b, 0.82)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.08
	m.metallic = 0.2
	m.metallic_specular = 0.9
	_cache[key] = m
	return m


## Этикетка из res://art/labels/<name>.png
static func label(name: String) -> StandardMaterial3D:
	var key := "l:" + name
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	var t = load("res://art/labels/%s.png" % name) if ResourceLoader.exists("res://art/labels/%s.png" % name) else null
	if t:
		m.albedo_texture = t
	else:
		m.albedo_color = Color(0.9, 0.85, 0.7)
	m.roughness = 0.6
	_cache[key] = m
	return m


## Лицо (прозрачная картинка поверх головы).
static func face(name: String) -> StandardMaterial3D:
	var key := "f:" + name
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://art/faces/%s.png" % name)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.4
	m.roughness = 0.9
	_cache[key] = m
	return m


static func vertex_color_mat() -> StandardMaterial3D:
	var key := "vc"
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.45
	m.metallic = 0.15
	_cache[key] = m
	return m


static func ui_icon(name: String) -> Texture2D:
	return load("res://art/ui/%s.png" % name)


## Быстро добавить MeshInstance3D.
static func add_mesh(parent: Node3D, mesh: Mesh, mat: Material, pos := Vector3.ZERO, rot := Vector3.ZERO,
		scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi


static func box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func cyl(top: float, bottom: float, height: float, seg: int = 12) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = height
	c.radial_segments = seg
	c.rings = 1
	return c


static func sphere(r: float, seg: int = 12) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = seg
	s.rings = seg / 2
	return s


static func capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 10
	c.rings = 3
	return c
