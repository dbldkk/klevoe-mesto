extends Interactable
## В камере: копать ложкой под нарами. Удерживай E. Если дежурная смотрит — добавят срок.

var _prog := 0.0
var _stroke := 1.35
var _bar: MeshInstance3D
var _label: Label3D
var _dirt: Node3D
var _dug := 0


func _ready() -> void:
	add_to_group("jail_dig")
	monitoring = false
	var sh := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, 1.2, 1.4)
	sh.shape = box
	sh.position.y = 0.4
	add_child(sh)
	_dirt = Node3D.new()
	add_child(_dirt)
	_label = Build.text(self, Vector3(0, 1.15, 0), "", 28, Color(0.95, 0.9, 0.7), 0.004, 0.0, true)
	_rebuild_dirt()


func get_prompt(player: Node) -> String:
	if player == null or not player.has_method("is_jailed") or not player.is_jailed():
		return ""
	return "Копать ложкой (удерживай E)"


func interact(player: Node) -> void:
	if player and player.has_method("start_jail_dig"):
		player.start_jail_dig()


func _process(delta: float) -> void:
	var p := get_tree().get_first_node_in_group("local_player")
	if p == null or not p.has_method("is_jailed") or not p.is_jailed():
		_prog = 0.0
		_label.text = ""
		return
	if not p._digging:
		_prog = 0.0
		_label.text = "Ложка под нарами"
		return
	if not Input.is_action_pressed("interact"):
		p.stop_jail_dig()
		_prog = 0.0
		return
	# Дежурная смотрит — поймали.
	var st := get_parent()
	if st and st.has_method("cell_is_watched") and st.cell_is_watched():
		p.jail_caught_digging()
		_prog = 0.0
		_label.text = "Попался!"
		return
	_prog += delta
	_label.text = "Копаем… %d%%" % int((_prog / _stroke) * 100.0)
	if _prog >= _stroke:
		_prog = 0.0
		p.apply_dig_stroke()
		_dug += 1
		_rebuild_dirt()
		_label.text = "Земля поддалась"
		Sfx.play("click", global_position, -8.0)


func _rebuild_dirt() -> void:
	for c in _dirt.get_children():
		c.queue_free()
	var n := mini(_dug, 5)
	if n <= 0:
		return
	var hole := Art.color(Color(0.1, 0.07, 0.04), 1.0)
	var soil := Art.color(Color(0.28, 0.18, 0.1), 0.97)
	Art.add_mesh(_dirt, Art.cyl(0.28 + n * 0.08, 0.34 + n * 0.08, 0.07, 12), hole, Vector3(0, 0.01, 0))
	Art.add_mesh(_dirt, Art.cyl(0.22 + n * 0.05, 0.28 + n * 0.05, 0.12 + n * 0.04, 10), soil, Vector3(0.22, 0.05 + n * 0.02, 0.06))
	Art.add_mesh(_dirt, Art.box(Vector3(0.22, 0.025, 0.035)), Art.color(Color(0.62, 0.58, 0.45), 0.45, 0.4), Vector3(0.18, 0.08, 0.02), Vector3(0, 0, 0.55))
