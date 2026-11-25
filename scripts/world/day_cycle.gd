class_name DayCycle
extends Node
## Время суток, освещение, сон всем лобби и итоги дня.
##
## 1 игровая минута = 1 секунда. Время считает хост и рассылает всем (узел Sync).
## minutes > 1440 — это «после полуночи». В 05:00 все вырубаются от усталости.
##
## Сон: все игроки легли (дома в кровать) → хост выбирает, до скольки спать →
## каждый присылает свои итоги дня → всем показывается таблица с титулами → новый день.

signal phase_changed(phase: int)

enum Phase { AWAKE, CHOOSING, SUMMARY }

const MIN_PER_SEC := 1.0
const START_MIN := 7.0 * 60.0
const FAINT_MIN := 1440.0 + 5.0 * 60.0
const SUNRISE := 5.0 * 60.0 + 30.0
const SUNSET := 21.0 * 60.0 + 30.0

const SKY_SHADER := """
shader_type sky;
uniform vec3 top_color : source_color = vec3(0.22, 0.45, 0.85);
uniform vec3 horizon_color : source_color = vec3(0.62, 0.78, 0.95);
uniform vec3 ground_color : source_color = vec3(0.25, 0.3, 0.25);
uniform float night = 0.0;
uniform float cloud_amount = 0.45;
uniform sampler2D cloud_noise : repeat_enable, filter_linear_mipmap;
void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	vec3 col = mix(horizon_color, top_color, pow(clamp(h, 0.0, 1.0), 0.5));
	col = mix(col, ground_color, smoothstep(0.0, -0.25, h));
	if (LIGHT0_ENABLED) {
		float sd = max(dot(d, LIGHT0_DIRECTION), 0.0);
		col += LIGHT0_COLOR * LIGHT0_ENERGY * (pow(sd, 1400.0) * 30.0 + pow(sd, 10.0) * 0.18);
	}
	if (night > 0.01 && h > 0.0) {
		vec3 p = floor(d * 260.0);
		float st = fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
		col += vec3(step(0.9972, st)) * night * (0.55 + 0.45 * sin(TIME * 2.0 + st * 300.0));
	}
	if (LIGHT1_ENABLED) {
		float md = dot(d, LIGHT1_DIRECTION);
		col += vec3(0.9, 0.93, 1.0) * smoothstep(0.99962, 0.99978, md) * night * 0.75;
		col += vec3(0.08, 0.1, 0.18) * pow(max(md, 0.0), 40.0) * night;
	}
	if (h > 0.0) {
		vec2 uv = d.xz / (h + 0.12) * 0.22 + vec2(TIME * 0.003, TIME * 0.0015);
		float c = texture(cloud_noise, uv).r;
		c = smoothstep(1.0 - cloud_amount, 1.0 - cloud_amount + 0.32, c);
		vec3 ccol = mix(vec3(1.0, 0.98, 0.95), horizon_color * 1.15, 0.35) * (1.0 - night * 0.88);
		col = mix(col, ccol, c * smoothstep(0.0, 0.18, h) * 0.9);
	}
	COLOR = col;
}
"""

@export var minutes: float = START_MIN
@export var day: int = 1
@export var phase: int = Phase.AWAKE

@onready var sun: DirectionalLight3D = get_node("../Sun")
@onready var moon: DirectionalLight3D = get_node("../Moon")
@onready var env: Environment = (get_node("../WorldEnvironment") as WorldEnvironment).environment

var sun_elevation := 30.0
var _sky_mat: ShaderMaterial
var _was_night := false
var _check_timer := 0.0
var _wake_hour := 8
var _reports: Dictionary = {}
var _summary_timer := -1.0
var _report_timer := -1.0
var _forced := false


func _ready() -> void:
	add_to_group("day_cycle")
	var sh := Shader.new()
	sh.code = SKY_SHADER
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = sh
	var noise := FastNoiseLite.new()
	noise.frequency = 0.006
	noise.fractal_octaves = 5
	var nt := NoiseTexture2D.new()
	nt.width = 512
	nt.height = 512
	nt.seamless = true
	nt.noise = noise
	_sky_mat.set_shader_parameter("cloud_noise", nt)
	var sky := Sky.new()
	sky.sky_material = _sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	Net.hosted.connect(_load)
	Saves.before_save.connect(_save)
	_apply_lighting(true)


# ------------------------------------------------------------ время

func hour() -> int:
	return int(fmod(minutes, 1440.0) / 60.0)


func clock_text() -> String:
	var m := int(fmod(minutes, 1440.0))
	return "%02d:%02d" % [m / 60, m % 60]


