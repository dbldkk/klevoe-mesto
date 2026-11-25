extends Node3D
## «Белочка» — видения у очень пьяного (видит только он сам).
## Вокруг летают говорящие рыбы, прыгает рыжая белочка и всё комментирует, мерещатся голоса.
## Проходит, когда протрезвеешь (опьянение < 60) или через полторы минуты.

const FISH_LINES := ["Отпусти меня, я золотая!", "Ты чего на меня так смотришь?", "Буль-буль… шучу.",
	"А Толя-то тебя обманывает!", "Пойдём с нами на дно, там весело", "Я твой внутренний окунь",
	"Ещё стопочку — и я исполню желание", "Не лови меня, у меня дети!"]
const SQUIRREL_LINES := ["Ну здравствуй, рыбак!", "Я за тобой с утра слежу", "Орешков нет? А водочка?",
	"Гоша — мой брат-близнец", "Не оборачивайся…", "Я и есть белочка. Приятно познакомиться",
	"Ты уже третий раз со мной здороваешься"]
const VOICES := ["Кто-то шепчет: «Сом под пирсом… сом под пирсом…»", "Где-то вдалеке поют рыбы",
	"Небо стало подозрительно фиолетовым", "Тебе кажется, что поплавок смотрит на тебя",
	"Голос Михалыча из-под земли: «Предъявите чек!»"]

var player: Node3D
var _t := 0.0
var _fish: Array[Node3D] = []
var _labels: Array[Label3D] = []
var _squirrel: Node3D
var _sq_label: Label3D
var _talk_t := 0.0
var _voice_t := 6.0
var _ending := false


func _ready() -> void:
	var ids := [&"golden", &"pike", &"perch"]
	for i in 3:
		var f: FishData = GameData.get_fish(ids[i])
		var n := Node3D.new()
		add_child(n)
		var m := FishMesh.build(f)
		m.scale = Vector3.ONE * 2.2
		n.add_child(m)
		var l := _make_label(Color(0.7, 0.95, 1.0))
		l.position.y = 0.7
		n.add_child(l)
		_fish.append(n)
		_labels.append(l)
	_squirrel = _build_squirrel()
	add_child(_squirrel)
	_sq_label = _make_label(Color(1.0, 0.75, 0.4))
	_sq_label.position.y = 1.1
	_squirrel.add_child(_sq_label)
	Events.notify("Ой… а это кто тут?!", Color(1.0, 0.6, 0.9))
	Sfx.play("hic", null, -2.0)


func _make_label(c: Color) -> Label3D:
	var l := Label3D.new()
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 38
	l.pixel_size = 0.006
	l.outline_size = 10
	l.modulate = c
	l.no_depth_test = true
	return l


func _build_squirrel() -> Node3D:
	var s := Node3D.new()
	var fur := Art.color(Color(0.85, 0.42, 0.12), 0.9)
	var belly := Art.color(Color(0.98, 0.88, 0.7), 0.9)
	Art.add_mesh(s, Art.sphere(0.22, 12), fur, Vector3(0, 0.3, 0), Vector3.ZERO, Vector3(1, 1.3, 1))
	Art.add_mesh(s, Art.sphere(0.13, 10), belly, Vector3(0, 0.28, -0.12))
	Art.add_mesh(s, Art.sphere(0.15, 12), fur, Vector3(0, 0.62, -0.03))
	for x in [-0.08, 0.08]:
		Art.add_mesh(s, Art.cyl(0.0, 0.04, 0.1, 6), fur, Vector3(x, 0.79, -0.02))
		Art.add_mesh(s, Art.sphere(0.03, 6), Art.color(Color(0.05, 0.05, 0.05)), Vector3(x * 0.7, 0.66, -0.16))
	Art.add_mesh(s, Art.sphere(0.2, 10), fur, Vector3(0, 0.5, 0.25), Vector3(0.5, 0, 0), Vector3(0.9, 1.8, 0.9))
	return s


func finish() -> void:
	if _ending:
		return
	_ending = true
	Events.notify("Белочка помахала лапкой и исчезла… Фух", Color(1.0, 0.75, 0.4))
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * 0.01, 0.8)
	tw.finished.connect(queue_free)


func _process(delta: float) -> void:
	if not is_instance_valid(player):
		queue_free()
		return
	_t += delta
	if _t > 90.0:
		finish()
	var c := player.global_position
	for i in _fish.size():
		var a := _t * (0.6 + i * 0.25) + i * TAU / 3.0
		var r := 2.6 + sin(_t * 0.7 + i) * 0.8
		_fish[i].global_position = c + Vector3(cos(a) * r, 1.4 + sin(_t * 1.3 + i * 2.0) * 0.5, sin(a) * r)
		_fish[i].rotation = Vector3(sin(_t + i) * 0.3, -a, 0)
	var fwd := -player.global_basis.z
	var side := player.global_basis.x
	var hop := absf(sin(_t * 4.0)) * 0.35
	_squirrel.global_position = c + fwd * 2.2 + side * sin(_t * 0.5) * 1.5 + Vector3(0, hop, 0)
	_squirrel.look_at(c + Vector3(0, 0.3, 0), Vector3.UP, true)
	_talk_t -= delta
	if _talk_t <= 0.0:
		_talk_t = randf_range(3.0, 5.0)
		var k := randi() % 4
		for l in _labels:
			l.text = ""
		_sq_label.text = ""
		if k == 3:
			_sq_label.text = SQUIRREL_LINES.pick_random()
		else:
			_labels[k].text = FISH_LINES.pick_random()
		Sfx.play("hic", _squirrel.global_position, -14.0, 0.4)
	_voice_t -= delta
	if _voice_t <= 0.0:
		_voice_t = randf_range(9.0, 15.0)
		Events.notify(VOICES.pick_random(), Color(1.0, 0.6, 0.9))
