extends CanvasLayer
## Инвентарь (Tab): квадратики с картинками вещей (перетаскиваются мышью),
## садок с рыбой, справочник рыб и статистика игрока.

var _tabs: Array[Button] = []
var _pages: Array[Control] = []
var _slots: Array[ItemSlot] = []
var _detail_icon: TextureRect
var _detail_name: Label
var _detail_desc: Label
var _detail_actions: HBoxContainer
var _basket_box: GridContainer
var _stats_box: VBoxContainer
var _stats_box2: VBoxContainer
var _book_holder: Control
var _focus_slot := -1


func _ready() -> void:
	layer = 6
	add_to_group("inventory_ui")
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.4)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := UiKit.panel(Vector2(1060, 660))
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	v.add_child(tabs)
	for t in ["Вещи", "Садок", "Справочник", "Статистика"]:
		var b := UiKit.button(t, Callable(), 17)
		b.custom_minimum_size.x = 150
		b.toggle_mode = true
		var idx := _tabs.size()
		b.pressed.connect(func() -> void: _show_page(idx))
		tabs.add_child(b)
		_tabs.append(b)

	var pages := Control.new()
	pages.custom_minimum_size = Vector2(1010, 520)
	v.add_child(pages)
	_pages.append(_build_items_page())
	_pages.append(_build_basket_page())
	_book_holder = Control.new()
	_pages.append(_book_holder)
	_pages.append(_build_stats_page())
	for p in _pages:
		p.set_anchors_preset(Control.PRESET_FULL_RECT)
		pages.add_child(p)
	v.add_child(UiKit.button("Закрыть (Tab / Esc)", close))
	Inventory.changed.connect(func() -> void:
		if visible:
			_refresh())
	_show_page(0)


func _show_page(i: int) -> void:
	for k in _pages.size():
		_pages[k].visible = k == i
		_tabs[k].button_pressed = k == i
	if i == 2:
		for c in _book_holder.get_children():
			c.queue_free()
		var view := FishBookUI.make_view()
		view.set_anchors_preset(Control.PRESET_FULL_RECT)
		_book_holder.add_child(view)


func open() -> void:
	visible = true
	Events.ui_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()


func close() -> void:
	visible = false
	Events.ui_open = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var p := get_tree().get_first_node_in_group("local_player")
	if p:
		p.input_cooldown = 0.3


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("inventory")):
		get_viewport().set_input_as_handled()
		close()


# ------------------------------------------------------------ вещи

func _build_items_page() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 20)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	h.add_child(left)
	left.add_child(UiKit.label("Панель быстрого доступа (1-9)", 15, UiKit.ACCENT))
	var hot := GridContainer.new()
	hot.columns = 9
	hot.add_theme_constant_override("h_separation", 6)
	left.add_child(hot)
	left.add_child(UiKit.label("Рюкзак — перетаскивай вещи мышкой", 15, UiKit.ACCENT))
	var bag := GridContainer.new()
	bag.columns = 9
	bag.add_theme_constant_override("h_separation", 6)
	bag.add_theme_constant_override("v_separation", 6)
	left.add_child(bag)
	for i in Inventory.SLOTS:
		var s := ItemSlot.new()
		s.index = i
		s.draggable = true
		if i < Inventory.HOTBAR:
			s.set_number(str(i + 1))
			hot.add_child(s)
		else:
			bag.add_child(s)
		s.clicked.connect(_on_slot_clicked)
		s.hovered.connect(func(idx: int) -> void: _show_detail(idx))
		_slots.append(s)

	var right := PanelContainer.new()
	right.custom_minimum_size = Vector2(330, 0)
	right.add_theme_stylebox_override("panel", UiKit.box(Color(1, 1, 1, 0.04), 10, 16))
	h.add_child(right)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 8)
	right.add_child(dv)
	_detail_icon = TextureRect.new()
	_detail_icon.custom_minimum_size = Vector2(140, 140)
	_detail_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	dv.add_child(_detail_icon)
	_detail_name = UiKit.label("", 20, UiKit.ACCENT)
	_detail_name.autowrap_mode = TextServer.AUTOWRAP_WORD
	dv.add_child(_detail_name)
	_detail_desc = UiKit.label("Наведи на вещь", 15, Color(1, 1, 1, 0.75))
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	_detail_desc.custom_minimum_size.x = 290
	dv.add_child(_detail_desc)
	_detail_actions = HBoxContainer.new()
	_detail_actions.add_theme_constant_override("separation", 6)
	dv.add_child(_detail_actions)
	return h


