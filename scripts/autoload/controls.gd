extends Node
## Назначение клавиш (автозагрузка Controls).
## Используются физические клавиши, поэтому всё работает и на русской раскладке.

## Для панели подсказок: [действие (или текст), описание]. Клавиша подставляется из текущих настроек.
const HELP := [
	["fish_action", "действие · удар (пустые руки/бита)"],
	["1-9", "выбрать ячейку (или колесо)"],
	["release_fish", "отпустить рыбу"],
	["cycle_bait", "сменить наживку"],
	["interact", "взять · говорить · спрятаться · лечь"],
	["gift", "угостить выпивкой"],
	["pee", "туалет: малый"],
	["poop", "туалет: большой"],
	["drop_cart", "выложить корзину"],
	["inventory", "инвентарь"],
	["map", "карта"],
	["flashlight", "фонарик"],
	["toast", "поднять тост"],
	["dispute", "поспорить (глядя на игрока)"],
	["accept", "принять спор / предложение"],
	["E в транспорте", "выйти · W/S газ · A/D руль"],
	["toggle_camera", "камера 1/3 лица"],
	["jump", "прыжок · вылезти · встать"],
	["fullscreen", "полный экран"],
	["Esc", "меню и настройки"],
	["toggle_help", "скрыть подсказку"],
]

## Что можно переназначить в настройках: [действие, название].
const REBIND := [
	["move_forward", "Вперёд"], ["move_back", "Назад"], ["move_left", "Влево"], ["move_right", "Вправо"],
	["jump", "Прыжок"], ["sprint", "Бег"], ["interact", "Действие (E)"], ["fish_action", "Заброс / удар"],
	["release_fish", "Отпустить рыбу"], ["cycle_bait", "Сменить наживку"], ["gift", "Угостить"],
	["pee", "Туалет: малый"], ["poop", "Туалет: большой"], ["drop_cart", "Выложить корзину"],
	["inventory", "Инвентарь"], ["map", "Карта"], ["flashlight", "Фонарик"], ["toast", "Тост"],
	["dispute", "Поспорить"], ["accept", "Принять"], ["toggle_camera", "Камера"], ["toggle_help", "Подсказка"],
]

var _defaults: Dictionary = {}


## Подсказка с текущими клавишами.
func help() -> Array:
	var out := []
	for row in HELP:
		var k: String = row[0]
		out.append([key_label(k) if InputMap.has_action(k) else k, row[1]])
	return out


## Как зовут клавишу действия («E», «ЛКМ»…).
func key_label(action: StringName) -> String:
	if not InputMap.has_action(action):
		return "?"
	for ev in InputMap.action_get_events(action):
		return event_label(ev)
	return "—"


static func event_label(ev: InputEvent) -> String:
	if ev is InputEventKey:
		var k := (ev as InputEventKey).physical_keycode
		if k == KEY_SPACE:
			return "Пробел"
		return OS.get_keycode_string(k)
	if ev is InputEventMouseButton:
		match (ev as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT: return "ЛКМ"
			MOUSE_BUTTON_RIGHT: return "ПКМ"
			MOUSE_BUTTON_MIDDLE: return "СКМ"
		return "Мышь %d" % (ev as InputEventMouseButton).button_index
	return "?"


## Переназначить: ev — нажатая клавиша или кнопка мыши.
func rebind(action: StringName, ev: InputEvent) -> void:
	InputMap.action_erase_events(action)
	if ev is InputEventKey:
		var k := InputEventKey.new()
		k.physical_keycode = (ev as InputEventKey).physical_keycode
		InputMap.action_add_event(action, k)
	elif ev is InputEventMouseButton:
		var m := InputEventMouseButton.new()
		m.button_index = (ev as InputEventMouseButton).button_index
		InputMap.action_add_event(action, m)


func reset_bindings() -> void:
	apply_bindings(_defaults)


func export_bindings() -> Dictionary:
	var d := {}
	for r in REBIND:
		for ev in InputMap.action_get_events(r[0]):
			if ev is InputEventKey:
				d[r[0]] = ["k", int((ev as InputEventKey).physical_keycode)]
			elif ev is InputEventMouseButton:
				d[r[0]] = ["m", int((ev as InputEventMouseButton).button_index)]
			break
	return d


func apply_bindings(d: Dictionary) -> void:
	for a in d:
		if not InputMap.has_action(a):
			continue
		var e: Array = d[a]
		if e[0] == "k":
			var k := InputEventKey.new()
			k.physical_keycode = int(e[1]) as Key
			rebind(a, k)
		else:
			var m := InputEventMouseButton.new()
			m.button_index = int(e[1]) as MouseButton
			rebind(a, m)


func _ready() -> void:
	_key("move_forward", KEY_W)
	_key("move_back", KEY_S)
	_key("move_left", KEY_A)
	_key("move_right", KEY_D)
	_key("jump", KEY_SPACE)
	_key("sprint", KEY_SHIFT)
	_key("toggle_camera", KEY_V)
	_key("interact", KEY_E)
	_key("gift", KEY_G)
	_key("release_fish", KEY_R)
	_key("cycle_bait", KEY_B)
	_key("pee", KEY_N)
	_key("poop", KEY_M)
	_key("drop_cart", KEY_C)
	_key("inventory", KEY_TAB)
	_key("toggle_help", KEY_F1)
	_key("map", KEY_K)
	_key("flashlight", KEY_F)
	_key("toast", KEY_T)
	_key("dispute", KEY_Z)
	_key("accept", KEY_Y)
	_key("fullscreen", KEY_F11)
	for i in 9:
		_key("slot_%d" % (i + 1), KEY_1 + i)
	_mouse("fish_action", MOUSE_BUTTON_LEFT)
	_defaults = export_bindings()


	apply_window_mode.call_deferred()


## Полный экран / окно (запоминается в профиле).
func apply_window_mode() -> void:
	if Engine.is_embedded_in_editor():
		return
	if Saves.fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen"):
		Saves.fullscreen = not Saves.fullscreen
		Saves.save_profile()
		apply_window_mode()
		get_viewport().set_input_as_handled()


func _ensure(action: StringName) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)


func _key(action: StringName, keycode: Key) -> void:
	_ensure(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)


func _mouse(action: StringName, button: MouseButton) -> void:
	_ensure(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)
