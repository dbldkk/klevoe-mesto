class_name Farm
extends Node3D
## Совхоз «Рассвет» за дорогой на северо-востоке. Две подработки:
##  · мешки с комбикормом — из ЗИЛа в коровник (как коробки у «Шестёрочки», но тяжелее);
##  · пасти корову Зорьку на огороженном пастбище — она то и дело убегает, надо пригнать обратно (E).
## Тётя Валя выдаёт работу. Решает хост.

const SACK_PAY := 35
const SACKS_PER_DAY := 12
const COW_PAY := 320
const COW_SHIFT := 180.0     ## секунд коровы на пастбище за смену
const BARN_DOOR := Vector3(-4.0, 0, 1.2)

var sacks_left := SACKS_PER_DAY
var cow_peer := 0            ## кто сейчас пасёт (сервер)
var cow_done_day := {}       ## имя -> день, когда уже пас
var _sack_vis: Array[Node3D] = []
var _valya: CharacterModel
var _valya_speech: Label3D


func _enter_tree() -> void:
	transform = Layout.xform("farm")


func _ready() -> void:
	add_to_group("farm")
	add_to_group("poi")
	set_meta("poi_name", "Совхоз «Рассвет»")
	_barn()
	_truck()
	_sign()
	_fence()
	_valya = Build.person(self, Vector3(1.2, 0, 3.2), 0.0, {"shirt": 3, "pants": 1, "skin": 1, "hat": 2, "hat_color": 1, "face": 1}, "seller")
	_valya.rotation.y = PI
	Chatter.attach.call_deferred(_valya, "f", SpeechBank.valya(), 2.55, 5.0, "valya")
	Build.text(self, Vector3(1.2, 2.0, 3.2), "Тётя Валя", 36, Color(1, 0.9, 0.85), 0.006, 0.0, true)
	_valya_speech = Build.text(self, Vector3(1.2, 2.35, 3.2), "", 34, Color(1, 1, 0.8), 0.006, 0.0, true)
	Build.talk_area(self, Vector3(1.2, 0.9, 3.2), Vector3(1.2, 1.8, 1.2), _Valya.new(self))
	Events.new_day.connect(func(_d: int) -> void:
		if multiplayer.is_server():
			_set_left(SACKS_PER_DAY))
	Net.hosted.connect(func() -> void: _set_left(int(Saves.get_section("farm").get("sacks", SACKS_PER_DAY))))
	Net.player_registered.connect(func(peer: int, _d: Dictionary) -> void:
		NetUtil.call_peer(self, peer, "set_left", [sacks_left]))
	Saves.before_save.connect(func() -> void: Saves.set_section("farm", {"sacks": sacks_left}))


# ------------------------------------------------------------ постройки

func _barn() -> void:
	var wood := Art.tex_world("planks", 0.5).duplicate() as StandardMaterial3D
	wood.albedo_color = Color(0.75, 0.42, 0.32)
	var n := Node3D.new()
	n.position = Vector3(-4.0, 0, -2.0)
	add_child(n)
	Build.block(n, Vector3(0, 0.15, 0), Vector3(9.4, 0.3, 6.4), Art.tex_world("brick_dark", 0.5), true)
	Build.block(n, Vector3(0, 1.75, -3.0), Vector3(9.0, 2.9, 0.2), wood, true)
	Build.block(n, Vector3(-4.4, 1.75, 0), Vector3(0.2, 2.9, 6.0), wood, true)
	Build.block(n, Vector3(4.4, 1.75, 0), Vector3(0.2, 2.9, 6.0), wood, true)
	Build.block(n, Vector3(-2.9, 1.75, 3.0), Vector3(3.2, 2.9, 0.2), wood, true)
	Build.block(n, Vector3(2.9, 1.75, 3.0), Vector3(3.2, 2.9, 0.2), wood, true)
	Build.block(n, Vector3(0, 2.75, 3.0), Vector3(2.6, 0.9, 0.2), wood, true)
	var roof := Art.tex_world("roof", 0.35)
	for sd in [-1.0, 1.0]:
		Build.block(n, Vector3(0, 3.75, sd * 1.65), Vector3(9.8, 0.14, 3.7), roof, false, Vector3(sd * 0.5, 0, 0))
	# фронтоны
	for x in [-4.45, 4.45]:
		for k in 4:
			Build.block(n, Vector3(x, 3.25 + k * 0.25, 0), Vector3(0.2, 0.25, 6.0 - k * 1.45), wood, false)
	# белая окантовка ворот и крестовины
	var white := Art.color(Color(0.95, 0.95, 0.92), 0.7)
	Build.block(n, Vector3(0, 2.3, 3.12), Vector3(2.7, 0.12, 0.06), white, false)
	for x in [-1.3, 1.3]:
		Build.block(n, Vector3(x, 1.15, 3.12), Vector3(0.12, 2.3, 0.06), white, false)
	Build.text(n, Vector3(0, 3.6, 3.15), "КОРОВНИК №2", 48, Color(0.95, 0.95, 0.9), 0.006)
	Build.lamp(n, Vector3(0, 2.6, 3.4), 0.9, 7.0, Color(1, 0.85, 0.6), true)
	# сено внутри
	for i in 4:
		Build.block(n, Vector3(-3.2 + i * 0.9, 0.55, -2.2), Vector3(0.8, 0.5, 1.1), Art.color(Color(0.85, 0.75, 0.35), 0.95), true)
	Build.talk_area(self, BARN_DOOR + Vector3(0, 1.0, 0.4), Vector3(2.4, 2.0, 1.2), _Barn.new(self))


