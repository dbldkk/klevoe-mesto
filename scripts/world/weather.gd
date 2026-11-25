class_name Weather
extends Node
## Погода: ясно / облачно / дождь / гроза / туман. Решает хост, всем приходит через Sync.
## Влияет на свет, небо, туман, звук и клёв (GameData.conditions — ставится перед броском рыбы).
## В грозу молния может ударить в рыбака с удочкой у воды.

enum W { CLEAR, CLOUDY, RAIN, STORM, FOG }
const NAMES := ["ясно", "облачно", "дождь", "гроза", "туман"]
const ICONS := ["☀", "☁", "☂", "⚡", "≋"]
## Куда может смениться погода (веса).
const NEXT := {
	W.CLEAR: [[W.CLEAR, 3], [W.CLOUDY, 4], [W.FOG, 1]],
	W.CLOUDY: [[W.CLEAR, 3], [W.RAIN, 3], [W.STORM, 1], [W.CLOUDY, 1]],
	W.RAIN: [[W.CLOUDY, 3], [W.RAIN, 2], [W.STORM, 1], [W.CLEAR, 1]],
	W.STORM: [[W.RAIN, 3], [W.CLOUDY, 2]],
	W.FOG: [[W.CLEAR, 3], [W.CLOUDY, 2]],
}

@export var state: int = W.CLEAR
## Что будет дальше (для «перед грозой клюёт»).
@export var next_state: int = W.CLEAR

var _k := {"cloud": 0.0, "rain": 0.0, "fog": 0.0, "dark": 0.0}
var _timer := 60.0
var _flash := 0.0
var _flash_timer := 6.0
var _rng := RandomNumberGenerator.new()
var _rain: CPUParticles3D
var _flash_light: DirectionalLight3D


func _ready() -> void:
	add_to_group("weather")
	_rng.randomize()
	_rain = CPUParticles3D.new()
	_rain.amount = 900
	_rain.lifetime = 0.9
	_rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_rain.emission_box_extents = Vector3(14, 0.5, 14)
	_rain.direction = Vector3(0.08, -1, 0.04)
	_rain.spread = 3.0
	_rain.gravity = Vector3(0, -20, 0)
	_rain.initial_velocity_min = 14.0
	_rain.initial_velocity_max = 18.0
	_rain.local_coords = false
	var drop := BoxMesh.new()
	drop.size = Vector3(0.012, 0.4, 0.012)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.75, 0.82, 0.9, 0.35)
	drop.material = m
	_rain.mesh = drop
	_rain.emitting = false
	add_child(_rain)
	_flash_light = DirectionalLight3D.new()
	_flash_light.rotation = Vector3(-1.2, 0.4, 0)
	_flash_light.light_color = Color(0.85, 0.9, 1.0)
	_flash_light.light_energy = 0.0
	_flash_light.visible = false
	add_child(_flash_light)
	Net.hosted.connect(func() -> void:
		var w := Saves.get_section("weather")
		state = int(w.get("state", W.CLEAR))
		next_state = _pick(state))
	Saves.before_save.connect(func() -> void: Saves.set_section("weather", {"state": state}))


func word() -> String:
	return NAMES[state]


func icon() -> String:
	return ICONS[state]


func _pick(from: int) -> int:
	var opts: Array = NEXT[from]
	var total := 0
	for o in opts:
		total += o[1]
	var r := _rng.randi() % total
	for o in opts:
		r -= o[1]
		if r < 0:
			return o[0]
	return W.CLEAR


func _process(delta: float) -> void:
	# В главном меню погода не меняется и дождь не шумит.
	if not Net.is_online():
		Sfx.loop("rain", false)
		if _rain:
			_rain.emitting = false
		return
	# Плавные переходы
	var want := {"cloud": 0.1, "rain": 0.0, "fog": 0.0, "dark": 0.0}
	match state:
		W.CLOUDY: want = {"cloud": 0.75, "rain": 0.0, "fog": 0.15, "dark": 0.35}
		W.RAIN: want = {"cloud": 0.95, "rain": 0.7, "fog": 0.35, "dark": 0.55}
		W.STORM: want = {"cloud": 1.0, "rain": 1.0, "fog": 0.45, "dark": 0.75}
		W.FOG: want = {"cloud": 0.5, "rain": 0.0, "fog": 1.0, "dark": 0.3}
	for k in _k:
		_k[k] = move_toward(_k[k], want[k], delta * 0.08)
	_update_rain()
	if state == W.STORM:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			_flash_timer = _rng.randf_range(5.0, 14.0)
			_lightning()
	_flash = maxf(_flash - delta * 4.0, 0.0)
	_flash_light.visible = _flash > 0.01
	_flash_light.light_energy = _flash * 2.5
	if multiplayer.is_server():
		_timer -= delta
		if _timer <= 0.0:
			_timer = _rng.randf_range(60.0, 150.0)
			state = next_state
			next_state = _pick(state)
			if state == W.STORM:
				NetUtil.call_all(self, "announce", ["Небо почернело — начинается гроза! С удочкой у воды опасно"])
			elif state == W.RAIN:
				NetUtil.call_all(self, "announce", ["Пошёл дождь"])
			elif state == W.FOG:
				NetUtil.call_all(self, "announce", ["Над озером опустился туман"])


