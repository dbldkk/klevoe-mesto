extends Node3D
## Мелкие постройки, которые строятся из кода. Тип задаётся в сцене:
## "thimbles" — будка напёрсточника, "fandomat" — приём бутылок, "outhouse_decor" и т.п.

@export_enum("thimbles", "fandomat", "garage") var kind: String = "thimbles"


func _enter_tree() -> void:
	if kind == "thimbles":
		transform = Layout.xform("thimbles")
	elif kind == "garage":
		transform = Layout.xform("garage")


func _ready() -> void:
	match kind:
		"thimbles": _thimbles()
		"fandomat": _fandomat()
		"garage": _garage()


func _thimbles() -> void:
	add_to_group("poi")
	set_meta("poi_name", "Напёрстки")
	var wood := Art.tex_world("planks", 0.6)
	Build.block(self, Vector3(0, 0.4, 0.9), Vector3(1.4, 0.8, 0.8), wood, true)
	Build.block(self, Vector3(0, 0.81, 0.9), Vector3(1.45, 0.02, 0.85), Art.color(Color(0.75, 0.15, 0.12), 0.9), false)
	for i in 3:
		Art.add_mesh(self, Art.cyl(0.06, 0.08, 0.13, 12), Art.color(Color(0.85, 0.7, 0.3), 0.3, 0.6), Vector3(-0.3 + i * 0.3, 0.885, 1.0))
	for x in [-0.9, 0.9]:
		Build.block(self, Vector3(x, 1.2, 0.0), Vector3(0.08, 2.4, 0.08), wood, false)
		Build.block(self, Vector3(x, 1.2, 1.5), Vector3(0.08, 2.4, 0.08), wood, false)
	Build.block(self, Vector3(0, 2.45, 0.75), Vector3(2.1, 0.08, 1.9), Art.color(Color(0.8, 0.2, 0.15), 0.8), false)
	Build.sign(self, Vector3(0, 2.15, 1.56), "sign_thimbles", Vector2(1.7, 0.4), 0.0, 0.5)
	Build.lamp(self, Vector3(0, 2.2, 0.9), 0.9, 5.0, Color(1, 0.8, 0.5), true)


## Навес проката «Нивы»: крыша на столбах, табличка, бочка, канистра.
func _garage() -> void:
	var metal := Art.tex_world("metal", 0.6)
	var post := Art.color(Color(0.35, 0.35, 0.38), 0.5, 0.6)
	Build.block(self, Vector3(0, 0.03, 0), Vector3(4.2, 0.06, 5.6), Art.tex_world("asphalt", 0.4), false)
	for x in [-2.0, 2.0]:
		for z in [-2.6, 2.6]:
			Build.block(self, Vector3(x, 1.2, z), Vector3(0.12, 2.4, 0.12), post, true)
	Build.block(self, Vector3(0, 2.45, 0), Vector3(4.5, 0.1, 6.0), metal, false, Vector3(0.05, 0, 0))
	Build.block(self, Vector3(0, 1.2, -2.75), Vector3(4.2, 2.4, 0.08), metal, true)
	Build.board_sign(self, Vector3(0, 0.0, 3.15), "ПРОКАТ «НИВЫ» · 300 ₽", 0.0, Vector2(1.15, 0.44), 2.15, Color(1, 0.9, 0.4))
	Build.cylinder(self, Vector3(-1.6, 0.45, -2.2), 0.3, 0.9, Art.color(Color(0.2, 0.35, 0.6), 0.6, 0.3), true, 12)
	Build.block(self, Vector3(1.6, 0.25, -2.3), Vector3(0.3, 0.5, 0.18), Art.color(Color(0.7, 0.15, 0.1), 0.5), true)
	Build.lamp(self, Vector3(0, 2.2, 0), 1.0, 7.0, Color(1, 0.9, 0.7), true)


func _fandomat() -> void:
	add_to_group("poi")
	set_meta("poi_name", "Фандомат")
	Build.block(self, Vector3(0, 0.95, 0), Vector3(1.0, 1.9, 0.7), Art.tex_world("metal", 0.8), true)
	Build.block(self, Vector3(0, 1.75, 0.36), Vector3(0.9, 0.3, 0.02), Art.color(Color(0.1, 0.45, 0.2)), false)
	Build.sign(self, Vector3(0, 1.75, 0.375), "sign_fandomat", Vector2(0.86, 0.27), 0.0, 0.5)
	Build.block(self, Vector3(0, 1.1, 0.36), Vector3(0.35, 0.35, 0.03), Art.color(Color(0.05, 0.05, 0.05)), false)
	Art.add_mesh(self, Art.cyl(0.1, 0.1, 0.05, 16), Art.color(Color(0.15, 0.15, 0.15)), Vector3(0, 1.1, 0.38), Vector3(PI / 2, 0, 0))
	Art.add_mesh(self, Art.sphere(0.04, 8), Build.glow_mat(Color(0.2, 1.0, 0.3), 3.0), Vector3(0.35, 1.45, 0.37))
	Build.talk_area(self, Vector3(0, 1.1, 0.6), Vector3(1.1, 1.6, 0.8), self)


func get_prompt(_player: Node) -> String:
	if kind != "fandomat":
		return ""
	var n := Inventory.count_of("bottle", &"empty")
	return "Сдать пустые бутылки: %d шт. × %d ₽" % [n, GameData.BOTTLE_RETURN_PRICE] if n > 0 \
		else "Фандомат: принимает пустые бутылки по %d ₽" % GameData.BOTTLE_RETURN_PRICE


func interact(_player: Node) -> void:
	if kind != "fandomat":
		return
	var n := Inventory.count_of("bottle", &"empty")
	if n <= 0:
		Events.notify("Нет пустых бутылок. Подбирай их на земле (E)", Color.LIGHT_GRAY)
		return
	Inventory.remove_item("bottle", &"empty", n)
	var pay := n * GameData.BOTTLE_RETURN_PRICE
	Inventory.money += pay
	Sfx.play("fandomat", global_position + Vector3.UP)
	Inventory.stat_add("bottles_returned", n)
	Inventory.stat_add("earned", pay)
	Inventory.changed.emit()
	Events.notify("*дзынь-дзынь* Принято бутылок: %d. Выдано %d ₽" % [n, pay], Color.GOLD)