func _truck() -> void:
	var t := Node3D.new()
	t.position = Vector3(5.5, 0, 0.5)
	t.rotation.y = 0.15
	add_child(t)
	var green := Art.color(Color(0.25, 0.4, 0.3), 0.6, 0.2)
	Build.block(t, Vector3(0, 1.05, -1.9), Vector3(2.1, 1.5, 1.6), green, true)
	Build.block(t, Vector3(0, 1.3, -2.71), Vector3(1.8, 0.6, 0.02), Art.color(Color(0.3, 0.45, 0.55, 0.8), 0.1, 0.5), false)
	Build.block(t, Vector3(0, 0.75, 1.0), Vector3(2.3, 0.15, 4.0), Art.tex_world("planks", 0.6), true)
	for x in [-1.12, 1.12]:
		Build.block(t, Vector3(x, 1.05, 1.0), Vector3(0.06, 0.5, 4.0), green, false)
	Build.block(t, Vector3(0, 1.05, 2.98), Vector3(2.3, 0.5, 0.06), green, false)
	for x in [-1.0, 1.0]:
		for z in [-1.9, 0.4, 1.9]:
			Art.add_mesh(t, Art.cyl(0.42, 0.42, 0.3, 16), Art.color(Color(0.1, 0.1, 0.1), 0.9), Vector3(x, 0.42, z), Vector3(0, 0, PI / 2))
	Build.text(t, Vector3(1.16, 1.25, -1.9), "ЗИЛ", 54, Color(0.95, 0.95, 0.9), 0.006, PI / 2)
	for i in 8:
		var s := ItemModels.build("sack", &"sack")
		s.position = Vector3(-0.6 + (i % 3) * 0.6, 0.85 + (i / 3) * 0.36, 0.6 + (i % 2) * 0.7)
		s.rotation.y = i * 0.7
		s.set_meta("no_bake", true)
		t.add_child(s)
		_sack_vis.append(s)
	Build.talk_area(t, Vector3(0, 1.2, 3.2), Vector3(2.4, 2.0, 1.4), _Truck.new(self))


func _sign() -> void:
	var s := Node3D.new()
	s.position = Vector3(-9.5, 0, 6.5)
	add_child(s)
	for x in [-1.3, 1.3]:
		Build.block(s, Vector3(x, 1.2, 0), Vector3(0.1, 2.4, 0.1), Art.color(Color(0.4, 0.3, 0.2)), true)
	Build.block(s, Vector3(0, 2.2, 0), Vector3(2.9, 0.8, 0.06), Art.color(Color(0.75, 0.2, 0.15)), false)
	Build.text(s, Vector3(0, 2.3, 0.04), "СОВХОЗ «РАССВЕТ»", 44, Color(1, 0.95, 0.6), 0.006)
	Build.text(s, Vector3(0, 2.0, 0.04), "нужны работники · оплата сразу", 26, Color(1, 1, 1), 0.006)


