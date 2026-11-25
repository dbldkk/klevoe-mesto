class_name Vehicle
extends CharacterBody3D
## Транспорт: лодка, велосипед «Кама», «Нива». Едет на хосте: водитель шлёт газ/руль (send_input),
## хост двигает и рассылает позицию через Sync. Игроки сидят на местах (seat_transform).
## Лодка плавает только по воде, машина и велосипед — только по суше.
## Пьяный водитель виляет; пьяный на лодке на резком повороте может её перевернуть.

const SPECS := {
	"boat": {"name": "Лодка", "seats": [Vector3(0, -0.12, 0.35), Vector3(0, -0.12, -0.95)],
		"poses": ["row", "sit"], "max": 3.4, "accel": 1.4, "turn": 1.1, "exit": Vector3(1.6, 0.4, 0)},
	"bike": {"name": "Велосипед «Кама»", "seats": [Vector3(0, -0.05, 0.12)],
		"poses": ["bike"], "max": 7.5, "accel": 3.2, "turn": 1.9, "exit": Vector3(1.0, 0.3, 0)},
	"niva": {"name": "«Нива»", "seats": [Vector3(-0.38, 0.05, 0.1), Vector3(0.38, 0.05, 0.1),
		Vector3(-0.38, 0.05, 0.95), Vector3(0.38, 0.05, 0.95)],
		"poses": ["drive", "sit", "sit", "sit"], "max": 15.0, "accel": 5.0, "turn": 1.25, "exit": Vector3(1.8, 0.3, 0)},
}

@export_enum("boat", "bike", "niva") var kind: String = "boat"
## Аренда на день (0 — бесплатно).
@export var rent_price: int = 0
## Где стоит по умолчанию: место Layout + смещение (если пусто — позиция из сцены).
@export var home_spot: String = ""
@export var home_offset: Vector3 = Vector3.ZERO
@export var home_yaw: float = 0.0

## Синхронизируется с хоста:
@export var speed: float = 0.0
@export var occupants: PackedInt32Array = PackedInt32Array()
@export var rented_day: int = -1
@export var capsized: float = 0.0
@export var steer_vis: float = 0.0

var spec: Dictionary
var visual: Node3D
## Сглаженное положение для вида и мест (между тиками физики у хоста и между пакетами сети у клиентов).
var _vis_xf := Transform3D.IDENTITY
var _prev_xf := Transform3D.IDENTITY
var _cur_xf := Transform3D.IDENTITY
var _rock := Vector3.ZERO     ## качка/наклон вида
var _in := {"th": 0.0, "st": 0.0, "drunk": 0.0, "t": -10.0}
var _t := 0.0
var _home := Transform3D()
var _wheels: Array[Node3D] = []
var _oars: Array[Node3D] = []
var _front_wheel: Node3D
var _lights: Array[Node3D] = []
var _snd: AudioStreamPlayer3D
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _rng := RandomNumberGenerator.new()


func _enter_tree() -> void:
	if home_spot != "":
		var t := Layout.xform(home_spot)
		var p := t * home_offset
		transform = Transform3D(Basis(Vector3.UP, t.basis.get_euler().y + home_yaw), p)


func _ready() -> void:
	add_to_group("vehicles")
	_rng.randomize()
	spec = SPECS[kind]
	collision_layer = 1
	collision_mask = 1
	if kind != "boat":
		position.y = Terrain.height(position.x, position.z) + 0.05
	else:
		position.y = Terrain.WATER_Y
	_home = transform
	process_priority = -10            # раньше игроков: они садятся уже по новому положению
	process_physics_priority = -10
	if occupants.size() != spec.seats.size():
		occupants.resize(spec.seats.size())
		occupants.fill(0)
	visual = Node3D.new()
	add_child(visual)
	match kind:
		"boat": _build_boat()
		"bike": _build_bike()
		"niva": _build_niva()
	# Зона «смотришь и жмёшь E» — чуть больше корпуса, чтобы луч попадал в неё раньше, чем в корпус.
	match kind:
		"boat": Build.talk_area(self, Vector3(0, 0.35, 0), Vector3(1.8, 1.4, 3.4), self)
		"bike": Build.talk_area(self, Vector3(0, 0.6, 0), Vector3(1.0, 1.4, 2.0), self)
		"niva": Build.talk_area(self, Vector3(0, 1.0, 0), Vector3(2.3, 2.1, 4.4), self)
	_snd = AudioStreamPlayer3D.new()
	_snd.bus = "Effects"
	_snd.stream = Sfx.stream_of({"boat": "oars", "bike": "bike", "niva": "engine"}[kind])
	_snd.unit_size = 5.0
	_snd.max_distance = 40.0
	add_child(_snd)
	Events.new_day.connect(func(_d: int) -> void:
		if multiplayer.is_server() and _empty():
			_go_home())
	if kind == "boat" and name.ends_with("0"):
		add_to_group("poi")
		set_meta("poi_name", "Прокат лодок")
	elif kind == "niva":
		add_to_group("poi")
		set_meta("poi_name", "Прокат «Нивы»")


