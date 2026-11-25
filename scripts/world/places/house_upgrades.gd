extends Node3D
## Улучшения дома (общие на всех, хранит хост). Покупаются по каталогу «Уютный дом» на столе.
## 1 — ремонт (свежие стены, шторы, цветы; после сна +20 здоровья),
## 2 — вторая кровать, 4 — холодильник (общий, хранит рыбу и выпивку),
## 8 — телевизор (прогноз погоды и клёва, новости посёлка).

const UP_REPAIR := 1
const UP_BED := 2
const UP_FRIDGE := 4
const UP_TV := 8
const CATALOG := [
	[UP_REPAIR, "Ремонт", 1500, "Новые обои, шторы, цветы. Высыпаешься лучше: +20 здоровья утром."],
	[UP_BED, "Вторая кровать", 1200, "Чтобы не спать вдвоём на одной."],
	[UP_FRIDGE, "Холодильник «ЗиЛ»", 2500, "Общий: кладите рыбу и выпивку, достать может любой."],
	[UP_TV, "Телевизор «Рубин»", 1800, "Прогноз погоды и клёва, новости посёлка."],
]
const FRIDGE_MAX := 30
const BED2_FOOT := Vector3(-1.4, 0.62, -0.9)

@export var upgrades: int = 0

var fridge: Array = []        ## [{kind:"fish", id, kg} | {kind:"drink", id}] — только на сервере
var _built := 0
var _tv_on := false
var _tv_t := 0.0
var _tv_label: Label3D
var _tv_screen: MeshInstance3D
var _tv_snd: AudioStreamPlayer3D
var _house: Node3D


func _ready() -> void:
	add_to_group("house_upgrades")
	_house = get_parent()
	# Каталог на столе
	Art.add_mesh(self, Art.box(Vector3(0.22, 0.02, 0.3)), Art.color(Color(0.85, 0.3, 0.2)), Vector3(2.75, 0.78, -2.15), Vector3(0, 0.3, 0))
	Build.text(self, Vector3(2.75, 0.795, -2.15), "УЮТНЫЙ\nДОМ", 22, Color.WHITE, 0.003).rotation = Vector3(-PI / 2, 0.3, 0)
	Build.talk_area(self, Vector3(2.75, 0.85, -2.15), Vector3(0.35, 0.25, 0.4), _Talk.new(self, "catalog"))
	Net.hosted.connect(func() -> void:
		var d := Saves.get_section("house")
		upgrades = int(d.get("upgrades", 0))
		fridge = d.get("fridge", []))
	Saves.before_save.connect(func() -> void: Saves.set_section("house", {"upgrades": upgrades, "fridge": fridge}))
	# Каждое утро в холодильнике — банка бабушкиного рассола (если холодильник есть).
	Events.new_day.connect(func(_d: int) -> void:
		if multiplayer.is_server() and has(4):
			var n := 0
			for it in fridge:
				if it.get("id", "") == "brine":
					n += 1
			if n < 2 and fridge.size() < FRIDGE_MAX:
				fridge.append({"kind": "misc", "id": "brine"}))


func has(bit: int) -> bool:
	return upgrades & bit != 0


func _process(delta: float) -> void:
	if upgrades != _built:
		for c in CATALOG:
			if has(c[0]) and _built & int(c[0]) == 0:
				_build(c[0])
		_built = upgrades
	if _tv_on and _tv_label:
		_tv_t -= delta
		if _tv_t <= 0.0:
			_tv_t = 7.0
			_tv_label.text = _channel()
		(_tv_screen.material_override as StandardMaterial3D).emission_energy_multiplier = 1.2 + sin(Time.get_ticks_msec() * 0.01) * 0.2


# ------------------------------------------------------------ постройка

func _build(bit: int) -> void:
	match bit:
		UP_REPAIR: _repair()
		UP_BED: _bed2()
		UP_FRIDGE: _fridge()
		UP_TV: _tv()


