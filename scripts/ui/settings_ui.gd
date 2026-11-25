extends ModalUi
## Настройки: графика, звук (отдельно эффекты, природа, музыка, голоса), мышь и клавиши.
## Открывается из главного меню и из паузы.

var _tabs: TabContainer
var _wait_action := ""
var _wait_btn: Button
var _key_btns := {}
var _back_to := ""


func _ready() -> void:
	_setup("settings_ui", "НАСТРОЙКИ", 720, Color(0.7, 0.9, 1.0))
	layer = 20
	_tabs = TabContainer.new()
	_tabs.custom_minimum_size = Vector2(680, 470)
	body.add_child(_tabs)
	_tabs.add_child(_gfx_tab())
	_tabs.add_child(_audio_tab())
	_tabs.add_child(_keys_tab())
	var row := ModalUi.row(10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(UiKit.button("Готово", close))
	body.add_child(row)


func open(back_to := "") -> void:
	Sfx.stop_voices()
	_back_to = back_to
	_refresh_keys()
	_show()


func close() -> void:
	Sfx.stop_voices()
	Settings.save()
	Settings.changed.emit()
	if _back_to != "":
		visible = false
		var ui := get_tree().get_first_node_in_group(_back_to)
		if ui:
			ui.visible = true
		return
	super.close()


# ------------------------------------------------------------ вкладки

func _page(title: String) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.name = title
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 10)
	sc.add_child(v)
	return v


func _slider(v: VBoxContainer, text: String, lo: float, hi: float, step: float, val: float, fmt: Callable, cb: Callable) -> void:
	var r := ModalUi.row(10)
	var l := UiKit.label(text, 17)
	l.custom_minimum_size.x = 230
	r.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = val
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(s)
	var vl := UiKit.label(fmt.call(val), 16, Color(1, 1, 1, 0.75))
	vl.custom_minimum_size.x = 90
	r.add_child(vl)
	s.value_changed.connect(func(x: float) -> void:
		vl.text = fmt.call(x)
		cb.call(x))
	v.add_child(r)


func _check(v: VBoxContainer, text: String, val: bool, cb: Callable) -> void:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = val
	c.add_theme_font_size_override("font_size", 17)
	c.toggled.connect(cb)
	v.add_child(c)


func _gfx_tab() -> Control:
	var v := _page("Графика")
	var r := ModalUi.row(10)
	var l := UiKit.label("Качество", 17)
	l.custom_minimum_size.x = 230
	r.add_child(l)
	var ob := OptionButton.new()
	for i in Settings.QUALITY_NAMES.size():
		ob.add_item(Settings.QUALITY_NAMES[i], i)
	ob.selected = Settings.quality
	ob.item_selected.connect(func(i: int) -> void:
		Settings.quality = i
		Settings.apply_display())
	r.add_child(ob)
	v.add_child(r)
	v.add_child(_hint("Низкое — без теней и эффектов (для слабых ноутбуков). Ультра — сглаживание, тени от фонарей."))
	_slider(v, "Разрешение 3D", 0.5, 1.0, 0.05, Settings.render_scale, func(x: float) -> String: return "%d%%" % roundi(x * 100),
		func(x: float) -> void:
			Settings.render_scale = x
			Settings.apply_display())
	_slider(v, "Поле зрения (FOV)", 60, 100, 1, Settings.fov, func(x: float) -> String: return "%d°" % x,
		func(x: float) -> void: Settings.fov = x)
	_slider(v, "Густота травы", 0.0, 1.5, 0.1, Settings.grass, func(x: float) -> String: return "выкл" if x < 0.05 else "%d%%" % roundi(x * 100),
		func(x: float) -> void: Settings.grass = x)
	v.add_child(_hint("Трава меняется после перезахода в мир."))
	var fr := ModalUi.row(10)
	var fl := UiKit.label("Ограничение FPS", 17)
	fl.custom_minimum_size.x = 230
	fr.add_child(fl)
	var fo := OptionButton.new()
	var caps := [0, 30, 60, 90, 120, 144]
	for c in caps:
		fo.add_item("без ограничения" if c == 0 else str(c))
	fo.selected = maxi(caps.find(Settings.max_fps), 0)
	fo.item_selected.connect(func(i: int) -> void:
		Settings.max_fps = caps[i]
		Settings.apply_display())
	fr.add_child(fo)
	v.add_child(fr)
	_check(v, "Вертикальная синхронизация", Settings.vsync, func(on: bool) -> void:
		Settings.vsync = on
		Settings.apply_display())
	_check(v, "Полный экран (F11)", Saves.fullscreen, func(on: bool) -> void:
		Saves.fullscreen = on
		Saves.save_profile()
		Controls.apply_window_mode())
	return v.get_parent()


