class_name Guard
extends CharacterBody3D
## Охранник Михалыч. Живёт на сервере, у остальных только отображается.
##
## Он то бдит, то сидит в телефоне, то дремлет — по нему видно (надпись над головой).
## Друг может заговорить ему зубы (E) или угостить (G) — тогда он уснёт.
## Если заметит вора на выходе — погонится. Догонит — штраф и всё отберёт.
## Чем дороже украденное — тем быстрее и дольше бежит.
## Вор может спрятаться (кусты, мусорка, туалет): если Михалыч не видел, куда — поищет и уйдёт.
## Ударишь — полезет в драку. Вырубишь — «Шестёрочка» закрыта, пока он не очухается.

enum State { WATCH, PHONE, DOZE, DISTRACTED, SUSPICIOUS, CHASE, RETURN, SEARCH, KO }

const BASE_RUN := 5.6
const WALK_SPEED := 2.5
const CATCH_RADIUS := 1.3
const MAX_HP := 100.0
const KO_TIME := 180.0
const PUNCH_DAMAGE := 12.0
const PUNCH_COOLDOWN := 1.1
const FIGHT_TIME := 25.0
const SEE_HIDE_DISTANCE := 4.0

## Базовый шанс заметить кражу в каждом состоянии.
const SPOT_CHANCE := {
	State.WATCH: 0.75, State.PHONE: 0.3, State.DOZE: 0.08, State.DISTRACTED: 0.05,
	State.SUSPICIOUS: 0.9, State.CHASE: 0.5, State.RETURN: 0.55, State.SEARCH: 0.5, State.KO: 0.0,
}

@export var state: int = State.WATCH
@export var talker: String = ""
@export var hp: float = MAX_HP

@onready var shop: ShopController = get_parent()
@onready var visual: CharacterModel = $Visual
@onready var label: Label3D = $Status

var _timer := 15.0
var _target_peer := 0
var _chase_reason := 0          ## 0 — кража, 1 — бутылка/нагадил, 2 — драка
var _chase_value := 0           ## сумма украденного
var _punch_cd := 0.0
var _search_pos := Vector3.ZERO
var _chase_time := 0.0
var _post := Vector3.ZERO
var _post_rot := 0.0
var _talker_peer := 0
var _t := 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _rng := RandomNumberGenerator.new()


var _return_time := 0.0
var _punch_t := 0.0


func _ready() -> void:
	var ch := Chatter.attach(self, "m_low", SpeechBank.mikhalych(), 2.3, 4.0, "mikhalych")
	ch.condition = func() -> bool: return state == State.WATCH or state == State.PHONE
	add_to_group("npc")
	_rng.randomize()
	_post = position
	_post_rot = rotation.y


# ------------------------------------------------------------ для игроков (E / G)

func display_name() -> String:
	return "Михалыч"


func get_prompt(_player: Node) -> String:
	match state:
		State.WATCH, State.PHONE, State.DOZE:
			return "Заговорить зубы охраннику"
		State.SUSPICIOUS:
			return "Охранник не настроен болтать"
	return ""


func interact(_player: Node) -> void:
	if state in [State.WATCH, State.PHONE, State.DOZE]:
		NetUtil.call_server(self, "srv_distract", [Net.player_name])
	else:
		Events.notify("Михалыч: «Иди-иди, не мешай работать»", Color.LIGHT_GRAY)


func get_gift_prompt(_player: Node) -> String:
	if state in [State.CHASE, State.RETURN, State.KO, State.SEARCH]:
		return ""
	var d := Inventory.get_drink()
	return "Угостить охранника: %s" % d.display_name if d else ""


func gift(_player: Node) -> void:
	var d := Inventory.take_drink()
	if d:
		NetUtil.call_server(self, "srv_drink", [d.strength, Net.player_name])


## Шанс, что заметит кражу.
func spot_chance(count: int, bulky: bool, drunk: float, value: int = 0) -> float:
	var c: float = SPOT_CHANCE.get(state, 0.5)
	c += 0.05 * (count - 1) + (0.3 if bulky else 0.0) + drunk * 0.002 + clampf(value / 4000.0, 0.0, 0.15)
	# Ночью Михалыч клюёт носом.
	var dc := get_tree().get_first_node_in_group("day_cycle") as DayCycle
	if dc:
		c *= 1.0 - 0.3 * dc.darkness()
	return clampf(c, 0.03, 0.97)


func start_chase(peer: int, reason: int, value: int = 0) -> void:
	if reason == 0:
		var police := get_tree().get_first_node_in_group("police")
		if police:
			police.report(peer, "кража в «Шестёрочке»")
	state = State.CHASE
	_target_peer = peer
	_chase_reason = reason
	_chase_value = value
	_chase_time = 0.0


