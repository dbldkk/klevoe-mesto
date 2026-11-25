extends CanvasLayer
## Меню паузы (Esc). Игра при этом не останавливается — это кооп.

var _info: Label
var _save_btn: Button


func _ready() -> void:
	layer = 15
	add_to_group("pause_menu")
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel := UiKit.panel(Vector2(440, 0))
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	v.add_child(UiKit.title("ПАУЗА"))
	_info = UiKit.label("", 16, Color(1, 1, 1, 0.75))
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD
	v.add_child(_info)
	v.add_child(UiKit.button("Продолжить", close))
	v.add_child(UiKit.button("Памятка и достижения", func() -> void:
		get_tree().get_first_node_in_group("guide_ui").open("pause_menu")))
	var fs := UiKit.button("", Callable())
	fs.text = _fs_text()
	fs.pressed.connect(func() -> void:
		Saves.fullscreen = not Saves.fullscreen
		Saves.save_profile()
		Controls.apply_window_mode()
		fs.text = _fs_text())
	v.add_child(fs)
	v.add_child(UiKit.button("Настройки", func() -> void:
		var su := get_tree().get_first_node_in_group("settings_ui")
		if su:
			visible = false
			su.open("pause_menu")))
	_save_btn = UiKit.button("Сохранить мир", func() -> void:
		Net.send_snapshot()
		if Saves.save_world():
			Events.notify("Мир сохранён", Color.PALE_GREEN))
	v.add_child(_save_btn)
	v.add_child(UiKit.button("Сохранить и выйти в меню", func() -> void:
		visible = false
		Net.exit_to_menu()))
	v.add_child(UiKit.button("Выйти из игры", Net.quit_game))


func _fs_text() -> String:
	return "Экран: %s (F11)" % ("на весь экран" if Saves.fullscreen else "в окне")


func open() -> void:
	visible = true
	Events.ui_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var host := multiplayer.is_server()
	_save_btn.visible = host
	var lines := ["Мир: %s" % Saves.world_display_name()]
	if host:
		var ips := Net.local_ips()
		lines.append("Ты хост. Друзья подключаются по IP:\n%s" % (", ".join(ips) if not ips.is_empty() else "127.0.0.1"))
		lines.append("Игроков онлайн: %d" % (multiplayer.get_peers().size() + 1))
		lines.append("Автосохранение каждые 45 секунд")
	else:
		lines.append("Ты в гостях. Твои вещи сохраняются у хоста")
	_info.text = "\n".join(lines)


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