# ------------------------------------------------------------ модели
	visual.top_level = true
	_vis_xf = global_transform
	_prev_xf = global_transform
	_cur_xf = global_transform


func _box(pos: Vector3, size: Vector3, mat: Material, collide := false, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := Art.add_mesh(visual, Art.box(size), mat, pos, rot)
	if collide:
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		cs.position = pos
		cs.rotation = rot
		add_child(cs)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return mi


func _build_boat() -> void:
	var wood := Art.tex_world("planks", 0.9).duplicate() as StandardMaterial3D
	wood.uv1_world_triplanar = false
	var paint := Art.color(Color(0.2, 0.42, 0.35), 0.7)
	_box(Vector3(0, -0.12, 0), Vector3(1.2, 0.08, 3.0), wood, true)
	for x in [-0.62, 0.62]:
		_box(Vector3(x, 0.05, 0), Vector3(0.06, 0.38, 3.0), paint, false, Vector3(0, 0, 0.25 * signf(x)))
	_box(Vector3(0, 0.05, -1.55), Vector3(1.0, 0.38, 0.08), paint, false, Vector3(0.4, 0, 0))
	_box(Vector3(0, 0.05, 1.52), Vector3(1.1, 0.36, 0.06), paint)
	for z in [0.35, -0.95]:
		_box(Vector3(0, 0.26, z), Vector3(1.15, 0.05, 0.32), wood)
	for side in [-1.0, 1.0]:
		var oar := Node3D.new()
		oar.position = Vector3(0.68 * side, 0.25, 0.3)
		visual.add_child(oar)
		Art.add_mesh(oar, Art.cyl(0.025, 0.025, 1.8, 6), Art.color(Color(0.55, 0.4, 0.25)), Vector3(0.75 * side, -0.15, 0), Vector3(0, 0, PI / 2 + 0.2 * side))
		Art.add_mesh(oar, Art.box(Vector3(0.35, 0.02, 0.16)), Art.color(Color(0.55, 0.4, 0.25)), Vector3(1.55 * side, -0.33, 0))
		_oars.append(oar)
	Build.text(visual, Vector3(0.66, 0.1, 0.6), "№%s" % name.right(1), 40, Color.WHITE, 0.005, PI / 2)


func _build_bike() -> void:
	var frame_m := Art.color(Color(0.65, 0.12, 0.12), 0.4, 0.5)
	var black := Art.color(Color(0.08, 0.08, 0.08), 0.8)
	var chrome := Art.color(Color(0.8, 0.8, 0.82), 0.25, 0.8)
	for z in [-0.55, 0.55]:
		var w := Node3D.new()
		w.position = Vector3(0, 0.34, z)
		visual.add_child(w)
		Art.add_mesh(w, Art.cyl(0.33, 0.33, 0.04, 20), black, Vector3.ZERO, Vector3(0, 0, PI / 2))
		Art.add_mesh(w, Art.cyl(0.28, 0.28, 0.045, 20), chrome, Vector3.ZERO, Vector3(0, 0, PI / 2))
		Art.add_mesh(w, Art.box(Vector3(0.05, 0.56, 0.02)), chrome, Vector3.ZERO)
		_wheels.append(w)
	_front_wheel = _wheels[0]
	_box(Vector3(0, 0.62, 0.0), Vector3(0.05, 0.05, 0.95), frame_m, false, Vector3(-0.15, 0, 0))
	_box(Vector3(0, 0.5, 0.2), Vector3(0.05, 0.55, 0.05), frame_m, false, Vector3(0.25, 0, 0))
	_box(Vector3(0, 0.82, 0.25), Vector3(0.16, 0.05, 0.25), black)
	_box(Vector3(0, 0.85, -0.5), Vector3(0.55, 0.04, 0.04), chrome)
	_box(Vector3(0, 0.6, -0.52), Vector3(0.04, 0.5, 0.04), chrome)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.4, 0.9, 1.6)
	cs.shape = sh
	cs.position = Vector3(0, 0.45, 0)
	add_child(cs)