func _update_rain() -> void:
	var cam := get_viewport().get_camera_3d()
	var on: bool = _k.rain > 0.05 and cam != null
	if on:
		var p := cam.global_position
		on = not Sfx._inside_any(p)
		_rain.global_position = p + Vector3(0, 9, 0)
	_rain.emitting = on
	Sfx.loop("rain", _k.rain > 0.05, lerpf(-30.0, -8.0, _k.rain) - (10.0 if not on else 0.0))


func _lightning() -> void:
	_flash = 1.0
	var d := _rng.randf_range(0.3, 2.0)
	get_tree().create_timer(d).timeout.connect(func() -> void: Sfx.play("thunder", null, -2.0 - d * 3.0, 0.15))
	if not multiplayer.is_server():
		return
	# Удар в рыбака с удочкой у воды (редко).
	if _rng.randf() < 0.18:
		for p in get_tree().get_nodes_in_group("players"):
			var pp := p as Node3D
			if p.held_kind == "rod" and Terrain.lake_distance(pp.global_position.x, pp.global_position.z).x < 6.0 \
					and not p.hidden and _rng.randf() < 0.5:
				NetUtil.call_peer(p, p.name.to_int(), "take_melee", [45.0, "Молния"])
				NetUtil.call_all(self, "announce", ["Молния ударила в %s! Не рыбачь в грозу" % p.player_name])
				break


@rpc("authority", "reliable")
func announce(text: String) -> void:
	Events.notify(text, Color(0.75, 0.85, 1.0))


## Вызывает DayCycle после своего освещения.
func apply(dc: DayCycle) -> void:
	var dark: float = _k.dark
	dc.sun.light_energy *= 1.0 - 0.75 * dark
	dc.env.ambient_light_energy *= 1.0 - 0.3 * dark
	dc.env.fog_density += 0.012 * _k.fog + 0.003 * _k.rain
	var grey := Vector3(0.45, 0.48, 0.52) * (1.0 - 0.8 * float(dc._sky_mat.get_shader_parameter("night")))
	for p in ["top_color", "horizon_color"]:
		var c: Vector3 = dc._sky_mat.get_shader_parameter(p)
		dc._sky_mat.set_shader_parameter(p, c.lerp(grey, dark * 0.8))
	dc._sky_mat.set_shader_parameter("cloud_amount", lerpf(0.45, 0.92, _k.cloud))
	dc.env.fog_light_color = dc.env.fog_light_color.lerp(Color(0.6, 0.63, 0.66), _k.fog * 0.6)
	if _flash > 0.0:
		dc.env.ambient_light_energy += _flash * 1.5


## Клёв от погоды и времени (на сервере перед броском).
static func update_conditions(tree: SceneTree) -> void:
	var c := {"night": 0.0, "big": 1.0, "speed": 1.0}
	var dc := tree.get_first_node_in_group("day_cycle") as DayCycle
	if dc:
		c.night = dc.darkness()
		var h := fmod(dc.minutes, 1440.0) / 60.0
		if h >= 4.5 and h < 8.0:
			c.speed *= 1.45      # утренний клёв
		elif h >= 19.0 and h < 21.5:
			c.speed *= 1.2       # вечерний
	var w := tree.get_first_node_in_group("weather") as Weather
	if w:
		match w.state:
			W.CLOUDY:
				c.speed *= 1.1
				if w.next_state == W.STORM:
					c.speed *= 1.5   # перед грозой рыба жрёт
					c.big *= 1.3
			W.RAIN:
				c.speed *= 1.3
				c.big *= 1.15
			W.STORM:
				c.speed *= 0.8
				c.big *= 1.5
			W.FOG:
				c.speed *= 1.1
	GameData.conditions = c
