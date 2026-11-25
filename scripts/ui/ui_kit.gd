class_name UiKit
## Общий стиль интерфейса: панели, заголовки, кнопки.

const BG := Color(0.08, 0.1, 0.12, 0.94)
const ACCENT := Color(0.95, 0.75, 0.3)


static func panel(min_size: Vector2, bg: Color = BG) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = min_size
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.add_theme_stylebox_override("panel", box(bg, 12, 22))
	return p


static func box(bg: Color, radius: int = 8, margin: int = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	return s


static func title(text: String, color: Color = ACCENT) -> Label:
	var l := label(text, 32, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


static func label(text: String, size: int = 18, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func button(text: String, on_press: Callable, size: int = 18) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size.y = 36
	b.add_theme_stylebox_override("normal", box(Color(0.2, 0.23, 0.27), 6, 8))
	b.add_theme_stylebox_override("hover", box(Color(0.28, 0.32, 0.37), 6, 8))
	b.add_theme_stylebox_override("pressed", box(Color(0.35, 0.3, 0.15), 6, 8))
	b.add_theme_stylebox_override("disabled", box(Color(0.15, 0.16, 0.18), 6, 8))
	b.pressed.connect(func() -> void: Sfx.play("click", null, -10.0, 0.05))
	if on_press.is_valid():
		b.pressed.connect(on_press)
	return b


## Полоска (здоровье, опьянение, натяжение).
static func bar(color: Color, min_size: Vector2 = Vector2(220, 12)) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = min_size
	b.show_percentage = false
	b.max_value = 100.0
	b.add_theme_stylebox_override("background", box(Color(0, 0, 0, 0.5), 4, 0))
	b.add_theme_stylebox_override("fill", box(color, 4, 0))
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b
