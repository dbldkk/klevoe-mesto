extends CanvasLayer
## Разговор с Дядей Толей: продажа рыбы с торгом и подарки.

var _trader: Trader
var _fish_list: ItemList
var _status: Label
var _speech: Label
var _his_offer: Label
var _my_price: Label
var _slider: HSlider
var _sell_his: Button
var _sell_mine: Button
var _gift_fish: Button
var _gift_drink: Button
var _gift_snack: Button
var _sell_moon: Button
const MOON_PRICE := 110
var _repair_box: VBoxContainer
var _tb: Dictionary = {}
var _repair_sig := ""
var _bonus := 0.0         ## насколько он уже «подвинулся» в этом разговоре
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	layer = 6
	add_to_group("trader_ui")
	visible = false
	_rng.randomize()
	_build()
	Inventory.changed.connect(func() -> void:
		if visible:
			_refresh_fish())


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel := UiKit.panel(Vector2(760, 0))
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	v.add_child(UiKit.title("ДЯДЯ ТОЛЯ · РЫНОК", Color(0.45, 0.75, 1.0)))
	_status = UiKit.label("", 17, Color(1, 1, 1, 0.7))
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_status)
	var bars := HBoxContainer.new()
	bars.alignment = BoxContainer.ALIGNMENT_CENTER
	bars.add_theme_constant_override("separation", 14)
	v.add_child(bars)
	for k in [["drunk", "Пьяный", Color(0.85, 0.45, 0.9)], ["mood", "Настроение", Color(0.95, 0.8, 0.3)],
			["loyalty", "К тебе", Color(0.35, 0.75, 1.0)]]:
		bars.add_child(UiKit.label(k[1], 15, Color(1, 1, 1, 0.7)))
		var b := UiKit.bar(k[2], Vector2(120, 12))
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bars.add_child(b)
		_tb[k[0]] = b
	_speech = UiKit.label("", 20, Color(1, 0.92, 0.75))
	load("res://scripts/ui/speech_watch.gd").attach(self, _speech, func() -> String: return "m_low")
	_speech.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speech.autowrap_mode = TextServer.AUTOWRAP_WORD
	v.add_child(_speech)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 18)
	v.add_child(cols)

	# Левая колонка — садок
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	left.add_child(UiKit.label("Твой садок (выбери рыбу):", 17, Color(1, 0.9, 0.6)))
	_fish_list = ItemList.new()
	_fish_list.select_mode = ItemList.SELECT_MULTI
	_fish_list.custom_minimum_size = Vector2(340, 250)
	_fish_list.multi_selected.connect(func(_i, _s) -> void: _refresh_offer())
	left.add_child(_fish_list)
	var sel_all := UiKit.button("Выбрать всю рыбу", func() -> void:
		for i in _fish_list.item_count:
			_fish_list.select(i, false)
		_refresh_offer())
	left.add_child(sel_all)

	# Правая колонка — торг и подарки
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	cols.add_child(right)
	right.add_child(UiKit.label("Торг", 20, Color(1, 0.9, 0.6)))
	_his_offer = UiKit.label("", 19)
	right.add_child(_his_offer)
	_sell_his = UiKit.button("Отдать за его цену", _sell_at_his)
	right.add_child(_sell_his)
	_my_price = UiKit.label("", 19)
	right.add_child(_my_price)
	_slider = HSlider.new()
	_slider.min_value = 50
	_slider.max_value = 250
	_slider.step = 5
	_slider.value = 100
	_slider.value_changed.connect(func(_v) -> void: _refresh_offer())
	right.add_child(_slider)
	_sell_mine = UiKit.button("Предложить свою цену", _propose)
	right.add_child(_sell_mine)

	right.add_child(HSeparator.new())
	right.add_child(UiKit.label("Подарки", 20, Color(1, 0.9, 0.6)))
	_gift_drink = UiKit.button("", func() -> void:
		if _trader.give_drink():
			_after_gift("Ооо! Вот это уважение!"))
	right.add_child(_gift_drink)
	_gift_snack = UiKit.button("", func() -> void:
		var i := Inventory.first_food_slot()
		if i >= 0 and _trader.give_snack(i):
			_after_gift("Закусь — это правильно."))
	right.add_child(_gift_snack)
	_sell_moon = UiKit.button("", func() -> void:
		if Inventory.remove_item("drink", &"samogon", 1):
			Inventory.money += MOON_PRICE
			Inventory.stat_add("earned", MOON_PRICE)
			Inventory.changed.emit()
			Sfx.play("coin")
			NetUtil.call_server(_trader, "srv_gift", ["snack", 0.0, &""])
			_after_gift(["Свой, домашний? Беру!", "О, первач! Уважаю.", "Чистый как слеза. Давай ещё неси."].pick_random()))
	right.add_child(_sell_moon)
	_gift_fish = UiKit.button("Подарить выбранную рыбу", func() -> void:
		var sel := _fish_list.get_selected_items()
		if sel.size() == 1 and _trader.give_fish(sel[0]):
			_after_gift("Ух ты, спасибо, рыбачок!"))
	right.add_child(_gift_fish)

	right.add_child(HSeparator.new())
	right.add_child(UiKit.label("Ремонт удочек", 20, Color(1, 0.9, 0.6)))
	_repair_box = VBoxContainer.new()
	right.add_child(_repair_box)

	v.add_child(UiKit.button("Уйти (Esc)", close))