func is_chasing() -> bool:
	return state == State.CHASE or state == State.SEARCH


func is_out() -> bool:
	return state == State.KO


func run_speed() -> float:
	return BASE_RUN + clampf(_chase_value / 1500.0, 0.0, 1.9)


func give_up_time() -> float:
	return FIGHT_TIME if _chase_reason == 2 else 14.0 + clampf(_chase_value / 80.0, 0.0, 26.0)


func give_up_distance() -> float:
	return 32.0 if _chase_reason == 2 else 24.0 + clampf(_chase_value / 150.0, 0.0, 20.0)


## Ударили битой или кулаком.
func on_melee_hit(by: int, damage: float) -> void:
	if not multiplayer.is_server() or state == State.KO:
		return
	hp -= damage
	if hp <= 0.0:
		_knock_out(by)
		return
	if not (state == State.CHASE and _target_peer == by):
		if state == State.CHASE and _chase_reason == 0:
			return   # погоня за вором важнее
		start_chase(by, 2)
		shop.announce_all("%s полез драться с Михалычем!" % Net.peer_names.get(by, "Кто-то"))
	_chase_time = 0.0


func _knock_out(by: int) -> void:
	var was_chasing_thief := state == State.CHASE and _chase_reason == 0
	state = State.KO
	_timer = KO_TIME
	hp = 0.0
	if was_chasing_thief:
		shop.send_result(_target_peer, ShopController.Result.ESCAPED)
	shop.announce_all("%s вырубил Михалыча! «Шестёрочка» закрыта" % Net.peer_names.get(by, "Кто-то"))
	var combat := get_tree().get_first_node_in_group("combat")
	if combat:
		combat.report_knockout(by, "Михалыч в нокауте!")


## Новый день — очухался.
func reset_day() -> void:
	if state == State.KO:
		state = State.RETURN
	hp = MAX_HP


# ------------------------------------------------------------ сервер

@rpc("any_peer", "reliable")
func srv_distract(pname: String) -> void:
	if not multiplayer.is_server() or state not in [State.WATCH, State.PHONE, State.DOZE]:
		return
	state = State.DISTRACTED
	talker = pname
	_talker_peer = NetUtil.sender(self)
	_timer = _rng.randf_range(10.0, 14.0)
	shop.announce_all("%s заговаривает зубы охраннику" % pname)


@rpc("any_peer", "reliable")
func srv_drink(strength: float, pname: String) -> void:
	if not multiplayer.is_server() or state in [State.CHASE, State.RETURN, State.KO, State.SEARCH]:
		return
	state = State.DOZE
	_timer = 10.0 + strength * 0.8
	shop.announce_all("%s угостил охранника. Михалыч закемарил…" % pname)


## Бутылкой в охранника — плохая идея.
func on_bottle_hit(by: int) -> void:
	if not multiplayer.is_server():
		return
	if state == State.CHASE or state == State.KO:
		return
	hp -= 8.0
	start_chase(by, 1)
	shop.send_result(by, ShopController.Result.HIT_SPOTTED)
	shop.announce_all("%s запустил бутылкой в охранника!" % Net.peer_names.get(by, "Кто-то"))