func _build_niva() -> void:
	var body_m := Art.color(Color(0.92, 0.9, 0.84), 0.45, 0.25)
	var glass := Art.glass(Color(0.25, 0.35, 0.45, 0.7))
	var black := Art.color(Color(0.08, 0.08, 0.08), 0.8)
	_box(Vector3(0, 0.75, 0), Vector3(1.65, 0.6, 3.8), body_m, true)
	_box(Vector3(0, 1.33, 0.35), Vector3(1.55, 0.58, 2.1), body_m)
	_box(Vector3(0, 1.33, -0.72), Vector3(1.45, 0.5, 0.04), glass, false, Vector3(-0.35, 0, 0))
	for x in [-0.79, 0.79]:
		_box(Vector3(x, 1.35, 0.35), Vector3(0.03, 0.42, 1.9), glass)
	_box(Vector3(0, 1.35, 1.41), Vector3(1.4, 0.42, 0.03), glass)
	_box(Vector3(0, 0.65, -1.92), Vector3(1.5, 0.25, 0.08), Art.color(Color(0.2, 0.2, 0.22), 0.4, 0.6))
	Build.text(visual, Vector3(0, 0.72, -1.97), "ВАЗ-2121", 36, Color(0.15, 0.15, 0.15), 0.005, PI)
	for x in [-0.6, 0.6]:
		var hl := Art.add_mesh(visual, Art.cyl(0.11, 0.11, 0.04, 14), Build.glow_mat(Color(1, 0.97, 0.85), 0.3), Vector3(x, 0.8, -1.92), Vector3(PI / 2, 0, 0))
		var l := SpotLight3D.new()
		l.position = Vector3(x, 0.8, -1.95)
		l.spot_range = 25.0
		l.spot_angle = 30.0
		l.light_energy = 2.5
		l.visible = false
		visual.add_child(l)
		_lights.append(l)
		_lights.append(hl)
	for x in [-0.82, 0.82]:
		for z in [-1.2, 1.2]:
			var w := Node3D.new()
			w.position = Vector3(x, 0.36, z)
			visual.add_child(w)
			Art.add_mesh(w, Art.cyl(0.36, 0.36, 0.26, 16), black, Vector3.ZERO, Vector3(0, 0, PI / 2))
			Art.add_mesh(w, Art.cyl(0.2, 0.2, 0.27, 12), Art.color(Color(0.6, 0.6, 0.62), 0.3, 0.6), Vector3.ZERO, Vector3(0, 0, PI / 2))
			_wheels.append(w)


# ------------------------------------------------------------ места

func seat_transform(i: int) -> Transform3D:
	var seats: Array = spec.seats
	return _vis_xf * Transform3D(Basis(), seats[clampi(i, 0, seats.size() - 1)])


func smooth_yaw() -> float:
	return _vis_xf.basis.get_euler().y


## Вид двигаем каждый кадр отрисовки: у хоста — интерполяция между тиками физики,
## у клиентов — плавно догоняем то, что пришло по сети. Так лодка и машина не дёргаются.
func _process(delta: float) -> void:
	if multiplayer.is_server():
		_vis_xf = _prev_xf.interpolate_with(_cur_xf, Engine.get_physics_interpolation_fraction())
	else:
		if _vis_xf.origin.distance_to(global_position) > 6.0:
			_vis_xf = global_transform
		else:
			_vis_xf = _vis_xf.interpolate_with(global_transform, 1.0 - exp(-delta * 14.0))
	_vis_xf = _vis_xf.orthonormalized()
	visual.global_transform = _vis_xf * Transform3D(Basis.from_euler(_rock), Vector3.ZERO)


