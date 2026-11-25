extends ModalUi
## Ставки в казино и у напёрсточника. Ставишь деньги или вещь (вещь человек оценит сам
## и может отказать). Слоты крутят барабаны, рулетка — шарик, напёрстки — три стакана.

const SYMBOL_ICON := {"poop": ["bait", &"poop"], "bread": ["bait", &"bread"], "beer": ["drink", &"beer"],
	"vodka": ["drink", &"vodka"], "pike": ["fish", &"pike"], "golden": ["fish", &"golden"]}
const ROULETTE := [["red", "Красное ×2"], ["black", "Чёрное ×2"], ["even", "Чёт ×2"], ["odd", "Нечет ×2"],
	["low", "1–18 ×2"], ["high", "19–36 ×2"]]

var _dealer: CasinoDealer
var _speech: Label
var _money: Label
var _amount: SpinBox
var _items: VBoxContainer
var _stake_label: Label
var _game_box: VBoxContainer
var _result: Label
var _play_btns: Array[Button] = []
var _number: SpinBox

## Текущая ставка: {"money": int} или {"item": {...}, "value": int}
var _stake := {}
var _busy := false
var _anim_t := 0.0
var _anim_kind := ""
var _anim_result := {}
var _reels: Array[TextureRect] = []
var _wheel_label: Label
var _cups: Array[Button] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_setup("casino_ui", "", 820, Color(1.0, 0.8, 0.3))
	_speech = UiKit.label("", 20, Color(1, 0.92, 0.75))
	load("res://scripts/ui/speech_watch.gd").attach(self, _speech, func() -> String:
		return "f" if _dealer and String(_dealer.face).ends_with("_f") else "m")
	_speech.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speech.autowrap_mode = TextServer.AUTOWRAP_WORD
	body.add_child(_speech)
	_money = UiKit.label("", 17, Color.GOLD)
	_money.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_money)

	var cols := ModalUi.row(18)
	body.add_child(cols)
	# Слева — ставка
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 360
	cols.add_child(left)
	left.add_child(UiKit.label("Ставка деньгами:", 18, Color(1, 0.9, 0.6)))
	var r := ModalUi.row(6)
	_amount = SpinBox.new()
	_amount.min_value = 10
	_amount.step = 10
	_amount.suffix = "₽"
	_amount.custom_minimum_size.x = 130
	r.add_child(_amount)
	r.add_child(UiKit.button("Ставлю", _stake_money, 16))
	for v in [50, 200, 1000]:
		r.add_child(UiKit.button(str(v), func() -> void: _amount.value = v, 14))
	left.add_child(r)
	left.add_child(UiKit.label("…или поставить вещь:", 18, Color(1, 0.9, 0.6)))
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 260)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(sc)
	_items = VBoxContainer.new()
	_items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_items)
	# Справа — игра
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	cols.add_child(right)
	_stake_label = UiKit.label("Ставка не выбрана", 19)
	_stake_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	right.add_child(_stake_label)
	_game_box = VBoxContainer.new()
	_game_box.add_theme_constant_override("separation", 8)
	right.add_child(_game_box)
	_result = UiKit.label("", 24, Color.WHITE)
	_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result.autowrap_mode = TextServer.AUTOWRAP_WORD
	right.add_child(_result)
	body.add_child(UiKit.button("Уйти (Esc)", close))
	Inventory.changed.connect(func() -> void:
		if visible:
			_money.text = "В кармане: %d ₽" % Inventory.money)


func open(dealer: CasinoDealer) -> void:
	_dealer = dealer
	_stake = {}
	_busy = false
	_result.text = ""
	_speech.text = "%s: «%s»" % [dealer.dealer_name, _hello()]
	_money.text = "В кармане: %d ₽" % Inventory.money
	_amount.max_value = maxi(Inventory.money, 10)
	_amount.value = clampi(100, 10, maxi(Inventory.money, 10))
	_build_game()
	_refresh_items()
	_update_stake()
	_show()


func close() -> void:
	if _busy:
		return
	super.close()