func _physics_process(delta: float) -> void:
	_t += delta
	_update_visual()
	if not multiplayer.is_server():
		return

	if not is_on_floor():
		velocity.y -= _gravity * delta
	var goal := Vector3.INF
	velocity.x = 0.0
	velocity.z = 0.0
	var speed := WALK_SPEED

	match state:
		State.WATCH, State.PHONE, State.DOZE, State.SUSPICIOUS:
			_timer -= delta
			if _timer <= 0.0:
				_next_idle_state()
			rotation.y = lerp_angle(rotation.y, _post_rot, delta * 3.0)
		State.DISTRACTED:
			_timer -= delta
			_face(_peer_pos(_talker_peer), delta)
			if _timer <= 0.0:
				state = State.SUSPICIOUS
				_timer = 18.0
				talker = ""
		State.CHASE:
			_chase_time += delta
			_punch_cd = maxf(_punch_cd - delta, 0.0)
			var target := _player_node(_target_peer)
			if target == null:
				state = State.RETURN
			elif target.hidden:
				var dist := global_position.distance_to(target.global_position)
				if dist < SEE_HIDE_DISTANCE and _chase_reason != 2:
					_end_chase(true)
					shop.announce_all("Михалыч видел, куда ты спрятался!")
				else:
					state = State.SEARCH
					_search_pos = target.global_position
					_timer = 7.0
			else:
				speed = run_speed()
				goal = _route_to(target.global_position)
				var dist := global_position.distance_to(target.global_position)
				if _chase_reason == 2:
					# Драка: бьёт, пока не устанет или противник не ляжет.
					if dist < CATCH_RADIUS + 0.3:
						goal = Vector3.INF
						_face(target.global_position, delta * 6.0)
						if _punch_cd <= 0.0:
							_punch_cd = PUNCH_COOLDOWN
							_punch_t = 0.3
							NetUtil.call_peer(target, _target_peer, "take_melee", [PUNCH_DAMAGE, "Михалыч"])
					if target.pose == "ko" or _chase_time > give_up_time() or dist > give_up_distance():
						state = State.RETURN
						_return_time = 0.0
				elif dist < CATCH_RADIUS:
					_end_chase(true)
				elif _chase_time > give_up_time() or dist > give_up_distance():
					_end_chase(false)
		State.SEARCH:
			_timer -= delta
			var target := _player_node(_target_peer)
			if target and not target.hidden and global_position.distance_to(target.global_position) < 10.0:
				state = State.CHASE
			else:
				goal = _route_to(_search_pos)
				if global_position.distance_to(_search_pos) < 1.0:
					goal = Vector3.INF
					rotation.y += delta * 1.5
				if _timer <= 0.0:
					if _chase_reason == 2:
						state = State.RETURN
						_return_time = 0.0
					else:
						_end_chase(false)
						shop.announce_all("Михалыч поискал и плюнул")
		State.KO:
			_timer -= delta
			if _timer <= 0.0:
				hp = MAX_HP
				state = State.RETURN
				_return_time = 0.0
				shop.announce_all("Михалыч очухался. «Шестёрочка» снова работает")
		State.RETURN:
			var post := shop.to_global(_post)
			goal = _route_to(post)
			_return_time += delta
			# Застрял по дороге — просто возвращается на пост.
			if _return_time > 25.0:
				global_position = post
			if global_position.distance_to(post) < 0.4:
				_return_time = 0.0
				state = State.SUSPICIOUS
				_timer = 15.0
				global_position = post

	if goal != Vector3.INF:
		var dir := goal - global_position
		dir.y = 0.0
		if dir.length() > 0.1:
			dir = dir.normalized()
			velocity.x = dir.x * speed
			velocity.z = dir.z * speed
			_face(global_position + dir, delta * 4.0)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	NpcMotion.move(self, delta)


func _next_idle_state() -> void:
	var r := _rng.randf()
	if r < 0.45:
		state = State.WATCH
		_timer = _rng.randf_range(12.0, 25.0)
	elif r < 0.8:
		state = State.PHONE
		_timer = _rng.randf_range(8.0, 16.0)
	else:
		state = State.DOZE
		_timer = _rng.randf_range(8.0, 14.0)


func _end_chase(caught: bool) -> void:
	var R = ShopController.Result
	var result: int
	if _chase_reason == 0:
		result = R.BUSTED if caught else R.ESCAPED
	else:
		result = R.HIT_BUSTED if caught else R.HIT_ESCAPED
	shop.send_result(_target_peer, result)
	var pname: String = Net.peer_names.get(_target_peer, "вор")
	shop.announce_all("Михалыч поймал %s!" % pname if caught else "%s удрал от охранника!" % pname)
	state = State.RETURN
	_return_time = 0.0


## Маршрут: если один внутри магазина, а другой снаружи — сначала к двери.
func _route_to(target: Vector3) -> Vector3:
	var me := _zone(global_position)
	var it := _zone(target)
	if me == it:
		return _around_building(target) if me == Zone.OUTSIDE else target
	var local := shop.to_local(global_position)
	match me:
		Zone.INSIDE:
			# Сначала встать напротив двери, потом в проём.
			if absf(local.x) > 0.4:
				return shop.to_global(Vector3(0, 0, 4.3))
			return shop.to_global(Vector3(0, 0, 5.5))
		Zone.DOOR:
			# В проёме идём строго прямо — внутрь или наружу.
			if it == Zone.INSIDE:
				return shop.to_global(Vector3(0, 0, 4.0))
			return shop.to_global(Vector3(0, 0, 7.9))
		_:
			# Снаружи: сначала встать перед дверью (обходя здание).
			if absf(local.x) > 0.4 or local.z < 5.5:
				return _around_building(shop.to_global(Vector3(0, 0, 7.3)))
			return shop.to_global(Vector3(0, 0, 5.5))


enum Zone { OUTSIDE, DOOR, INSIDE }