func _on_slot_clicked(index: int, button: int) -> void:
	_focus_slot = index
	_show_detail(index)
	if button == MOUSE_BUTTON_RIGHT:
		_quick_use(index)


func _show_detail(index: int) -> void:
	if index < 0:
		return
	var s = Inventory.slot(index)
	for c in _detail_actions.get_children():
		c.queue_free()
	if s == null:
		_detail_icon.texture = null
		_detail_name.text = ""
		_detail_desc.text = "Пустая ячейка"
		return
	var cond: float = s.get("cond", 100.0)
	_detail_icon.texture = Icons.get_icon(s.kind, s.id, cond)
	_detail_name.text = GameData.item_name(s.kind, s.id) + (" ×%d" % s.count if s.count > 1 else "")
	var d := GameData.item_description(s.kind, s.id)
	if s.kind == "rod":
		d += "\nСостояние: %s" % GameData.condition_word(cond)
	if s.kind == "bait" and s.id == Inventory.equipped_bait:
		d += "\nСейчас на крючке."
	_detail_desc.text = d
	if index >= Inventory.HOTBAR:
		_action_btn("На панель", func() -> void: _to_hotbar(index))
	if GameData.is_edible(s.kind, s.id):
		_action_btn("Съесть", func() -> void: _eat(index))
	if s.kind == "bait" and s.id != Inventory.equipped_bait:
		_action_btn("Насадить", func() -> void:
			Inventory.equip_bait(s.id)
			_show_detail(index))
	if s.kind == "drink":
		_action_btn("Выпить", func() -> void: _drink(index))
	_action_btn("Выбросить", func() -> void:
		Inventory.remove_slot(index, s.count)
		_show_detail(index))


func _action_btn(text: String, cb: Callable) -> void:
	var b := UiKit.button(text, cb, 15)
	_detail_actions.add_child(b)


func _quick_use(index: int) -> void:
	var s = Inventory.slot(index)
	if s == null:
		return
	if GameData.is_edible(s.kind, s.id) and s.kind == "food":
		_eat(index)
	elif s.kind == "drink":
		_drink(index)
	elif s.kind == "bait":
		Inventory.equip_bait(s.id)


func _to_hotbar(index: int) -> void:
	for i in Inventory.HOTBAR:
		if Inventory.slot(i) == null:
			Inventory.move_slot(index, i)
			return
	Inventory.move_slot(index, Inventory.selected)


func _eat(index: int) -> void:
	var p := get_tree().get_first_node_in_group("local_player")
	if p:
		p.try_eat(index)
	_show_detail(index)


func _drink(index: int) -> void:
	if index < Inventory.HOTBAR:
		Inventory.select(index)
	else:
		_to_hotbar(index)
		var i := Inventory.first_of_kind("drink")
		if i >= 0 and i < Inventory.HOTBAR:
			Inventory.select(i)
	close()
	var p := get_tree().get_first_node_in_group("local_player")
	if p:
		p.try_drink()


# ------------------------------------------------------------ садок

func _build_basket_page() -> Control:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_basket_box = GridContainer.new()
	_basket_box.columns = 6
	_basket_box.add_theme_constant_override("h_separation", 10)
	_basket_box.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_basket_box)
	return scroll


func _refresh_basket() -> void:
	for c in _basket_box.get_children():
		c.queue_free()
	if Inventory.basket.is_empty():
		_basket_box.add_child(UiKit.label("Садок пуст — иди лови!", 18, Color(1, 1, 1, 0.6)))
		return
	for e in Inventory.basket:
		var f := GameData.get_fish(e.id)
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(156, 150)
		var sb := UiKit.box(Color(1, 1, 1, 0.05), 10, 8)
		sb.border_color = FishData.rarity_color(f.rarity)
		sb.border_width_bottom = 3
		card.add_theme_stylebox_override("panel", sb)
		var v := VBoxContainer.new()
		card.add_child(v)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(130, 90)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = Icons.get_icon("fish", f.id)
		v.add_child(icon)
		var n := UiKit.label(f.display_name, 15, FishData.rarity_color(f.rarity))
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(n)
		var w := UiKit.label("%.2f кг" % e.kg, 14, Color(1, 1, 1, 0.75))
		w.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(w)
		_basket_box.add_child(card)


# ------------------------------------------------------------ статистика

