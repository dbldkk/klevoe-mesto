class_name Police
extends CharacterBody3D
## Участковые посёлка. Ходят своими участками, ловят пьяных за рулём, воров и драчунов.
## Дежурная сидит в опорном и смотрит в камеру. Решения принимает хост.

enum S { PATROL, CHASE, ESCORT }

const WALK := 2.1
const RUN := 5.4
const CATCH := 1.5
const SEE := 16.0
const WANTED_TIME := 100.0

@export var state: int = S.PATROL
@export var target_name: String = ""
@export var officer_key: String = "petrovich"
@export var duty: bool = false
@export var officer_title: String = "Участковый Петрович"

var _target := 0
var _reason := ""
var _chase_t := 0.0
var _lost_t := 0.0
var _wanted: Dictionary = {}       ## peer -> [reason, expires_at, strict]
var _cooldown: Dictionary = {}     ## peer -> до какого времени не трогать
var _wp: Array[Vector3] = []
var _wp_i := 0
var _wp_dir := 1
var _scan := 0.0
var _say_t := 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _prev := Vector3.ZERO
var model: CharacterModel
var _label: Label3D
var _speech: Label3D
var _bribe_t := 0.0
const BRIBE_TIME := 14.0


func _ready() -> void:
	_apply_profile()
	var lines: Array = SpeechBank.petrovich()
	if officer_key == "semenov":
		lines = SpeechBank.semenov()
	elif officer_key == "nina":
		lines = SpeechBank.nina()
	var ch := Chatter.attach(self, "m_low" if officer_key != "nina" else "f", lines, 2.9, 6.0, officer_key)
	ch.condition = func() -> bool: return state == S.PATROL
	add_to_group("npc")
	add_to_group("police")
	add_to_group("district_officer")
	collision_layer = 8
	collision_mask = 1
	var cs := CollisionShape3D.new()
	var sh := CapsuleShape3D.new()
	sh.radius = 0.4
	sh.height = 1.9
	cs.shape = sh
	cs.position.y = 0.95
	add_child(cs)
	model = CharacterModel.new()
	_style_model()
	add_child(model)
	_label = Build.text(self, Vector3(0, 2.25, 0), officer_title, 36, Color(0.7, 0.8, 1.0), 0.006, 0.0, true)
	_speech = Build.text(self, Vector3(0, 2.6, 0), "", 38, Color(1, 1, 0.8), 0.006, 0.0, true)
	_build_route()
	if multiplayer.is_server():
		if duty:
			global_position = Layout.local_to_world("police", Vector3(2.0, 0.1, -2.36))
			global_rotation.y = Layout.face_in_yaw(Layout.SPOTS.police[0]) + PI
		elif not _wp.is_empty():
			global_position = _wp[0] + Vector3.UP * 0.5
	# Синхронизация для участковых, созданных скриптом (не из .tscn).
	if get_node_or_null("Sync") == null:
		var sync := MultiplayerSynchronizer.new()
		sync.name = "Sync"
		var cfg := SceneReplicationConfig.new()
		cfg.add_property(NodePath(":position"))
		cfg.add_property(NodePath(":rotation"))
		cfg.add_property(NodePath(":state"))
		cfg.add_property(NodePath(":target_name"))
		sync.replication_config = cfg
		add_child(sync)


func _apply_profile() -> void:
	match officer_key:
		"semenov":
			officer_title = "Участковый Сергей Палыч"
			duty = false
		"nina":
			officer_title = "Участковый Нина Васильевна"
			duty = true
		_:
			officer_key = "petrovich"
			officer_title = "Участковый Петрович"
			duty = false


func _style_model() -> void:
	model.pants = Color(0.12, 0.13, 0.16)
	model.hat = CharacterModel.Hat.CAP
	match officer_key:
		"semenov":
			model.shirt = Color(0.18, 0.24, 0.36)
			model.hat_color = Color(0.14, 0.18, 0.28)
			model.face_name = "player_b"
			model.height_scale = 1.0
			model.skin = Color(0.82, 0.64, 0.48)
		"nina":
			model.shirt = Color(0.17, 0.2, 0.32)
			model.hat_color = Color(0.1, 0.12, 0.2)
			model.face_name = "neutral"
			model.height_scale = 0.97
			model.hair_color = Color(0.25, 0.18, 0.12)
			model.skin = Color(0.9, 0.74, 0.6)
		_:
			model.shirt = Color(0.16, 0.2, 0.34)
			model.hat_color = Color(0.12, 0.15, 0.26)
			model.face_name = "guard"
			model.height_scale = 1.05