func _repair() -> void:
	var fresh := Art.color(Color(0.93, 0.88, 0.75), 0.9)
	var w: float = _house.W
	var d: float = _house.D
	var h: float = _house.H
	var t := 0.24
	Build.block(self, Vector3(0, h / 2, -d / 2 + t), Vector3(w - 2 * t, h - 0.05, 0.01), fresh, false)
	Build.block(self, Vector3(-w / 2 + t, h / 2, 0), Vector3(0.01, h - 0.05, d - 2 * t), fresh, false)
	Build.block(self, Vector3(w / 2 - t, h / 2, -1.6), Vector3(0.01, h - 0.05, 2.6), fresh, false)
	Build.block(self, Vector3(w / 2 - t, h / 2, 1.6), Vector3(0.01, h - 0.05, 2.6), fresh, false)
	# Шторы
	var cloth := Art.color(Color(0.75, 0.25, 0.25), 0.95)
	for x in [-2.6, 2.6]:
		for s in [-0.85, 0.85]:
			Build.block(self, Vector3(x + s, 1.6, d / 2 - t - 0.03), Vector3(0.3, 1.5, 0.03), cloth, false)
	# Цветы и картина
	Build.cylinder(self, Vector3(2.0, 0.85, -2.6), 0.06, 0.16, Art.glass(Color(0.5, 0.7, 0.8, 0.5)), false, 10)
	for i in 4:
		Art.add_mesh(self, Art.sphere(0.06, 8), Art.color([Color(0.9, 0.2, 0.3), Color(1, 0.85, 0.2), Color(0.95, 0.95, 0.95), Color(0.7, 0.3, 0.9)][i]),
			Vector3(2.0 + cos(i * 1.6) * 0.06, 1.02 + i * 0.02, -2.6 + sin(i * 1.6) * 0.06))
	Build.block(self, Vector3(0, 1.8, -d / 2 + t + 0.03), Vector3(1.2, 0.8, 0.04), Art.color(Color(0.45, 0.3, 0.15), 0.6), false)
	Build.block(self, Vector3(0, 1.8, -d / 2 + t + 0.055), Vector3(1.05, 0.65, 0.01), Art.color(Color(0.35, 0.55, 0.75)), false)
	Build.text(self, Vector3(0, 1.78, -d / 2 + t + 0.065), "~ Озеро ~", 30, Color(1, 1, 1, 0.9), 0.004)
	Build.block(self, Vector3(-2.0, 0.046, 0.8), Vector3(1.6, 0.01, 1.1), Art.color(Color(0.3, 0.45, 0.3), 0.95), false)


func _bed2() -> void:
	var wood := Art.tex_world("planks", 0.9)
	var p := Vector3(-2.45, 0, -0.9)
	Build.block(self, p + Vector3(0, 0.25, 0), Vector3(2.2, 0.3, 1.2), wood, true)
	Build.block(self, p + Vector3(-1.15, 0.6, 0), Vector3(0.1, 1.0, 1.25), wood, false)
	Build.block(self, p + Vector3(0, 0.47, 0), Vector3(2.1, 0.16, 1.1), Art.color(Color(0.95, 0.95, 0.92), 0.9), false)
	Build.block(self, p + Vector3(-0.8, 0.6, 0), Vector3(0.45, 0.12, 0.8), Art.color(Color(0.98, 0.98, 0.98), 0.9), false)
	Build.block(self, p + Vector3(0.45, 0.57, 0), Vector3(1.3, 0.06, 1.16), Art.color(Color(0.7, 0.35, 0.3), 0.95), false)
	Build.talk_area(self, p + Vector3(0, 0.6, 0), Vector3(2.2, 1.0, 1.3), _Talk.new(self, "bed2"))


func _fridge() -> void:
	var white := Art.color(Color(0.93, 0.93, 0.9), 0.35, 0.1)
	Build.block(self, Vector3(3.95, 0.9, -1.2), Vector3(0.65, 1.8, 0.7), white, true)
	Build.block(self, Vector3(3.6, 1.15, -1.2), Vector3(0.03, 0.4, 0.06), Art.color(Color(0.7, 0.7, 0.72), 0.3, 0.8), false)
	Build.text(self, Vector3(3.615, 1.6, -1.2), "ЗиЛ", 40, Color(0.75, 0.1, 0.1), 0.005, -PI / 2)
	Build.talk_area(self, Vector3(3.5, 1.0, -1.2), Vector3(0.5, 1.8, 0.9), _Talk.new(self, "fridge"))


