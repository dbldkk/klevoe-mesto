extends CharacterBody3D
## Корова Зорька. Пасётся на пастбище совхоза; во время смены то и дело удирает (пьяных пастухов
## особенно не любит). Пастух подходит и жмёт E — Зорька идёт за ним, пока не окажется на пастбище.
## Решает хост; позиция/поворот/состояние/время — через Sync.

enum S { HOME, GRAZE, ESCAPE, ROAM, FOLLOW }

@export var state: int = S.HOME
@export var graze_left: float = 0.0
@export var herder_name: String = ""

var _herder := 0
var _goal := Vector3.ZERO
var _t := 0.0
var _think := 0.0
var _follow_t := 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _rng := RandomNumberGenerator.new()
var _legs: Array[Node3D] = []
var _head: Node3D
var _tail: Node3D
var _label: Label3D
var _prev := Vector3.ZERO
var _spd := 0.0
var _moo_t := 8.0
var _calm := 0.0   ## после возвращения какое-то время не убегает


func _ready() -> void:
	add_to_group("cow")
	add_to_group("npc")
	_rng.randomize()
	collision_layer = 8
	collision_mask = 1
	var cs := CollisionShape3D.new()
	var sh := CapsuleShape3D.new()
	sh.radius = 0.45
	sh.height = 1.3
	cs.shape = sh
	cs.position.y = 0.75
	add_child(cs)
	_build()
	_label = Build.text(self, Vector3(0, 2.0, 0), "Зорька", 36, Color(1, 0.95, 0.85), 0.006, 0.0, true)
	Build.talk_area(self, Vector3(0, 0.9, 0), Vector3(1.4, 1.6, 2.4), self)
	if multiplayer.is_server():
		global_position = Farm.pasture_point(0.0, 0.3) + Vector3.UP * 0.3
		_goal = global_position


func _build() -> void:
	var white := Art.color(Color(0.95, 0.93, 0.88), 0.8)
	var black := Art.color(Color(0.1, 0.09, 0.08), 0.8)
	var pink := Art.color(Color(0.92, 0.65, 0.65), 0.7)
	var v := Node3D.new()
	add_child(v)
	Art.add_mesh(v, Art.box(Vector3(0.85, 0.75, 1.6)), white, Vector3(0, 1.0, 0))
	for p in [Vector3(0.36, 1.1, 0.3), Vector3(-0.38, 0.95, -0.35), Vector3(0.1, 1.38, -0.2), Vector3(-0.2, 1.2, 0.55)]:
		Art.add_mesh(v, Art.box(Vector3(0.18, 0.4, 0.45)), black, p)
	Art.add_mesh(v, Art.sphere(0.17, 10), pink, Vector3(0, 0.6, 0.35), Vector3.ZERO, Vector3(1, 0.7, 1.2))   # вымя
	_head = Node3D.new()
	_head.position = Vector3(0, 1.25, -0.85)
	v.add_child(_head)
	Art.add_mesh(_head, Art.box(Vector3(0.42, 0.45, 0.55)), white, Vector3(0, 0, -0.15))
	Art.add_mesh(_head, Art.box(Vector3(0.36, 0.25, 0.2)), pink, Vector3(0, -0.12, -0.48))
	Art.add_mesh(_head, Art.box(Vector3(0.44, 0.18, 0.2)), black, Vector3(0, 0.14, -0.1))
	for sd in [-1.0, 1.0]:
		Art.add_mesh(_head, Art.cyl(0.03, 0.015, 0.2, 6), Art.color(Color(0.9, 0.85, 0.7)), Vector3(0.18 * sd, 0.28, 0.0), Vector3(0, 0, -0.6 * sd))
		Art.add_mesh(_head, Art.box(Vector3(0.18, 0.06, 0.1)), white, Vector3(0.28 * sd, 0.12, 0.0))
		Art.add_mesh(_head, Art.sphere(0.04, 6), black, Vector3(0.15 * sd, 0.08, -0.42))
	Art.add_mesh(_head, Art.cyl(0.05, 0.05, 0.08, 8), Art.color(Color(0.8, 0.65, 0.2), 0.3, 0.8), Vector3(0, -0.32, -0.15))   # колокольчик
	for x in [-0.3, 0.3]:
		for z in [-0.6, 0.6]:
			var leg := Node3D.new()
			leg.position = Vector3(x, 0.65, z)
			v.add_child(leg)
			Art.add_mesh(leg, Art.box(Vector3(0.16, 0.65, 0.16)), white, Vector3(0, -0.3, 0))
			Art.add_mesh(leg, Art.box(Vector3(0.17, 0.08, 0.17)), black, Vector3(0, -0.62, 0))
			_legs.append(leg)
	_tail = Node3D.new()
	_tail.position = Vector3(0, 1.3, 0.8)
	v.add_child(_tail)
	Art.add_mesh(_tail, Art.cyl(0.025, 0.025, 0.7, 6), white, Vector3(0, -0.35, 0.05))
	Art.add_mesh(_tail, Art.sphere(0.06, 6), black, Vector3(0, -0.72, 0.05))