func _unhandled_input(event: InputEvent) -> void:
	if not _busy:
		super._unhandled_input(event)


func _hello() -> String:
	match _dealer.game:
		"thimbles": return ["Кручу-верчу, обмануть хочу! Ставь что угодно!", "Где шарик — там и счастье. Угадаешь?", "Подходи, не стесняйся, хоть носок ставь!"].pick_random()
		"roulette": return ["Делайте ваши ставки, господа.", "Красное или чёрное?", "Ставки принимаются."].pick_random()
	return ["Дёргай ручку, золотой карась ждёт!", "Три щуки — и ты король.", "Автомат сегодня щедрый. Наверное."].pick_random()


# ------------------------------------------------------------ выбор ставки

func _refresh_items() -> void:
	ModalUi.clear(_items)
	for i in Inventory.slots.size():
		var s = Inventory.slots[i]
		if s == null:
			continue
		_item_row(ModalUi.item_icon(s.kind, s.id, s.get("cond", 100.0), 34),
			"%s ×%d" % [GameData.item_name(s.kind, s.id), s.count],
			{"src": "slot", "i": i, "kind": s.kind, "id": s.id, "count": s.count, "cond": s.get("cond", 100.0)})
	for i in Inventory.basket.size():
		var f: Dictionary = Inventory.basket[i]
		var fd := GameData.get_fish(f.id)
		_item_row(ModalUi.item_icon("fish", f.id, 100.0, 34), "%s, %.2f кг" % [fd.display_name, f.kg],
			{"src": "fish", "i": i, "kind": "fish", "id": f.id, "count": 1, "cond": f.kg})
	if _items.get_child_count() == 0:
		_items.add_child(UiKit.label("Карманы пусты", 16, Color(1, 1, 1, 0.5)))


func _item_row(ic: TextureRect, text: String, item: Dictionary) -> void:
	var r := ModalUi.row(6)
	r.add_child(ic)
	var l := UiKit.label(text, 15)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.clip_text = true
	r.add_child(l)
	r.add_child(UiKit.button("Предложить", func() -> void: _offer_item(item), 14))
	_items.add_child(r)


func _offer_item(item: Dictionary) -> void:
	if _busy:
		return
	var a := _dealer.appraise(item.kind, item.id, item.count, item.cond)
	_speech.text = "%s: «%s»" % [_dealer.dealer_name, a.line]
	if a.ok:
		_stake = {"item": item, "value": int(a.value)}
	_update_stake()


func _stake_money() -> void:
	if _busy:
		return
	var v := int(_amount.value)
	if v > Inventory.money:
		_speech.text = "%s: «Денег-то нет столько.»" % _dealer.dealer_name
		return
	_stake = {"money": v}
	_update_stake()


func _stake_value() -> int:
	return int(_stake.get("money", _stake.get("value", 0)))


func _update_stake() -> void:
	if _stake.is_empty():
		_stake_label.text = "Ставка не выбрана"
	elif _stake.has("money"):
		_stake_label.text = "Ставка: %d ₽ (макс. выигрыш %d ₽)" % [_stake.money, _dealer.max_payout(_stake.money)]
	else:
		var it: Dictionary = _stake.item
		var nm := GameData.get_fish(it.id).display_name if it.kind == "fish" else GameData.item_name(it.kind, it.id)
		_stake_label.text = "Ставка: %s (оценили в %d ₽)" % [nm, _stake.value]
	for b in _play_btns:
		b.disabled = _stake.is_empty() or _busy


# ------------------------------------------------------------ игровая часть