func _tv() -> void:
	var wood := Art.tex_world("planks", 0.7)
	var p := Vector3(0.4, 0, -3.0)
	Build.block(self, p + Vector3(0, 0.3, 0), Vector3(1.0, 0.6, 0.45), wood, true)
	Build.block(self, p + Vector3(0, 0.88, 0), Vector3(0.8, 0.56, 0.45), Art.color(Color(0.25, 0.2, 0.15), 0.5), false)
	var scr := StandardMaterial3D.new()
	scr.albedo_color = Color(0.05, 0.08, 0.1)
	scr.emission_enabled = true
	scr.emission = Color(0.35, 0.5, 0.6)
	scr.emission_energy_multiplier = 0.0
	_tv_screen = Art.add_mesh(self, Art.box(Vector3(0.58, 0.4, 0.01)), scr, p + Vector3(-0.05, 0.9, 0.23))
	_tv_label = Build.text(self, p + Vector3(-0.05, 0.9, 0.24), "", 18, Color(1, 1, 0.9), 0.0025)
	_tv_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_tv_label.width = 220
	Build.text(self, p + Vector3(0, 1.22, 0.23), "РУБИН", 20, Color(0.8, 0.7, 0.5), 0.003)
	_tv_snd = AudioStreamPlayer3D.new()
	_tv_snd.bus = "Effects"
	_tv_snd.stream = Sfx.stream_of("tv")
	_tv_snd.position = p + Vector3(0, 0.9, 0.2)
	_tv_snd.unit_size = 3.0
	_tv_snd.volume_db = -10.0
	add_child(_tv_snd)
	Build.talk_area(self, p + Vector3(0, 0.9, 0.3), Vector3(0.9, 0.7, 0.5), _Talk.new(self, "tv"))


# ------------------------------------------------------------ телевизор

func _channel() -> String:
	var w := get_tree().get_first_node_in_group("weather") as Weather
	var lines := []
	if w:
		lines.append("ПРОГНОЗ: сейчас %s, дальше — %s.%s" % [w.word(), Weather.NAMES[w.next_state],
			" Перед грозой рыба клюёт как бешеная!" if w.next_state == Weather.W.STORM else ""])
	var baits := ["червя", "опарыша", "кукурузу", "тесто", "сосиску"]
	var fish := ["лещ", "карась", "окунь", "щука", "судак", "линь"]
	lines.append("«Рыбалка с Ивановым»: сегодня на %s хорошо идёт %s" % [baits.pick_random(), fish.pick_random()])
	lines.append("НОВОСТИ: Дядя Толя опять перебрал. Участковый просит не пить за рулём")
	lines.append("НОВОСТИ: в посёлке снова видели белочку")
	lines.append("РЕКЛАМА: «Шестёрочка» — у нас есть всё! Почти.")
	lines.append("Соревнование у Толи в 17:00. Приз — солидный!")
	lines.append("Сериал «Улицы разбитых удочек», серия 248")
	var dc := get_tree().get_first_node_in_group("day_cycle") as DayCycle
	if dc:
		var party := Club.next_party_text(dc.day)
		if party != "":
			lines.append("АФИША: клуб «Огонёк» — " + party)
	lines.append("НОВОСТИ: рыбнадзор Семёныч вышел на катере — браконьерам несдобровать")
	lines.append("НОВОСТИ: рыбаки опять рассказывают про Царь-сома на Дальнем плёсе. Врут, наверное")
	lines.append("Совхозу «Рассвет» требуются грузчики и пастух. Тётя Валя ждёт!")
	return lines[0] if randf() < 0.4 else lines.pick_random()


func toggle_tv() -> void:
	_tv_on = not _tv_on
	_tv_t = 0.0
	_tv_label.text = ""
	(_tv_screen.material_override as StandardMaterial3D).emission_energy_multiplier = 0.0
	if _tv_on:
		_tv_snd.play()
		Sfx.play("click", null, -6.0)
	else:
		_tv_snd.stop()