func is_night() -> bool:
	return sun_elevation < 0.0


## 0 — день, 1 — глубокая ночь (для шансов охранника и т.п.).
func darkness() -> float:
	return 1.0 - smoothstep(-8.0, 6.0, sun_elevation)


func _process(delta: float) -> void:
	if phase == Phase.AWAKE:
		minutes += delta * MIN_PER_SEC
	_apply_lighting(false)
	if not multiplayer.is_server():
		return
	_server_tick(delta)


# ------------------------------------------------------------ освещение

func _apply_lighting(force: bool) -> void:
	var m := fmod(minutes, 1440.0)
	var f := (m - SUNRISE) / (SUNSET - SUNRISE)
	var theta := f * PI
	sun_elevation = 62.0 * sin(theta)
	var yaw := PI * 0.5 - theta
	var e := deg_to_rad(sun_elevation)
	var dir := Vector3(cos(e) * sin(yaw), sin(e), cos(e) * cos(yaw))
	if dir.y > -0.999:
		sun.global_transform = Transform3D(Basis.looking_at(-dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.FORWARD), Vector3.ZERO)
	var md := Vector3(-cos(0.7) * sin(yaw), sin(0.7) * maxf(-sin(theta), 0.2), -cos(0.7) * cos(yaw)).normalized()
	moon.global_transform = Transform3D(Basis.looking_at(-md, Vector3.UP), Vector3.ZERO)

	var day_k := smoothstep(-7.0, 12.0, sun_elevation)
	var low := 1.0 - smoothstep(0.0, 22.0, absf(sun_elevation))
	sun.light_energy = 1.2 * smoothstep(-3.0, 8.0, sun_elevation)
	sun.light_color = Color(1.0, 0.55, 0.32).lerp(Color(1.0, 0.96, 0.88), smoothstep(4.0, 32.0, sun_elevation))
	sun.visible = sun.light_energy > 0.01
	moon.light_energy = 0.32 * (1.0 - day_k)
	moon.visible = moon.light_energy > 0.01

	var top := Color(0.01, 0.015, 0.045).lerp(Color(0.18, 0.42, 0.86), day_k)
	var hor := Color(0.035, 0.05, 0.11).lerp(Color(0.6, 0.78, 0.96), day_k)
	hor = hor.lerp(Color(1.0, 0.5, 0.26), low * 0.75 * smoothstep(-8.0, 2.0, sun_elevation))
	top = top.lerp(Color(0.28, 0.3, 0.55), low * 0.4 * day_k)
	_sky_mat.set_shader_parameter("top_color", Vector3(top.r, top.g, top.b))
	_sky_mat.set_shader_parameter("horizon_color", Vector3(hor.r, hor.g, hor.b))
	_sky_mat.set_shader_parameter("ground_color", Vector3(0.12, 0.15, 0.12) * (0.2 + 0.8 * day_k))
	_sky_mat.set_shader_parameter("night", 1.0 - day_k)

	env.ambient_light_sky_contribution = 0.25 + 0.75 * day_k
	env.ambient_light_color = Color(0.16, 0.2, 0.34)
	env.ambient_light_energy = 0.45 + 0.25 * day_k
	env.fog_light_color = hor.lerp(Color(0.05, 0.06, 0.1), 1.0 - day_k)
	env.fog_density = lerpf(0.004, 0.0012, day_k)
	env.tonemap_exposure = lerpf(1.35, 0.92, day_k)

	var weather := get_tree().get_first_node_in_group("weather") as Weather if is_inside_tree() else null
	if weather:
		weather.apply(self)

	var night := sun_elevation < 4.0
	if night != _was_night or force:
		_was_night = night
		for l in get_tree().get_nodes_in_group("night_lights"):
			l.visible = night
		for b in get_tree().get_nodes_in_group("night_bulbs"):
			var bm := (b as MeshInstance3D).material_override as StandardMaterial3D
			if bm:
				bm.emission_energy_multiplier = float(bm.get_meta("night_glow", 3.0)) if night else 0.0
		for w in get_tree().get_nodes_in_group("night_windows"):
			for g in w.get_children():
				if g.has_meta("glass"):
					var mat := (g as MeshInstance3D).material_override as StandardMaterial3D
					mat.emission_energy_multiplier = 1.6 if night else 0.0


# ------------------------------------------------------------ сон (сервер)

