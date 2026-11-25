extends Node
## Настройки (автозагрузка Settings): графика, звук по шинам, мышь, клавиши.
## Хранятся в user://settings.cfg. Громкость «Общая» и полный экран — по-прежнему в профиле (Saves).

signal changed

const PATH := "user://settings.cfg"
const QUALITY_NAMES := ["Низкое", "Среднее", "Высокое", "Ультра"]

var quality := 2           ## 0..3
var render_scale := 1.0    ## 0.5..1.0 (FSR при < 1)
var fov := 75.0
var vsync := true
var max_fps := 0           ## 0 — без ограничения
var grass := 1.0           ## густота травы 0..1.5 (применяется при входе в мир)
var mouse_sens := 1.0
var invert_y := false
var vol := {"Effects": 0.9, "Ambient": 0.8, "Music": 0.7, "Voices": 0.9}
var head_bob := true
## Голоса NPC: 0 — речь (синтез речи системы), 1 — бормотание, 2 — только текст.
var voice_mode := 0


func _ready() -> void:
	_load()
	apply_audio.call_deferred()
	apply_display.call_deferred()


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	quality = clampi(int(cfg.get_value("gfx", "quality", quality)), 0, 3)
	render_scale = float(cfg.get_value("gfx", "render_scale", render_scale))
	fov = float(cfg.get_value("gfx", "fov", fov))
	vsync = bool(cfg.get_value("gfx", "vsync", vsync))
	max_fps = int(cfg.get_value("gfx", "max_fps", max_fps))
	grass = float(cfg.get_value("gfx", "grass", grass))
	mouse_sens = float(cfg.get_value("input", "mouse_sens", mouse_sens))
	invert_y = bool(cfg.get_value("input", "invert_y", invert_y))
	head_bob = bool(cfg.get_value("input", "head_bob", head_bob))
	voice_mode = int(cfg.get_value("audio", "voice_mode", voice_mode))
	for b in vol:
		vol[b] = float(cfg.get_value("audio", b, vol[b]))
	var keys: Dictionary = cfg.get_value("input", "keys", {})
	Controls.apply_bindings(keys)


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("gfx", "quality", quality)
	cfg.set_value("gfx", "render_scale", render_scale)
	cfg.set_value("gfx", "fov", fov)
	cfg.set_value("gfx", "vsync", vsync)
	cfg.set_value("gfx", "max_fps", max_fps)
	cfg.set_value("gfx", "grass", grass)
	cfg.set_value("input", "mouse_sens", mouse_sens)
	cfg.set_value("input", "invert_y", invert_y)
	cfg.set_value("input", "head_bob", head_bob)
	cfg.set_value("audio", "voice_mode", voice_mode)
	cfg.set_value("input", "keys", Controls.export_bindings())
	for b in vol:
		cfg.set_value("audio", b, vol[b])
	cfg.save(PATH)


func apply_audio() -> void:
	for b in vol:
		Sfx.set_bus_volume(b, vol[b])


func apply_display() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = max_fps
	var vp := get_viewport()
	vp.scaling_3d_scale = render_scale
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if render_scale < 0.99 else Viewport.SCALING_3D_MODE_BILINEAR
	vp.msaa_3d = Viewport.MSAA_2X if quality >= 3 else Viewport.MSAA_DISABLED
	if RenderingServer.get_current_rendering_method() != "gl_compatibility":
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if quality >= 1 else Viewport.SCREEN_SPACE_AA_DISABLED
	apply_world()
	changed.emit()


## Окружение мира: тени, SSAO/SSIL, свечение, туман — по качеству.
func apply_world() -> void:
	var world := get_tree().root.get_node_or_null("World")
	if world == null:
		return
	var we := world.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we and we.environment:
		var e := we.environment
		var forward_plus := RenderingServer.get_current_rendering_method() == "forward_plus"
		e.ssao_enabled = forward_plus and quality >= 2
		e.ssil_enabled = forward_plus and quality >= 3
		e.glow_enabled = quality >= 1
		e.sdfgi_enabled = false
	for n in ["Sun", "Moon"]:
		var l := world.get_node_or_null(n) as DirectionalLight3D
		if l:
			l.shadow_enabled = quality >= 1
			l.directional_shadow_max_distance = [40.0, 55.0, 70.0, 100.0][quality] * (0.7 if n == "Moon" else 1.0)
			l.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if quality == 0 else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	RenderingServer.directional_shadow_atlas_set_size([1024, 2048, 4096, 4096][quality], true)
	var vp := get_viewport()
	vp.positional_shadow_atlas_size = [1024, 2048, 4096, 4096][quality]
	# Лампы/фонари: тени только на высоком.
	for l in get_tree().get_nodes_in_group("lamp_lights"):
		(l as Light3D).shadow_enabled = quality >= 3


func set_volume(bus: String, v: float) -> void:
	vol[bus] = v
	Sfx.set_bus_volume(bus, v)