func _build_game() -> void:
	ModalUi.clear(_game_box)
	_play_btns.clear()
	_reels.clear()
	_cups.clear()
	_game_box.add_child(UiKit.label(_dealer.game_title(), 26, Color(1.0, 0.8, 0.3)))
	match _dealer.game:
		"slots":
			var r := ModalUi.row(8)
			r.alignment = BoxContainer.ALIGNMENT_CENTER
			for k in 3:
				var p := PanelContainer.new()
				p.add_theme_stylebox_override("panel", UiKit.box(Color(0.95, 0.94, 0.9), 6, 6))
				var t := ModalUi.icon(_sym_icon("golden"), 84)
				p.add_child(t)
				r.add_child(p)
				_reels.append(t)
			_game_box.add_child(r)
			_game_box.add_child(UiKit.label("3 одинаковых: хлеб ×5, пиво ×8, водка ×15, щука ×30, золотой ×100.\n2 одинаковых ×2 (золотых ×4). Какашки не платят.", 14, Color(1, 1, 1, 0.65)))
			_play_btns.append(UiKit.button("Дёрнуть ручку!", func() -> void: _play({}), 20))
			_game_box.add_child(_play_btns[0])
		"roulette":
			_wheel_label = UiKit.label("—", 54, Color.WHITE)
			_wheel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_game_box.add_child(_wheel_label)
			var g := GridContainer.new()
			g.columns = 3
			for o in ROULETTE:
				var t: String = o[0]
				var b := UiKit.button(o[1], func() -> void: _play({"type": t}), 16)
				_play_btns.append(b)
				g.add_child(b)
			_game_box.add_child(g)
			var r := ModalUi.row(6)
			r.add_child(UiKit.label("Число:", 16))
			_number = SpinBox.new()
			_number.min_value = 0
			_number.max_value = 36
			r.add_child(_number)
			var nb := UiKit.button("На число ×36", func() -> void: _play({"type": "number", "n": int(_number.value)}), 16)
			_play_btns.append(nb)
			r.add_child(nb)
			_game_box.add_child(r)
		"thimbles":
			_game_box.add_child(UiKit.label("Под каким стаканом шарик? Угадаешь — ×%d" % CasinoDealer.THIMBLE_MULT, 16))
			var r := ModalUi.row(12)
			r.alignment = BoxContainer.ALIGNMENT_CENTER
			for k in 3:
				var c := k
				var b := UiKit.button("▲\nстакан %d" % (k + 1), func() -> void: _play({"cup": c}), 20)
				b.custom_minimum_size = Vector2(110, 110)
				_cups.append(b)
				_play_btns.append(b)
				r.add_child(b)
			_game_box.add_child(r)


func _sym_icon(s: String) -> Texture2D:
	var d: Array = SYMBOL_ICON.get(s, ["bait", &"poop"])
	return Icons.get_icon(d[0], d[1])


func _play(choice: Dictionary) -> void:
	if _busy or _stake.is_empty():
		return
	var host := _dealer.get_parent()
	if host.has_method("can_play") and not host.can_play():
		_speech.text = host.refuse_line()
		return
	var v := _stake_value()
	# Забираем ставку
	if _stake.has("money"):
		if Inventory.money < v:
			_speech.text = "%s: «Денег-то нет столько.»" % _dealer.dealer_name
			return
		Inventory.money -= v
		Inventory.changed.emit()
	else:
		if not _take_item(_stake.item):
			_speech.text = "%s: «А где вещь-то?»" % _dealer.dealer_name
			_stake = {}
			_update_stake()
			return
	Inventory.stat_add("bets")
	_busy = true
	_result.text = ""
	_update_stake()
	if _dealer.game == "slots":
		_speech.text = "*дзынь-дзынь-дзынь*"
	elif _dealer.game == "roulette":
		_speech.text = "%s: «Ставки сделаны, ставок больше нет.»" % _dealer.dealer_name
	else:
		_speech.text = "Гоша: «Кручу-верчу…»"
	_anim_kind = "wait"
	_anim_t = 0.0
	Sfx.play({"slots": "slot_spin", "roulette": "roulette"}.get(_dealer.game, "cups"), null, -4.0)
	_dealer.play(v, choice)


func _take_item(it: Dictionary) -> bool:
	if it.src == "fish":
		var i: int = it.i
		if i < Inventory.basket.size() and Inventory.basket[i].id == it.id:
			Inventory.remove_fish(i)
			return true
		return false
	var s = Inventory.slot(it.i)
	if s == null or s.kind != it.kind or s.id != it.id:
		return false
	Inventory.remove_slot(it.i, s.count)
	return true


