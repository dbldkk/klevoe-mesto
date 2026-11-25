extends CanvasLayer
## Сон и итоги дня.
## CHOOSING: хост выбирает, до скольки спать (остальные ждут).
## SUMMARY: карточки всех игроков — деньги, выпито, улов и титул «Главный …». Хост жмёт «Новый день».

var _choose: PanelContainer
var _choose_body: VBoxContainer
var _summary: PanelContainer
var _title: Label
var _cards: HFlowContainer
var _new_day_btn: Button
var _wait_label: Label
var _dc: DayCycle


func _ready() -> void:
	layer = 7
	add_to_group("day_ui")
	_build_choose()
	_build_summary()
	_choose.visible = false
	_summary.visible = false
	await get_tree().process_frame
	_dc = get_tree().get_first_node_in_group("day_cycle") as DayCycle
	if _dc:
		_dc.phase_changed.connect(_on_phase)


func _build_choose() -> void:
	_choose = UiKit.panel(Vector2(520, 0), Color(0.05, 0.07, 0.14, 0.94))
	_choose.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_choose.position.y = 60
	add_child(_choose)
	_choose_body = VBoxContainer.new()
	_choose_body.add_theme_constant_override("separation", 10)
	_choose.add_child(_choose_body)


func _build_summary() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_summary = PanelContainer.new()
	_summary.set_anchors_preset(Control.PRESET_FULL_RECT)
	_summary.add_theme_stylebox_override("panel", UiKit.box(Color(0.03, 0.04, 0.08, 0.96), 0, 30))
	root.add_child(_summary)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	_summary.add_child(v)
	_title = UiKit.title("", Color(1.0, 0.85, 0.45))
	_title.add_theme_font_size_override("font_size", 44)
	v.add_child(_title)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(center)
	_cards = HFlowContainer.new()
	_cards.custom_minimum_size.x = 1000
	_cards.add_theme_constant_override("h_separation", 16)
	_cards.add_theme_constant_override("v_separation", 16)
	_cards.alignment = FlowContainer.ALIGNMENT_CENTER
	center.add_child(_cards)
	_wait_label = UiKit.label("", 18, Color(1, 1, 1, 0.6))
	_wait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_wait_label)
	var c := CenterContainer.new()
	v.add_child(c)
	_new_day_btn = UiKit.button("☀  Новый день", func() -> void:
		if _dc:
			NetUtil.call_server(_dc, "srv_new_day", []), 24)
	_new_day_btn.custom_minimum_size = Vector2(300, 56)
	c.add_child(_new_day_btn)


func _on_phase(p: int) -> void:
	match p:
		DayCycle.Phase.CHOOSING:
			_show_choose()
		DayCycle.Phase.AWAKE:
			close_all()


func _show_choose() -> void:
	ModalUi.clear(_choose_body)
	_choose_body.add_child(UiKit.title("Все легли спать", Color(0.7, 0.8, 1.0)))
	_choose_body.add_child(_centered(UiKit.label("Сейчас %s" % (_dc.clock_text() if _dc else ""), 18, Color(1, 1, 1, 0.7))))
	if multiplayer.is_server():
		_choose_body.add_child(_centered(UiKit.label("До скольки спим?", 20)))
		var r := ModalUi.row(8)
		r.alignment = BoxContainer.ALIGNMENT_CENTER
		for h in [6, 8, 10, 12]:
			var hh: int = h
			r.add_child(UiKit.button("%02d:00" % h, func() -> void:
				NetUtil.call_server(_dc, "srv_choose_wake", [hh])
				_choose.visible = false
				_release_mouse(false), 20))
		_choose_body.add_child(r)
		_release_mouse(true)
	else:
		_choose_body.add_child(_centered(UiKit.label("Хост выбирает, до скольки спать… Zzz", 19)))
	_choose.visible = true


func _centered(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func show_summary(s: Dictionary) -> void:
	_choose.visible = false
	_title.text = ("Вырубились в 5 утра… " if s.get("forced", false) else "") + "Итоги дня %d" % int(s.day)
	ModalUi.clear(_cards)
	var rows: Array = s.rows
	rows.sort_custom(func(a, b) -> bool: return int(a.get("money", 0)) > int(b.get("money", 0)))
	for row in rows:
		_cards.add_child(_card(row))
	var host := multiplayer.is_server()
	_new_day_btn.visible = host
	_wait_label.text = "Подъём в %02d:00. %s" % [int(s.wake),
		"Жми, когда все насмотрятся (или само через 40 с)" if host else "Ждём, когда хост начнёт новый день…"]
	_summary.visible = true
	_release_mouse(true)


func _card(r: Dictionary) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(300, 0)
	p.add_theme_stylebox_override("panel", UiKit.box(Color(0.12, 0.14, 0.2, 0.95), 12, 16))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	var nm := UiKit.label(str(r.get("name", "?")), 26, Color(0.8, 0.9, 1.0))
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(nm)
	var t := UiKit.label(str(r.get("title", "")), 22, Color(1.0, 0.8, 0.3))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var st := UiKit.label(str(r.get("subtitle", "")), 16, Color(1, 0.92, 0.75, 0.8))
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(st)
	v.add_child(HSeparator.new())
	var delta := int(r.get("money_delta", 0))
	_line(v, "Баланс", "%d ₽ (%s%d)" % [int(r.get("money", 0)), "+" if delta >= 0 else "", delta],
		Color.GOLD if delta >= 0 else Color.TOMATO)
	_line(v, "Выпито", "%d" % int(r.get("drinks", 0)))
	_line(v, "Поймано", "%d рыб, %.1f кг" % [int(r.get("fish", 0)), float(r.get("fish_kg", 0.0))])
	if int(r.get("bets", 0)) > 0:
		_line(v, "Казино", "+%d / −%d ₽" % [int(r.get("bet_won", 0)), int(r.get("bet_lost", 0))])
	for k in [["hits", "Ударов"], ["thefts", "Краж"], ["boxes", "Коробок"], ["bottles", "Сдал бутылок"], ["smokes", "Выкурил"]]:
		if int(r.get(k[0], 0)) > 0:
			_line(v, k[1], str(int(r.get(k[0], 0))))
	return p


func _line(v: VBoxContainer, a: String, b: String, c := Color.WHITE) -> void:
	var h := ModalUi.row(6)
	var l := UiKit.label(a, 16, Color(1, 1, 1, 0.65))
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	h.add_child(UiKit.label(b, 16, c))
	v.add_child(h)


func _release_mouse(on: bool) -> void:
	Events.ui_open = on
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if on else Input.MOUSE_MODE_CAPTURED


func close_all() -> void:
	var was := _summary.visible or (_choose.visible and multiplayer.is_server())
	_choose.visible = false
	_summary.visible = false
	if was:
		_release_mouse(false)
