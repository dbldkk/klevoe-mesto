extends Interactable
## Товар на полке: ряд одинаковых предметов и жёлтый ценник на краю полки.
## Посмотри и нажми E — положишь в корзину.
## Полка стоит на краю — ценник висит на её переднем ребре (shelf_depth/2 вперёд).

@export_enum("rod", "bait", "drink", "food", "weapon", "smoke", "misc", "tool") var kind: String = "drink"
@export var item_id: StringName = &"beer"
## Сколько штук стоит в ряд (для красоты).
@export var facings: int = 4
@export var spacing: float = 0.13
## Глубина полки — ценник вешается на её переднее ребро.
@export var shelf_depth: float = 0.55
## Только для вида (полки за прилавком).
@export var decor_only: bool = false


func _ready() -> void:
	var length := spacing * facings
	set_meta("bake_detail_range", 20.0)
	set_meta("bake_ok", true)   # товары на полке не двигаются — MeshBaker склеит
	for i in facings:
		var m := ItemModels.build(kind, item_id)
		m.position.x = -length * 0.5 + spacing * (i + 0.5)
		if kind == "rod" or kind == "weapon":
			m.rotation.z = 0.06
		else:
			m.rotation.y = randf_range(-0.25, 0.25)
		for mi in m.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(m)
	if decor_only:
		collision_layer = 0
		return
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var tall := kind == "rod" or kind == "weapon"
	if tall:
		box.size = Vector3(length + 0.2, 2.3 if kind == "rod" else 1.1, 0.4)
		shape.position.y = box.size.y / 2
	else:
		box.size = Vector3(length + 0.05, 0.4, shelf_depth)
		shape.position.y = 0.18
	shape.shape = box
	add_child(shape)

	var name_txt := GameData.item_name(kind, item_id)
	var price_txt := "%d ₽" % price()
	var pack := Inventory.pack_of(kind, item_id)
	if pack > 1:
		price_txt += "  ×%d" % pack
	if tall:
		# Табличка над крючком.
		var plate_w := maxf(length + 0.1, 0.7)
		var y := 2.4 if kind == "rod" else 1.25
		Art.add_mesh(self, Art.box(Vector3(plate_w, 0.2, 0.02)), Art.color(Color(0.97, 0.88, 0.25), 0.7), Vector3(0, y, 0.05))
		_label(name_txt, Vector3(0, y + 0.04, 0.065), 15, plate_w)
		_label(price_txt, Vector3(0, y - 0.055, 0.065), 22, plate_w)
	else:
		# Ценник на ребре полки, не загораживает товар.
		var w := maxf(length, 0.42)
		var z := shelf_depth / 2 + 0.008
		Art.add_mesh(self, Art.box(Vector3(w, 0.085, 0.008)), Art.color(Color(0.97, 0.88, 0.25), 0.7), Vector3(0, -0.06, z))
		_label(name_txt, Vector3(0, -0.04, z + 0.006), 13, w)
		_label(price_txt, Vector3(0, -0.08, z + 0.006), 19, w)


func _label(txt: String, pos: Vector3, size: int, width: float) -> void:
	var l := Label3D.new()
	l.text = txt
	l.font_size = size
	l.pixel_size = 0.0022
	l.outline_size = 0
	l.modulate = Color(0.1, 0.08, 0.06)
	l.position = pos
	l.double_sided = false
	l.visibility_range_end = 9.0
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	# Не вылезать за ценник: ужимаем шрифт, если строка длинная.
	var max_chars := int(width / (size * 0.62 * l.pixel_size))
	if txt.length() > max_chars and max_chars > 0:
		l.font_size = maxi(8, int(size * float(max_chars) / txt.length()))
	add_child(l)


func price() -> int:
	var sh := _shop()
	return sh.price_of(kind, item_id) if sh is ShopController else GameData.item_price(kind, item_id)


func _shop() -> Node:
	var p := get_parent()
	return p if p and p.has_method("is_closed") else null


func get_prompt(_player: Node) -> String:
	var sh := _shop()
	if sh and sh.is_closed():
		return "Магазин закрыт — охрана в отключке"
	var extra := ""
	var pack := Inventory.pack_of(kind, item_id)
	if pack > 1:
		extra = " (×%d)" % pack
	return "Взять: %s%s — %d ₽" % [GameData.item_name(kind, item_id), extra, price()]


func interact(_player: Node) -> void:
	var sh := _shop()
	if sh and sh.is_closed():
		Events.notify("Зина: «Закрыто! Охранника вырубили, полицию вызвала!»", Color.TOMATO)
		return
	Inventory.add_to_cart(kind, item_id, price(), sh.spot_key if sh is ShopController else "")
