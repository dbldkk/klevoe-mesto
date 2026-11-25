extends CanvasLayer
## Колесо действий на Q: редкие действия без отдельных клавиш.
## Наведение + клик (или отпускание Q) запускает действие и закрывает меню.

const RADIUS := 230.0
const BTN := Vector2(118, 70)

const ACTIONS := [
	{"id":"doctor","title":"Позвать\nврача","hint":"слушай колокольчик"},
	{"id":"bucket","title":"Снять\nведро","hint":"освободить голову"},
	{"id":"goose","title":"Откупиться\nот гуся","hint":"хлеб или 15 ₽"},
	{"id":"mermaid","title":"Русалка\nДокументы!","hint":"проверить удостоверение"},
	{"id":"mermaid_fish","title":"Отдать\nрыбу","hint":"русалке при исполнении"},
	{ "id": "pee", "title": "Обоссаться", "hint": "когда прижмёт" },
	{ "id": "poop", "title": "Обосраться", "hint": "когда прижмёт" },
	{ "id": "toast", "title": "Тост", "hint": "нужна бутылка" },
	{ "id": "gift", "title": "Угостить", "hint": "посмотри на человека" },
	{ "id": "flashlight", "title": "Фонарик", "hint": "из «Шестёрочки»" },
	{ "id": "drop_cart", "title": "Выложить\nкорзину", "hint": "вернуть товар на полки" },
	{ "id": "dispute", "title": "Поспорить", "hint": "посмотри на игрока" },
]

var _hover := -1
var _btns: Array[Button] = []
var _opened_at := 0.0
var _holding := false
var _enabled: Array[bool] = []
var _center: Control
var _hint: Label


func _ready() -> void:
	add_to_group("radial_menu")
	layer = 22
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.04, 0.38)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	_center = Control.new()
	_center.set_anchors_preset(Control.PRESET_CENTER)
	_center.position = Vector2.ZERO
	add_child(_center)
	var title := Label.new()
	title.text = "ДЕЙСТВИЕ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(-80, -16)
	title.size = Vector2(160, 24)
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(0.85, 0.88, 0.9, 0.85))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center.add_child(title)
	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.position = Vector2(-180, 20)
	_hint.size = Vector2(360, 24)
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_color", Color(0.75, 0.78, 0.72))
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center.add_child(_hint)
	for i in ACTIONS.size():
		var b := Button.new()
		b.custom_minimum_size = BTN
		b.position = _slot_pos(i) - BTN * 0.5
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		var idx := i
		b.mouse_entered.connect(func() -> void: _hover = idx; _refresh_hint())
		b.mouse_exited.connect(func() -> void:
			if _hover == idx:
				_hover = -1
				_refresh_hint())
		b.pressed.connect(func() -> void: activate(ACTIONS[idx]["id"]))
		_center.add_child(b)
		_btns.append(b)
		_enabled.append(false)
	_rebuild()


func _slot_pos(i: int) -> Vector2:
	var a := -PI / 2.0 + TAU * float(i) / float(ACTIONS.size())
	return Vector2(cos(a), sin(a)) * RADIUS


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and visible:
		get_viewport().set_input_as_handled()
		close()
		return
	if not event.is_action("radial"):
		return
	if event.is_action_pressed("radial"):
		get_viewport().set_input_as_handled()
		if visible:
			close()
		elif not Events.ui_open:
			open()
			_holding = true
	elif event.is_action_released("radial") and visible and _holding:
		get_viewport().set_input_as_handled()
		_holding = false
		if Time.get_ticks_msec() / 1000.0 - _opened_at < 0.18:
			return
		if _hover >= 0 and _hover < _enabled.size() and _enabled[_hover]:
			activate(ACTIONS[_hover]["id"])
		else:
			close()


func open() -> void:
	if visible or Events.ui_open:
		return
	var p := get_tree().get_first_node_in_group("local_player")
	if p == null or p._knocked_out:
		return
	visible = true
	Events.ui_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_opened_at = Time.get_ticks_msec() / 1000.0
	_hover = -1
	_rebuild()


