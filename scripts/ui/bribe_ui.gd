extends ModalUi
## «Договориться» с участковым: деньги, рыба, бутылка — или «пройду, начальник».
## Решает хост (Police.srv_bribe), здесь только выбор. Время на раздумье ограничено.

var _police: Node
var _list: VBoxContainer
var _timer: Label
var _left := 0.0
var _sent := false


func _ready() -> void:
	_setup("bribe_ui", "УЧАСТКОВЫЙ ПЕТРОВИЧ", 560, Color(0.6, 0.75, 1.0))
	_timer = UiKit.label("", 18, Color(1, 0.8, 0.5))
	_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_timer)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	body.add_child(_list)


func offer(police: Node, reason: String, secs: float) -> void:
	_police = police
	_left = secs
	_sent = false
	ModalUi.clear(_list)
	var head := UiKit.label("«Так-так, гражданин. %s — это до суток. Ну что, будем оформлять… или как?»" % (reason.substr(0, 1).to_upper() + reason.substr(1)), 18)
	head.autowrap_mode = TextServer.AUTOWRAP_WORD
	_list.add_child(head)
	for sum in [300, 700, 1500]:
		if Inventory.money >= sum:
			var s: int = sum
			_list.add_child(UiKit.button("Сунуть %d ₽ «на бензин»" % s, func() -> void: _send("money", s, {})))
	# Самая ценная рыба
	var best := -1
	var best_v := 0
	for i in Inventory.basket.size():
		var v := Inventory.fish_price(Inventory.basket[i])
		if v > best_v:
			best_v = v
			best = i
	if best >= 0:
		var f: Dictionary = Inventory.basket[best]
		var fd := GameData.get_fish(f.id)
		_list.add_child(UiKit.button("Отдать рыбу: %s, %.2f кг" % [fd.display_name, f.kg], func() -> void:
			_send("fish", best_v, {"id": String(f.id), "kg": f.kg})))
	# Самая дорогая бутылка
	var bd: DrinkData = null
	for s in Inventory.slots:
		if s and s.kind == "drink":
			var d := GameData.get_drink(s.id)
			if d and (bd == null or d.price > bd.price):
				bd = d
	if bd:
		var did := bd.id
		_list.add_child(UiKit.button("Предложить бутылку: %s" % bd.display_name, func() -> void:
			_send("drink", bd.price, {"id": String(did)})))
	_list.add_child(UiKit.button("«Пройду, начальник…»", func() -> void: _send("surrender", 0, {})))
	_show()


func _send(kind: String, value: int, data: Dictionary) -> void:
	if _sent:
		return
	_sent = true
	NetUtil.call_server(_police, "srv_bribe", [kind, value, data])
	close()


func _process(delta: float) -> void:
	if not visible:
		return
	_left -= delta
	_timer.text = "Думай быстрее: %d с" % maxi(int(ceil(_left)), 0)
	if _left <= 0.0:
		_sent = true
		close()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_send("surrender", 0, {})
