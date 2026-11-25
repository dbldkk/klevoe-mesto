extends Node3D
## Царь-сом «мелькает»: огромная тёмная спина всплывает и уходит под воду на Дальнем плёсе.
## Видно только у себя на экране и только «в нужном состоянии» (скрытая механика — в игре не объяснять).

const LINES := ["Что это там… бревно? Нет — оно плывёт!", "Мать честная… вот это спина!",
	"Показалось? Да нет же, ВОТ ОН!", "Царь-сом… значит, не врут мужики"]

var _wait := 30.0
var _fish: Node3D
var _t := -1.0
var _from := Vector3.ZERO
var _dir := Vector3.FORWARD
var _ripple: MeshInstance3D
var _seen := 0


func _ready() -> void:
	add_to_group("tsar")
	_fish = Node3D.new()
	add_child(_fish)
	var dark := Art.color(Color(0.08, 0.09, 0.07), 0.35)
	Art.add_mesh(_fish, Art.sphere(0.6, 14), dark, Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 0.45, 4.2))
	Art.add_mesh(_fish, Art.box(Vector3(0.06, 0.55, 0.9)), dark, Vector3(0, 0.35, -0.3), Vector3(0.35, 0, 0))
	Art.add_mesh(_fish, Art.box(Vector3(1.4, 0.05, 0.7)), dark, Vector3(0, 0.0, 2.6), Vector3(0, 0, 0))
	_fish.visible = false
	_ripple = Art.add_mesh(self, Art.cyl(1.0, 1.0, 0.01, 24), Art.color(Color(0.85, 0.92, 0.95, 0.5), 0.2), Vector3.ZERO)
	var rm := (_ripple.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ripple.material_override = rm
	_ripple.visible = false


func _process(delta: float) -> void:
	if _t >= 0.0:
		_animate(delta)
		return
	var me := get_tree().get_first_node_in_group("local_player") as Node3D
	if me == null or Inventory.drunk < 50.0:
		return
	var p := me.global_position
	if Terrain.lake_distance(p.x, p.z).x > 25.0 or p.z > -95.0:
		return
	_wait -= delta * (1.0 + Inventory.drunk / 100.0)
	if _wait > 0.0:
		return
	_wait = randf_range(35.0, 80.0)
	var look: Vector3 = me.call("look_dir")
	look.y = 0.0
	for k in 12:
		var d := look.normalized().rotated(Vector3.UP, randf_range(-0.9, 0.9)) * randf_range(10.0, 24.0)
		var q := p + d
		if Terrain.is_far(q.x, q.z) and Terrain.depth(q.x, q.z) > 3.5:
			_start(Vector3(q.x, Terrain.WATER_Y, q.z))
			return


func _start(at: Vector3) -> void:
	_from = at
	_dir = Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU)
	_fish.rotation.y = atan2(_dir.x, _dir.z)
	_t = 0.0
	_fish.visible = true
	_ripple.visible = true
	Sfx.play("splash_big", at, 2.0, 0.2)
	Events.notify(LINES[_seen % LINES.size()], Color(0.8, 0.95, 0.7))
	_seen += 1


func _animate(delta: float) -> void:
	_t += delta
	var k := _t / 3.2
	var rise := sin(clampf(k, 0.0, 1.0) * PI)
	_fish.global_position = _from + _dir * k * 4.0 + Vector3.UP * (rise * 0.55 - 0.45)
	_fish.rotation.x = lerpf(0.15, -0.2, k)
	_ripple.global_position = _from + _dir * k * 2.0 + Vector3.UP * 0.02
	var s := 1.0 + _t * 2.2
	_ripple.scale = Vector3(s, 1, s)
	(_ripple.material_override as StandardMaterial3D).albedo_color.a = maxf(0.5 - _t * 0.12, 0.0)
	if _t > 2.6 and _t - delta <= 2.6:
		Sfx.play("splash", _fish.global_position, 0.0, 0.2)
	if _t > 4.2:
		_t = -1.0
		_fish.visible = false
		_ripple.visible = false
