extends Node3D
## Рыбнадзор Семёныч на катере. Ходит кругами по ближнему озеру, протоке и Дальнему плёсу.
## Снимает чужие сети, штрафует браконьеров (видел, как ставил или тащил сеть), иногда сдаёт участковому.
## Решает хост; позиция/поворот/состояние — через Sync.

enum S { PATROL, CHASE }

const SPEED := 4.6
const CHASE_SPEED := 7.0
const SEE := 30.0
const FINE_MIN := 400
const FINE_PART := 0.25

@export var state: int = S.PATROL
@export var siren: bool = false

var _route: Array[Vector3] = []
var _i := 0
var _scan := 0.0
var _target := 0
var _chase_t := 0.0
var _fined: Dictionary = {}      ## peer -> время последнего штрафа
var _checked: Dictionary = {}    ## id сети -> до какого времени не замечает (уже проплывал мимо)
var _t := 0.0
var _light: OmniLight3D
var _beacon: MeshInstance3D
var _speech: Label3D
var _snd: AudioStreamPlayer3D
var _hull: Node3D
var _prev := Vector3.ZERO
var _spd := 0.0


func _ready() -> void:
	Chatter.attach.call_deferred(self, "m_low", SpeechBank.semenych(), 3.2, 16.0, "semenych")
	add_to_group("inspector")
	add_to_group("npc")
	_build_route()
	_build_boat()
	_build_post()
	if multiplayer.is_server() and not _route.is_empty():
		global_position = _route[0]


func display_name() -> String:
	return "Рыбнадзор"


# ------------------------------------------------------------ маршрут по воде

