extends Node3D
## Опорный пункт участкового: стол, «обезьянник» с решёткой. Сюда сажают «на сутки».
## Один игрок в мире — время прыгает на полдня вперёд. Несколько — сидишь 2 минуты (остальные-то играют).

const W := 7.0
const D := 6.0
const H := 3.0
const CELL := Vector3(-2.3, 0.1, -1.9)
const OUT := Vector3(1.5, 0.1, 4.6)
const JAIL_COOP := 120.0
const JAIL_SOLO := 45.0


func _enter_tree() -> void:
	transform = Layout.xform("police")


func _ready() -> void:
	add_to_group("police_station")
	add_to_group("poi")
	set_meta("poi_name", "Опорный пункт")
	var wall := Art.tex_world("plaster", 0.5).duplicate() as StandardMaterial3D
	wall.albedo_color = Color(0.75, 0.82, 0.95)
	Build.room(self, W, D, H, wall, Art.tex_world("plaster", 0.5), Art.tex_world("linoleum", 0.4), Art.tex_world("roof", 0.35), 1.2, 2.2, 1.5)
	Build.gable_roof(self, W, D, H, Art.color(Color(0.3, 0.42, 0.35), 0.6, 0.3), wall, 1.1)
	Build.plinth(self, W, D, 1.2, 1.5)
	Build.door(self, Vector3(1.5, 0, D / 2 - 0.11), 1.2, 2.2, false, Color(0.3, 0.35, 0.45))
	Build.block(self, Vector3(0, 2.6, D / 2 + 0.03), Vector3(5.2, 0.55, 0.05), Art.color(Color(0.12, 0.25, 0.55)), false)
	Build.text(self, Vector3(0, 2.6, D / 2 + 0.06), "ОПОРНЫЙ ПУНКТ ПОЛИЦИИ", 44, Color.WHITE, 0.006)
	Build.window(self, Vector3(-1.8, 1.5, D / 2), Vector2(1.4, 1.0))
	var blue := Build.glow_mat(Color(0.2, 0.4, 1.0), 1.5)
	Art.add_mesh(self, Art.sphere(0.12, 8), blue, Vector3(3.0, 3.1, D / 2 - 0.3))
	Build.lamp(self, Vector3(0, H - 0.4, 0), 1.0, 8.0, Color(0.95, 0.97, 1.0))
	# Стол и стул
	var wood := Art.tex_world("planks", 0.7)
	Build.block(self, Vector3(2.0, 0.4, -1.5), Vector3(1.6, 0.8, 0.8), wood, true)
	Build.block(self, Vector3(2.0, 0.82, -1.5), Vector3(0.4, 0.03, 0.3), Art.color(Color(0.9, 0.9, 0.85)), false)
	Build.block(self, Vector3(2.0, 0.45, -2.3), Vector3(0.45, 0.06, 0.45), wood, false)
	Build.text(self, Vector3(2.0, 2.0, -2.88), "Их разыскивает полиция", 30, Color(0.2, 0.2, 0.2), 0.004)
	# «Обезьянник»: решётка по двум сторонам в углу
	var bars := Art.color(Color(0.3, 0.3, 0.32), 0.4, 0.8)
	var x0 := -W / 2 + 0.22
	var z0 := -D / 2 + 0.22
	var xb := -0.9
	var zb := -0.6
	for i in 12:
		var z := z0 + (zb - z0) * (i + 0.5) / 12.0
		Art.add_mesh(self, Art.cyl(0.025, 0.025, H - 0.1, 6), bars, Vector3(xb, (H - 0.1) / 2, z))
	for i in 14:
		var x := x0 + (xb - x0) * (i + 0.5) / 14.0
		Art.add_mesh(self, Art.cyl(0.025, 0.025, H - 0.1, 6), bars, Vector3(x, (H - 0.1) / 2, zb))
	# коллизия решётки (невидимые стенки)
	Build.block(self, Vector3(xb, H / 2, (z0 + zb) / 2), Vector3(0.06, H, zb - z0), _invisible(), true).visible = false
	Build.block(self, Vector3((x0 + xb) / 2, H / 2, zb), Vector3(xb - x0, H, 0.06), _invisible(), true).visible = false
	Build.block(self, Vector3(-2.6, 0.3, -2.4), Vector3(1.4, 0.06, 0.6), wood, true)   # нары
	Build.text(self, Vector3(-2.2, 2.2, zb + 0.03), "КПЗ", 50, Color(0.9, 0.2, 0.2), 0.006)
	var dig := preload("res://scripts/world/places/jail_dig.gd").new()
	dig.name = "JailDig"
	dig.position = Vector3(-2.4, 0.0, -2.15)
	add_child(dig)
	# миска и ложка у нар
	Art.add_mesh(self, Art.cyl(0.08, 0.09, 0.04, 10), Art.color(Color(0.55, 0.55, 0.5), 0.4, 0.5), Vector3(-1.7, 0.36, -2.35))
	Art.add_mesh(self, Art.box(Vector3(0.12, 0.012, 0.02)), Art.color(Color(0.6, 0.58, 0.5), 0.45, 0.5), Vector3(-1.62, 0.37, -2.28))


func _invisible() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0, 0, 0, 0)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


## Сервер: посадить игрока.
func jail(peer: int, reason: String, mult := 1.0) -> void:
	var p := get_tree().get_root().get_node_or_null("World/Players/%d" % peer)
	if p == null:
		return
	var solo := get_tree().get_nodes_in_group("players").size() <= 1
	var secs := (JAIL_SOLO if solo else JAIL_COOP) * mult
	# Сдвиг времени суток — при выходе, и его можно укоротить, копая ложкой.
	NetUtil.call_peer(p, peer, "go_to_jail", [secs, to_global(CELL), to_global(OUT), reason, solo])
	NetUtil.call_all(self, "announce", ["Участковый посадил %s «на сутки»: %s" % [p.player_name, reason]])


@rpc("authority", "call_remote", "reliable")
func announce(text: String) -> void:
	Events.notify(text, Color(0.6, 0.75, 1.0))


func cell_is_watched() -> bool:
	for o in get_tree().get_nodes_in_group("police"):
		if o.has_method("is_watching_cell") and o.is_watching_cell():
			return true
	return false
