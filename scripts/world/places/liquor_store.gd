extends Node3D
## «Бухло & Табак»: прилавок, за ним продавщица Люда и полки с бутылками.
## Здесь всё через прилавок — украсть не выйдет. Выпивка на 10% дешевле, чем в «Шестёрочке».

const W := 8.0
const D := 6.0
const H := 3.0
const DISCOUNT := 0.9

const GOODS := [
	["drink", &"beer"], ["drink", &"strong_beer"], ["drink", &"cider"], ["drink", &"champagne"],
	["drink", &"port"], ["drink", &"wine"], ["drink", &"vodka"], ["drink", &"samogon"], ["drink", &"cognac"],
	["smoke", &"cigs"], ["smoke", &"belomor"], ["food", &"seeds"], ["food", &"crackers"],
]

var seller: CharacterModel


func _enter_tree() -> void:
	transform = Layout.xform("liquor")


func _ready() -> void:
	add_to_group("poi")
	set_meta("poi_name", "Бухло & Табак")
	var wall := Art.tex_world("brick_dark", 0.55)
	var inner := Art.tex_world("plaster", 0.5)
	Build.room(self, W, D, H, wall, inner, Art.tex_world("linoleum", 0.4), Art.tex_world("roof", 0.35), 1.4, 2.3, -2.0)
	Build.plinth(self, W, D, 1.4, -2.0, 0.3, Art.color(Color(0.3, 0.3, 0.32), 0.9))
	# козырёк-маркиза
	for i in 7:
		Build.block(self, Vector3(-2.85 + i * 0.95, 2.05, D / 2 + 0.55), Vector3(0.95, 0.05, 1.1), Art.color(Color(0.75, 0.12, 0.12) if i % 2 == 0 else Color(0.95, 0.9, 0.85), 0.8), false, Vector3(-0.3, 0, 0))
	Build.door(self, Vector3(-2.0, 0, D / 2 - 0.11), 1.4, 2.3, false, Color(0.25, 0.3, 0.35))
	Build.sign(self, Vector3(0.6, 2.55, D / 2 + 0.02), "sign_liquor", Vector2(4.4, 0.95), 0.0, 0.8)
	Build.window(self, Vector3(1.8, 1.4, D / 2), Vector2(2.4, 1.2))
	Art.add_mesh(self, Art.box(Vector3(0.6, 0.35, 0.05)), Build.glow_mat(Color(1.0, 0.2, 0.2), 2.5), Vector3(3.3, 2.2, D / 2 + 0.05))
	Build.text(self, Vector3(3.3, 2.2, D / 2 + 0.085), "24", 64, Color.WHITE, 0.004)
	Build.lamp(self, Vector3(0, H - 0.4, 0), 1.3, 8.0, Color(1, 0.9, 0.8))
	Build.lamp(self, Vector3(0, 2.4, D / 2 + 1.0), 0.8, 5.0, Color(1.0, 0.6, 0.4), true)
	# Прилавок поперёк
	var counter_m := Art.tex_world("planks", 0.6)
	Build.block(self, Vector3(0.6, 0.5, -0.6), Vector3(6.4, 1.0, 0.7), counter_m, true)
	Build.block(self, Vector3(0.6, 1.02, -0.6), Vector3(6.5, 0.05, 0.8), Art.color(Color(0.2, 0.2, 0.22), 0.4, 0.3), false)
	# Сигареты на витрине
	var shelf := load("res://scripts/world/shop/shop_item.gd")
	for i in 2:
		var it: Node3D = shelf.new()
		it.kind = "smoke"
		it.item_id = [&"cigs", &"belomor"][i]
		it.facings = 5
		it.spacing = 0.08
		it.decor_only = true
		it.position = Vector3(-1.2 + i * 1.0, 1.05, -0.6)
		add_child(it)
	# Полки за прилавком
	var row := 0
	for y in [0.3, 0.9, 1.5, 2.1]:
		Build.block(self, Vector3(0.6, y - 0.02, -2.7), Vector3(6.6, 0.04, 0.5), Art.color(Color(0.3, 0.22, 0.15), 0.6), false)
		var ids: Array = [&"beer", &"strong_beer", &"vodka", &"samogon", &"port", &"wine", &"champagne", &"cognac", &"cider"]
		for j in 4:
			var it: Node3D = shelf.new()
			it.kind = "drink"
			it.item_id = ids[(row * 4 + j) % ids.size()]
			it.facings = 7
			it.spacing = 0.13
			it.decor_only = true
			it.position = Vector3(-2.2 + j * 1.6 + 0.6, y, -2.7)
			add_child(it)
		row += 1
	Build.block(self, Vector3(0.6, 1.25, -2.98), Vector3(6.8, 2.5, 0.04), Art.color(Color(0.22, 0.16, 0.12)), false)
	# Люда
	seller = Build.person(self, Vector3(0.6, 0, -1.5), PI, {"shirt": 1, "pants": 1, "skin": 4, "hat": 0, "hat_color": 6, "face": 0}, "seller", true)
	Build.text(self, Vector3(0.6, 2.15, -1.5), "Люда", 40, Color(1, 1, 1, 0.85), 0.006, 0.0, true)
	Build.talk_area(self, Vector3(0.6, 1.2, -1.2), Vector3(2.4, 1.6, 1.2), self)


func get_prompt(_player: Node) -> String:
	return "Купить у Люды (выпивка, сигареты)"


func interact(player: Node) -> void:
	if player.stinky > 0.0:
		Events.notify("Люда: «Фу! Сначала помойся, потом приходи»", Color.ORANGE)
		return
	var ui := get_tree().get_first_node_in_group("store_ui")
	if ui:
		ui.open(self)


func price_of(kind: String, id: StringName) -> int:
	var p := GameData.item_price(kind, id)
	return roundi(p * DISCOUNT) if kind == "drink" else p


func greeting() -> String:
	var dc := get_tree().get_first_node_in_group("day_cycle") as DayCycle
	if dc and dc.is_night():
		return ["Ночью только по паспорту. Шучу, бери.", "Опять не спится?", "Последняя на сегодня, да?"].pick_random()
	return ["Чего тебе?", "Только не в долг.", "Свежее завезли.", "Сдачи нет, сразу говорю."].pick_random()