# ------------------------------------------------------------ взаимодействие

func get_prompt(p: Node) -> String:
	if state in [S.ESCAPE, S.ROAM] and p.player_name == herder_name:
		return "E — гнать Зорьку на пастбище"
	if state == S.FOLLOW:
		return ""
	return "Погладить Зорьку"


func interact(p: Node) -> void:
	NetUtil.call_server(self, "srv_lead", [p.player_name])


@rpc("any_peer", "reliable")
func srv_lead(who: String) -> void:
	if not multiplayer.is_server():
		return
	var peer := NetUtil.sender(self)
	if who == herder_name and state in [S.ESCAPE, S.ROAM]:
		state = S.FOLLOW
		_follow_t = 30.0
		_herder = peer
		NetUtil.call_all(self, "moo", [])
	else:
		NetUtil.call_peer(self, peer, "petted", [])


@rpc("authority", "reliable")
func petted() -> void:
	Events.notify(["Зорька довольно фыркнула", "Му-у… (Зорька не против)", "Тёплая. Пахнет сеном"].pick_random(), Color(0.9, 0.9, 0.8))


@rpc("authority", "call_remote", "reliable")
func moo() -> void:
	Sfx.play("moo", global_position + Vector3.UP, 0.0, 0.1)


# ------------------------------------------------------------ смена (сервер)

func start_shift(peer: int, who: String) -> void:
	_herder = peer
	herder_name = who
	graze_left = Farm.COW_SHIFT
	state = S.GRAZE
	_calm = 12.0
	_goal = Farm.pasture_point(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1))


func _end_shift(ok: bool) -> void:
	var farm := get_tree().get_first_node_in_group("farm")
	if farm:
		farm.cow_finished(_herder, herder_name, ok)
	state = S.HOME
	herder_name = ""
	graze_left = 0.0
	_goal = Farm.pasture_point(0.0, 0.3)