## Габариты здания с запасом (локально) и углы для обхода.
const BLD := Vector2(8.6, 6.1)
const CORNERS := [Vector2(9.2, 7.2), Vector2(-9.2, 7.2), Vector2(9.2, -6.8), Vector2(-9.2, -6.8)]


## Если прямой путь снаружи упирается в здание — идём через ближайший удобный угол.
func _around_building(target: Vector3) -> Vector3:
	var a := _l2(global_position)
	var b := _l2(target)
	if not _blocked(a, b):
		return target
	var best := Vector2.INF
	var best_cost := INF
	for c: Vector2 in CORNERS:
		if _blocked(a, c):
			continue
		var cost := a.distance_to(c) + c.distance_to(b) + (0.0 if not _blocked(c, b) else 20.0)
		if cost < best_cost:
			best_cost = cost
			best = c
	if best == Vector2.INF:
		return target
	return shop.to_global(Vector3(best.x, 0, best.y))


func _l2(p: Vector3) -> Vector2:
	var l := shop.to_local(p)
	return Vector2(l.x, l.z)


func _blocked(a: Vector2, b: Vector2) -> bool:
	var r := [Vector2(-BLD.x, -BLD.y), Vector2(BLD.x, -BLD.y), Vector2(BLD.x, BLD.y), Vector2(-BLD.x, BLD.y)]
	for i in 4:
		if Geometry2D.segment_intersects_segment(a, b, r[i], r[(i + 1) % 4]) != null:
			return true
	return false


func _zone(p: Vector3) -> Zone:
	var l := shop.to_local(p)
	if absf(l.x) < 1.4 and l.z >= 4.75 and l.z < 6.8:
		return Zone.DOOR
	if shop.is_inside(p):
		return Zone.INSIDE
	return Zone.OUTSIDE


var _prev_pos := Vector3.ZERO
var _rs := 0.0


func _remote_speed() -> float:
	var d := global_position - _prev_pos
	d.y = 0.0
	_prev_pos = global_position
	_rs = lerpf(_rs, d.length() / maxf(get_physics_process_delta_time(), 0.001), 0.2)
	return _rs


func _player_node(peer: int) -> Node3D:
	return get_tree().get_root().get_node_or_null("World/Players/%d" % peer) as Node3D


func _peer_pos(peer: int) -> Vector3:
	var p := _player_node(peer)
	return p.global_position if p else global_position - global_basis.z


func _face(point: Vector3, weight: float) -> void:
	var d := point - global_position
	if Vector2(d.x, d.z).length() < 0.05:
		return
	global_rotation.y = lerp_angle(global_rotation.y, atan2(-d.x, -d.z), clampf(weight, 0.0, 1.0))


# ------------------------------------------------------------ как выглядит (у всех)

func _update_visual() -> void:
	visual.speed = Vector2(velocity.x, velocity.z).length() if multiplayer.is_server() else _remote_speed()
	visual.pose = "idle"
	visual.set_face("guard")
	match state:
		State.WATCH:
			label.text = "*бдит*"
			visual.set_head_tilt(0.0, sin(_t * 0.7) * 0.25)
		State.PHONE:
			label.text = "*залип в телефон*"
			visual.pose = "phone"
			visual.set_head_tilt(0.0)
		State.DOZE:
			label.text = "Zzz…"
			visual.set_face("guard_sleep")
			visual.set_head_tilt(0.5, 0.35)
		State.DISTRACTED:
			label.text = "*болтает с %s*" % talker
			visual.pose = "talk"
			visual.set_head_tilt(0.0, sin(_t * 3.0) * 0.1)
		State.SUSPICIOUS:
			label.text = "*подозрительно косится*"
			visual.set_head_tilt(0.0, sin(_t * 1.5) * 0.4)
		State.CHASE:
			visual.set_head_tilt(0.1)
		State.RETURN:
			label.text = "*пыхтит*"
			visual.set_head_tilt(0.0)
		State.SEARCH:
			label.text = "*ищет* Где ты, гад?!"
			visual.set_head_tilt(0.0, sin(_t * 4.0) * 0.5)
		State.KO:
			label.text = "*в отключке*"
			visual.pose = "ko"
			visual.set_face("guard_sleep")
	if state == State.CHASE:
		if _chase_reason == 2:
			label.text = "Ну держись!!!"
			if _punch_t > 0.0:
				visual.pose = "punch"
		else:
			label.text = "СТОЯТЬ!!!"
	_punch_t = maxf(_punch_t - get_physics_process_delta_time(), 0.0)
	label.modulate = Color.TOMATO if state == State.CHASE or state == State.SEARCH else Color(1, 1, 1, 0.85)