## Ответ хоста.
func on_result(dealer: CasinoDealer, result: Dictionary) -> void:
	if dealer != _dealer:
		return
	_anim_result = result
	_anim_kind = dealer.game
	_anim_t = 0.0


func _process(delta: float) -> void:
	if not visible or not _busy:
		return
	_anim_t += delta
	match _anim_kind:
		"wait", "slots":
			if _dealer.game == "slots":
				var stop := 3 if _anim_kind == "wait" else int(_anim_t / 0.55)
				for k in 3:
					if _anim_kind == "wait" or k >= stop:
						if int(_anim_t * 14.0 + k) % 2 == 0:
							_reels[k].texture = _sym_icon(CasinoDealer.REELS[_rng.randi() % CasinoDealer.REELS.size()][0])
					else:
						_reels[k].texture = _sym_icon(_anim_result.reels[k])
				if _anim_kind == "slots" and _anim_t > 1.8:
					_finish()
			elif _dealer.game == "roulette":
				_wheel_label.text = str(_rng.randi() % 37)
				_wheel_label.add_theme_color_override("font_color", Color.WHITE)
			else:
				for k in 3:
					_cups[k].text = "▲\n%s" % ["…", "~", "*"][(int(_anim_t * 8.0) + k) % 3]
		"roulette":
			if _anim_t < 2.2:
				if fmod(_anim_t, 0.05 + _anim_t * 0.08) < delta:
					_wheel_label.text = str(_rng.randi() % 37)
			else:
				var n: int = _anim_result.n
				_wheel_label.text = str(n)
				_wheel_label.add_theme_color_override("font_color",
					Color(0.2, 0.9, 0.3) if n == 0 else (Color(1, 0.3, 0.3) if CasinoDealer.is_red(n) else Color(0.75, 0.75, 0.8)))
				_finish()
		"thimbles":
			if _anim_t < 1.4:
				for k in 3:
					_cups[k].text = "▲\n%s" % ["…", "~", "*"][(int(_anim_t * 10.0) + k) % 3]
			else:
				for k in 3:
					_cups[k].text = "● шарик!" if k == int(_anim_result.ball) else "▲\nпусто"
				_finish()


func _finish() -> void:
	_busy = false
	_anim_kind = ""
	var stake := int(_anim_result.get("stake", 0))
	var mult := float(_anim_result.get("mult", 0.0))
	var win := roundi(stake * mult)
	if win > 0:
		Inventory.money += win
		Inventory.stat_add("bet_won", win - stake)
		Inventory.today_add("bet_won", win - stake)
		Inventory.changed.emit()
		_result.text = "ВЫИГРЫШ: %d ₽!" % win
		Sfx.play("slot_win" if mult >= 4.0 else "coin")
		_result.add_theme_color_override("font_color", Color.GOLD)
		_speech.text = "%s: «%s»" % [_dealer.dealer_name, ["Поздравляю… повезло.", "Ну ничего себе!", "Сегодня твой день."].pick_random()]
		if mult >= 15.0:
			Events.notify("%s сорвал куш: %d ₽!" % [Net.player_name, win], Color.GOLD)
	else:
		Inventory.stat_add("bet_lost", stake)
		Inventory.today_add("bet_lost", stake)
		_result.text = "Мимо. Минус %d ₽" % stake
		Sfx.play("lose", null, -6.0)
		_result.add_theme_color_override("font_color", Color.TOMATO)
		_speech.text = "%s: «%s»" % [_dealer.dealer_name, ["Не повезло. Ещё разок?", "Отыграешься!", "Бывает. Следующая точно твоя."].pick_random()]
	# Вещь ушла — ставку надо выбрать заново; деньги — можно повторить.
	if _stake.has("item"):
		_stake = {}
		_refresh_items()
	_amount.max_value = maxi(Inventory.money, 10)
	_update_stake()
