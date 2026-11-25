extends ModalUi
## Прилавок «Бухло & Табак»: всё покупается сразу, без корзины.

var _store: Node
var _title: Label
var _speech: Label
var _money: Label
var _grid: GridContainer


func _ready() -> void:
	_setup("store_ui", "", 720, Color(1.0, 0.55, 0.35))
	_title = UiKit.title("", Color(1.0, 0.55, 0.35))
	body.add_child(_title)
	_speech = UiKit.label("", 19, Color(1, 0.92, 0.75))
	load("res://scripts/ui/speech_watch.gd").attach(self, _speech, func() -> String:
		return "old" if _seller() == "Баба Зоя" else "f")
	_speech.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_speech)
	_money = UiKit.label("", 18, Color.GOLD)
	_money.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_money)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 430)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(sc)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 8)
	sc.add_child(_grid)
	body.add_child(UiKit.button("Уйти (Esc)", close))
	Inventory.changed.connect(func() -> void:
		if visible:
			_money.text = "В кармане: %d ₽" % Inventory.money)


func open(store: Node) -> void:
	_store = store
	_title.text = store.store_title() if store.has_method("store_title") else "БУХЛО & ТАБАК"
	_speech.text = "%s: «%s»" % [_seller(), store.greeting()]
	_money.text = "В кармане: %d ₽" % Inventory.money
	ModalUi.clear(_grid)
	for g in store.GOODS:
		var kind: String = g[0]
		var id: StringName = g[1]
		if GameData.get_item(kind, id) == null:
			continue
		var price: int = store.price_of(kind, id)
		var r := ModalUi.row(8)
		r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(ModalUi.item_icon(kind, id, 100.0, 44))
		var pack := Inventory.pack_of(kind, id)
		var nm := GameData.item_name(kind, id) + (" ×%d" % pack if pack > 1 else "")
		var l := UiKit.label(nm, 17)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.clip_text = true
		l.tooltip_text = GameData.item_description(kind, id)
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		r.add_child(l)
		r.add_child(UiKit.button("%d ₽" % price, func() -> void: _buy(kind, id, price), 16))
		_grid.add_child(r)
	_show()


func _buy(kind: String, id: StringName, price: int) -> void:
	if Inventory.buy(kind, id, price):
		Sfx.play("coin", null, -4.0)
		Inventory.stat_add("spent", price)
		_speech.text = "%s: «%s»" % [_seller(), ["Держи.", "Следующий!", "Пакет нужен? Нет? Ну и ладно.", "Не урони."].pick_random()]
		Events.notify("Купил: %s за %d ₽" % [GameData.item_name(kind, id), price], Color(0.9, 0.9, 0.8))


func _seller() -> String:
	return _store.seller_name() if _store and _store.has_method("seller_name") else "Люда"
