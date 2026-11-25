class_name FishBookUI
extends CanvasLayer
## «Справочник рыбака»: все рыбы — картинка, редкость, вес, где водится, на что клюёт, твой рекорд.


func _ready() -> void:
	layer = 7
	add_to_group("fish_book_ui")
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := UiKit.panel(Vector2(1040, 640))
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	v.add_child(UiKit.title("СПРАВОЧНИК РЫБАКА"))
	var view := make_view()
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(view)
	v.add_child(UiKit.button("Закрыть (Esc)", close))


func open() -> void:
	visible = true
	Events.ui_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


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


## Сетка карточек рыб (используется и в инвентаре).
static func make_view() -> Control:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(980, 500)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)
	for f in GameData.fish:
		grid.add_child(_card(f))
	return scroll


static func _card(f: FishData) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(318, 150)
	var sb := UiKit.box(Color(1, 1, 1, 0.05), 10, 10)
	sb.border_color = FishData.rarity_color(f.rarity)
	sb.border_width_left = 4
	card.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	card.add_child(h)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(96, 96)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = Icons.get_icon("fish", f.id)
	var key := Icons.key_of("fish", f.id)
	Icons.icon_ready.connect(func(k: String) -> void:
		if k == key and is_instance_valid(icon):
			icon.texture = Icons.get_icon("fish", f.id))
	h.add_child(icon)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 1)
	h.add_child(v)
	v.add_child(UiKit.label(f.display_name, 19, FishData.rarity_color(f.rarity)))
	v.add_child(UiKit.label("%s · %s–%s кг" % [FishData.rarity_name(f.rarity), _kg(f.min_kg), _kg(f.max_kg)], 13, Color(1, 1, 1, 0.7)))
	v.add_child(UiKit.label("Водится: %s" % FishData.habitat_name(f.habitat), 13, Color(1, 1, 1, 0.7)))
	v.add_child(UiKit.label("Клюёт на: %s" % _best_baits(f), 13, Color(1, 1, 1, 0.7)))
	var caught: int = int(Inventory.stats.get("fish_count", {}).get(String(f.id), 0))
	var rec: float = float(Inventory.stats.get("fish_record", {}).get(String(f.id), 0.0))
	v.add_child(UiKit.label("Поймано: %d%s" % [caught, (" · рекорд %.2f кг" % rec) if caught > 0 else ""], 13,
		Color(0.7, 1, 0.7) if caught > 0 else Color(1, 1, 1, 0.45)))
	var desc := UiKit.label(f.description, 12, Color(1, 1, 1, 0.55))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.custom_minimum_size.x = 190
	v.add_child(desc)
	return card


static func _kg(v: float) -> String:
	if v < 1.0:
		return ("%.2f" % v).rstrip("0").rstrip(".")
	return ("%.1f" % v).rstrip("0").rstrip(".")


static func _best_baits(f: FishData) -> String:
	var scored := []
	for b in GameData.baits:
		var m: float = float(b.fish_multipliers.get(f.id, 1.0))
		if f.rarity < b.min_rarity:
			m = 0.0
		elif f.rarity >= FishData.Rarity.RARE:
			m *= b.rare_bonus
		if m > 1.05:
			scored.append([m, b.display_name.to_lower()])
	scored.sort_custom(func(a, b): return a[0] > b[0])
	var names := []
	for e in scored.slice(0, 2):
		names.append(e[1])
	return ", ".join(names) if not names.is_empty() else "что угодно"