func _build_route() -> void:
	_wp.clear()
	var a := -140
	var b := 110
	var step := 15
	match officer_key:
		"semenov":
			a = -55
			b = 35
			step = 12
		"nina":
			return
	for phi in range(a, b + 1, step):
		_wp.append(Layout.ring(float(phi), 1.8))


func is_watching_cell() -> bool:
	if not duty or state != S.PATROL:
		return false
	return fmod(Time.get_ticks_msec() / 1000.0 + 1.7, 8.0) > 4.2


func display_name() -> String:
	return officer_title


func status_word() -> String:
	match state:
		S.CHASE: return "гонится за %s" % target_name
		S.ESCORT: return "беседует с %s" % target_name
	return "патрулирует"


# ------------------------------------------------------------ донесения (сервер)

## Кто-то сообщил о нарушении. strict — сажать даже если уже трезвый/успокоился.
func report(peer: int, reason: String, strict := true) -> void:
	if not multiplayer.is_server():
		return
	var now := Time.get_ticks_msec() / 1000.0
	if float(_cooldown.get(peer, 0.0)) > now:
		return
	_wanted[peer] = [reason, now + WANTED_TIME, strict]


## Драка: видел сам или видела бабка.
func witness(peer: int, reason: String, where: Vector3) -> void:
	var seen := global_position.distance_to(where) < 30.0
	var babka := get_tree().get_first_node_in_group("babka") as Node3D
	if babka and babka.global_position.distance_to(where) < 22.0:
		seen = true
		babka.call("tattle", "Ой, дерутся! Петрович, сюда!")
	if seen:
		report(peer, reason)


func on_melee_hit(by: int, _damage: float) -> void:
	if not multiplayer.is_server():
		return
	const ASSAULT := "нападение на участкового"
	_say("Ах ты так?! Нападение на сотрудника!")
	if duty:
		for officer in get_tree().get_nodes_in_group("police"):
			if not officer.duty:
				officer.report(by, ASSAULT)
		return
	report(by, ASSAULT)
	_start_chase(by, ASSAULT)


# ------------------------------------------------------------ поведение (сервер)

func _physics_process(delta: float) -> void:
	if not Net.is_online():
		return
	_animate(delta)
	if not multiplayer.is_server():
		return
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = -0.5
	_say_t = maxf(_say_t - delta, 0.0)
	_scan -= delta
	if _scan <= 0.0:
		_scan = 0.5
		_look_around()
	var goal := Vector3.INF
	velocity.x = 0.0
	velocity.z = 0.0
	var spd := WALK
	match state:
		S.ESCORT:
			_bribe_t -= delta
			var t := _player(_target)
			if t:
				var to := t.global_position - global_position
				global_rotation.y = lerp_angle(global_rotation.y, atan2(-to.x, -to.z), clampf(delta * 6.0, 0.0, 1.0))
			if _bribe_t <= 0.0 or t == null:
				_jail(_target, 1.0)
		S.PATROL:
			if duty:
				_duty_look(delta)
				goal = Vector3.INF
			elif _wp.is_empty():
				return
			else:
				goal = _wp[_wp_i]
			if Vector2(goal.x - global_position.x, goal.z - global_position.z).length() < 1.2:
				_wp_i += _wp_dir
				if _wp_i >= _wp.size() or _wp_i < 0:
					_wp_dir = -_wp_dir
					_wp_i = clampi(_wp_i + _wp_dir * 2, 0, _wp.size() - 1)
		S.CHASE:
			var t := _player(_target)
			_chase_t += delta
			if t == null or _chase_t > 70.0:
				_give_up("Ушёл, зараза… В следующий раз поймаю")
			else:
				var d := t.global_position.distance_to(global_position)
				if t.hidden:
					_lost_t += delta
					if d < 3.0:
						_arrest(t)   # нашёл в кустах
					elif _lost_t > 6.0:
						_give_up("Где-то тут прячется… ладно")
				else:
					_lost_t = 0.0
					goal = _route_to(t.global_position)
					spd = RUN
					if d < CATCH:
						_arrest(t)
					elif d > 60.0:
						_give_up("Убежал…")
	if goal != Vector3.INF:
		var dir := goal - global_position
		dir.y = 0.0
		if dir.length() > 0.2:
			dir = dir.normalized()
			velocity.x = dir.x * spd
			velocity.z = dir.z * spd
			global_rotation.y = lerp_angle(global_rotation.y, atan2(-dir.x, -dir.z), clampf(delta * 6.0, 0.0, 1.0))
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	NpcMotion.move(self, delta)


