extends CanvasLayer
## Главное меню: имя, свои миры (создать / загрузить / удалить), подключение к другу.

var _name_edit: LineEdit
var _world_list: ItemList
var _new_world_edit: LineEdit
var _ip_edit: LineEdit
var _status: Label
var _delete_btn: Button
var _worlds: Array[Dictionary] = []
var _confirm_delete := false
var _preview: CharacterModel
var _skin_labels: Dictionary = {}

## Что можно менять во внешности: ключ, подпись, сколько вариантов.
const SKIN_OPTS := [["shirt", "Куртка"], ["pants", "Штаны"], ["skin", "Кожа"], ["hat", "Голова"],
	["hat_color", "Цвет шапки"], ["face", "Лицо"], ["stripes", "Тельняшка"], ["outfit", "Образ"]]
const FRIEND_SKIN := {"shirt": 7, "pants": 1, "skin": 0, "hat": 5, "hat_color": 5, "face": 0, "stripes": 0, "outfit": 1}


func _ready() -> void:
	layer = 20
	add_to_group("main_menu")

	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.07, 0.1, 0.55)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var panel := UiKit.panel(Vector2(860, 0))
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	v.add_child(UiKit.title("КЛЁВОЕ МЕСТО"))
	var sub := UiKit.label("кооперативная рыбалка · пей, лови, торгуйся", 16, Color(1, 1, 1, 0.55))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.text += " · v" + str(ProjectSettings.get_setting("application/config/version", ""))
	v.add_child(sub)

	var name_row := HBoxContainer.new()
	name_row.add_child(UiKit.label("Твоё имя:", 18))
	_name_edit = LineEdit.new()
	_name_edit.text = Saves.profile_name
	_name_edit.max_length = 16
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(_name_edit)
	v.add_child(name_row)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	v.add_child(cols)

	# --- Свои миры
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	cols.add_child(left)
	left.add_child(UiKit.label("Мои миры (ты — хост)", 20, UiKit.ACCENT))
	_world_list = ItemList.new()
	_world_list.custom_minimum_size = Vector2(420, 200)
	_world_list.item_activated.connect(func(_i) -> void: _on_play())
	_world_list.item_selected.connect(func(_i) -> void: _reset_delete())
	left.add_child(_world_list)
	var row := HBoxContainer.new()
	var play := UiKit.button("Играть", _on_play)
	play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(play)
	_delete_btn = UiKit.button("Удалить", _on_delete)
	row.add_child(_delete_btn)
	left.add_child(row)
	var new_row := HBoxContainer.new()
	_new_world_edit = LineEdit.new()
	_new_world_edit.placeholder_text = "Название нового мира"
	_new_world_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_row.add_child(_new_world_edit)
	new_row.add_child(UiKit.button("Создать мир", _on_create))
	left.add_child(new_row)

	# --- Подключение
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 320
	right.add_theme_constant_override("separation", 8)
	cols.add_child(right)
	right.add_child(UiKit.label("Зайти к другу", 20, UiKit.ACCENT))
	right.add_child(UiKit.label("IP хоста:", 16, Color(1, 1, 1, 0.7)))
	_ip_edit = LineEdit.new()
	_ip_edit.text = "127.0.0.1"
	right.add_child(_ip_edit)
	right.add_child(UiKit.button("Подключиться", _on_join))
	var hint := UiKit.label("Мир хранится у хоста. Он запомнит тебя\nи твои вещи — заходи хоть завтра.", 14, Color(1, 1, 1, 0.5))
	right.add_child(hint)
	right.add_child(UiKit.button("Как играть", func() -> void:
		get_tree().get_first_node_in_group("guide_ui").open("main_menu")))
	right.add_child(UiKit.button("Настройки", func() -> void:
		var su := get_tree().get_first_node_in_group("settings_ui")
		if su:
			su.open("main_menu")))

	v.add_child(HSeparator.new())
	v.add_child(_build_skin())

	_status = UiKit.label(Net.last_message, 17, Color(1, 0.7, 0.5))
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	v.add_child(_status)
	Net.last_message = ""

	Net.joined.connect(_hide_menu)
	Net.hosted.connect(_hide_menu)
	Net.join_failed.connect(func() -> void: _status.text = "Не удалось подключиться")

	_refresh_worlds()
	Events.ui_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _refresh_worlds() -> void:
	_worlds = Saves.list_worlds()
	_world_list.clear()
	for w in _worlds:
		var date := Time.get_datetime_string_from_unix_time(int(w.modified)).replace("T", " ").left(16)
		_world_list.add_item("%s   ·   игроков: %d   ·   %s" % [w.name, w.players, date])
	if not _worlds.is_empty():
		_world_list.select(0)
	_reset_delete()


func _apply_name() -> void:
	var n := _name_edit.text.strip_edges()
	Net.player_name = n if n != "" else "Рыбак"
	Saves.profile_name = Net.player_name
	Saves.save_profile()


