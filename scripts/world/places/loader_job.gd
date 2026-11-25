extends Node3D
## Подработка грузчиком у «Шестёрочки»: взять коробку из «ГАЗели» (E) и отнести к двери склада (E).
## 22 ₽ за коробку. Коробок в машине ограниченно — новые привезут утром.
## Пьяный может уронить коробку, в воду — утопить, от удара — выронить.

const PAY := 22
const PER_DAY := 15
## Дверь склада относительно этого узла.
const DOOR := Vector3(-3.97, 0, -1.0)

var boxes_left: int = PER_DAY
var _stack: Array[Node3D] = []


func _ready() -> void:
	add_to_group("poi")
	set_meta("poi_name", "Подработка")
	_truck()
	# Дверь склада на стене магазина
	var door := Node3D.new()
	door.position = DOOR
	door.rotation.y = PI / 2
	add_child(door)
	Build.block(door, Vector3(0, 1.1, 0), Vector3(1.4, 2.2, 0.08), Art.tex_world("metal", 0.6), false)
	Build.text(door, Vector3(0, 2.45, 0.06), "СКЛАД · ПРИЁМ ТОВАРА", 36, Color(1, 0.95, 0.7), 0.005)
	Build.talk_area(door, Vector3(0, 1.0, 0.5), Vector3(1.6, 2.0, 1.0), _Door.new(self))
	Build.sign(self, Vector3(-3.9, 1.7, 1.2), "sign_job", Vector2(1.6, 0.4), PI / 2, 0.2)
	Build.lamp(self, Vector3(-3.5, 2.6, -1.0), 0.8, 6.0, Color(1, 0.9, 0.7), true)
	Events.new_day.connect(func(_d: int) -> void: _set_left(PER_DAY))
	Net.hosted.connect(func() -> void: _set_left(int(Saves.get_section("job").get("left", PER_DAY))))
	Net.player_registered.connect(func(peer: int, _d: Dictionary) -> void:
		NetUtil.call_peer(self, peer, "set_left", [boxes_left]))
	Saves.before_save.connect(func() -> void: Saves.set_section("job", {"left": boxes_left}))


func _truck() -> void:
	var t := Node3D.new()
	t.position = Vector3(1.5, 0, 0)
	add_child(t)
	var body_m := Art.color(Color(0.92, 0.92, 0.9), 0.5, 0.2)
	Build.block(t, Vector3(0, 1.45, 0.6), Vector3(2.0, 2.0, 3.4), body_m, true)
	Build.block(t, Vector3(0, 1.0, -1.7), Vector3(2.0, 1.4, 1.3), Art.color(Color(0.2, 0.35, 0.7), 0.4, 0.3), true)
	Build.block(t, Vector3(0, 1.4, -2.36), Vector3(1.8, 0.6, 0.02), Art.color(Color(0.3, 0.45, 0.55, 0.8), 0.1, 0.5), false)
	for x in [-0.95, 0.95]:
		for z in [-1.6, 1.4]:
			var w := Art.add_mesh(t, Art.cyl(0.38, 0.38, 0.28, 16), Art.color(Color(0.1, 0.1, 0.1), 0.9), Vector3(x, 0.38, z), Vector3(0, 0, PI / 2))
			w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	Build.text(t, Vector3(1.01, 1.6, 0.6), "ГАЗЕЛЬ · ПРОДУКТЫ", 48, Color(0.2, 0.3, 0.6), 0.006, PI / 2)
	# Открытые двери кузова и коробки внутри
	for i in 6:
		var b := ItemModels.build("box", &"box")
		b.position = Vector3(-0.5 + (i % 2) * 1.0, 0.45 + (i / 2) * 0.4, 2.0)
		t.add_child(b)
		_stack.append(b)
	Build.talk_area(t, Vector3(0, 1.2, 2.6), Vector3(2.2, 2.0, 1.2), self)


func get_prompt(player: Node) -> String:
	if player.carrying:
		return ""
	if boxes_left <= 0:
		return "Коробок больше нет — приходи завтра"
	return "Взять коробку (осталось %d, %d ₽ за штуку)" % [boxes_left, PAY]


func interact(player: Node) -> void:
	if player.carrying or boxes_left <= 0:
		return
	NetUtil.call_server(self, "srv_take", [])


@rpc("any_peer", "reliable")
func srv_take() -> void:
	if not multiplayer.is_server():
		return
	var peer := NetUtil.sender(self)
	if boxes_left <= 0:
		return
	_set_left(boxes_left - 1)
	NetUtil.call_peer(self, peer, "give_box", [])


@rpc("authority", "reliable")
func give_box() -> void:
	var p := get_tree().get_first_node_in_group("local_player")
	if p and p.pick_box():
		Events.notify("Взял коробку. Неси к двери склада (E). Не бегай — не получится", Color(0.9, 0.9, 0.8))


func deliver(player: Node) -> void:
	if player.deliver_box():
		Sfx.play("coin", null, -4.0)
		Inventory.money += PAY
		Inventory.stat_add("boxes")
		Inventory.stat_add("earned", PAY)
		Inventory.changed.emit()
		Events.notify("Коробка на складе: +%d ₽" % PAY, Color.GOLD)


func _set_left(n: int) -> void:
	if multiplayer.is_server():
		NetUtil.call_all(self, "set_left", [n])
	else:
		set_left(n)


@rpc("authority", "reliable")
func set_left(n: int) -> void:
	boxes_left = n
	for i in _stack.size():
		_stack[i].visible = i < ceili(n / 2.5)


class _Door:
	extends Node
	var job: Node

	func _init(j: Node) -> void:
		job = j

	func get_prompt(player: Node) -> String:
		return "Сдать коробку на склад (+%d ₽)" % job.PAY if player.carrying and player.carry_kind == "box" else "Склад «Шестёрочки»"

	func interact(player: Node) -> void:
		if player.carry_kind == "box":
			job.deliver(player)