## Точки у берега (на глубине ~2 м), идём снаружи внутрь — острова не мешают.
static func _loop(center: Vector2, sx: float, r0: float, n: int, a0: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for k in n:
		var a := a0 + TAU * k / n
		var dir := Vector2(cos(a) * sx, sin(a))
		var r := r0
		while r > 2.0:
			var p := center + dir * r
			if Terrain.depth(p.x, p.y) > 2.2:
				var q := center + dir * (r - 4.0)
				if Terrain.depth(q.x, q.y) < 1.5:
					q = p
				out.append(Vector3(q.x, Terrain.WATER_Y, q.y))
				break
			r -= 0.5
	return out


func _build_route() -> void:
	var mouth: Vector2 = Terrain.RIVER[0]
	var a_near := atan2(mouth.y - Terrain.LAKE_C.y, (mouth.x - Terrain.LAKE_C.x) / Terrain.LAKE_SX)
	var near := _loop(Terrain.LAKE_C, Terrain.LAKE_SX, 55.0, 18, a_near + 0.35)
	var top: Vector2 = Terrain.RIVER[Terrain.RIVER.size() - 1]
	var a_far := atan2(top.y - Terrain.FAR_C.y, (top.x - Terrain.FAR_C.x) / Terrain.FAR_SX)
	var far := _loop(Terrain.FAR_C, Terrain.FAR_SX, 75.0, 20, a_far + 0.3)
	var up: Array[Vector3] = []
	for p in Terrain.RIVER:
		up.append(Vector3(p.x, Terrain.WATER_Y, p.y))
	_route.append_array(near)
	_route.append_array(up)
	_route.append_array(far)
	var down := up.duplicate()
	down.reverse()
	_route.append_array(down)


# ------------------------------------------------------------ вид

func _build_boat() -> void:
	_hull = Node3D.new()
	add_child(_hull)
	var white := Art.color(Color(0.92, 0.93, 0.95), 0.5)
	var blue := Art.color(Color(0.12, 0.3, 0.7), 0.5)
	var dark := Art.color(Color(0.15, 0.15, 0.17), 0.6, 0.3)
	Art.add_mesh(_hull, Art.box(Vector3(1.7, 0.45, 4.0)), white, Vector3(0, 0.05, 0))
	Art.add_mesh(_hull, Art.box(Vector3(1.2, 0.4, 1.0)), white, Vector3(0, 0.05, -2.3), Vector3(0.0, 0.0, 0.0), Vector3(1, 1, 1))
	Art.add_mesh(_hull, Art.box(Vector3(1.74, 0.12, 4.04)), blue, Vector3(0, 0.12, 0))
	Art.add_mesh(_hull, Art.box(Vector3(1.4, 0.06, 0.05)), Art.color(Color(0.4, 0.6, 0.8, 0.6), 0.1), Vector3(0, 0.6, -0.7), Vector3(-0.5, 0, 0))
	Art.add_mesh(_hull, Art.box(Vector3(0.35, 0.7, 0.35)), dark, Vector3(0, 0.25, 2.15))   # мотор
	Art.add_mesh(_hull, Art.box(Vector3(0.5, 0.45, 0.4)), Art.color(Color(0.85, 0.85, 0.88), 0.4, 0.5), Vector3(0, 0.55, 0.2))   # пульт
	for sd in [-1.0, 1.0]:
		Build.text(_hull, Vector3(0.88 * sd, 0.15, 0.2), "РЫБНАДЗОР", 52, Color(0.12, 0.3, 0.7), 0.006, PI / 2 * sd)
	_beacon = Art.add_mesh(_hull, Art.sphere(0.1, 8), Build.glow_mat(Color(0.2, 0.4, 1.0), 3.0), Vector3(0, 0.95, 0.2))
	_light = OmniLight3D.new()
	_light.position = Vector3(0, 1.1, 0.2)
	_light.light_color = Color(0.3, 0.5, 1.0)
	_light.omni_range = 9.0
	_light.light_energy = 0.0
	_hull.add_child(_light)
	var m := CharacterModel.new()
	m.shirt = Color(0.28, 0.33, 0.2)
	m.pants = Color(0.2, 0.22, 0.16)
	m.hat = CharacterModel.Hat.CAP
	m.hat_color = Color(0.25, 0.3, 0.18)
	m.face_name = "guard"
	m.position = Vector3(0, 0.25, 0.75)
	_hull.add_child(m)
	m.pose = "sit"
	Build.text(self, Vector3(0, 2.4, 0), "Рыбнадзор Семёныч", 36, Color(0.7, 0.9, 1.0), 0.006, 0.0, true)
	_speech = Build.text(self, Vector3(0, 2.8, 0), "", 38, Color(1, 1, 0.8), 0.006, 0.0, true)
	_snd = AudioStreamPlayer3D.new()
	_snd.stream = Sfx.stream_of("engine")
	_snd.unit_size = 6.0
	_snd.max_distance = 60.0
	_snd.volume_db = -12.0
	_snd.pitch_scale = 1.35
	add_child(_snd)


## Будка рыбнадзора с мостками — на южном берегу Дальнего плёса (видна издалека).
func _build_post() -> void:
	var x := 14.0
	var z := -100.0
	while z > -140.0 and Terrain.depth(x, z) <= 0.0:
		z -= 0.5
	var post := Node3D.new()
	post.name = "InspectorPost"
	post.position = Vector3(x, 0, z)
	var wood := Art.tex_world("planks", 0.6)
	var y := Terrain.height(x, z + 5.0)
	Build.block(post, Vector3(0, y + 1.3, 5.0), Vector3(3.0, 2.6, 2.6), Art.color(Color(0.25, 0.4, 0.3), 0.8), true)
	Build.block(post, Vector3(0, y + 2.75, 5.0), Vector3(3.5, 0.2, 3.1), Art.tex_world("roof", 0.35), false)
	Build.block(post, Vector3(0, y + 2.2, 3.66), Vector3(2.6, 0.45, 0.05), Art.color(Color(0.12, 0.3, 0.7)), false)
	Build.text(post, Vector3(0, y + 2.2, 3.63), "РЫБООХРАНА", 44, Color.WHITE, 0.006, PI)
	Build.window(post, Vector3(0.6, y + 1.4, 3.69), Vector2(1.0, 0.8))
	Build.block(post, Vector3(0, 0.1, -2.5), Vector3(1.6, 0.12, 7.0), wood, true)   # мостки
	for zz in [-5.5, -3.0, -0.5]:
		for xx in [-0.7, 0.7]:
			Build.block(post, Vector3(xx, -0.9, zz), Vector3(0.14, 2.0, 0.14), wood, false)
	Build.text(post, Vector3(0, 2.2, -1.0), "ЛОВ СЕТЯМИ ЗАПРЕЩЁН!\nШтраф — по всей строгости", 34, Color(1, 0.4, 0.3), 0.006, PI, true)
	post.add_to_group("poi")
	post.set_meta("poi_name", "Рыбоохрана")
	get_parent().add_child.call_deferred(post)


# ------------------------------------------------------------ поведение (сервер)

func _process(delta: float) -> void:
	# В главном меню мир стоит «на паузе»: катер не плавает и не гудит мотором.
	if not Net.is_online():
		if _snd.playing:
			_snd.stop()
		return
	_t += delta
	_animate(delta)
	if not multiplayer.is_server() or _route.is_empty():
		return
	_scan -= delta
	if _scan <= 0.0:
		_scan = 0.5
		_look()
	var goal: Vector3 = _route[_i]
	var spd := SPEED
	if state == S.CHASE:
		var p := _player(_target)
		_chase_t += delta
		if p == null or _chase_t > 40.0:
			state = S.PATROL
			siren = false
		else:
			var pp: Vector3 = p.global_position
			if Terrain.depth(pp.x, pp.z) > 1.0:
				goal = Vector3(pp.x, Terrain.WATER_Y, pp.z)
			spd = CHASE_SPEED
			if Vector2(pp.x - global_position.x, pp.z - global_position.z).length() < 14.0:
				_fine(_target, "браконьерство")
				state = S.PATROL
				siren = false
	var to := goal - global_position
	to.y = 0.0
	if to.length() < 2.0 and state == S.PATROL:
		_i = (_i + 1) % _route.size()
	elif to.length() > 0.1:
		var step := to.normalized() * minf(spd * delta, to.length())
		var nx := global_position + step
		if Terrain.depth(nx.x, nx.z) > 0.5 or state == S.PATROL:
			global_position = Vector3(nx.x, Terrain.WATER_Y, nx.z)
		rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), clampf(delta * 2.5, 0.0, 1.0))


