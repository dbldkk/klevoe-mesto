class_name ModalUi
extends CanvasLayer
## Общая основа окон: затемнение, панель по центру, Esc — закрыть, мышь освобождается.

var panel: PanelContainer
var body: VBoxContainer


func _setup(group: String, title: String, width := 640.0, title_color := UiKit.ACCENT) -> void:
	layer = 6
	add_to_group(group)
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	panel = UiKit.panel(Vector2(width, 0))
	add_child(panel)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	panel.add_child(body)
	if title != "":
		body.add_child(UiKit.title(title, title_color))


func _show() -> void:
	visible = true
	Events.ui_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	if not visible:
		return
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


static func clear(c: Node) -> void:
	for ch in c.get_children():
		ch.queue_free()


static func row(sep := 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func icon(tex: Texture2D, size := 48) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.custom_minimum_size = Vector2(size, size)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return t


## Иконка предмета; если картинка ещё рендерится — подставится, когда будет готова.
static func item_icon(kind: String, id: StringName, cond := 100.0, size := 48) -> TextureRect:
	var t := icon(Icons.get_icon(kind, id, cond), size)
	var key := Icons.key_of(kind, id, cond)
	var cb := func(k: String) -> void:
		if k == key and is_instance_valid(t):
			t.texture = Icons.get_icon(kind, id, cond)
	Icons.icon_ready.connect(cb)
	t.tree_exiting.connect(func() -> void:
		if Icons.icon_ready.is_connected(cb):
			Icons.icon_ready.disconnect(cb))
	return t
