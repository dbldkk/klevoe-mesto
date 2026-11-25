extends ModalUi
## Краткий маршрут новичка и личные достижения.

var _back_group := ""


func _ready() -> void:
	_setup("guide_ui", "ПАМЯТКА РЫБАКА", 720.0)
	panel.add_theme_stylebox_override("panel", UiKit.box(Color(0.08, 0.1, 0.12), 12, 22))
	layer = 25


func open(back_group: String) -> void:
	_back_group = back_group
	# Preserve the title while rebuilding current bindings and records.
	for child in body.get_children().slice(1):
		body.remove_child(child)
		child.queue_free()
	var rows := [
		"После самогона потемнело в глазах? Q → «Позвать врача». Колокольчик приведёт к бесплатной больнице за домом.",
		"1. Дойди до берега. Выбери удочку клавишей 1.",
		"2. Зажми %s и отпусти — сила заброса зависит от удержания." % Controls.key_label("fish_action"),
		"3. Поплавок играет — жди. Утонул — нажми %s для подсечки." % Controls.key_label("fish_action"),
		"4. Подматывай с паузами. На рывке веди удочку против рыбы; при прыжке отпусти кнопку.",
		"5. Продай улов Дяде Толе на рынке. Там же можно починить удочку.",
		"%s — наживка · %s — инвентарь · %s — карта · %s — отпустить рыбу · %s — действия (туалет, тост, фонарик)" % [
			Controls.key_label("cycle_bait"), Controls.key_label("inventory"),
			Controls.key_label("map"), Controls.key_label("release_fish"), Controls.key_label("radial")],
		"Друзья: хост создаёт мир, остальные вводят его IP. В Интернете нужен UDP 7777 или общая VPN-сеть.",
	]
	for text in rows:
		var label := UiKit.label(text, 17, Color(0.88, 0.91, 0.94))
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(label)
	if get_tree().get_first_node_in_group("local_player"):
		body.add_child(HSeparator.new())
		var caught := int(Inventory.stats.get("caught", 0))
		var earned := int(Inventory.stats.get("earned", 0))
		var species: Dictionary = Inventory.stats.get("fish_count", {})
		body.add_child(UiKit.label("Твои вехи", 21, UiKit.ACCENT))
		for goal in [[caught >= 1, "Первая рыба", "%d поймано" % caught],
			[species.size() >= 5, "Пять видов", "%d / 5 видов" % species.size()],
			[earned >= 1000, "Первая тысяча", "%d / 1000 ₽ заработано" % earned]]:
			body.add_child(UiKit.label("%s  %s · %s" % ["✓" if goal[0] else "○", goal[1], goal[2]], 17,
				Color.PALE_GREEN if goal[0] else Color.WHITE))
		var record := float(Inventory.stats.get("biggest_kg", 0.0))
		if record > 0.0:
			body.add_child(UiKit.label("Рекорд: %s — %.2f кг" % [Inventory.stats.get("biggest_name", ""), record], 17))
	body.add_child(UiKit.button("Понятно", close))
	_show()


func close() -> void:
	if not visible:
		return
	var back := get_tree().get_first_node_in_group(_back_group)
	if back and back.visible:
		visible = false
		Events.ui_open = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		super.close()
