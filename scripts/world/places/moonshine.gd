extends Node3D
## Самогонный аппарат в доме. 2 кг сахара + дрожжи → через 2 игровых часа 3 бутылки самогона.
## Состояние хранит хост (и сохраняет в мире); видно всем: булькает и парит, пока гонится.

const SUGAR := 2
const YEAST := 1
const BREW_MIN := 120.0
const YIELD := 3

## 0 — пусто, 1 — гонится, 2 — готово.
@export var stage: int = 0
@export var left: float = 0.0

var _steam: CPUParticles3D
var _snd: AudioStreamPlayer3D
var _jar: MeshInstance3D


func _ready() -> void:
	var copper := Art.color(Color(0.78, 0.45, 0.25), 0.3, 0.8)
	var steel := Art.color(Color(0.7, 0.72, 0.75), 0.25, 0.8)
	Build.block(self, Vector3(0, 0.25, 0), Vector3(0.9, 0.5, 0.6), Art.tex_world("planks", 0.8), true)
	Build.cylinder(self, Vector3(-0.15, 0.78, 0), 0.24, 0.55, steel, false, 16)
	Art.add_mesh(self, Art.sphere(0.24, 14), steel, Vector3(-0.15, 1.05, 0), Vector3.ZERO, Vector3(1, 0.5, 1))
	Art.add_mesh(self, Art.cyl(0.025, 0.025, 0.5, 8), copper, Vector3(0.1, 1.15, 0), Vector3(0, 0, -1.2))
	for i in 5:
		Art.add_mesh(self, Art.cyl(0.09, 0.09, 0.03, 12), copper, Vector3(0.32, 1.02 - i * 0.07, 0), Vector3(0.2, 0, 0))
	Art.add_mesh(self, Art.cyl(0.02, 0.02, 0.3, 6), copper, Vector3(0.32, 0.7, 0))
	_jar = Art.add_mesh(self, Art.cyl(0.08, 0.08, 0.2, 12), Art.glass(Color(0.85, 0.9, 0.95, 0.5)), Vector3(0.32, 0.6, 0))
	Build.text(self, Vector3(0, 0.3, 0.31), "АППАРАТ", 30, Color(1, 0.9, 0.6), 0.004)
	_steam = CPUParticles3D.new()
	_steam.position = Vector3(-0.15, 1.2, 0)
	_steam.amount = 16
	_steam.lifetime = 1.6
	_steam.direction = Vector3.UP
	_steam.spread = 15.0
	_steam.gravity = Vector3(0, 0.4, 0)
	_steam.initial_velocity_min = 0.2
	_steam.initial_velocity_max = 0.4
	_steam.scale_amount_min = 0.5
	_steam.scale_amount_max = 1.4
	var q := SphereMesh.new()
	q.radius = 0.06
	q.height = 0.12
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1, 1, 1, 0.25)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	q.material = m
	_steam.mesh = q
	_steam.emitting = false
	add_child(_steam)
	_snd = AudioStreamPlayer3D.new()
	_snd.bus = "Effects"
	_snd.stream = Sfx.stream_of("bubbling")
	_snd.unit_size = 2.5
	_snd.volume_db = -8.0
	add_child(_snd)
	Build.talk_area(self, Vector3(0, 0.8, 0.2), Vector3(1.0, 1.2, 0.9), self)
	Net.hosted.connect(func() -> void:
		var d := Saves.get_section("moonshine")
		stage = int(d.get("stage", 0))
		left = float(d.get("left", 0.0)))
	Saves.before_save.connect(func() -> void: Saves.set_section("moonshine", {"stage": stage, "left": left}))


func get_prompt(_p: Node) -> String:
	match stage:
		1: return "Самогон гонится… ещё %d мин" % ceili(left)
		2: return "Забрать самогон (%d бут.)" % YIELD
	return "Самогонный аппарат: загрузить %d кг сахара + дрожжи (есть: сахар %d, дрожжи %d)" % [SUGAR,
		Inventory.count_of("misc", &"sugar"), Inventory.count_of("misc", &"yeast")]


func interact(_p: Node) -> void:
	match stage:
		0:
			if Inventory.count_of("misc", &"sugar") < SUGAR or Inventory.count_of("misc", &"yeast") < YEAST:
				Events.notify("Нужно %d кг сахара и пачка дрожжей — продаются в «Шестёрочке»" % SUGAR, Color.LIGHT_GRAY)
				return
			Inventory.remove_item("misc", &"sugar", SUGAR)
			Inventory.remove_item("misc", &"yeast", YEAST)
			Inventory.changed.emit()
			NetUtil.call_server(self, "srv_start", [])
			Events.notify("Загрузил брагу. Через пару часов будет самогон", Color(1.0, 0.9, 0.6))
		2:
			NetUtil.call_server(self, "srv_take", [])


@rpc("any_peer", "reliable")
func srv_start() -> void:
	if multiplayer.is_server() and stage == 0:
		stage = 1
		left = BREW_MIN


@rpc("any_peer", "reliable")
func srv_take() -> void:
	if not multiplayer.is_server() or stage != 2:
		return
	stage = 0
	NetUtil.call_peer(self, NetUtil.sender(self), "give", [YIELD])


@rpc("authority", "reliable")
func give(n: int) -> void:
	if Inventory.add_item("drink", &"samogon", n):
		Inventory.stat_add("moonshine", n)
		Sfx.play("bottle_clink", global_position + Vector3.UP)
		Events.notify("Свой самогон: %d бутылки! Можно выпить или продать Толе" % n, Color.GOLD)


func _process(delta: float) -> void:
	_steam.emitting = stage == 1
	_jar.visible = stage != 0
	if stage == 1:
		if not _snd.playing:
			_snd.play()
	elif _snd.playing:
		_snd.stop()
	if multiplayer.is_server() and stage == 1:
		left -= delta   # 1 игровая минута = 1 с
		if left <= 0.0:
			left = 0.0
			stage = 2
