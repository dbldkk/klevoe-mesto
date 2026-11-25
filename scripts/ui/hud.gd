extends CanvasLayer
## Интерфейс поверх игры — минимальный: панель вещей внизу, нужды слева внизу,
## деньги справа вверху, подсказка «что под прицелом» по центру.

const TOAST_TIME := 4.5

const DRUNK_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float amount = 0.0;
void fragment() {
	float a = amount;
	vec2 uv = SCREEN_UV;
	uv += vec2(sin(uv.y * 9.0 + TIME * 1.7), cos(uv.x * 7.0 + TIME * 1.3)) * 0.005 * a;
	vec2 ghost = vec2(sin(TIME * 0.8), cos(TIME * 0.6)) * 0.02 * a;
	vec3 c = texture(screen_tex, uv).rgb;
	vec3 g = texture(screen_tex, uv + ghost).rgb;
	vec3 col = mix(c, (c + g) * 0.5, clamp(a * 1.2, 0.0, 0.8));
	col = mix(col, textureLod(screen_tex, uv, a * 2.5).rgb, a * 0.35);
	float vig = smoothstep(0.85, 0.25, length(SCREEN_UV - 0.5) * (1.0 + a));
	col *= mix(1.0, vig, a * 0.85);
	col = mix(col, col * vec3(1.08, 0.96, 0.85), a * 0.5);
	COLOR = vec4(col, 1.0);
}
"""

var _root: Control
var _drunk_fx: ColorRect
var _drunk_mat: ShaderMaterial
var _blackout: ColorRect
var _blackout_label: Label

var _money: Label
var _cart: Label
var _bars: Dictionary = {}
var _slots: Array[ItemSlot] = []
var _held_name: Label
var _held_hint: Label
var _held_fade := 0.0
var _prompt: VBoxContainer
var _status: Label
var _charge_bar: ProgressBar
var _tension_bar: ProgressBar
var _tension_fill: StyleBoxFlat
var _distance: Label
var _toasts: VBoxContainer
var _help: PanelContainer
var _help_tab: Label
var _bait_label: Label
var _last_prompt := ""
var _clock: Label
var _tourn: Label
var _npc_panel: PanelContainer
var _npc_name: Label
var _npc_state: Label
var _npc_rows: Dictionary = {}   ## key -> [HBox, ProgressBar, Label]


func _ready() -> void:
	layer = 1
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_drunk_fx = ColorRect.new()
	_drunk_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	_drunk_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = DRUNK_SHADER
	_drunk_mat = ShaderMaterial.new()
	_drunk_mat.shader = sh
	_drunk_fx.material = _drunk_mat
	_drunk_fx.visible = false
	_root.add_child(_drunk_fx)

	_build_top_right()
	_build_needs()
	_build_hotbar()
	_build_center()
	_build_help()
	Settings.changed.connect(_rebuild_help)
	_build_clock()
	_build_npc_panel()

	_blackout = ColorRect.new()
	_blackout.color = Color.BLACK
	_blackout.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blackout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blackout.modulate.a = 0.0
	add_child(_blackout)
	_blackout_label = _label(_blackout, 34)
	_blackout_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_blackout_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_blackout_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	Events.toast.connect(_on_toast)
	Events.blackout.connect(_on_blackout)
	Inventory.changed.connect(_refresh_inventory)
	Inventory.selection_changed.connect(_on_selection)
	_refresh_inventory()


# ------------------------------------------------------------ строители

func _build_clock() -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.box(Color(0, 0, 0, 0.35), 8, 8))
	p.position = Vector2(18, 14)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(p)
	_clock = _label(p, 22, Color(1, 0.95, 0.8))
	_tourn = _label(_root, 18, Color(1.0, 0.85, 0.35))
	_tourn.position = Vector2(20, 60)
	_tourn.visible = false


func _build_npc_panel() -> void:
	_npc_panel = PanelContainer.new()
	_npc_panel.add_theme_stylebox_override("panel", UiKit.box(Color(0.05, 0.07, 0.1, 0.6), 10, 10))
	_npc_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_npc_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_npc_panel.position.y = 14
	_npc_panel.custom_minimum_size.x = 300
	_npc_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_npc_panel.visible = false
	_root.add_child(_npc_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_npc_panel.add_child(v)
	_npc_name = _label(v, 20, Color(0.75, 0.88, 1.0))
	_npc_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_npc_state = _label(v, 15, Color(1, 1, 1, 0.75))
	_npc_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for k in [["drunk", "Пьяный", Color(0.85, 0.45, 0.9)], ["mood", "Настроение", Color(0.95, 0.8, 0.3)],
			["loyalty", "К тебе", Color(0.35, 0.75, 1.0)], ["hp", "Здоровье", Color(0.9, 0.25, 0.25)]]:
		var h := HBoxContainer.new()
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l := _label(h, 14, Color(1, 1, 1, 0.8))
		l.text = k[1]
		l.custom_minimum_size.x = 92
		var b := UiKit.bar(k[2], Vector2(140, 10))
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(b)
		var w := _label(h, 14, Color(1, 1, 1, 0.8))
		w.custom_minimum_size.x = 80
		v.add_child(h)
		_npc_rows[k[0]] = [h, b, w]


## Кого сейчас «показывать» в панели: на кого смотришь, или Толя, если стоишь рядом.
func _npc_of(p: Node) -> Node:
	var f: Node = p.focus
	if f:
		var t: Node = f.get("target") if f.get("target") != null else f.get_parent()
		while t and not t.has_method("display_name") and t != get_tree().root:
			t = t.get_parent()
		if t and t.has_method("display_name") and not t.is_in_group("players"):
			if t.get("hp") == null and t.get_parent().get("hp") != null:
				t = t.get_parent()
			return t
	for n in get_tree().get_nodes_in_group("trader"):
		if (n as Node3D).global_position.distance_to(p.global_position) < 6.0:
			return n
	return null


func _update_npc(p: Node) -> void:
	var n := _npc_of(p)
	_npc_panel.visible = n != null and not Events.ui_open
	if n == null:
		return
	_npc_name.text = n.display_name()
	for k in _npc_rows:
		_npc_rows[k][0].visible = false
	_npc_state.text = n.status_word() if n.has_method("status_word") else ""
	if n is Trader:
		_npc_row("drunk", n.drunk, GameData.drunk_word(n.drunk))
		_npc_row("mood", n.mood + 50.0, "хорошее" if n.mood > 15 else ("плохое" if n.mood < -15 else "так себе"))
		_npc_row("loyalty", Inventory.trader_loyalty / 2.0 + 50.0, GameData.loyalty_word(Inventory.trader_loyalty))
	elif n.get("hp") != null:
		var mx: float = ThimbleMan.MAX_HP if n is ThimbleMan else 100.0
		_npc_row("hp", n.hp / mx * 100.0, "%d/%d" % [maxi(int(n.hp), 0), int(mx)])
		if n.has_method("is_out") and n.is_out():
			_npc_state.text = "в отключке"


func _npc_row(key: String, value: float, word: String) -> void:
	var r: Array = _npc_rows[key]
	r[0].visible = true
	r[1].value = clampf(value, 0.0, 100.0)
	r[2].text = word


func _label(parent: Control, size: int, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _build_top_right() -> void:
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	v.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	v.position += Vector2(-22, 14)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_BEGIN
	_root.add_child(v)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_END
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(h)
	var coin := TextureRect.new()
	coin.texture = Art.ui_icon("coin")
	coin.custom_minimum_size = Vector2(30, 30)
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(coin)
	_money = _label(h, 28, Color(1, 0.92, 0.6))
	_cart = _label(v, 16, Color(1, 0.85, 0.5))
	_cart.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_toasts = VBoxContainer.new()
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.add_theme_constant_override("separation", 2)
	v.add_child(_toasts)


func _build_needs() -> void:
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	v.grow_vertical = Control.GROW_DIRECTION_BEGIN
	v.position += Vector2(22, -22)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 6)
	_root.add_child(v)
	for row in [["heart", Color(0.9, 0.28, 0.28)], ["food", Color(0.95, 0.6, 0.25)],
			["toilet", Color(0.95, 0.85, 0.3)], ["drunk", Color(0.75, 0.45, 0.95)]]:
		var h := HBoxContainer.new()
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ic := TextureRect.new()
		ic.texture = Art.ui_icon(row[0])
		ic.custom_minimum_size = Vector2(22, 22)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(ic)
		var b := UiKit.bar(row[1], Vector2(150, 9))
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(b)
		v.add_child(h)
		_bars[row[0]] = b
	_bait_label = _label(v, 14, Color(1, 1, 1, 0.7))


func _build_hotbar() -> void:
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	v.grow_horizontal = Control.GROW_DIRECTION_BOTH
	v.grow_vertical = Control.GROW_DIRECTION_BEGIN
	v.position.y -= 16
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 4)
	_root.add_child(v)

	_status = _label(v, 22)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_charge_bar = UiKit.bar(Color(0.95, 0.8, 0.3), Vector2(420, 12))
	_charge_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(_charge_bar)
	_tension_bar = UiKit.bar(Color.GREEN, Vector2(420, 16))
	_tension_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_tension_fill = _tension_bar.get_theme_stylebox("fill")
	v.add_child(_tension_bar)
	_distance = _label(v, 16)
	_distance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_held_name = _label(v, 18)
	_held_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_held_hint = _label(v, 14, Color(1, 1, 1, 0.65))
	_held_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(h)
	for i in Inventory.HOTBAR:
		var s := ItemSlot.new()
		s.index = i
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		s.set_number(str(i + 1))
		h.add_child(s)
		_slots.append(s)


func _build_center() -> void:
	var cross := _label(_root, 22)
	cross.text = "·"
	cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	cross.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt = VBoxContainer.new()
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.position.y += 34
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_prompt)


func _prompt_row(key: String, text: String) -> void:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", UiKit.box(Color(1, 1, 1, 0.9), 5, 3))
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var k := Label.new()
	k.text = " %s " % key
	k.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	k.add_theme_font_size_override("font_size", 15)
	chip.add_child(k)
	h.add_child(chip)
	_label(h, 18).text = text
	_prompt.add_child(h)


## Клавиши переназначили — пересобрать подсказку.
func _rebuild_help() -> void:
	if _help:
		_help.queue_free()
	if _help_tab:
		_help_tab.queue_free()
	_build_help()


func _build_help() -> void:
	_help = PanelContainer.new()
	_help.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	_help.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_help.grow_vertical = Control.GROW_DIRECTION_BOTH
	_help.position.x -= 16
	_help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_help.add_theme_stylebox_override("panel", UiKit.box(Color(0.05, 0.07, 0.09, 0.5), 12, 12))
	_root.add_child(_help)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)
	_help.add_child(grid)
	for row in Controls.help():
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", UiKit.box(Color(1, 1, 1, 0.14), 5, 0))
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.custom_minimum_size.x = 58
		var key := _label(chip, 13)
		key.text = " %s " % row[0]
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(chip)
		var desc := _label(grid, 13, Color(1, 1, 1, 0.85))
		desc.text = row[1]
	_help_tab = _label(_root, 13, Color(1, 1, 1, 0.45))
	_help_tab.text = "F1 — подсказки"
	_help_tab.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	_help_tab.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_help_tab.position.x -= 16
	_apply_help()


func _apply_help() -> void:
	_help.visible = not Saves.help_hidden
	_help_tab.visible = Saves.help_hidden


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_help"):
		Saves.help_hidden = not Saves.help_hidden
		Saves.save_profile()
		_apply_help()


# ------------------------------------------------------------ обновление

func _refresh_inventory() -> void:
	_money.text = "%d ₽" % Inventory.money
	for s in _slots:
		s.refresh()
		s.set_selected(s.index == Inventory.selected)
	var b := GameData.get_bait(Inventory.equipped_bait)
	_bait_label.text = "На крючке: %s ×%d" % [b.display_name, Inventory.get_bait_count()] \
		if b and Inventory.get_bait_count() > 0 else "Наживки нет"
	_update_held_text()


func _on_selection() -> void:
	_refresh_inventory()
	_held_fade = 2.5


func _update_held_text() -> void:
	var s = Inventory.selected_slot()
	if s == null:
		_held_name.text = ""
		_held_hint.text = ""
		return
	_held_name.text = GameData.item_name(s.kind, s.id)
	match s.kind:
		"rod":
			_held_hint.text = "ЛКМ — забросить" if s.get("cond", 100.0) > 0 else "сломана — почини у Дяди Толи"
		"drink": _held_hint.text = "ЛКМ — выпить · G — угостить"
		"food": _held_hint.text = "ЛКМ — съесть"
		"bait": _held_hint.text = "ЛКМ — насадить на крючок"
		"bottle": _held_hint.text = "ЛКМ — бросить"
		_: _held_hint.text = ""


func _process(delta: float) -> void:
	var p := get_tree().get_first_node_in_group("local_player")
	_root.visible = p != null and not _menu_visible()
	if p == null:
		return

	_bars.heart.value = Inventory.health
	var dc := get_tree().get_first_node_in_group("day_cycle") as DayCycle
	if dc:
		var w := get_tree().get_first_node_in_group("weather") as Weather
		_clock.text = "%s  День %d · %s%s" % ["☾" if dc.is_night() else "☀", dc.day, dc.clock_text(),
			"  ·  " + w.word() if w else ""]
		var tn := get_tree().get_first_node_in_group("tournament") as Tournament
		_tourn.visible = tn != null and tn.active
		if _tourn.visible:
			_tourn.text = "★ Соревнование %s · приз %d ₽\n%s" % [tn.time_left_text(), tn.prize,
				"лидер: %s — %s, %.2f кг" % [tn.leader_name, tn.leader_fish, tn.leader_kg] if tn.leader_name != "" else "пока никто не поймал"]
	_update_npc(p)
	_bars.food.value = Inventory.satiety
	_bars.toilet.value = maxf(Inventory.bladder, Inventory.bowel)
	_bars.drunk.value = Inventory.drunk
	var a := Inventory.drunk / 100.0
	_drunk_fx.visible = a > 0.03
	_drunk_mat.set_shader_parameter("amount", a)

	_held_fade = maxf(_held_fade - delta, 0.0)
	var show_held: bool = _held_fade > 0.0 or p.fishing.state == FishingController.State.IDLE
	_held_name.modulate.a = 1.0 if _held_fade > 0.0 else 0.75
	_held_name.visible = show_held
	_held_hint.visible = show_held and _held_fade > 0.0

	if Inventory.theft == Inventory.Theft.CHASED:
		_cart.text = "ЗА ТОБОЙ ГОНИТСЯ ОХРАННИК!"
		_cart.add_theme_color_override("font_color", Color.RED)
	elif not Inventory.cart.is_empty():
		_cart.text = "Корзина: %d шт. · %d ₽" % [Inventory.cart.size(), Inventory.cart_total()]
		_cart.add_theme_color_override("font_color", Color(1, 0.85, 0.5))
	else:
		_cart.text = ""

	var e := ""
	var g := ""
	if p.focus and not Events.ui_open:
		e = p.focus.get_prompt(p)
		g = p.focus.get_gift_prompt(p)
	if e + "|" + g != _last_prompt:
		_last_prompt = e + "|" + g
		for c in _prompt.get_children():
			c.queue_free()
		if e != "":
			_prompt_row(Controls.key_label("interact"), e)
		if g != "":
			_prompt_row("G", g)

	var f: FishingController = p.fishing
	var S := FishingController.State
	_charge_bar.visible = f.state == S.CHARGING
	_charge_bar.value = f.charge * 100.0
	_tension_bar.visible = f.state == S.FIGHT
	_distance.visible = f.state == S.FIGHT
	match f.state:
		S.IDLE, S.FLYING:
			if p.swimming:
				_status.text = "ПЛЫВИ К БЕРЕГУ"
			elif p.sleeping:
				_status.text = "Спишь… Ждём, пока лягут все (Пробел — встать)"
			elif p.hidden:
				_status.text = "Ты в укрытии (E — вылезти)"
			elif p.jail_left() > 0.0:
				_status.text = "В КПЗ: ещё %d с" % ceili(p.jail_left())
			elif p.carrying:
				_status.text = "Несёшь коробку → дверь склада сбоку «Шестёрочки»"
			else:
				_status.text = ""
		S.CHARGING: _status.text = "Отпусти ЛКМ для заброса"
		S.WAITING: _status.text = "Поплавок играет… не спеши" if f.nibble > 0.0 else "Ждём поклёва… (ЛКМ — смотать)"
		S.BITE: _status.text = "КЛЮЁТ! ЛКМ!"
		S.FIGHT:
			if f.jump_time > 0.0:
				_status.text = "РЫБА ВЫПРЫГНУЛА! Отпусти ЛКМ!"
			elif f.dash_dir != 0:
				_status.text = ("← Рыба уходит влево — держи D" if f.dash_dir < 0 else "Рыба уходит вправо — держи A →") \
					+ ("  ✔" if f.dash_ok else "")
			elif f.tension >= 85.0:
				_status.text = "ЛЕСКА ТРЕЩИТ! Ослабь!"
			elif f.tension < 12.0:
				_status.text = "Леска провисла — тяни!"
			elif f.heavy:
				_status.text = "Тяжёлая! Не перетяни (R — отпустить)"
			elif f.surge:
				_status.text = "Рыба рвётся!"
			else:
				_status.text = "Держи ЛКМ — тянуть, отпусти — ослабить"
			_tension_bar.value = f.tension
			_distance.text = f.distance_word()
			if f.tension >= 85.0:
				_tension_fill.bg_color = Color(0.95, 0.15, 0.1)
			elif f.tension >= 60.0:
				_tension_fill.bg_color = Color(0.95, 0.8, 0.2)
			elif f.tension < 12.0:
				_tension_fill.bg_color = Color(0.5, 0.6, 0.9)
			else:
				_tension_fill.bg_color = Color(0.3, 0.85, 0.35)


func _menu_visible() -> bool:
	var m := get_tree().get_first_node_in_group("main_menu")
	return m != null and m.visible


func _on_toast(text: String, color: Color) -> void:
	var l := _label(_toasts, 17, color)
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.size_flags_horizontal = Control.SIZE_SHRINK_END
	if _toasts.get_child_count() > 6:
		_toasts.get_child(0).queue_free()
	var tw := l.create_tween()
	tw.tween_interval(TOAST_TIME)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)


func _on_blackout(text: String) -> void:
	_blackout_label.text = text
	var tw := create_tween()
	tw.tween_property(_blackout, "modulate:a", 1.0, 1.2)
	tw.tween_interval(2.0)
	tw.tween_property(_blackout, "modulate:a", 0.0, 1.5)