func _selected_world() -> Dictionary:
	var sel := _world_list.get_selected_items()
	return _worlds[sel[0]] if not sel.is_empty() else {}


func _on_play() -> void:
	var w := _selected_world()
	if w.is_empty():
		_status.text = "Выбери мир или создай новый"
		return
	if not Saves.load_world(w.file):
		_status.text = "Не удалось загрузить мир"
		return
	_start_host()


func _on_create() -> void:
	var err := Saves.create_world(_new_world_edit.text)
	if err != "":
		_status.text = err
		return
	_start_host()


func _start_host() -> void:
	_apply_name()
	if Net.host() != OK:
		Saves.close_world()
		_status.text = "Не удалось создать сервер (порт %d занят? Может, игра уже запущена хостом)" % Net.DEFAULT_PORT


func _on_delete() -> void:
	var w := _selected_world()
	if w.is_empty():
		return
	if not _confirm_delete:
		_confirm_delete = true
		_delete_btn.text = "Точно?"
		return
	Saves.delete_world(w.file)
	_status.text = "Мир «%s» удалён" % w.name
	_refresh_worlds()


func _reset_delete() -> void:
	_confirm_delete = false
	if _delete_btn:
		_delete_btn.text = "Удалить"


func _on_join() -> void:
	_apply_name()
	if Net.join(_ip_edit.text.strip_edges()) != OK:
		_status.text = "Ошибка подключения"
	else:
		_status.text = "Подключаемся…"


func _hide_menu() -> void:
	visible = false
	Events.ui_open = false


# ------------------------------------------------------------ внешность

func _build_skin() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 24)
	# 3D-превью
	var svc := SubViewportContainer.new()
	svc.custom_minimum_size = Vector2(210, 290)
	svc.stretch = true
	h.add_child(svc)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	svc.add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.78, 0.85)
	env.environment.ambient_light_energy = 0.7
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.6, 0.5, 0)
	sun.light_energy = 1.4
	vp.add_child(sun)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0.98, 4.4)
	cam.rotation.x = -0.02
	cam.fov = 32.0
	vp.add_child(cam)
	_preview = CharacterModel.new()
	vp.add_child(_preview)
	# Варианты
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 4)
	h.add_child(right)
	right.add_child(UiKit.label("Внешность рыбака", 20, UiKit.ACCENT))
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 24)
	right.add_child(g)
	for o in SKIN_OPTS:
		var key: String = o[0]
		var r := HBoxContainer.new()
		var l := UiKit.label(o[1], 16, Color(1, 1, 1, 0.7))
		l.custom_minimum_size.x = 100
		r.add_child(l)
		r.add_child(UiKit.button("◀", func() -> void: _skin_step(key, -1), 15))
		var val := UiKit.label("", 16)
		val.custom_minimum_size.x = 110
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		r.add_child(val)
		r.add_child(UiKit.button("▶", func() -> void: _skin_step(key, 1), 15))
		g.add_child(r)
		_skin_labels[key] = val
	right.add_child(UiKit.button("Случайно", func() -> void:
		for o in SKIN_OPTS:
			Saves.skin[o[0]] = randi() % _skin_count(o[0])
		Saves.skin["outfit"] = 0
		_skin_changed(), 15))
	right.add_child(UiKit.button("Друг из общаги", func() -> void:
		for k in FRIEND_SKIN:
			Saves.skin[k] = FRIEND_SKIN[k]
		_skin_changed(), 15))
	_skin_changed.call_deferred()
	return h


func _skin_count(key: String) -> int:
	match key:
		"shirt": return CharacterModel.SHIRTS.size()
		"pants": return CharacterModel.PANTS.size()
		"skin": return CharacterModel.SKINS.size()
		"hat": return CharacterModel.HAT_NAMES.size()
		"hat_color": return CharacterModel.HAT_COLORS.size()
		"face": return CharacterModel.FACES.size()
		"outfit": return CharacterModel.OUTFIT_NAMES.size()
	return 2


func _skin_word(key: String, v: int) -> String:
	match key:
		"hat": return CharacterModel.HAT_NAMES[v]
		"face": return CharacterModel.FACE_NAMES[v]
		"stripes": return "да" if v == 1 else "нет"
		"outfit": return CharacterModel.OUTFIT_NAMES[v]
	return "№%d" % (v + 1)


func _skin_step(key: String, d: int) -> void:
	var n := _skin_count(key)
	Saves.skin[key] = (int(Saves.skin.get(key, 0)) + d + n) % n
	if key == "outfit" and int(Saves.skin["outfit"]) == 1:
		for k in FRIEND_SKIN:
			Saves.skin[k] = FRIEND_SKIN[k]
	_skin_changed()


func _skin_changed() -> void:
	for o in SKIN_OPTS:
		var k: String = o[0]
		_skin_labels[k].text = _skin_word(k, int(Saves.skin.get(k, 0)))
	_preview.apply_skin(Saves.skin)
	Saves.save_profile()


func _process(delta: float) -> void:
	if visible and _preview:
		_preview.rotation.y += delta * 0.6