func open(trader: Trader) -> void:
	_trader = trader
	_bonus = 0.0
	visible = true
	Events.ui_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_speech.text = "«%s»" % trader.say()
	_repair_sig = ""
	trader.talk_anim()
	_slider.value = 100
	_refresh_fish()


func close() -> void:
	visible = false
	Events.ui_open = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var p := get_tree().get_first_node_in_group("local_player")
	if p:
		p.input_cooldown = 0.3


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _process(_delta: float) -> void:
	if not visible or _trader == null:
		return
	if not _trader.is_available():
		close()
		return
	_status.text = "Состояние: %s · К тебе: %s" % [_trader.status_word(),
		GameData.loyalty_word(Inventory.trader_loyalty)]
	_tb.drunk.value = _trader.drunk
	_tb.mood.value = _trader.mood + 50.0
	_tb.loyalty.value = Inventory.trader_loyalty / 2.0 + 50.0
	var d := Inventory.get_drink()
	_gift_drink.text = "Налить: %s" % d.display_name if d else "Налить (нечего)"
	_gift_drink.disabled = d == null
	var fi := Inventory.first_food_slot()
	var food = Inventory.slot(fi) if fi >= 0 else null
	_gift_snack.text = "Дать закусить: %s" % GameData.item_name(food.kind, food.id) if food else "Закусить (нечем)"
	_gift_snack.disabled = food == null
	var moon := Inventory.count_of("drink", &"samogon")
	_sell_moon.text = "Продать самогон: %d ₽ (есть %d)" % [MOON_PRICE, moon]
	_sell_moon.disabled = moon == 0
	_refresh_repair()
	_gift_fish.disabled = _fish_list.get_selected_items().size() != 1
	_refresh_offer()


func _refresh_repair() -> void:
	var sig := ""
	for i in Inventory.rod_slots():
		sig += "%d:%s;" % [i, Inventory.slot(i).cond]
	sig += str(Inventory.money) + str(roundi(_trader.drunk / 10.0))
	if sig == _repair_sig:
		return
	_repair_sig = sig
	for c in _repair_box.get_children():
		c.queue_free()
	var any := false
	for i in Inventory.rod_slots():
		var s = Inventory.slot(i)
		if s.cond >= 99.5:
			continue
		any = true
		var rod := GameData.get_rod(s.id)
		var cost := _trader.repair_cost(rod, s.cond)
		var idx := i
		var b := UiKit.button("%s (%s) — %d ₽" % [rod.display_name, GameData.condition_word(s.cond), cost],
			func() -> void:
				var res := _trader.repair(idx)
				if res != "":
					_speech.text = "«%s»" % res
				_repair_sig = "", 15)
		b.disabled = Inventory.money < cost
		_repair_box.add_child(b)
	if not any:
		_repair_box.add_child(UiKit.label("Все удочки целы", 14, Color(1, 1, 1, 0.5)))


func _refresh_fish() -> void:
	_fish_list.clear()
	for e in Inventory.basket:
		var f := GameData.get_fish(e.id)
		var i := _fish_list.add_item("%s — %.2f кг" % [f.display_name, e.kg])
		_fish_list.set_item_custom_fg_color(i, FishData.rarity_color(f.rarity))
		_fish_list.select(i, false)
	_refresh_offer()


func _selected() -> Array:
	return Array(_fish_list.get_selected_items())


func _fair() -> int:
	var sel := _selected()
	return Inventory.basket_value(sel) if not sel.is_empty() else 0


func _his_price() -> int:
	var f := _trader.offer_factor(Inventory.trader_loyalty)
	return roundi(_fair() * minf(f + _bonus, _trader.accept_factor(Inventory.trader_loyalty)))


func _my_ask() -> int:
	return roundi(_fair() * _slider.value / 100.0)


func _refresh_offer() -> void:
	if _trader == null:
		return
	var has := not _selected().is_empty()
	_his_offer.text = "Он даёт: %d ₽" % _his_price() if has else "Выбери рыбу слева"
	_my_price.text = "Ты просишь: %d ₽" % _my_ask() if has else ""
	_sell_his.disabled = not has
	_sell_mine.disabled = not has


func _sell_at_his() -> void:
	_deal(_his_price(), ["Договорились.", "Забирай деньги.", "Приятно иметь дело."].pick_random())


func _propose() -> void:
	var ask := _my_ask()
	var his := _his_price()
	if ask <= his:
		_deal(ask, "Да хоть даром, ха! Держи.")
		return
	var limit := _fair() * _trader.accept_factor(Inventory.trader_loyalty) * _rng.randf_range(0.9, 1.1)
	if ask <= limit:
		_deal(ask, ["Эх, грабишь… Ладно, по рукам!", "Ну ты и жук. Давай.", "Ладно-ладно, уговорил."].pick_random())
	else:
		_trader.report_refusal()
		# Немного уступает, если настаивать.
		_bonus += (ask - his) / maxf(_fair(), 1.0) * 0.3
		_speech.text = "«%s»" % ["Ты чего, с дуба рухнул?", "Не-не-не, за такие деньги сам лови.",
			"Совести у тебя нет!", "Хм… Нет. Но могу чуть добавить."].pick_random()


func _deal(price: int, line: String) -> void:
	var sel := _selected()
	if sel.is_empty():
		return
	Inventory.sell_fish(sel, price)
	_trader.report_deal()
	_bonus = 0.0
	_speech.text = "«%s»" % line
	Events.notify("Продано на %d ₽" % price, Color.GOLD)


func _after_gift(line: String) -> void:
	_speech.text = "«%s»" % line
	_bonus += 0.03
