extends Node3D
## Укрытие: куст, мусорный бак или деревенский туалет. E — залезть/вылезти.
## Охранник, потерявший тебя из виду, ищет 7 секунд; подойдёт ближе 4 м — найдёт.
## В туалете можно сходить по нужде без последствий.

@export_enum("bush", "dumpster", "outhouse") var kind: String = "bush"

## Где стоит: рядом с постройкой (anchor + offset в её координатах) или у дороги (ring_phi, ring_off).
@export var anchor: String = ""
@export var offset: Vector3 = Vector3.ZERO
@export var ring_phi: float = 999.0
@export var ring_off: float = 0.0

var occupied_by := 0


func _enter_tree() -> void:
	if anchor != "":
		var t := Layout.xform(anchor)
		position = t * offset
		rotation.y = t.basis.get_euler().y + rotation.y
	elif ring_phi < 900.0:
		position = Layout.ring(ring_phi, ring_off)


func _ready() -> void:
	add_to_group("hiding_spot")
	position.y = Terrain.height(global_position.x, global_position.z) - (0.05 if kind == "bush" else 0.0)
	match kind:
		"bush": _bush()
		"dumpster": _dumpster()
		"outhouse": _outhouse()
	Build.talk_area(self, Vector3(0, 0.9, 0), Vector3(1.8, 1.8, 1.8), self)


func _bush() -> void:
	var leaf := Art.tex_world("leaves", 0.8) if ResourceLoader.exists("res://art/textures/leaves.png") \
		else Art.color(Color(0.22, 0.48, 0.18), 0.9)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name)
	for i in 7:
		var r := rng.randf_range(0.55, 0.85)
		var p := Vector3(rng.randf_range(-0.6, 0.6), r * 0.9 + rng.randf() * 0.3, rng.randf_range(-0.6, 0.6))
		var mi := Art.add_mesh(self, Art.sphere(r, 10), leaf, p)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for i in 5:
		Art.add_mesh(self, Art.sphere(0.06, 6), Art.color(Color(0.8, 0.1, 0.15)),
			Vector3(rng.randf_range(-0.8, 0.8), rng.randf_range(0.6, 1.4), rng.randf_range(-0.8, 0.8)))


func _dumpster() -> void:
	var green := Art.color(Color(0.18, 0.4, 0.25), 0.6, 0.3)
	Build.block(self, Vector3(0, 0.65, 0), Vector3(1.8, 1.2, 1.1), green, true)
	Build.block(self, Vector3(0, 1.3, -0.05), Vector3(1.85, 0.08, 1.15), Art.color(Color(0.12, 0.28, 0.17), 0.5, 0.3), false,
		Vector3(-0.12, 0, 0))
	for x in [-0.7, 0.7]:
		Art.add_mesh(self, Art.cyl(0.08, 0.08, 0.06, 10), Art.color(Color(0.1, 0.1, 0.1)), Vector3(x, 0.05, 0.45), Vector3(0, 0, PI / 2))
	Build.text(self, Vector3(0, 0.75, 0.56), "МУСОР · ЖКХ", 40, Color(0.95, 0.95, 0.85), 0.005)
	# Пакеты рядом
	for i in 3:
		Art.add_mesh(self, Art.sphere(0.25, 8), Art.color(Color(0.08, 0.08, 0.08), 0.3, 0.1), Vector3(1.2 + i * 0.25, 0.2, 0.3 - i * 0.3))


func _outhouse() -> void:
	var wood := Art.tex_world("planks", 0.6)
	Build.block(self, Vector3(0, 0.05, 0), Vector3(1.3, 0.1, 1.3), wood, false)
	Build.block(self, Vector3(0, 1.15, -0.6), Vector3(1.3, 2.3, 0.08), wood, true)
	Build.block(self, Vector3(-0.6, 1.15, 0), Vector3(0.08, 2.3, 1.3), wood, true)
	Build.block(self, Vector3(0.6, 1.15, 0), Vector3(0.08, 2.3, 1.3), wood, true)
	Build.block(self, Vector3(0, 2.38, 0), Vector3(1.5, 0.08, 1.5), Art.color(Color(0.4, 0.3, 0.2)), true, Vector3(0.15, 0, 0))
	# Дверь с сердечком
	var door := Build.block(self, Vector3(0, 1.1, 0.62), Vector3(1.1, 2.1, 0.05), wood, true)
	Build.text(door, Vector3(0, 0.7, 0.04), "♥", 120, Color(0.2, 0.1, 0.05), 0.006)
	Build.block(self, Vector3(0, 0.45, -0.3), Vector3(1.1, 0.5, 0.5), wood, false)


func _inside_pos() -> Vector3:
	match kind:
		"outhouse": return to_global(Vector3(0, 0.15, 0.1))
		"dumpster": return to_global(Vector3(0, 0.1, 0))
	return to_global(Vector3(0, -0.15, 0))


func get_prompt(player: Node) -> String:
	if player.hidden:
		return ""
	if occupied_by != 0:
		return "Занято!"
	match kind:
		"outhouse": return "Зайти в туалет (тут можно спрятаться)"
		"dumpster": return "Залезть в мусорный бак (спрятаться)"
	return "Залезть в куст (спрятаться)"


func interact(player: Node) -> void:
	if player.hidden or occupied_by != 0:
		return
	NetUtil.call_server(self, "srv_enter", [])


@rpc("any_peer", "reliable")
func srv_enter() -> void:
	if not multiplayer.is_server():
		return
	var peer := NetUtil.sender(self)
	if occupied_by != 0 and occupied_by != peer:
		var p := get_tree().get_root().get_node_or_null("World/Players/%d" % occupied_by)
		if p and p.hidden and p.hide_spot == self:
			return
	NetUtil.call_all(self, "set_occupied", [peer])
	NetUtil.call_peer(self, peer, "do_enter", [])


@rpc("authority", "reliable")
func set_occupied(peer: int) -> void:
	occupied_by = peer


@rpc("authority", "reliable")
func do_enter() -> void:
	var p := get_tree().get_first_node_in_group("local_player")
	if p == null:
		return
	var yaw := global_rotation.y
	p.enter_hide(self, _inside_pos(), yaw)


## Вызывает игрок, когда вылез.
func leave() -> void:
	NetUtil.call_server(self, "srv_leave", [])


@rpc("any_peer", "reliable")
func srv_leave() -> void:
	if multiplayer.is_server() and occupied_by == NetUtil.sender(self):
		NetUtil.call_all(self, "set_occupied", [0])
