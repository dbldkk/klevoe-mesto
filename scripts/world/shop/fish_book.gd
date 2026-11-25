extends Node3D
## Подставка со «Справочником рыбака» в магазине.


func _ready() -> void:
	var wood := Art.tex("planks", 0.5)
	Art.add_mesh(self, Art.box(Vector3(0.5, 1.0, 0.4)), wood, Vector3(0, 0.5, 0))
	Art.add_mesh(self, Art.box(Vector3(0.6, 0.04, 0.45)), wood, Vector3(0, 1.05, 0), Vector3(-0.35, 0, 0))
	Art.add_mesh(self, Art.box(Vector3(0.42, 0.04, 0.3)), Art.color(Color(0.15, 0.3, 0.55)), Vector3(0, 1.1, 0.02), Vector3(-0.35, 0, 0))
	Art.add_mesh(self, Art.box(Vector3(0.38, 0.045, 0.27)), Art.color(Color(0.95, 0.93, 0.85)), Vector3(0, 1.115, 0.02), Vector3(-0.35, 0, 0))
	var l := Label3D.new()
	l.text = "СПРАВОЧНИК\nРЫБАКА"
	l.font_size = 32
	l.pixel_size = 0.0025
	l.outline_size = 8
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = Vector3(0, 1.55, 0)
	add_child(l)


func get_prompt(_player: Node) -> String:
	return "Читать «Справочник рыбака»"


func interact(_player: Node) -> void:
	var ui := get_tree().get_first_node_in_group("fish_book_ui")
	if ui:
		ui.open()