func _physics_process(delta: float) -> void:
	if not Net.is_online():
		return
	_t += delta
	_animate(delta)
	if not multiplayer.is_server():
		return
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = -0.5
	var herder := get_tree().get_root().get_node_or_null("World/Players/%d" % _herder) as Node3D
	if state != S.HOME and herder == null:
		_end_shift(false)
	_think -= delta
	_calm -= delta
	var inside := Farm.in_pasture(global_position)
	var spd := 0.9
	match state:
		S.HOME, S.GRAZE:
			if state == S.GRAZE and inside:
				graze_left -= delta
				if graze_left <= 0.0:
					_end_shift(true)
			if _think <= 0.0:
				_think = _rng.randf_range(5.0, 10.0)
				_goal = Farm.pasture_point(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1))
				if state == S.GRAZE and herder and _calm <= 0.0:
					var drunk := float(herder.get("drunk"))
					if _rng.randf() < 0.13 + drunk / 100.0 * 0.2:
						_escape()
		S.ESCAPE:
			spd = 3.6
			if _flat_dist(_goal) < 1.0 or _think <= 0.0:
				state = S.ROAM
				_think = 4.0
		S.ROAM:
			spd = 0.7
			if _think <= 0.0:
				_think = _rng.randf_range(4.0, 8.0)
				_goal = global_position + Vector3(_rng.randf_range(-6, 6), 0, _rng.randf_range(-6, 6))
				if Terrain.depth(_goal.x, _goal.z) > 0.2:
					_goal = global_position
		S.FOLLOW:
			_follow_t -= delta
			if herder:
				var to := herder.global_position - global_position
				to.y = 0.0
				_goal = herder.global_position - to.normalized() * 1.8
				spd = clampf(to.length() * 1.2, 0.0, 4.8)
			if inside:
				state = S.GRAZE
				_think = 2.0
				_calm = 20.0
				NetUtil.call_all(self, "moo", [])
			elif _follow_t <= 0.0:
				state = S.ROAM
	var dir := _goal - global_position
	dir.y = 0.0
	if dir.length() > 0.4:
		dir = dir.normalized()
		velocity.x = dir.x * spd
		velocity.z = dir.z * spd
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), clampf(delta * 3.0, 0.0, 1.0))
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	NpcMotion.move(self, delta)
	if global_position.y < -6.0:
		global_position = Farm.pasture_point(0, 0) + Vector3.UP


func _flat_dist(p: Vector3) -> float:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length()


func _escape() -> void:
	var away := Vector3.FORWARD.rotated(Vector3.UP, _rng.randf() * TAU)
	for k in 8:
		var g := global_position + away * _rng.randf_range(22.0, 34.0)
		if Terrain.depth(g.x, g.z) <= 0.0:
			_goal = g
			break
		away = away.rotated(Vector3.UP, 0.8)
	state = S.ESCAPE
	_think = 12.0
	NetUtil.call_all(self, "moo", [])
	NetUtil.call_peer(self, _herder, "escaped", [])


@rpc("authority", "reliable")
func escaped() -> void:
	Events.notify(["Зорька удрала! Догони и пригони обратно (E)", "Корова сбежала! Беги за ней!",
		"Му-у-у! Зорька рванула куда-то — догоняй"].pick_random(), Color.ORANGE)


# ------------------------------------------------------------ вид (у всех)

func _animate(delta: float) -> void:
	var moved := global_position - _prev
	moved.y = 0.0
	_prev = global_position
	_spd = lerpf(_spd, moved.length() / maxf(delta, 0.001), minf(delta * 6.0, 1.0))
	var k := clampf(_spd / 3.0, 0.0, 1.0)
	for i in _legs.size():
		var ph := _t * (4.0 + _spd * 2.0) + (PI if i == 1 or i == 2 else 0.0)
		_legs[i].rotation.x = sin(ph) * (0.15 + 0.45 * k) * (1.0 if _spd > 0.15 else 0.0)
	_head.rotation.x = lerpf(0.55, 0.0, clampf(_spd, 0.0, 1.0)) + sin(_t * 1.3) * 0.05   # жуёт траву
	_tail.rotation.z = sin(_t * 2.3) * 0.35
	if state == S.GRAZE or state == S.FOLLOW:
		_label.text = "Зорька · пасёт %s · %d:%02d" % [herder_name, int(graze_left) / 60, int(graze_left) % 60]
	elif state in [S.ESCAPE, S.ROAM]:
		_label.text = "Зорька · СБЕЖАЛА!"
	else:
		_label.text = "Зорька"
	_moo_t -= delta
	if _moo_t <= 0.0 and Net.is_online():
		_moo_t = randf_range(20.0, 45.0)
		Sfx.play("moo", global_position + Vector3.UP, -8.0, 0.15)