func _server_tick(delta: float) -> void:
	if phase == Phase.AWAKE:
		if minutes >= FAINT_MIN:
			_forced = true
			_wake_hour = 10
			NetUtil.call_all(self, "announce", ["Пять утра… Все вырубились от усталости прямо где стояли"])
			_begin_summary()
			return
		_check_timer -= delta
		if _check_timer <= 0.0:
			_check_timer = 0.5
			if _all_sleeping():
				_set_phase(Phase.CHOOSING)
	elif phase == Phase.CHOOSING:
		_check_timer -= delta
		if _check_timer <= 0.0:
			_check_timer = 0.5
			if not _all_sleeping():
				_set_phase(Phase.AWAKE)
	if _report_timer >= 0.0:
		_report_timer -= delta
		if _report_timer < 0.0 or _reports.size() >= get_tree().get_nodes_in_group("players").size():
			_report_timer = -1.0
			_finish_summary()
	if _summary_timer >= 0.0:
		_summary_timer -= delta
		if _summary_timer < 0.0:
			srv_new_day()


func _all_sleeping() -> bool:
	var ps := get_tree().get_nodes_in_group("players")
	if ps.is_empty():
		return false
	for p in ps:
		if not p.sleeping:
			return false
	return true


func _set_phase(p: int) -> void:
	phase = p
	NetUtil.call_all(self, "on_phase", [p])


@rpc("authority", "reliable")
func on_phase(p: int) -> void:
	phase = p
	phase_changed.emit(p)


## Хост выбрал, до скольки спать.
@rpc("any_peer", "reliable")
func srv_choose_wake(h: int) -> void:
	if not multiplayer.is_server() or NetUtil.sender(self) != 1 or phase != Phase.CHOOSING:
		return
	_forced = false
	_wake_hour = clampi(h, 5, 14)
	_begin_summary()


func _begin_summary() -> void:
	phase = Phase.SUMMARY
	_reports.clear()
	_report_timer = 1.5
	NetUtil.call_all(self, "request_report", [])


@rpc("authority", "reliable")
func request_report() -> void:
	phase = Phase.SUMMARY
	var data := Inventory.today.duplicate()
	data["money"] = Inventory.money
	data["name"] = Net.player_name
	data["skin"] = Saves.skin
	NetUtil.call_server(self, "srv_report", [data])


@rpc("any_peer", "reliable")
func srv_report(data: Dictionary) -> void:
	if multiplayer.is_server():
		_reports[NetUtil.sender(self)] = data


func _finish_summary() -> void:
	var rows: Array = []
	for peer in _reports:
		var r: Dictionary = _reports[peer]
		r["peer"] = peer
		r["money_delta"] = int(r.get("money", 0)) - int(r.get("money_start", r.get("money", 0)))
		rows.append(r)
	DayCycle.assign_titles(rows)
	var summary := {"day": day, "forced": _forced, "wake": _wake_hour, "rows": rows}
	NetUtil.call_all(self, "show_summary", [summary])
	_summary_timer = 40.0


@rpc("authority", "reliable")
func show_summary(summary: Dictionary) -> void:
	phase = Phase.SUMMARY
	phase_changed.emit(Phase.SUMMARY)
	var ui := get_tree().get_first_node_in_group("day_ui")
	if ui:
		ui.show_summary(summary)


## Хост нажал «Новый день» (или вышло время).
@rpc("any_peer", "reliable")
func srv_new_day() -> void:
	if not multiplayer.is_server() or phase != Phase.SUMMARY:
		return
	if multiplayer.get_remote_sender_id() not in [0, 1]:
		return
	_summary_timer = -1.0
	var now := minutes
	var target := _wake_hour * 60.0 + 1440.0 * floorf(minutes / 1440.0)
	if target <= now:
		target += 1440.0
	var hours := (target - now) / 60.0
	day += 1
	minutes = fmod(target, 1440.0)
	phase = Phase.AWAKE
	NetUtil.call_all(self, "wake_up", [hours, day, minutes])
	Saves.save_world()