## Угол точки на кольце дороги (градусы).
static func _phi(p: Vector3) -> float:
	return rad_to_deg(atan2((p.x - Layout.C.x) / Layout.AX, (p.z - Layout.C.y) / Layout.AZ))


## Далеко — бежим по дороге вокруг озера (напрямую можно угодить в воду), близко — напрямую.
func _route_to(target: Vector3) -> Vector3:
	if target.distance_to(global_position) < 14.0:
		return target
	var a := _phi(global_position)
	var b := _phi(target)
	var d := wrapf(b - a, -180.0, 180.0)
	if absf(d) < 8.0:
		return target
	return Layout.ring(a + signf(d) * 9.0, 1.8)


func _duty_look(delta: float) -> void:
	var desk_yaw := Layout.face_in_yaw(Layout.SPOTS.police[0]) + PI
	var cell_dir: Vector3 = Layout.local_to_world("police", Vector3(-2.3, 0.1, -1.9)) - global_position
	var cell_yaw := atan2(-cell_dir.x, -cell_dir.z)
	var target := cell_yaw if is_watching_cell() else desk_yaw
	global_rotation.y = lerp_angle(global_rotation.y, target, clampf(delta * 3.0, 0.0, 1.0))
	velocity.x = 0.0
	velocity.z = 0.0


func _player(peer: int) -> Node3D:
	return get_tree().get_root().get_node_or_null("World/Players/%d" % peer) as Node3D


func _look_around() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for k in _wanted.keys():
		if float(_wanted[k][1]) < now:
			_wanted.erase(k)
	if duty or state != S.PATROL:
		return
	for p in get_tree().get_nodes_in_group("players"):
		var pp := p as Node3D
		var peer: int = p.name.to_int()
		if p.hidden or p.sleeping or float(_cooldown.get(peer, 0.0)) > now or _other_officer_handling(peer):
			continue
		var d := pp.global_position.distance_to(global_position)
		# Пьяный за рулём — видно издалека.
		if d < SEE and p.vehicle_path != "" and p.seat == 0 and float(p.drunk) > 40.0:
			var v := get_node_or_null(p.vehicle_path)
			if v and v.get("kind") != "boat":
				_say("Стоять! Документы! Да ты пьяный за рулём!")
				_start_chase(peer, "пьяный за рулём")
				return
		if _wanted.has(peer) and d < 50.0:
			var w: Array = _wanted[peer]
			if not w[2] and float(p.drunk) < 60.0:
				continue   # бабка нажаловалась, но он уже протрезвел
			_say("Так-так, %s… на тебя поступил сигнал!" % p.player_name)
			_start_chase(peer, w[0])
			return


func _other_officer_handling(peer: int) -> bool:
	var st := get_tree().get_first_node_in_group("police_station")
	if st and st.recently_arrested(peer):
		return true
	for officer in get_tree().get_nodes_in_group("police"):
		if officer != self and officer._target == peer and officer.state in [S.CHASE, S.ESCORT]:
			return true
	return false


func _start_chase(peer: int, reason: String) -> void:
	if state == S.ESCORT or _other_officer_handling(peer):
		return
	state = S.CHASE
	_target = peer
	_reason = reason
	_chase_t = 0.0
	_lost_t = 0.0
	var p := _player(peer)
	target_name = p.player_name if p else "?"
	if p:
		NetUtil.call_peer(p, peer, "police_warning", [reason])


## Поймал: сначала «беседа» — можно попробовать договориться (BribeUI у игрока).
func _arrest(t: Node3D) -> void:
	var peer: int = t.name.to_int()
	if _other_officer_handling(peer):
		_give_up("")
		return
	_target = peer
	state = S.ESCORT
	_bribe_t = BRIBE_TIME
	velocity = Vector3.ZERO
	_say("Стоять! Ну что, гражданин, будем оформлять?")
	NetUtil.call_peer(t, peer, "bribe_offer", [get_path(), _reason, BRIBE_TIME - 1.0])