## Изгородь пастбища (из жердей) — по краю площадки «pasture».
func _fence() -> void:
	var pt := Layout.xform("pasture")
	var my := global_transform if is_inside_tree() else Layout.xform("farm")
	var s: Array = Layout.SPOTS.pasture
	var hx: float = s[2] - 0.5
	var hz: float = s[3] - 0.5
	var wood := Art.color(Color(0.5, 0.38, 0.25), 0.9)
	var corners := [Vector3(-hx, 0, -hz), Vector3(hx, 0, -hz), Vector3(hx, 0, hz), Vector3(-hx, 0, hz)]
	for i in 4:
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[(i + 1) % 4]
		var len := a.distance_to(b)
		var n := int(len / 2.5)
		for k in n + 1:
			var lp := a.lerp(b, float(k) / n)
			if i == 2 and absf(lp.x) < 1.8:
				continue   # ворота к дороге
			var wp := pt * lp
			wp.y = Terrain.height(wp.x, wp.z)
			Build.block(self, my.affine_inverse() * wp + Vector3(0, 0.6, 0), Vector3(0.12, 1.2, 0.12), wood, true)
		for k in n:
			var m := a.lerp(b, (k + 0.5) / n)
			if i == 2 and absf(m.x) < 1.8:
				continue
			var wp := pt * m
			wp.y = Terrain.height(wp.x, wp.z)
			var dir := (pt.basis * (b - a)).normalized()
			var yaw := atan2(dir.x, dir.z) - my.basis.get_euler().y
			for y in [0.55, 1.0]:
				Build.block(self, my.affine_inverse() * wp + Vector3(0, y, 0), Vector3(0.07, 0.07, len / n), wood, false, Vector3(0, yaw, 0))
	var sg := pt * Vector3(3.2, 0, hz + 0.3)
	sg.y = Terrain.height(sg.x, sg.z)
	Build.text(self, my.affine_inverse() * sg + Vector3(0, 1.5, 0), "ПАСТБИЩЕ", 40, Color(1, 0.95, 0.7), 0.006, 0.0, true)


## Внутри ли пастбища (мировая точка).
static func in_pasture(p: Vector3) -> bool:
	var l := Layout.xform("pasture").affine_inverse() * Vector3(p.x, 0, p.z)
	var s: Array = Layout.SPOTS.pasture
	return absf(l.x) < s[2] - 0.8 and absf(l.z) < s[3] - 0.8


static func pasture_point(rng_x: float, rng_z: float) -> Vector3:
	var s: Array = Layout.SPOTS.pasture
	var p := Layout.xform("pasture") * Vector3(rng_x * (s[2] - 2.0), 0, rng_z * (s[3] - 2.0))
	p.y = Terrain.height(p.x, p.z)
	return p


# ------------------------------------------------------------ мешки

func take_sack(p: Node) -> void:
	if p.carrying or sacks_left <= 0:
		return
	NetUtil.call_server(self, "srv_sack", [])


@rpc("any_peer", "reliable")
func srv_sack() -> void:
	if not multiplayer.is_server() or sacks_left <= 0:
		return
	_set_left(sacks_left - 1)
	NetUtil.call_peer(self, NetUtil.sender(self), "give_sack", [])


@rpc("authority", "reliable")
func give_sack() -> void:
	var p := get_tree().get_first_node_in_group("local_player")
	if p and p.pick_box("sack"):
		Sfx.play("sack", p.global_position, -6.0)
		Events.notify("Взвалил мешок. Неси в коровник (E у ворот)", Color(0.9, 0.9, 0.8))


func deliver_sack(p: Node) -> void:
	if p.carry_kind != "sack" or not p.deliver_box():
		return
	Sfx.play("sack", p.global_position, -4.0)
	Inventory.money += SACK_PAY
	Inventory.stat_add("earned", SACK_PAY)
	Inventory.stat_add("farm_jobs")
	Inventory.changed.emit()
	Events.notify("Мешок в коровнике: +%d ₽" % SACK_PAY, Color.GOLD)