func seat_pose(i: int) -> String:
	var poses: Array = spec.poses
	return poses[clampi(i, 0, poses.size() - 1)]


func exit_point(i: int) -> Vector3:
	var e: Vector3 = spec.exit
	var side := -1.0 if (i % 2 == 0) else 1.0
	return global_transform * Vector3(e.x * side, e.y, (spec.seats[i] as Vector3).z)


func enter_hint(i: int) -> String:
	if i == 0:
		match kind:
			"boat": return "На вёслах: W/S — грести, A/D — поворот, E — выйти. Остановись — и можно рыбачить"
			"bike": return "W — крутить педали, A/D — руль, Пробел — звонок, E — слезть"
			"niva": return "W/S — газ/назад, A/D — руль, Пробел — гудок, E — выйти. Пьяным лучше не садиться…"
	return "Ты пассажир. E — выйти" + ("; с лодки можно рыбачить" if kind == "boat" else "")


func allows_fishing(i: int) -> bool:
	return kind == "boat" and (i != 0 or absf(speed) < 0.5)


func _empty() -> bool:
	for o in occupants:
		if o != 0:
			return false
	return true


func _today() -> int:
	var dc := get_tree().get_first_node_in_group("day_cycle") as DayCycle
	return dc.day if dc else 1


# ------------------------------------------------------------ взаимодействие (у игрока)

func get_prompt(player: Node) -> String:
	if player.vehicle:
		return ""
	if capsized > 0.0:
		return "%s перевёрнута…" % spec.name
	if rent_price > 0 and rented_day != _today():
		return "Арендовать: %s — %d ₽ до утра" % [spec.name, rent_price]
	if occupants[0] == 0:
		return "Сесть за руль: %s" % spec.name if kind != "boat" else "Сесть на вёсла"
	for i in range(1, occupants.size()):
		if occupants[i] == 0:
			return "Сесть пассажиром (%s)" % spec.name
	return "Мест нет"


func interact(player: Node) -> void:
	if player.vehicle or capsized > 0.0:
		return
	if player.is_busy_body() or player.fishing.is_busy():
		return
	if rent_price > 0 and rented_day != _today():
		if Inventory.money < rent_price:
			Events.notify("Аренда стоит %d ₽ — не хватает" % rent_price, Color.TOMATO)
			return
		Inventory.money -= rent_price
		Inventory.stat_add("spent", rent_price)
		Inventory.changed.emit()
		Sfx.play("coin", null, -4.0)
		Events.notify("Арендовал %s до утра" % spec.name, Color.GOLD)
		NetUtil.call_server(self, "srv_rent", [])
	NetUtil.call_server(self, "srv_enter", [])


@rpc("any_peer", "reliable")
func srv_rent() -> void:
	if multiplayer.is_server():
		rented_day = _today()


@rpc("any_peer", "reliable")
func srv_enter() -> void:
	if not multiplayer.is_server() or capsized > 0.0:
		return
	var peer := NetUtil.sender(self)
	_cleanup()
	if peer in occupants:
		return
	if rent_price > 0 and rented_day != _today():
		return
	for i in occupants.size():
		if occupants[i] == 0:
			occupants[i] = peer
			NetUtil.call_peer(self, peer, "enter_ok", [i])
			return


@rpc("authority", "reliable")
func enter_ok(i: int) -> void:
	var p := get_tree().get_first_node_in_group("local_player")
	if p:
		p.enter_vehicle(self, i)
		Sfx.play("door_close" if kind == "niva" else "box_pick", global_position, -6.0)


func request_exit() -> void:
	NetUtil.call_server(self, "srv_exit", [])


@rpc("any_peer", "reliable")
func srv_exit() -> void:
	if not multiplayer.is_server():
		return
	var peer := NetUtil.sender(self)
	var i := occupants.find(peer)
	if i < 0:
		return
	occupants[i] = 0
	NetUtil.call_peer(self, peer, "exit_ok", [false])


@rpc("authority", "reliable")
func exit_ok(into_water: bool) -> void:
	var p := get_tree().get_first_node_in_group("local_player")
	if p and p.vehicle == self:
		p.exit_vehicle(into_water)


func honk() -> void:
	NetUtil.call_all(self, "play_honk", [])