func _audio_tab() -> Control:
	var v := _page("Звук")
	var pct := func(x: float) -> String: return "%d%%" % roundi(x * 100)
	_slider(v, "Общая громкость", 0.0, 1.0, 0.05, Saves.volume, pct, func(x: float) -> void:
		Saves.volume = x
		Saves.apply_volume())
	for b in [["Effects", "Эффекты (шаги, всплески, удары)"], ["Ambient", "Природа (птицы, вода, сверчки)"],
			["Music", "Музыка (казино, гармонь)"], ["Voices", "Голоса NPC"]]:
		var bus: String = b[0]
		_slider(v, b[1], 0.0, 1.0, 0.05, Settings.vol[bus], pct, func(x: float) -> void: Settings.set_volume(bus, x))
	var r := ModalUi.row(10)
	var l := UiKit.label("Как говорят NPC", 17)
	l.custom_minimum_size.x = 230
	r.add_child(l)
	var ob := OptionButton.new()
	ob.add_item("Речь (голос Windows)")
	ob.add_item("Бормотание")
	ob.add_item("Только текст")
	ob.selected = Settings.voice_mode
	ob.item_selected.connect(func(i: int) -> void:
		Sfx.stop_voices()
		Settings.voice_mode = i
		Sfx.say(Vector3.ZERO, "old", "Здравствуй, милок! Червячков не надо?", "zoya", true))
	r.add_child(ob)
	v.add_child(r)
	v.add_child(_hint("Речь работает, если в Windows есть русский голос (Параметры → Время и язык → Речь). Если нет — NPC бормочут."
		if not Sfx.has_tts() else "Найден русский голос — NPC говорят по-настоящему."))
	v.add_child(UiKit.button("Проверить звук", func() -> void:
		Sfx.play("splash")
		Sfx.say(Vector3.ZERO, "m_low", "Гражданин, предъявите документы!", "petrovich", true), 15))
	return v.get_parent()


func _keys_tab() -> Control:
	var v := _page("Управление")
	_slider(v, "Чувствительность мыши", 0.2, 3.0, 0.05, Settings.mouse_sens, func(x: float) -> String: return "×%.2f" % x,
		func(x: float) -> void: Settings.mouse_sens = x)
	_check(v, "Инвертировать мышь по вертикали", Settings.invert_y, func(on: bool) -> void: Settings.invert_y = on)
	v.add_child(_hint("Нажми на клавишу справа и затем — новую клавишу или кнопку мыши. Esc — отмена."))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 6)
	for r in Controls.REBIND:
		var a: String = r[0]
		var l := UiKit.label(r[1], 16)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(l)
		var b := UiKit.button("", Callable(), 15)
		b.custom_minimum_size.x = 160
		b.pressed.connect(func() -> void: _start_wait(a, b))
		grid.add_child(b)
		_key_btns[a] = b
	v.add_child(grid)
	v.add_child(UiKit.button("Сбросить клавиши", func() -> void:
		Controls.reset_bindings()
		_refresh_keys(), 15))
	return v.get_parent()


func _hint(t: String) -> Label:
	var l := UiKit.label(t, 14, Color(1, 1, 1, 0.55))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	return l


# ------------------------------------------------------------ переназначение

func _refresh_keys() -> void:
	for a in _key_btns:
		(_key_btns[a] as Button).text = Controls.key_label(a)


func _start_wait(action: String, b: Button) -> void:
	_refresh_keys()
	_wait_action = action
	_wait_btn = b
	b.text = "…нажми клавишу…"


func _input(event: InputEvent) -> void:
	if _wait_action == "" or not visible:
		return
	if event is InputEventKey and event.pressed:
		get_viewport().set_input_as_handled()
		if (event as InputEventKey).physical_keycode != KEY_ESCAPE:
			Controls.rebind(_wait_action, event)
		_wait_action = ""
		_refresh_keys()
	elif event is InputEventMouseButton and event.pressed:
		var bi := (event as InputEventMouseButton).button_index
		if bi in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2]:
			get_viewport().set_input_as_handled()
			Controls.rebind(_wait_action, event)
			_wait_action = ""
			_refresh_keys()


func _unhandled_input(event: InputEvent) -> void:
	if _wait_action != "":
		return
	super._unhandled_input(event)
