extends ModalUi
## Окна дома: каталог улучшений и холодильник.

var _up: Node
var _title: Label
var _list: VBoxContainer
var _list2: VBoxContainer
var _cols: HBoxContainer
var _money: Label


func _ready() -> void:
	_setup("house_ui", "", 760, Color(1.0, 0.8, 0.5))
	_title = UiKit.title("", Color(1.0, 0.8, 0.5))
	body.add_child(_title)
	_money = UiKit.label("", 17, Color.GOLD)
	_money.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_money)
	_cols = ModalUi.row(18)
	body.add_child(_cols)
	_list = _scroll_col()
	_list2 = _scroll_col()
	body.add_child(UiKit.button("Закрыть (Esc)", close))


func _scroll_col() -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 380)
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_cols.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	sc.add_child(v)
	return v


func show_catalog(up: Node) -> void:
	_up = up
	_title.text = "КАТАЛОГ «УЮТНЫЙ ДОМ»"
	_money.text = "В кармане: %d ₽" % Inventory.money
	ModalUi.clear(_list)
	ModalUi.clear(_list2)
	_list2.get_parent().visible = false
	for c in up.CATALOG:
		var bit: int = c[0]
		var price: int = c[2]
		var box := VBoxContainer.new()
		var r := ModalUi.row(8)
		var l := UiKit.label("%s — %d ₽" % [c[1], price], 19)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(l)
		var owned: bool = up.has(bit)
		var b := UiKit.button("Есть" if owned else "Купить", func() -> void:
			up.buy(bit, price)
			await get_tree().create_timer(0.3).timeout
			if visible:
				show_catalog(up), 16)
		b.disabled = owned
		r.add_child(b)
		box.add_child(r)
		var d := UiKit.label(c[3], 14, Color(1, 1, 1, 0.6))
		d.autowrap_mode = TextServer.AUTOWRAP_WORD
		box.add_child(d)
		_list.add_child(box)
	_show()


func show_fridge(up: Node, items: Array) -> void:
	_up = up
	_title.text = "ХОЛОДИЛЬНИК «ЗиЛ» (общий)"
	_money.text = "Внутри: %d / %d" % [items.size(), up.FRIDGE_MAX]
	_list2.get_parent().visible = true
	ModalUi.clear(_list)
	ModalUi.clear(_list2)
	_list.add_child(UiKit.label("У тебя:", 18, Color(1, 0.9, 0.6)))
	for i in Inventory.basket.size():
		var f: Dictionary = Inventory.basket[i]
		var fd := GameData.get_fish(f.id)
		var idx := i
		_row(_list, ModalUi.item_icon("fish", f.id, 100.0, 32), "%s, %.2f кг" % [fd.display_name, f.kg], "Положить →", func() -> void:
			if idx < Inventory.basket.size():
				var e := Inventory.remove_fish(idx)
				up.fridge_put({"kind": "fish", "id": String(e.id), "kg": e.kg}))
	for i in Inventory.slots.size():
		var s = Inventory.slots[i]
		if s and (s.kind == "drink" or s.kind == "food" or (s.kind == "misc" and s.id == &"brine")):
			var id: StringName = s.id
			var kind: String = s.kind
			_row(_list, ModalUi.item_icon(kind, id, 100.0, 32), "%s ×%d" % [GameData.item_name(kind, id), s.count], "Положить →", func() -> void:
				if Inventory.remove_item(kind, id, 1):
					up.fridge_put({"kind": kind, "id": String(id)}))
	_list2.add_child(UiKit.label("В холодильнике:", 18, Color(0.7, 0.9, 1.0)))
	if items.is_empty():
		_list2.add_child(UiKit.label("Пусто. Только лампочка горит", 15, Color(1, 1, 1, 0.5)))
	for i in items.size():
		var it: Dictionary = items[i]
		var idx := i
		var txt: String
		var ic: TextureRect
		if it.kind == "fish":
			txt = "%s, %.2f кг" % [GameData.get_fish(StringName(it.id)).display_name, float(it.kg)]
			ic = ModalUi.item_icon("fish", StringName(it.id), 100.0, 32)
		else:
			txt = GameData.item_name(String(it.kind), StringName(it.id))
			ic = ModalUi.item_icon(String(it.kind), StringName(it.id), 100.0, 32)
		_row(_list2, ic, txt, "← Взять", func() -> void: up.fridge_take(idx))
	_show()


func _row(v: VBoxContainer, ic: TextureRect, text: String, btn: String, cb: Callable) -> void:
	var r := ModalUi.row(6)
	r.add_child(ic)
	var l := UiKit.label(text, 15)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.clip_text = true
	r.add_child(l)
	r.add_child(UiKit.button(btn, cb, 14))
	v.add_child(r)