func _set_left(n: int) -> void:
	if multiplayer.is_server():
		NetUtil.call_all(self, "set_left", [n])
	else:
		set_left(n)


@rpc("authority", "reliable")
func set_left(n: int) -> void:
	sacks_left = n
	for i in _sack_vis.size():
		_sack_vis[i].visible = i < ceili(n / 1.5)


# ------------------------------------------------------------ корова

func ask_cow(p: Node) -> void:
	NetUtil.call_server(self, "srv_cow_job", [p.player_name])


@rpc("any_peer", "reliable")
func srv_cow_job(who: String) -> void:
	if not multiplayer.is_server():
		return
	var peer := NetUtil.sender(self)
	var dc := get_tree().get_first_node_in_group("day_cycle") as DayCycle
	var day := dc.day if dc else 0
	var cow := get_tree().get_first_node_in_group("cow")
	if cow_peer != 0 and get_tree().get_root().get_node_or_null("World/Players/%d" % cow_peer) != null:
		NetUtil.call_peer(self, peer, "valya_say", ["Зорьку уже пасут, милок. Мешки вон потаскай"])
		return
	if int(cow_done_day.get(who, -1)) == day:
		NetUtil.call_peer(self, peer, "valya_say", ["Ты сегодня уже пас. Завтра приходи"])
		return
	cow_peer = peer
	if cow:
		cow.start_shift(peer, who)
	NetUtil.call_all(self, "valya_say", ["Выведи Зорьку на пастбище и смотри, чтоб не убежала! %d ₽ за смену" % COW_PAY])


## Корова отпаслась (зовёт Cow на сервере).
func cow_finished(peer: int, who: String, ok: bool) -> void:
	cow_peer = 0
	var dc := get_tree().get_first_node_in_group("day_cycle") as DayCycle
	cow_done_day[who] = dc.day if dc else 0
	if ok:
		NetUtil.call_peer(self, peer, "cow_paid", [COW_PAY])
		NetUtil.call_all(self, "valya_say", ["Молодец, %s! Зорька сытая, довольная" % who])


@rpc("authority", "reliable")
func cow_paid(amount: int) -> void:
	Inventory.money += amount
	Inventory.stat_add("earned", amount)
	Inventory.stat_add("farm_jobs")
	Inventory.changed.emit()
	Sfx.play("coin")
	Events.notify("Тётя Валя: «Держи за корову, заслужил!» +%d ₽" % amount, Color.GOLD)


@rpc("authority", "call_remote", "reliable")
func valya_say(text: String) -> void:
	_valya_speech.text = text
	_valya_speech.modulate.a = 1.0
	Sfx.say(_valya.global_position + Vector3.UP * 1.6, "f", text, "valya")


func _process(delta: float) -> void:
	_valya_speech.modulate.a = maxf(_valya_speech.modulate.a - delta * 0.15, 0.0)
	_valya.pose = "talk" if _valya_speech.modulate.a > 0.3 else "idle"


class _Valya:
	extends Node
	var farm: Node

	func _init(f: Node) -> void:
		farm = f

	func get_prompt(_p: Node) -> String:
		return "Тётя Валя: пасти корову Зорьку (%d ₽)" % farm.COW_PAY

	func interact(p: Node) -> void:
		farm.ask_cow(p)


class _Truck:
	extends Node
	var farm: Node

	func _init(f: Node) -> void:
		farm = f

	func get_prompt(p: Node) -> String:
		if p.carrying:
			return ""
		if farm.sacks_left <= 0:
			return "Мешков больше нет — завтра привезут"
		return "Взять мешок комбикорма (осталось %d, %d ₽)" % [farm.sacks_left, farm.SACK_PAY]

	func interact(p: Node) -> void:
		farm.take_sack(p)


class _Barn:
	extends Node
	var farm: Node

	func _init(f: Node) -> void:
		farm = f

	func get_prompt(p: Node) -> String:
		return "Сложить мешок в коровник (+%d ₽)" % farm.SACK_PAY if p.carrying and p.carry_kind == "sack" else "Коровник"

	func interact(p: Node) -> void:
		farm.deliver_sack(p)