func _build_stats_page() -> Control:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 40)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(h)
	_stats_box = VBoxContainer.new()
	_stats_box.custom_minimum_size.x = 470
	_stats_box.add_theme_constant_override("separation", 6)
	h.add_child(_stats_box)
	_stats_box2 = VBoxContainer.new()
	_stats_box2.custom_minimum_size.x = 470
	_stats_box2.add_theme_constant_override("separation", 6)
	h.add_child(_stats_box2)
	return sc


func _stat(name: String, value: String, box: VBoxContainer = null) -> void:
	var h := HBoxContainer.new()
	var l := UiKit.label(name, 17, Color(1, 1, 1, 0.7))
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	h.add_child(UiKit.label(value, 17))
	(box if box else _stats_box).add_child(h)


func _bar(name: String, value: float, color: Color) -> void:
	_stats_box.add_child(UiKit.label(name, 15, Color(1, 1, 1, 0.7)))
	var b := UiKit.bar(color, Vector2(460, 12))
	b.value = value
	_stats_box.add_child(b)


func _refresh_stats() -> void:
	for box in [_stats_box, _stats_box2]:
		for c in box.get_children():
			c.queue_free()
	var s := Inventory.stats
	var t := Inventory.today
	_stats_box.add_child(UiKit.label(Net.player_name, 26, UiKit.ACCENT))
	_stat("Деньги", "%d ₽" % Inventory.money)
	_bar("Здоровье", Inventory.health, Color(0.85, 0.25, 0.25))
	_bar("Сытость", Inventory.satiety, Color(0.95, 0.6, 0.25))
	_bar("Хочется в туалет", maxf(Inventory.bladder, Inventory.bowel), Color(0.95, 0.85, 0.3))
	_bar("Опьянение: %s" % GameData.drunk_word(Inventory.drunk), Inventory.drunk, Color(0.75, 0.45, 0.95))
	_bar("Дядя Толя к тебе: %s" % GameData.loyalty_word(Inventory.trader_loyalty),
		(Inventory.trader_loyalty + 100.0) / 2.0, Color(0.4, 0.7, 1.0))
	_stats_box.add_child(HSeparator.new())
	_stats_box.add_child(UiKit.label("Сегодня", 20, UiKit.ACCENT))
	_stat("Выпито", str(t.get("drinks", 0)))
	_stat("Поймано", "%d рыб, %.1f кг" % [t.get("fish", 0), float(t.get("fish_kg", 0.0))])
	_stat("Заработано", "%d ₽" % int(t.get("earned", 0)))
	_stat("Казино: выиграно / проиграно", "%d / %d ₽" % [t.get("bet_won", 0), t.get("bet_lost", 0)])

	var b2 := _stats_box2
	b2.add_child(UiKit.label("За всё время", 22, UiKit.ACCENT))
	_stat("Поймано рыбы", str(s.get("caught", 0)), b2)
	var big := "—" if float(s.get("biggest_kg", 0)) <= 0 else "%s, %.2f кг" % [s.biggest_name, s.biggest_kg]
	_stat("Самая крупная", big, b2)
	_stat("Заработано", "%d ₽" % int(s.get("earned", 0)), b2)
	_stat("Потрачено", "%d ₽" % int(s.get("spent", 0)), b2)
	_stat("Выпито бутылок", str(s.get("drinks", 0)), b2)
	_stat("Выкурено", str(s.get("smokes", 0)), b2)
	_stat("Раз вырубался", str(s.get("blackouts", 0)), b2)
	_stat("Сломано удочек", str(s.get("rods_broken", 0)), b2)
	_stat("Удачных краж / попался", "%d / %d" % [s.get("thefts_ok", 0), s.get("thefts_busted", 0)], b2)
	_stat("Брошено бутылок", str(s.get("bottles_thrown", 0)), b2)
	_stat("Ударов / нокаутов", "%d / %d" % [s.get("hits", 0), s.get("knockouts", 0)], b2)
	_stat("Ставок в казино", str(s.get("bets", 0)), b2)
	_stat("Выиграно / проиграно", "%d / %d ₽" % [s.get("bet_won", 0), s.get("bet_lost", 0)], b2)
	_stat("Сдано бутылок", str(s.get("bottles_returned", 0)), b2)
	_stat("Перетаскано коробок", str(s.get("boxes", 0)), b2)
	_stat("Сходил по-большому", str(s.get("poops", 0)), b2)


func _refresh() -> void:
	for s in _slots:
		s.refresh()
		s.set_selected(s.index == Inventory.selected)
	if _focus_slot >= 0:
		_show_detail(_focus_slot)
	_refresh_basket()
	_refresh_stats()