# ------------------------------------------------------------ покупка (каталог)

func buy(bit: int, price: int) -> void:
	if has(bit):
		return
	if Inventory.money < price:
		Events.notify("Не хватает денег", Color.TOMATO)
		return
	Inventory.money -= price
	Inventory.stat_add("spent", price)
	Inventory.changed.emit()
	Sfx.play("cash")
	NetUtil.call_server(self, "srv_buy", [bit])


@rpc("any_peer", "reliable")
func srv_buy(bit: int) -> void:
	if multiplayer.is_server():
		upgrades |= bit
		var nm := ""
		for c in CATALOG:
			if c[0] == bit:
				nm = c[1]
		NetUtil.call_all(self, "announce", ["%s купил для дома: %s" % [Net.peer_names.get(NetUtil.sender(self), "Кто-то"), nm]])


@rpc("authority", "call_remote", "reliable")
func announce(text: String) -> void:
	Events.notify(text, Color(1.0, 0.9, 0.6))


# ------------------------------------------------------------ холодильник

func fridge_open() -> void:
	NetUtil.call_server(self, "srv_fridge_list", [])


@rpc("any_peer", "reliable")
func srv_fridge_list() -> void:
	if multiplayer.is_server():
		NetUtil.call_peer(self, NetUtil.sender(self), "fridge_list", [fridge])


@rpc("authority", "reliable")
func fridge_list(items: Array) -> void:
	var ui := get_tree().get_first_node_in_group("house_ui")
	if ui:
		ui.show_fridge(self, items)


func fridge_put(item: Dictionary) -> void:
	NetUtil.call_server(self, "srv_fridge_put", [item])


@rpc("any_peer", "reliable")
func srv_fridge_put(item: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	if fridge.size() >= FRIDGE_MAX:
		NetUtil.call_peer(self, NetUtil.sender(self), "fridge_full", [item])
		return
	fridge.append(item)
	NetUtil.call_peer(self, NetUtil.sender(self), "fridge_list", [fridge])


@rpc("authority", "reliable")
func fridge_full(item: Dictionary) -> void:
	_give(item)
	Events.notify("Холодильник забит", Color.TOMATO)


func fridge_take(i: int) -> void:
	NetUtil.call_server(self, "srv_fridge_take", [i])


@rpc("any_peer", "reliable")
func srv_fridge_take(i: int) -> void:
	if not multiplayer.is_server() or i < 0 or i >= fridge.size():
		return
	var it: Dictionary = fridge[i]
	fridge.remove_at(i)
	var peer := NetUtil.sender(self)
	NetUtil.call_peer(self, peer, "fridge_give", [it])
	NetUtil.call_peer(self, peer, "fridge_list", [fridge])


@rpc("authority", "reliable")
func fridge_give(item: Dictionary) -> void:
	_give(item)


func _give(item: Dictionary) -> void:
	if item.kind == "fish":
		Inventory.add_fish(StringName(item.id), float(item.kg))
	else:
		Inventory.add_item(String(item.kind), StringName(item.id), 1)


class _Talk:
	extends Node
	var up: Node
	var what: String

	func _init(u: Node, w: String) -> void:
		up = u
		what = w

	func get_prompt(p: Node) -> String:
		match what:
			"catalog": return "Каталог «Уютный дом» — улучшить дом"
			"bed2": return "" if p.sleeping else "Лечь спать (вторая кровать)"
			"fridge": return "Холодильник: положить / взять"
			"tv": return "Телевизор: выключить" if up._tv_on else "Телевизор: включить"
		return ""

	func interact(p: Node) -> void:
		match what:
			"catalog":
				var ui := up.get_tree().get_first_node_in_group("house_ui")
				if ui:
					ui.show_catalog(up)
			"bed2":
				var h: Node3D = up._house
				p.go_to_bed(h.to_global(up.BED2_FOOT), (h.global_basis * Vector3(-1, 0, 0)).normalized())
			"fridge":
				up.fridge_open()
			"tv":
				up.toggle_tv()
