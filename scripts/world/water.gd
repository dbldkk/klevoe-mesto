extends MeshInstance3D
## Поверхность озера: более заметная рябь, пена у берега, fresnel под цвет неба,
## затемнение и туман, когда камера под водой. Работает в Forward+ и Compatibility.

const SHADER := """
shader_type spatial;
render_mode cull_disabled, depth_draw_always;
uniform vec3 deep_color : source_color = vec3(0.03, 0.14, 0.20);
uniform vec3 shallow_color : source_color = vec3(0.22, 0.48, 0.46);
uniform vec3 foam_color : source_color = vec3(0.92, 0.96, 0.97);
uniform vec3 sky_color : source_color = vec3(0.45, 0.62, 0.85);
uniform vec3 horizon_color : source_color = vec3(0.75, 0.84, 0.92);
uniform sampler2D n1 : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D n2 : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear;
uniform float wave_amp = 0.07;
varying vec3 wpos;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(wpos.x * 0.55 + TIME * 1.15) * wave_amp
		+ cos(wpos.z * 0.4 + TIME * 0.85) * wave_amp
		+ sin((wpos.x + wpos.z) * 1.1 + TIME * 1.7) * wave_amp * 0.35;
}
void fragment() {
	vec2 uv = wpos.xz * 0.065;
	vec3 a = texture(n1, uv + TIME * vec2(0.02, 0.013)).rgb;
	vec3 b = texture(n2, uv * 1.8 - TIME * vec2(0.016, 0.024)).rgb;
	NORMAL_MAP = normalize(mix(a, b, 0.5));
	NORMAL_MAP_DEPTH = 0.32;
	float d = texture(depth_tex, SCREEN_UV).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, d * 2.0 - 1.0, 1.0);
#else
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
#endif
	vec4 view = INV_PROJECTION_MATRIX * ndc;
	view.xyz /= view.w;
	float wd = clamp(VERTEX.z - view.z, 0.0, 24.0);
	float t = clamp(wd / 2.6, 0.0, 1.0);
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fres = pow(1.0 - ndv, 2.4);
	vec3 col = mix(shallow_color, deep_color, t);
	float foam = 1.0 - smoothstep(0.0, 0.55, wd);
	foam *= 0.55 + 0.45 * sin(wpos.x * 4.2 + wpos.z * 3.1 + TIME * 2.4);
	col = mix(col, foam_color, clamp(foam, 0.0, 1.0) * 0.85);
	vec3 sky = mix(horizon_color, sky_color, clamp(NORMAL.y * 0.5 + 0.5, 0.0, 1.0));
	col = mix(col, sky, fres * 0.55);
	ALBEDO = col;
	ALPHA = clamp(0.58 + t * 0.38 + foam * 0.25 + fres * 0.22, 0.0, 0.97);
	ROUGHNESS = 0.12 + t * 0.08;
	SPECULAR = 0.35;
	METALLIC = 0.05;
}
"""

var _mat: ShaderMaterial
var _under: CanvasLayer
var _tint: ColorRect
var _under_on := false
var _saved_fog := 0.0015


func _ready() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(140, 200)
	plane.subdivide_width = [35, 35, 70, 140][Settings.quality]
	plane.subdivide_depth = [50, 50, 100, 200][Settings.quality]
	mesh = plane
	position = Vector3(-4, Terrain.WATER_Y, -102)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sh := Shader.new()
	sh.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_mat.set_shader_parameter("n1", _normal_tex(0.02, 11))
	_mat.set_shader_parameter("n2", _normal_tex(0.045, 29))
	material_override = _mat
	_under = CanvasLayer.new()
	_under.layer = 8
	_tint = ColorRect.new()
	_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tint.color = Color(0.02, 0.12, 0.18, 0.55)
	_tint.visible = false
	_under.add_child(_tint)
	add_child(_under)
	process_priority = 20


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	var under := cam != null and cam.global_position.y < Terrain.WATER_Y - 0.04
	_tint.visible = under
	var dc := get_tree().get_first_node_in_group("day_cycle") as DayCycle
	if dc and dc.env:
		if under:
			if not _under_on:
				_saved_fog = dc.env.fog_density
			dc.env.fog_density = 0.08
			dc.env.fog_light_color = Color(0.05, 0.2, 0.28)
		elif _under_on:
			dc.env.fog_density = _saved_fog
	_under_on = under
	if _mat:
		if dc and dc.env and dc.env.sky and dc.env.sky.sky_material:
			var sm = dc.env.sky.sky_material
			if sm is ProceduralSkyMaterial:
				var psm := sm as ProceduralSkyMaterial
				_mat.set_shader_parameter("sky_color", Vector3(psm.sky_top_color.r, psm.sky_top_color.g, psm.sky_top_color.b))
				_mat.set_shader_parameter("horizon_color", Vector3(psm.sky_horizon_color.r, psm.sky_horizon_color.g, psm.sky_horizon_color.b))
		elif dc and dc.has_method("darkness"):
			var night := clampf(dc.darkness(), 0.0, 1.0)
			_mat.set_shader_parameter("sky_color", Vector3(0.45, 0.62, 0.85).lerp(Vector3(0.04, 0.06, 0.12), night))
			_mat.set_shader_parameter("horizon_color", Vector3(0.75, 0.84, 0.92).lerp(Vector3(0.08, 0.1, 0.16), night))


func _normal_tex(freq: float, seed_value: int) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.frequency = freq
	noise.seed = seed_value
	noise.fractal_octaves = 3
	var t := NoiseTexture2D.new()
	t.width = 256
	t.height = 256
	t.seamless = true
	t.as_normal_map = true
	t.bump_strength = 1.6
	t.noise = noise
	return t
