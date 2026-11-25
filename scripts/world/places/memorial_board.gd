extends Node3D
## Шуточная «доска памяти» у остановки: друга выселили из общаги (и, может, из универа).
## Это не некролог.

const LINES := [
	"Помним. Скорбим. Выселен из общаги.",
	"Ушёл из общаги, но не из наших сердец.",
	"Пусть в новой хате будет не хуже, чем в старой.",
	"Комендантская не дремлет. Мы тоже не забудем.",
]

var _flowers := 0


func _ready() -> void:
	# Сбоку от остановки, чуть дальше от дороги — видно, но не мешает ждать автобус.
	var phi := -46.0
	var base := Layout.ring(phi, 8.2)
	var t := Layout.tangent(phi)
	global_position = base + t * 3.6
	rotation.y = Layout.face_in_yaw(phi)
	add_to_group("poi")
	set_meta("poi_name", "Доска памяти")

	var wood := Art.tex_world("planks", 0.5)
	var dark := Art.color(Color(0.18, 0.12, 0.08), 0.9)
	# столбы и щит
	Build.block(self, Vector3(-0.55, 1.15, 0), Vector3(0.1, 2.3, 0.1), wood, true)
	Build.block(self, Vector3(0.55, 1.15, 0), Vector3(0.1, 2.3, 0.1), wood, true)
	Build.block(self, Vector3(0, 1.55, 0.0), Vector3(1.35, 1.15, 0.08), dark, true)
	# полка для цветов
	Build.block(self, Vector3(0, 0.85, 0.12), Vector3(1.2, 0.06, 0.28), wood, true)

	var tex: Texture2D = load("res://art/textures/memorial_friend.jpg")
	var mat := StandardMaterial3D.new()
	if tex:
		mat.albedo_texture = tex
	else:
		mat.albedo_color = Color(0.45, 0.38, 0.28)
	mat.roughness = 0.85
	var quad := QuadMesh.new()
	quad.size = Vector2(0.72, 0.78)
	var photo := Art.add_mesh(self, quad, mat, Vector3(0, 1.72, 0.05))
	photo.name = "Photo"

	Build.text(self, Vector3(0, 1.18, 0.05), "ПОМНИМ. СКОРБИМ.\nВЫСЕЛЕН ИЗ ОБЩАГИ", 22, Color(0.92, 0.86, 0.7), 0.004)
	Build.talk_area(self, Vector3(0, 1.2, 0.5), Vector3(1.6, 2.2, 1.2), self)


func get_prompt(_player: Node) -> String:
	if _flowers <= 0:
		return "Прочитать доску / возложить цветы"
	if _player and String(_player.get("held_kind")) == "drink":
		return "Прочитать доску / поднять тост"
	return "Прочитать доску памяти"


func interact(player: Node) -> void:
	var line: String = LINES[randi() % LINES.size()]
	Events.notify(line, Color(0.85, 0.8, 0.65))
	if _flowers <= 0:
		_lay_flowers()
		Events.notify("Ты положил скромный букетик к доске.", Color(0.7, 0.85, 0.55))
	elif player and String(player.get("held_kind")) == "drink":
		Events.notify("За друга из общаги! Пусть комната найдётся.", Color(0.95, 0.85, 0.5))
		Sfx.play("cups", global_position, -6.0)


func _lay_flowers() -> void:
	_flowers += 1
	var red := Art.color(Color(0.7, 0.12, 0.14), 0.7)
	var green := Art.color(Color(0.2, 0.4, 0.15), 0.9)
	for i in 5:
		var a := -0.4 + i * 0.2
		Art.add_mesh(self, Art.cyl(0.01, 0.01, 0.22, 5), green, Vector3(a, 0.98, 0.18), Vector3(0.3, 0, 0))
		Art.add_mesh(self, Art.sphere(0.035, 8), red, Vector3(a, 1.1, 0.2))
	Sfx.play("sack", global_position, -12.0)
