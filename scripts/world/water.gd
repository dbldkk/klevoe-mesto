extends MeshInstance3D
## Поверхность озера: рябь, глубина (у берега светлее, в центре темнее), пена у кромки.

const SHADER := """
shader_type spatial;
render_mode cull_disabled, depth_draw_always;
uniform vec3 deep_color : source_color = vec3(0.04, 0.16, 0.22);
uniform vec3 shallow_color : source_color = vec3(0.2, 0.42, 0.42);
uniform sampler2D n1 : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D n2 : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear;
varying vec3 wpos;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(wpos.x * 0.6 + TIME * 1.2) * 0.025 + cos(wpos.z * 0.45 + TIME * 0.9) * 0.025;
}
void fragment() {
	vec2 uv = wpos.xz * 0.07;
	vec3 a = texture(n1, uv + TIME * vec2(0.018, 0.011)).rgb;
	vec3 b = texture(n2, uv * 1.9 - TIME * vec2(0.015, 0.022)).rgb;
	NORMAL_MAP = normalize(mix(a, b, 0.5));
	NORMAL_MAP_DEPTH = 0.18;
	float d = texture(depth_tex, SCREEN_UV).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, d * 2.0 - 1.0, 1.0);
#else
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
#endif
	vec4 view = INV_PROJECTION_MATRIX * ndc;
	view.xyz /= view.w;
	float wd = clamp(VERTEX.z - view.z, 0.0, 20.0);
	float t = clamp(wd / 3.0, 0.0, 1.0);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 col = mix(shallow_color, deep_color, t);
	float foam = 1.0 - smoothstep(0.0, 0.3, wd);
	foam *= 0.6 + 0.4 * sin(wpos.x * 3.0 + wpos.z * 2.0 + TIME * 2.0);
	col = mix(col, vec3(0.9, 0.95, 0.95), clamp(foam, 0.0, 1.0) * 0.7);
	ALBEDO = col * (1.0 - fres * 0.25) + vec3(0.02, 0.05, 0.08) * fres;
	ALPHA = clamp(0.62 + t * 0.36 + foam * 0.3 + fres * 0.2, 0.0, 0.96);
	ROUGHNESS = 0.18;
	SPECULAR = 0.12;
}
"""


func _ready() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(140, 200)
	plane.subdivide_width = 140
	plane.subdivide_depth = 200
	mesh = plane
	position = Vector3(-4, Terrain.WATER_Y, -102)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sh := Shader.new()
	sh.code = SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("n1", _normal_tex(0.02, 11))
	m.set_shader_parameter("n2", _normal_tex(0.045, 29))
	material_override = m


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
	t.bump_strength = 1.2
	t.noise = noise
	return t