@rpc("any_peer", "call_remote", "reliable")
func play_honk() -> void:
	Sfx.play("bell" if kind == "bike" else ("horn" if kind == "niva" else "splash"), global_position + Vector3.UP)


## Водитель (у клиента) → хосту.
func send_input(th: float, st: float, drunk: float) -> void:
	if multiplayer.is_server():
		srv_input(th, st, drunk)
	else:
		srv_input.rpc_id(1, th, st, drunk)


@rpc("any_peer", "unreliable_ordered")
func srv_input(th: float, st: float, drunk: float) -> void:
	if not multiplayer.is_server():
		return
	if occupants.size() == 0 or occupants[0] != NetUtil.sender(self):
		return
	_in = {"th": clampf(th, -1.0, 1.0), "st": clampf(st, -1.0, 1.0), "drunk": clampf(drunk, 0.0, 100.0),
		"t": Time.get_ticks_msec() / 1000.0}


# ------------------------------------------------------------ движение (хост)

func _cleanup() -> void:
	for i in occupants.size():
		var o := occupants[i]
		if o != 0 and get_tree().get_root().get_node_or_null("World/Players/%d" % o) == null:
			occupants[i] = 0
	

func _physics_process(delta: float) -> void:
	_t += delta
	_animate(delta)
	if not multiplayer.is_server():
		return
	_prev_xf = _cur_xf
	_step(delta)
	_cur_xf = global_transform
	if _prev_xf.origin.distance_to(_cur_xf.origin) > 6.0:
		_prev_xf = _cur_xf   # телепорт домой — без «полёта»


func _step(delta: float) -> void:
	if int(_t * 2.0) % 6 == 0:
		_cleanup()
	if capsized > 0.0:
		capsized = maxf(capsized - delta, 0.0)
		return
	var fresh: bool = Time.get_ticks_msec() / 1000.0 - float(_in.t) < 0.5 and occupants[0] != 0
	var th: float = _in.th if fresh else 0.0
	var st: float = _in.st if fresh else 0.0
	var drunk: float = _in.drunk if fresh else 0.0
	var mx: float = spec.max
	var acc: float = spec.accel
	if kind == "bike" and th < 0.0:
		th *= 0.3   # назад на велике — только тормоз
	if th != 0.0:
		speed = move_toward(speed, th * mx * (0.4 if th < 0.0 else 1.0), acc * delta)
	else:
		speed = move_toward(speed, 0.0, acc * (0.6 if kind == "boat" else 1.2) * delta)
	# Пьяный руль
	var wob := sin(_t * 1.3) * 0.5 + sin(_t * 3.1) * 0.25
	st += wob * drunk / 100.0 * (0.9 if kind != "boat" else 0.6)
	steer_vis = lerpf(steer_vis, st, delta * 6.0)
	var k := clampf(absf(speed) / mx * 1.6, 0.0, 1.0)
	rotation.y -= st * float(spec.turn) * k * signf(speed if speed != 0.0 else 1.0) * delta
	var dir := -global_basis.z
	if kind == "boat":
		_move_boat(dir, delta, st, drunk)
	else:
		_move_ground(dir, delta)


func _move_boat(dir: Vector3, delta: float, st: float, drunk: float) -> void:
	var next := global_position + dir * speed * delta
	if Terrain.height(next.x, next.z) > Terrain.WATER_Y - 0.35:
		speed *= -0.3   # упёрлись в берег
	else:
		global_position = Vector3(next.x, Terrain.WATER_Y - 0.02, next.z)
	# Пьяный, резкий поворот на скорости — переворот.
	if drunk > 70.0 and absf(st) > 0.7 and absf(speed) > 1.8 and _rng.randf() < 0.4 * delta:
		_capsize()


