class_name ItemSlot
extends PanelContainer
## Квадратик инвентаря: картинка предмета, количество, номер, полоска износа удочки.
## Поддерживает перетаскивание (если draggable).

signal clicked(index: int, button: int)
signal hovered(index: int)

const SIZE := 64

var index: int = 0
var draggable := false
var selected := false

var _icon: TextureRect
var _count: Label
var _num: Label
var _cond: ProgressBar
var _key := ""


func _init() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)
	_num = _mk_label(12, Color(1, 1, 1, 0.55))
	_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_num.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_count = _mk_label(15, Color.WHITE)
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_cond = UiKit.bar(Color(0.4, 0.85, 0.4), Vector2(SIZE - 14, 4))
	_cond.size_flags_vertical = Control.SIZE_SHRINK_END
	_cond.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(_cond)
	_style()
	Icons.icon_ready.connect(func(k: String) -> void:
		if k == _key:
			refresh())
	mouse_entered.connect(func() -> void: hovered.emit(index))


func _mk_label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.size_flags_vertical = Control.SIZE_FILL
	add_child(l)
	return l


## Вещь выбрана щелчком в инвентаре (кнопки справа относятся к ней).
var pinned := false


func set_pinned(v: bool) -> void:
	if v != pinned:
		pinned = v
		_style()


func _style() -> void:
	var sb := UiKit.box(Color(0.06, 0.07, 0.09, 0.62), 8, 4)
	if pinned:
		sb.bg_color = Color(0.15, 0.25, 0.32, 0.85)
		sb.border_color = Color(0.55, 0.85, 1.0)
		sb.set_border_width_all(3)
	elif selected:
		sb.bg_color = Color(0.25, 0.22, 0.12, 0.8)
		sb.border_color = UiKit.ACCENT
		sb.set_border_width_all(3)
	else:
		sb.border_color = Color(1, 1, 1, 0.12)
		sb.set_border_width_all(1)
	add_theme_stylebox_override("panel", sb)


func set_number(n: String) -> void:
	_num.text = n


func set_selected(v: bool) -> void:
	if v != selected:
		selected = v
		_style()


func refresh() -> void:
	var s = Inventory.slot(index)
	if s == null:
		_icon.texture = null
		_count.text = ""
		_cond.visible = false
		_key = ""
		tooltip_text = ""
		return
	var cond: float = s.get("cond", 100.0)
	_key = Icons.key_of(s.kind, s.id, cond)
	_icon.texture = Icons.get_icon(s.kind, s.id, cond)
	_count.text = str(s.count) if s.count > 1 else ""
	_cond.visible = s.kind == "rod"
	if s.kind == "rod":
		_cond.value = cond
		var fill := _cond.get_theme_stylebox("fill") as StyleBoxFlat
		fill.bg_color = Color(0.9, 0.2, 0.2) if cond < 25 else (Color(0.95, 0.8, 0.2) if cond < 60 else Color(0.4, 0.85, 0.4))
	var t := GameData.item_name(s.kind, s.id)
	if s.kind == "rod":
		t += " — %s" % GameData.condition_word(cond)
	if s.kind == "bait" and s.id == Inventory.equipped_bait:
		t += " (на крючке)"
	tooltip_text = ""


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		clicked.emit(index, event.button_index)


func _get_drag_data(_pos: Vector2) -> Variant:
	if not draggable or Inventory.slot(index) == null:
		return null
	var preview := TextureRect.new()
	preview.texture = _icon.texture
	preview.size = Vector2(SIZE, SIZE)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.modulate.a = 0.8
	set_drag_preview(preview)
	return {"slot": index}


func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	return draggable and data is Dictionary and data.has("slot")


func _drop_data(_pos: Vector2, data: Variant) -> void:
	Inventory.move_slot(data.slot, index)
