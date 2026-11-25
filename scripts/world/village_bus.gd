extends Node3D
## Рейсовый автобус: едет по кольцу, останавливается у остановки, можно проехать за 20 ₽.

const FARE := 20
const SPEED := 9.0
const WAIT := 8.0

var _phi := -80.0
var _state := "drive"   # drive / wait
var _wait := 0.0
var _body: Node3D
var _rider: Node3D
var _dest_phi := -46.0


func _ready() -> void:
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	var paint := Art.color(Color(0.75, 0.62, 0.18), 0.7)
	var dark := Art.color(Color(0.12, 0.12, 0.14), 0.8)
	var glass := Art.color(Color(0.35, 0.45, 0.55, 0.7), 0.2)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	Build.block(_body, Vector3(0, 1.15, 0), Vector3(2.4, 1.3, 7.2), paint, true)
	Build.block(_body, Vector3(0, 2.05, 0), Vector3(2.3, 0.7, 6.6), paint, false)
	Build.block(_body, Vector3(0, 1.7, 3.5), Vector3(2.0, 0.7, 0.08), glass, false)
	for z in [-2.2, -0.4, 1.4]:
		Build.block(_body, Vector3(1.21, 1.65, z), Vector3(0.06, 0.55, 1.2), glass, false)
		Build.block(_body, Vector3(-1.21, 1.65, z), Vector3(0.06, 0.55, 1.2), glass, false)
	for z in [-2.4, 2.4]:
		for x in [-0.95, 0.95]:
			Art.add_mesh(_body, Art.cyl(0.32, 0.32, 0.22, 10), dark, Vector3(x, 0.32, z), Vector3(0, 0, PI / 2))
	Build.board_sign(_body, Vector3(0, 1.4, 3.7), "КЛЁВОЕ МЕСТО", 0.0, Vector2(1.1, 0.28), 0.9)
	var area := Build.talk_area(_body, Vector3(1.4, 1.0, 1.6), Vector3(1.6, 2.0, 2.2), self)
	area.name = "Door"
	_place(_phi)


func _place(phi: float) -> void:
	var p := Layout.ring(phi, 0.0)
	p.y = 0.0
	global_position = p
	rotation.y = Layout.face_in_yaw(phi) + PI / 2.0   # нос вдоль касательной


func _process(delta: float) -> void:
	if _state == "wait":
		_wait -= delta
		if _wait <= 0.0:
			if _rider:
				_drop_rider()
			_state = "drive"
		return
	_phi = wrapf(_phi + SPEED * delta * 0.55, -180.0, 180.0)
	_place(_phi)
	# подъехали к остановке
	if absf(wrapf(_phi - -46.0, -180.0, 180.0)) < 1.2:
		_state = "wait"
		_wait = WAIT
		Sfx.play("horn", global_position, -6.0)
	if _rider and is_instance_valid(_rider):
		_rider.global_position = global_position + Vector3(0, 0.4, 0)


func get_prompt(_player: Node) -> String:
	if _state != "wait":
		return ""
	if _rider:
		return "Выйти на остановке"
	return "Сесть в автобус (%d ₽)" % FARE


func interact(player: Node) -> void:
	if _state != "wait":
		Events.notify("Автобус уже уехал. Подожди следующий.", Color.LIGHT_GRAY)
		return
	if _rider == player:
		_drop_rider()
		return
	if Inventory.money < FARE:
		Events.notify("Проезд %d ₽ — не хватает" % FARE, Color.TOMATO)
		return
	Inventory.money -= FARE
	Inventory.changed.emit()
	_rider = player
	Events.notify("Поехали. Выйдешь на следующей остановке.", Color(0.85, 0.9, 0.6))
	Sfx.play("coin", global_position, -8.0)


func _drop_rider() -> void:
	if _rider and is_instance_valid(_rider):
		_rider.global_position = Layout.ring(-46.0, 5.0) + Vector3(0, 0.2, 0)
		Events.notify("Приехали. Остановка «Клёвое место».", Color(0.85, 0.9, 0.6))
	_rider = null
