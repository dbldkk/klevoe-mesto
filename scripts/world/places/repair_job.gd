extends Node3D
## Подработка: починить «Ниву» соседа Гены (у гаража). Раз в день. Окно RepairUI — 4 поломки,
## для каждой надо выбрать правильный инструмент. Пьяному инструмент выскальзывает из рук.

const PAY := 450

var done_day := -1
var _hood: Node3D
var _gena: CharacterModel


func _enter_tree() -> void:
	transform = Layout.xform("repair")


func _ready() -> void:
	add_to_group("repair_job")
	add_to_group("poi")
	set_meta("poi_name", "Ремонт «Нивы» (Гена)")
	var body_m := Art.color(Color(0.75, 0.45, 0.15), 0.5, 0.3)
	var dark := Art.color(Color(0.1, 0.1, 0.1), 0.9)
	var car := Node3D.new()
	car.position = Vector3(0, 0, -0.5)
	car.rotation = Vector3(0, 0, 0.04)
	add_child(car)
	Build.block(car, Vector3(0, 0.75, 0), Vector3(1.7, 0.6, 3.7), body_m, true)
	Build.block(car, Vector3(0, 1.3, 0.35), Vector3(1.6, 0.55, 2.0), body_m, false)
	Build.block(car, Vector3(0, 1.3, -0.66), Vector3(1.5, 0.45, 0.02), Art.color(Color(0.3, 0.45, 0.55, 0.8), 0.1, 0.5), false)
	for x in [-0.85, 0.85]:
		for z in [-1.25, 1.25]:
			if x > 0 and z < 0:
				continue   # колеса нет — машина на домкрате
			Art.add_mesh(car, Art.cyl(0.34, 0.34, 0.24, 16), dark, Vector3(x, 0.34, z), Vector3(0, 0, PI / 2))
	Art.add_mesh(self, Art.cyl(0.34, 0.34, 0.24, 16), dark, Vector3(1.6, 0.12, -2.2), Vector3(PI / 2, 0, 0))   # снятое колесо
	Build.block(car, Vector3(0.75, 0.2, -1.25), Vector3(0.2, 0.4, 0.2), Art.color(Color(0.8, 0.15, 0.1), 0.5, 0.5), false)   # домкрат
	_hood = Node3D.new()
	_hood.position = Vector3(0, 1.05, -1.85)
	_hood.rotation.x = -1.1
	car.add_child(_hood)
	Build.block(_hood, Vector3(0, 0, 0.6), Vector3(1.6, 0.05, 1.2), body_m, false)
	Build.block(car, Vector3(0, 0.95, -1.35), Vector3(1.1, 0.3, 0.8), Art.color(Color(0.25, 0.25, 0.27), 0.5, 0.6), false)   # мотор
	Build.text(car, Vector3(0, 0.75, 1.86), "Т 666 ОК", 40, Color(0.1, 0.1, 0.1), 0.004)
	_gena = Build.person(self, Vector3(-1.6, 0, -1.6), 0.0, {"shirt": 4, "pants": 2, "skin": 1, "hat": 1, "hat_color": 5, "face": 2}, "player_b")
	_gena.rotation.y = -0.6
	Chatter.attach.call_deferred(_gena, "m", SpeechBank.gena(), 2.3, 5.0, "gena")
	Build.text(self, Vector3(-1.6, 2.0, -1.6), "Сосед Гена", 36, Color(1, 0.9, 0.75), 0.006, 0.0, true)
	Build.talk_area(self, Vector3(0, 1.0, -1.0), Vector3(2.6, 2.0, 4.6), self)
	# ящик с инструментами
	Build.block(self, Vector3(-1.4, 0.2, 0.6), Vector3(0.6, 0.35, 0.3), Art.color(Color(0.75, 0.1, 0.1), 0.5, 0.4), true)


func get_prompt(_p: Node) -> String:
	var dc := get_tree().get_first_node_in_group("day_cycle") as DayCycle
	if dc and dc.day == done_day:
		return "Гена: «Спасибо, едет! Завтра опять сломается — приходи»"
	return "Сосед Гена: помочь починить «Ниву» (%d ₽)" % PAY


func interact(_p: Node) -> void:
	var dc := get_tree().get_first_node_in_group("day_cycle") as DayCycle
	if dc and dc.day == done_day:
		return
	var ui := get_tree().get_first_node_in_group("repair_ui")
	if ui:
		ui.open(self)


func finished(ok: bool) -> void:
	var dc := get_tree().get_first_node_in_group("day_cycle") as DayCycle
	done_day = dc.day if dc else 0
	if ok:
		Inventory.money += PAY
		Inventory.stat_add("earned", PAY)
		Inventory.stat_add("repairs")
		Inventory.changed.emit()
		Sfx.play("horn", global_position + Vector3.UP)
		Events.notify("Гена: «Завелась! Золотые руки!» +%d ₽" % PAY, Color.GOLD)
	else:
		Events.notify("Гена: «Ты что наделал?! Теперь ещё и фара отвалилась…» Денег не будет", Color.TOMATO)


func _process(_delta: float) -> void:
	_gena.pose = "talk" if fmod(Time.get_ticks_msec() / 1000.0, 7.0) < 2.0 else "idle"