func _jail(peer: int, mult: float) -> void:
	_wanted.erase(peer)
	_cooldown[peer] = Time.get_ticks_msec() / 1000.0 + 90.0
	if mult > 1.0:
		_say("Взятку?! Должностному лицу?! Ну всё, вдвойне посидишь!", true)
	else:
		_say("Пройдёмте, гражданин. Сутки посидишь — подумаешь", true)
	var st := get_tree().get_first_node_in_group("police_station")
	if st:
		st.jail(peer, _reason + (" + попытка дать взятку" if mult > 1.0 else ""), mult)
	state = S.PATROL
	target_name = ""


## Игрок предлагает «договориться». Шанс зависит от ценности, причины и свидетелей.
@rpc("any_peer", "reliable")
func srv_bribe(kind: String, value: int, data: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var peer := NetUtil.sender(self)
	if state != S.ESCORT or peer != _target:
		return
	if kind == "surrender":
		_jail(peer, 1.0)
		return
	var v := float(value)
	if kind == "drink":
		v *= 2.2   # Петрович уважает
	var p := clampf(v / 1200.0, 0.08, 0.9)
	if _reason.begins_with("нападение"):
		p *= 0.25
	elif _reason.contains("бабушк"):
		p *= 0.45
	elif _reason.contains("за рулём"):
		p *= 1.15
	var witnesses := 0
	for o in get_tree().get_nodes_in_group("players"):
		if o.name.to_int() != peer and (o as Node3D).global_position.distance_to(global_position) < 10.0:
			witnesses += 1
	p *= pow(0.7, witnesses)
	if randf() < p:
		_say(["Ладно… на первый раз. Иди отсюда", "Так и быть. Я тебя не видел", "Хм. Свободен. И чтоб тихо мне!"].pick_random(), true)
		NetUtil.call_peer(self, peer, "bribe_result", [true, kind, value, data])
		_wanted.erase(peer)
		_cooldown[peer] = Time.get_ticks_msec() / 1000.0 + 120.0
		state = S.PATROL
		target_name = ""
	else:
		NetUtil.call_peer(self, peer, "bribe_result", [false, kind, value, data])
		_jail(peer, 2.0)


@rpc("authority", "reliable")
func bribe_result(ok: bool, kind: String, value: int, data: Dictionary) -> void:
	if not ok:
		Events.notify("Не взял! Ещё и срок добавил…", Color.TOMATO)
		return
	match kind:
		"money":
			Inventory.money -= mini(value, Inventory.money)
		"fish":
			for i in Inventory.basket.size():
				var f: Dictionary = Inventory.basket[i]
				if String(f.id) == String(data.id) and absf(float(f.kg) - float(data.kg)) < 0.001:
					Inventory.remove_fish(i)
					break
		"drink":
			Inventory.remove_item("drink", StringName(data.id), 1)
	Inventory.stat_add("bribes")
	Inventory.changed.emit()
	Events.notify("Договорились. Участковый сделал вид, что тебя не видел", Color(0.7, 1.0, 0.7))


func _give_up(line: String) -> void:
	if not line.is_empty():
		_say(line)
	_cooldown[_target] = Time.get_ticks_msec() / 1000.0 + 20.0
	state = S.PATROL
	target_name = ""


func _say(text: String, force := false) -> void:
	if _say_t > 0.0 and state != S.CHASE and not force:
		return
	_say_t = 3.0
	NetUtil.call_all(self, "say", [text])


@rpc("authority", "call_remote", "reliable")
func say(text: String) -> void:
	_speech.text = text
	_speech.modulate.a = 1.0
	Sfx.say(global_position + Vector3.UP * 1.7, "m_low" if officer_key != "nina" else "f", text, officer_key)


# ------------------------------------------------------------ вид (у всех)

func _animate(delta: float) -> void:
	var moved := global_position - _prev
	moved.y = 0.0
	_prev = global_position
	if model:
		model.speed = lerpf(model.speed, moved.length() / maxf(delta, 0.001), minf(delta * 8.0, 1.0))
		model.pose = "sit" if duty and state == S.PATROL else "idle"
	if _speech:
		_speech.modulate.a = maxf(_speech.modulate.a - delta * 0.2, 0.0)
	if _label:
		_label.modulate = Color(1.0, 0.5, 0.4) if state == S.CHASE else Color(0.7, 0.8, 1.0)