func _move_ground(dir: Vector3, delta: float) -> void:
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = -0.5
	var before := absf(speed)
	var ahead := global_position + dir * signf(speed) * 1.8
	if Terrain.height(ahead.x, ahead.z) < Terrain.WATER_Y + 0.05 and absf(speed) > 0.1 and not Terrain.on_bridge(ahead.x, ahead.z) and not Terrain.on_bridge(global_position.x, global_position.z):
		speed = 0.0     # в воду не едем
		velocity.x = 0.0
		velocity.z = 0.0
	move_and_slide()
	if get_slide_collision_count() > 0:
		var floor_y := -INF
		for i in get_slide_collision_count():
			var fc := get_slide_collision(i)
			if fc.get_normal().y > 0.7:
				floor_y = maxf(floor_y, fc.get_position().y)
		for i in get_slide_collision_count():
			var c := get_slide_collision(i)
			# Невысокая ступенька (край моста, бордюр) — заезжаем, а не бьёмся.
			var step := c.get_position().y - floor_y if floor_y > -INF else 1.0
			if absf(c.get_normal().y) < 0.7 and step < 0.35 and absf(before) > 0.2:
				global_position.y += step + 0.06
				continue
			if absf(c.get_normal().y) < 0.5:
				speed *= 0.2
				if before > 7.0:
					NetUtil.call_all(self, "crash_fx", [before])
					for o in occupants:
						if o != 0:
							var p := get_tree().get_root().get_node_or_null("World/Players/%d" % o)
							if p:
								NetUtil.call_peer(p, o, "crash_hurt", [clampf(before * 1.5, 5.0, 30.0)])
				break
	if global_position.y < -20.0:
		_go_home()


@rpc("authority", "call_remote", "reliable")
func crash_fx(_s: float) -> void:
	Sfx.play("crash", global_position + Vector3.UP)


func _capsize() -> void:
	capsized = 6.0
	speed = 0.0
	NetUtil.call_all(self, "announce", ["Лодка перевернулась! Все в воду!"])
	for i in occupants.size():
		var o := occupants[i]
		if o != 0:
			occupants[i] = 0
			NetUtil.call_peer(self, o, "exit_ok", [true])


@rpc("authority", "call_remote", "reliable")
func announce(text: String) -> void:
	Events.notify(text, Color(0.6, 0.85, 1.0))
	Sfx.play("splash_big", global_position)


func _go_home() -> void:
	transform = _home
	speed = 0.0
	capsized = 0.0


# ------------------------------------------------------------ вид и звук (у всех)

func _animate(delta: float) -> void:
	match kind:
		"boat":
			_rock.z = sin(_t * 1.1) * 0.03 - steer_vis * 0.04 + (PI if capsized > 0.0 else 0.0)
			_rock.x = sin(_t * 0.8) * 0.02
			for i in _oars.size():
				var side := -1.0 if i == 0 else 1.0
				var a := sin(_t * 3.0) * 0.6 if absf(speed) > 0.2 else 0.0
				_oars[i].rotation = Vector3(0, a * side, (0.25 + cos(_t * 3.0) * 0.15 if absf(speed) > 0.2 else 0.3) * side)
		"bike", "niva":
			var r := 0.36 if kind == "niva" else 0.33
			for w in _wheels:
				w.rotation.x -= speed / r * delta
			if _front_wheel:
				_front_wheel.rotation.y = -steer_vis * 0.4
			_rock.z = lerpf(_rock.z, steer_vis * (0.15 if kind == "bike" else 0.02) * clampf(absf(speed) / 4.0, 0.0, 1.0), delta * 5.0)
			if kind == "bike" and occupants.size() > 0 and occupants[0] == 0:
				_rock.z = 0.25   # стоит, наклонившись
	# фары «Нивы» ночью, когда в ней водитель
	if kind == "niva":
		var dc := get_tree().get_first_node_in_group("day_cycle") as DayCycle
		var on: bool = occupants.size() > 0 and occupants[0] != 0 and dc != null and dc.is_night()
		for l in _lights:
			if l is SpotLight3D:
				l.visible = on
			else:
				((l as MeshInstance3D).material_override as StandardMaterial3D).emission_energy_multiplier = 3.0 if on else 0.3
	# звук: вёсла / цепь / мотор
	var moving := absf(speed) > 0.3
	var engine_on: bool = kind == "niva" and occupants.size() > 0 and occupants[0] != 0
	if moving or engine_on:
		if not _snd.playing:
			_snd.play()
		_snd.pitch_scale = 0.7 + absf(speed) / float(spec.max) * (0.9 if kind == "niva" else 0.5)
		_snd.volume_db = -10.0 if kind == "niva" else -14.0
	elif _snd.playing:
		_snd.stop()