func _player(peer: int) -> Node3D:
	return get_tree().get_root().get_node_or_null("World/Players/%d" % peer) as Node3D


func _look() -> void:
	var nets := get_tree().get_first_node_in_group("nets")
	if nets == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	for n in nets.nets_near(global_position, 16.0):
		if float(_checked.get(n.id, 0.0)) > now:
			continue
		_checked[n.id] = now + 90.0
		if randf() > 0.4:
			continue   # проплыл мимо — не заметил
		var got: Dictionary = nets.confiscate(n.id)
		if got.is_empty():
			continue
		_say("Так, сеточка! Изымается. Кто ставил?")
		NetUtil.call_all(self, "announce", ["Рыбнадзор снял сеть (%s)" % got.owner])
		for p in get_tree().get_nodes_in_group("players"):
			if p.player_name == got.owner and (p as Node3D).global_position.distance_to(global_position) < SEE + 10.0:
				_start_chase(p.name.to_int())


## Кто-то при нём вытащил сеть.
func saw_poacher(peer: int, where: Vector3) -> void:
	if where.distance_to(global_position) < SEE + 5.0:
		_say("Ага! С поличным! Стоять!")
		_start_chase(peer)


func _start_chase(peer: int) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_fined.get(peer, -999.0)) < 60.0:
		return
	state = S.CHASE
	siren = true
	_target = peer
	_chase_t = 0.0


func _fine(peer: int, reason: String) -> void:
	_fined[peer] = Time.get_ticks_msec() / 1000.0
	var p := _player(peer)
	if p == null:
		return
	_say("Протокол! Штраф за %s, гражданин %s" % [reason, p.player_name])
	NetUtil.call_peer(self, peer, "fined", [FINE_MIN, FINE_PART, reason])
	NetUtil.call_all(self, "announce", ["Рыбнадзор оштрафовал %s за %s" % [p.player_name, reason]])
	if randf() < 0.5:
		var police := get_tree().get_first_node_in_group("police")
		if police:
			police.report(peer, "браконьерство (сдал рыбнадзор)")


@rpc("authority", "reliable")
func fined(fine_min: int, part: float, reason: String) -> void:
	var amount := clampi(roundi(Inventory.money * part), fine_min, 1500)
	amount = mini(amount, Inventory.money)
	Inventory.money -= amount
	Inventory.changed.emit()
	Inventory.stat_add("fined", 1)
	Events.notify("Штраф рыбнадзора за %s: −%d ₽" % [reason, amount], Color.TOMATO)


func _say(text: String) -> void:
	NetUtil.call_all(self, "say", [text])


@rpc("authority", "call_remote", "reliable")
func say(text: String) -> void:
	_speech.text = text
	_speech.modulate.a = 1.0
	Sfx.say(global_position + Vector3.UP * 1.5, "m_low", text, "semenych")


@rpc("authority", "call_remote", "reliable")
func announce(text: String) -> void:
	Events.notify(text, Color(0.6, 0.85, 1.0))


# ------------------------------------------------------------ вид (у всех)

func _animate(delta: float) -> void:
	var moved := global_position - _prev
	_prev = global_position
	_spd = lerpf(_spd, moved.length() / maxf(delta, 0.001), delta * 3.0)
	_hull.rotation.x = -clampf(_spd / 7.0, 0.0, 1.0) * 0.08 + sin(_t * 1.3) * 0.02
	_hull.rotation.z = sin(_t * 0.9) * 0.025
	_speech.modulate.a = maxf(_speech.modulate.a - delta * 0.2, 0.0)
	var dc := get_tree().get_first_node_in_group("day_cycle") as DayCycle
	var night := dc != null and dc.is_night()
	var blink := (siren or night) and fmod(_t, 0.6) < 0.3
	_light.light_energy = 2.5 if blink else 0.0
	(_beacon.material_override as StandardMaterial3D).emission_energy_multiplier = 4.0 if blink else 0.3
	if _spd > 0.5:
		if not _snd.playing:
			_snd.play()
		_snd.pitch_scale = 1.0 + _spd / 7.0 * 0.6
	elif _snd.playing:
		_snd.stop()