func close() -> void:
	if not visible:
		return
	visible = false
	_holding = false
	Events.ui_open = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var p := get_tree().get_first_node_in_group("local_player")
	if p:
		p.input_cooldown = 0.2


func is_enabled(id: String) -> bool:
	for i in ACTIONS.size():
		if ACTIONS[i]["id"] == id:
			return _enabled[i] if i < _enabled.size() else false
	return false


func refresh() -> void:
	_rebuild()


func _rebuild() -> void:
	_enabled.clear()
	for i in ACTIONS.size():
		var ok := can_do(ACTIONS[i]["id"])
		_enabled.append(ok)
		var b := _btns[i]
		b.text = ACTIONS[i]["title"]
		b.disabled = not ok
		b.modulate = Color(1, 1, 1, 1) if ok else Color(0.55, 0.55, 0.55, 0.7)
	_refresh_hint()


func _refresh_hint() -> void:
	if _hint == null:
		return
	if _hover < 0 or _hover >= ACTIONS.size():
		_hint.text = "Наведи и нажми · отпусти Q, чтобы выбрать"
		return
	var a: Dictionary = ACTIONS[_hover]
	_hint.text = a["title"] if _enabled[_hover] else String(a["hint"])


func can_do(id: String) -> bool:
	var p := get_tree().get_first_node_in_group("local_player")
	if p == null:
		return false
	var m := get_tree().get_first_node_in_group("mischief")
	if id == "doctor":
		return Inventory.blindness > 0
	if id == "bucket":
		return m != null and m.bucket_left > 0
	if id == "goose":
		var g := get_tree().get_first_node_in_group("goose")
		return g != null and g.target_peer == multiplayer.get_unique_id()
	if id in ["mermaid","mermaid_fish"]:
		return m != null and is_instance_valid(m._prank_model) and (id == "mermaid" or not Inventory.basket.is_empty())
	if p.is_busy_body() and not (id == "pee" or id == "poop"):
		return false
	match id:
		"pee":
			return Inventory.bladder >= 12.0 and not p.fishing.is_busy() and not p.swimming and not p.carrying
		"poop":
			return Inventory.bowel >= 15.0 and not p.fishing.is_busy() and not p.swimming and not p.carrying
		"toast":
			return Inventory.get_drink() != null and not p.is_busy_body()
		"gift":
			return p.focus != null and p.focus.get_gift_prompt(p) != ""
		"flashlight":
			return Inventory.count_of("tool", &"flashlight") > 0
		"drop_cart":
			return not Inventory.cart.is_empty() and Inventory.theft == Inventory.Theft.NONE
		"dispute":
			var t: Node = p.focus.get_parent() if p.focus else null
			return t != null and t.is_in_group("players") and t != p
	return false


func activate(id: String) -> void:
	if not visible:
		return
	var p := get_tree().get_first_node_in_group("local_player")
	if p == null or not can_do(id):
		if p:
			Events.notify("Сейчас нельзя", Color.LIGHT_GRAY)
		close()
		return
	close()
	var m := get_tree().get_first_node_in_group("mischief")
	match id:
		"doctor": m.call_doctor()
		"bucket": m.remove_bucket()
		"goose": get_tree().get_first_node_in_group("goose").pay_off()
		"mermaid": m.answer_prank(false)
		"mermaid_fish": m.answer_prank(true)
		"pee":
			p.start_toilet("pee")
		"poop":
			p.start_toilet("poop")
		"toast":
			p.propose_toast()
		"gift":
			if p.focus and p.focus.get_gift_prompt(p) != "":
				p.focus.gift(p)
		"flashlight":
			p.toggle_flashlight()
		"drop_cart":
			Inventory.drop_cart()
			Events.notify("Выложил всё обратно на полки", Color.LIGHT_GRAY)
		"dispute":
			var t: Node = p.focus.get_parent() if p.focus else null
			var ui := get_tree().get_first_node_in_group("dispute_ui")
			if ui and t:
				ui.open(t)
