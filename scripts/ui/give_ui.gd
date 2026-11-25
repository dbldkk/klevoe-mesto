extends ModalUi
## Передача денег и вещей другому игроку (смотришь на него и жмёшь E).

var _target: Node
var _who: Label
var _amount: SpinBox
var _items: VBoxContainer


func _ready() -> void:
	_setup("give_ui", "ПЕРЕДАТЬ", 520)
	_who = UiKit.label("", 20, Color(0.8, 0.9, 1.0))
	_who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_who)
	var r := ModalUi.row()
	r.add_child(UiKit.label("Деньги:", 18))
	_amount = SpinBox.new()
	_amount.min_value = 1
	_amount.step = 10
	_amount.custom_minimum_size.x = 140
	_amount.suffix = "₽"
	r.add_child(_amount)
	r.add_child(UiKit.button("Передать", _give_money))
	for v in [50, 100, 500]:
		r.add_child(UiKit.button(str(v), func() -> void: _amount.value = v, 15))
	body.add_child(r)
	body.add_child(UiKit.label("Или отдай вещь:", 18, Color(1, 0.9, 0.6)))
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 300)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(sc)
	_items = VBoxContainer.new()
	_items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_items)
	body.add_child(UiKit.button("Закрыть (Esc)", close))


func open(target: Node) -> void:
	_target = target
	_who.text = "Кому: %s   ·   у тебя %d ₽" % [target.player_name, Inventory.money]
	_amount.max_value = maxi(Inventory.money, 1)
	_amount.value = mini(100, maxi(Inventory.money, 1))
	_refresh()
	_show()


func _refresh() -> void:
	ModalUi.clear(_items)
	for i in Inventory.slots.size():
		var s = Inventory.slots[i]
		if s == null:
			continue
		var r := ModalUi.row(8)
		r.add_child(ModalUi.item_icon(s.kind, s.id, s.get("cond", 100.0), 36))
		var l := UiKit.label("%s ×%d" % [GameData.item_name(s.kind, s.id), s.count], 16)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(l)
		var idx := i
		r.add_child(UiKit.button("Отдать", func() -> void:
			if is_instance_valid(_target) and _target.send_item(idx):
				_refresh(), 15))
		_items.add_child(r)
	if _items.get_child_count() == 0:
		_items.add_child(UiKit.label("Отдавать нечего", 16, Color(1, 1, 1, 0.5)))


func _give_money() -> void:
	if not is_instance_valid(_target):
		close()
		return
	var a := int(_amount.value)
	if a > Inventory.money:
		Events.notify("Столько нет", Color.TOMATO)
		return
	if _target.send_money(a):
		_who.text = "Кому: %s   ·   у тебя %d ₽" % [_target.player_name, Inventory.money]
		_amount.max_value = maxi(Inventory.money, 1)