@rpc("authority", "reliable")
func wake_up(hours: float, new_day: int, new_minutes: float) -> void:
	day = new_day
	minutes = new_minutes
	phase = Phase.AWAKE
	# Похмелье: чем больше выпил вчера и чем пьянее лёг — тем хуже утро.
	var was_drunk := Inventory.drunk
	var drinks := int(Inventory.today.get("drinks", 0)) + int(Inventory.today.get("party_drinks", 0))
	var hang := clampf((was_drunk - 25.0) / 60.0 + maxf(drinks - 2, 0) * 0.07, 0.0, 1.0)
	Inventory.drunk = maxf(Inventory.drunk - hours * 15.0, 0.0)
	Inventory.satiety = maxf(Inventory.satiety - hours * 4.0, 15.0)
	Inventory.bladder = minf(Inventory.bladder + hours * 6.0, 80.0)
	Inventory.bowel = minf(Inventory.bowel + hours * 4.0, 80.0)
	Inventory.health = minf(Inventory.health + hours * 8.0, Inventory.MAX_HEALTH)
	Inventory.reset_today()
	Inventory.changed.emit()
	var p := get_tree().get_first_node_in_group("local_player")
	if p:
		var up := get_tree().get_first_node_in_group("house_upgrades")
		if up and up.has(1) and p.sleeping:
			Inventory.health = minf(Inventory.health + 20.0, Inventory.MAX_HEALTH)
			Inventory.changed.emit()
		p.wake_up()
		if hang > 0.05:
			p.start_hangover(hang)
	Events.new_day.emit(new_day)
	phase_changed.emit(Phase.AWAKE)
	var ui := get_tree().get_first_node_in_group("day_ui")
	if ui:
		ui.close_all()
	Events.notify("Доброе утро! День %d, %s" % [new_day, clock_text()], Color(1, 0.95, 0.7))


@rpc("authority", "reliable")
func announce(text: String) -> void:
	Events.notify(text, Color(0.75, 0.85, 1.0))


# ------------------------------------------------------------ титулы

const TITLES := [
	["tourn_wins", "Чемпион по рыбалке", "выиграл соревнование Толи"],
	["belochka", "Видел белочку", "общался с белочкой: %d раз"],
	["toasts", "Главный тамада", "чокнулся: %d раз"],
	["moonshine", "Главный самогонщик", "выгнал бутылок: %d"],
	["jailed", "Главный рецидивист", "сидел в КПЗ: %d раз"],
	["net_fish", "Главный браконьер", "вытащил из сетей рыб: %d"],
	["bribes", "Решала", "договорился с участковым: %d раз"],
	["disputes_won", "Главный спорщик", "выиграл споров: %d"],
	["party_drinks", "Душа праздника", "выпил на гулянке: %d"],
	["farm_jobs", "Колхозник года", "отработал на ферме: %d раз"],
	["repairs", "Золотые руки", "починил машин: %d"],
	["drinks", "Главный алкоголик", "выпил бутылок: %d"],
	["fish_kg", "Главный рыбак", "наловил %.1f кг рыбы"],
	["hits", "Главный задира", "раздал ударов: %d"],
	["bets", "Главный лудоман", "сделал ставок: %d"],
	["thefts", "Главный вор", "вынес не заплатив: %d раз"],
	["knockouts", "Главный боец", "отправил в нокаут: %d"],
	["earned", "Главный бизнесмен", "заработал %d ₽"],
	["money", "Главный богач", "в кармане %d ₽"],
	["boxes", "Главный работяга", "перетаскал коробок: %d"],
	["bottles", "Главный эколог", "сдал бутылок: %d"],
	["poops", "Главный засранец", "сходил по-большому: %d"],
	["smokes", "Главный курильщик", "выкурил: %d"],
]


static func assign_titles(rows: Array) -> void:
	var taken := {}
	for row in rows:
		row["title"] = ""
		row["subtitle"] = ""
	for t in TITLES:
		var key: String = t[0]
		var best: Dictionary = {}
		var best_v := 0.0
		for row in rows:
			var v := float(row.get(key, 0))
			if v > best_v:
				best_v = v
				best = row
		if best.is_empty() or best.title != "":
			continue
		best["title"] = t[1]
		best["subtitle"] = _fmt(t[2], key, best_v)
		taken[key] = true
	for row in rows:
		if row.title != "":
			continue
		# Не выиграл ни одной номинации — ищем, где он хоть что-то сделал.
		for t in TITLES:
			var v := float(row.get(t[0], 0))
			if v > 0 and not taken.has(t[0]):
				row["title"] = t[1]
				row["subtitle"] = _fmt(t[2], t[0], v)
				taken[t[0]] = true
				break
		if row.title == "":
			if int(row.get("drinks", 0)) == 0:
				row["title"] = "Главный трезвенник"
				row["subtitle"] = "ни капли в рот"
			else:
				row["title"] = "Просто хороший человек"
				row["subtitle"] = "старался как мог"


static func _fmt(pattern: String, key: String, v: float) -> String:
	return pattern % v if key == "fish_kg" else pattern % int(v)


# ------------------------------------------------------------ сохранение

func _save() -> void:
	Saves.set_section("time", {"minutes": minutes, "day": day})


func _load() -> void:
	var t := Saves.get_section("time")
	minutes = float(t.get("minutes", START_MIN))
	day = int(t.get("day", 1))
	phase = Phase.AWAKE
	if minutes >= FAINT_MIN - 30.0:
		minutes = START_MIN
