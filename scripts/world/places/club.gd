class_name Club
extends Node3D
## Клуб «Огонёк» с шатром: каждый третий день — то свадьба, то поминки. Наливают бесплатно,
## тамада проводит конкурсы, а под конец — обязательная драка (два гостя лезут ко всем).
## Расписание и решения — у хоста; состояние (kind/stage) — через Sync.

enum K { NONE, WEDDING, FUNERAL }
enum St { IDLE, GATHER, CONTEST, BOUQUET, BRAWL }

const OPEN := 12 * 60
const CONTEST_AT := 12 * 60 + 30
const CONTEST_END := 13 * 60 + 15
const BOUQUET_AT := 13 * 60 + 30
const BRAWL_AT := 14 * 60 + 30
const CLOSE := 16 * 60
const FREE_POURS := 6

@export var kind: int = K.NONE
@export var stage: int = St.IDLE

var _pours: Dictionary = {}       ## peer -> сколько налили за праздник
var _contest: Dictionary = {}     ## peer -> выпито в конкурсе
var _guests: Array[CharacterModel] = []
var _bride: CharacterModel
var _groom: CharacterModel
var _portrait: Node3D
var _deco: Node3D
var _tamada: CharacterModel
var _speech: Label3D
var _board: Label3D
var _music: AudioStreamPlayer3D
var _music_kind := -1
var _t := 0.0
var _done_today := {}             ## этапы, уже пройденные сегодня (сервер)


func _enter_tree() -> void:
	transform = Layout.xform("club")


func _ready() -> void:
	add_to_group("club")
	add_to_group("poi")
	set_meta("poi_name", "Клуб «Огонёк»")
	_build_club()
	_build_party()
	Events.new_day.connect(func(_d: int) -> void:
		_done_today = {}
		_pours = {}
		_contest = {})


static func party_kind(day: int) -> int:
	if day % 3 != 2:
		return K.NONE
	return K.WEDDING if (day / 3) % 2 == 0 else K.FUNERAL


static func next_party_text(day: int) -> String:
	for k in 4:
		var t := party_kind(day + k)
		if t != K.NONE:
			var what := "Свадьба Михалыча и Люси" if t == K.WEDDING else "Поминки деда Егора"
			return "%s — %s, в 12:00" % [what, "СЕГОДНЯ" if k == 0 else ("завтра" if k == 1 else "через %d дн." % k)]
	return ""


# ------------------------------------------------------------ постройки

func _build_club() -> void:
	var wall := Art.tex_world("plaster", 0.5).duplicate() as StandardMaterial3D
	wall.albedo_color = Color(0.95, 0.85, 0.65)
	var n := Node3D.new()
	n.position = Vector3(0, 0, -4.5)
	add_child(n)
	Build.room(n, 10.0, 5.0, 3.4, wall, Art.tex_world("plaster", 0.5), Art.tex_world("planks", 0.6), Art.tex_world("roof", 0.35), 1.6, 2.4, 0.0)
	Build.gable_roof(n, 10.0, 5.0, 3.4, Art.color(Color(0.55, 0.25, 0.2), 0.7), wall, 1.3)
	Build.plinth(n, 10.0, 5.0, 1.6)
	Build.door(n, Vector3(0, 0, 2.39), 1.6, 2.4, true, Color(0.55, 0.3, 0.2))
	Build.block(n, Vector3(0, 3.0, 2.56), Vector3(4.8, 0.6, 0.06), Art.color(Color(0.75, 0.15, 0.12)), false)
	Build.text(n, Vector3(0, 3.0, 2.6), "КЛУБ «ОГОНЁК»", 56, Color(1, 0.9, 0.5), 0.006)
	for x in [-3.2, 3.2]:
		Build.window(n, Vector3(x, 1.6, 2.5), Vector2(1.4, 1.1))
	# колонны у входа
	for x in [-1.6, 1.6]:
		Build.cylinder(n, Vector3(x, 1.4, 2.9), 0.15, 2.8, Art.color(Color(0.95, 0.95, 0.92), 0.6), true, 12)
	Build.block(n, Vector3(0, 2.86, 2.9), Vector3(4.0, 0.12, 1.0), Art.color(Color(0.95, 0.95, 0.92), 0.6), false)
	# доска объявлений
	var b := Node3D.new()
	b.position = Vector3(6.2, 0, 1.5)
	b.rotation.y = -0.4
	add_child(b)
	Build.block(b, Vector3(0, 1.0, 0), Vector3(0.08, 2.0, 0.08), Art.color(Color(0.35, 0.25, 0.15)), true)
	Build.block(b, Vector3(0, 1.75, 0.05), Vector3(1.7, 1.0, 0.04), Art.color(Color(0.85, 0.8, 0.65)), false)
	_board = Build.text(b, Vector3(0, 1.75, 0.08), "", 26, Color(0.15, 0.12, 0.1), 0.005)
	_board.width = 300
	_board.autowrap_mode = TextServer.AUTOWRAP_WORD


func _build_party() -> void:
	_deco = Node3D.new()
	add_child(_deco)
	# шатёр
	var pole := Art.color(Color(0.9, 0.9, 0.9), 0.5, 0.3)
	for x in [-4.5, 4.5]:
		for z in [-1.0, 4.5]:
			Build.cylinder(_deco, Vector3(x, 1.3, z), 0.05, 2.6, pole, true, 8)
	for i in 9:
		var c := Color(0.85, 0.15, 0.15) if i % 2 == 0 else Color(0.97, 0.97, 0.95)
		Build.block(_deco, Vector3(-4.0 + i * 1.0, 2.75, 1.75), Vector3(1.0, 0.06, 6.0), Art.color(c, 0.8), false)
	# стол «буквой П»
	var cloth := Art.color(Color(0.97, 0.97, 0.94), 0.8)
	Build.block(_deco, Vector3(0, 0.4, 0.4), Vector3(6.0, 0.8, 1.0), cloth, true)
	for x in [-3.2, 3.2]:
		Build.block(_deco, Vector3(x, 0.4, 2.4), Vector3(1.0, 0.8, 3.2), cloth, true)
	for p in [Vector3(-2.0, 0.8, 0.4), Vector3(-0.4, 0.8, 0.5), Vector3(1.3, 0.8, 0.35), Vector3(-3.1, 0.8, 2.0), Vector3(3.3, 0.8, 2.8)]:
		var bt := ItemModels.build("drink", &"vodka")
		bt.position = p
		_deco.add_child(bt)
		Art.add_mesh(_deco, Art.cyl(0.14, 0.14, 0.02, 12), Art.color(Color(0.95, 0.95, 0.95), 0.3), p + Vector3(0.3, 0.01, 0))
		Art.add_mesh(_deco, Art.sphere(0.07, 8), Art.color(Color(0.3, 0.6, 0.2)), p + Vector3(0.3, 0.06, 0))   # огурчик
	Build.talk_area(_deco, Vector3(0, 0.9, 1.2), Vector3(6.0, 1.4, 1.6), _Table.new(self))
	# сцена тамады
	Build.block(_deco, Vector3(0, 0.15, -1.6), Vector3(3.0, 0.3, 1.4), Art.tex_world("planks", 0.6), true)
	_tamada = Build.person(_deco, Vector3(-0.6, 0.3, -1.6), 0.0, {"shirt": 6, "pants": 1, "skin": 0, "hat": 0, "face": 1}, "smile")
	_tamada.rotation.y = PI
	var acc := Build.person(_deco, Vector3(0.8, 0.3, -1.8), 0.0, {"shirt": 2, "pants": 0, "skin": 1, "hat": 1, "hat_color": 0, "face": 2}, "player_b")
	acc.rotation.y = PI
	acc.pose = "sit"
	Art.add_mesh(acc, Art.box(Vector3(0.5, 0.3, 0.25)), Art.color(Color(0.6, 0.1, 0.1), 0.5), Vector3(0, 0.75, -0.3))   # гармонь
	_speech = Build.text(_deco, Vector3(-0.6, 2.6, -1.6), "", 36, Color(1, 1, 0.8), 0.006, 0.0, true)
	Build.text(_deco, Vector3(-0.6, 2.25, -1.6), "Тамада Аркадьевна", 32, Color(1, 0.85, 0.6), 0.006, 0.0, true)
	# гости
	var skins := [{"shirt": 0, "pants": 1, "skin": 0, "hat": 1, "hat_color": 2}, {"shirt": 3, "pants": 3, "skin": 1, "hat": 0},
		{"shirt": 5, "pants": 0, "skin": 2, "hat": 2, "hat_color": 1}, {"shirt": 9, "pants": 2, "skin": 0, "hat": 3, "hat_color": 5},
		{"shirt": 1, "pants": 4, "skin": 4, "hat": 0}, {"shirt": 6, "pants": 1, "skin": 1, "hat": 1, "hat_color": 4}]
	var spots := [Vector3(-2.4, 0, -0.3), Vector3(-1.0, 0, -0.3), Vector3(2.2, 0, -0.3), Vector3(-3.9, 0, 2.6),
		Vector3(3.9, 0, 1.8), Vector3(1.5, 0, 3.2)]
	for i in spots.size():
		var g := Build.person(_deco, spots[i], 0.0, skins[i], ["smile", "neutral", "player_b", "smile", "neutral", "angry"][i])
		g.rotation.y = [0.0, 0.0, 0.0, -PI / 2, PI / 2, PI][i]
		_guests.append(g)
		if i == 1 or i == 4:
			var ch := Chatter.attach(g, "m" if i == 1 else "m_low", [func() -> String:
				return ["Горько! Горько!", "За молодых!", "Михалыч, ну ты даёшь, женился!", "А невеста-то красавица!"].pick_random() \
					if kind == K.WEDDING else ["Хороший был мужик, дед Егор…", "Он такого леща однажды вытащил — во!", "Помянем. Не чокаясь."].pick_random()], 2.3, 5.0)
			ch.condition = func() -> bool: return kind != K.NONE
	_bride = Build.person(_deco, Vector3(-0.3, 0, -0.35), 0.0, {"shirt": 7, "pants": 5, "skin": 4, "hat": 0}, "smile")
	Art.add_mesh(_bride, Art.cyl(0.32, 0.5, 0.9, 12), Art.color(Color(0.98, 0.98, 0.98), 0.6), Vector3(0, 0.45, 0))   # платье
	Art.add_mesh(_bride, Art.box(Vector3(0.4, 0.5, 0.05)), Art.color(Color(1, 1, 1, 0.8), 0.3), Vector3(0, 1.55, 0.18))   # фата
	_groom = Build.person(_deco, Vector3(0.4, 0, -0.35), 0.0, {"shirt": 8, "pants": 1, "skin": 0, "hat": 0}, "player_b")
	Art.add_mesh(_groom, Art.sphere(0.05, 8), Art.color(Color(0.9, 0.2, 0.25)), Vector3(0.12, 1.35, -0.2))   # бутоньерка
	_portrait = Node3D.new()
	_portrait.position = Vector3(0, 0.3, -1.1)
	_portrait.set_meta("no_bake", true)
	_deco.add_child(_portrait)
	Build.block(_portrait, Vector3(0, 0.8, 0), Vector3(0.05, 1.6, 0.05), Art.color(Color(0.2, 0.15, 0.1)), false)
	Build.block(_portrait, Vector3(0, 1.4, 0.03), Vector3(0.55, 0.7, 0.04), Art.color(Color(0.1, 0.1, 0.1)), false)
	Build.text(_portrait, Vector3(0, 1.4, 0.06), "Дед Егор\n1941–2026\nрыбак", 22, Color(0.9, 0.9, 0.85), 0.004)
	_music = AudioStreamPlayer3D.new()
	_music.bus = "Music"
	_music.unit_size = 9.0
	_music.max_distance = 55.0
	_music.volume_db = -4.0
	_music.position = Vector3(0.8, 1.2, -1.8)
	_deco.add_child(_music)


# ------------------------------------------------------------ расписание (сервер)

func _process(delta: float) -> void:
	_t += delta
	_visuals(delta)
	if not multiplayer.is_server():
		return
	var dc := get_tree().get_first_node_in_group("day_cycle") as DayCycle
	if dc == null or dc.phase != DayCycle.Phase.AWAKE:
		return
	var m := int(dc.minutes) % 1440
	var k := party_kind(dc.day)
	if k == K.NONE or m < OPEN or m >= CLOSE:
		if kind != K.NONE:
			_finish()
		return
	if kind == K.NONE:
		kind = k
		stage = St.GATHER
		_announce("В клубе «Огонёк» %s! Наливают бесплатно — все приглашены" % ("свадьба Михалыча" if k == K.WEDDING else "поминки деда Егора"))
		_say("Гости дорогие, проходите, рассаживайтесь!" if k == K.WEDDING else "Проходите… помянем деда Егора, хороший был рыбак")
	if m >= CONTEST_AT and m < CONTEST_END and stage == St.GATHER and not _done_today.has("contest"):
		_done_today.contest = true
		stage = St.CONTEST
		_contest = {}
		_say("Конкурс! Кто больше выпьет за столом — тому приз 800 рублей!" if k == K.WEDDING else "Ну, по нашему обычаю… кто больше помянет — тому от вдовы 800 рублей")
	if m >= CONTEST_END and stage == St.CONTEST:
		_contest_result()
		stage = St.GATHER
	if m >= BOUQUET_AT and not _done_today.has("bouquet"):
		_done_today.bouquet = true
		if k == K.WEDDING:
			_throw_bouquet()
		else:
			_kutya()
	if m >= BRAWL_AT and not _done_today.has("brawl"):
		_done_today.brawl = true
		stage = St.BRAWL
		_say("Ты меня уважаешь?! А ты?!" if k == K.WEDDING else "Это ты деда обидел?! А ну иди сюда!")
		_announce("В клубе «Огонёк» началась драка! Как положено")
		for b in get_tree().get_nodes_in_group("brawlers"):
			b.start_brawl()


func _finish() -> void:
	kind = K.NONE
	stage = St.IDLE
	for b in get_tree().get_nodes_in_group("brawlers"):
		b.stop_brawl()
	_announce("Гулянка в клубе закончилась. Гости расходятся")


func _players_near(r: float) -> Array:
	var out := []
	for p in get_tree().get_nodes_in_group("players"):
		if (p as Node3D).global_position.distance_to(global_position) < r:
			out.append(p)
	return out


func _contest_result() -> void:
	var best := 0
	var best_n := 0
	for peer in _contest:
		if int(_contest[peer]) > best_n:
			best_n = int(_contest[peer])
			best = int(peer)
	var p := get_tree().get_root().get_node_or_null("World/Players/%d" % best)
	if p == null or best_n < 2:
		_say("Слабаки… Никто не выпил! Приз остаётся у меня")
		return
	_say("Победитель — %s! Выпил %d! Вот это человек!" % [p.player_name, best_n])
	NetUtil.call_peer(self, best, "prize", [800, "за победу в конкурсе"])


func _throw_bouquet() -> void:
	var near := _players_near(14.0)
	if near.is_empty():
		_say("Букет! …ну и поймать некому. Эх")
		return
	var p: Node = near.pick_random()
	_say("Невеста бросает букет… и его ловит %s!" % p.player_name)
	NetUtil.call_peer(self, p.name.to_int(), "prize", [500, "поймал букет невесты. Следующая свадьба — твоя"])


func _kutya() -> void:
	var near := _players_near(16.0)
	_say("Берите кутью, блины… поминайте")
	for p in near:
		NetUtil.call_peer(self, p.name.to_int(), "treat", [])


@rpc("authority", "reliable")
func prize(amount: int, why: String) -> void:
	Inventory.money += amount
	Inventory.changed.emit()
	Sfx.play("cheer")
	Events.notify("+%d ₽ — %s!" % [amount, why], Color.GOLD)


@rpc("authority", "reliable")
func treat() -> void:
	Inventory.add_item("food", &"cheburek", 1, false)
	Inventory.satiety = minf(Inventory.satiety + 30.0, 100.0)
	Inventory.changed.emit()
	Events.notify("Поел кутьи и блинов. Дали пирожок с собой", Color(0.9, 0.85, 0.7))


func _announce(text: String) -> void:
	NetUtil.call_all(self, "announce", [text])


@rpc("authority", "call_remote", "reliable")
func announce(text: String) -> void:
	Events.notify(text, Color(1.0, 0.8, 0.5))


func _say(text: String) -> void:
	NetUtil.call_all(self, "say", [text])


@rpc("authority", "call_remote", "reliable")
func say(text: String) -> void:
	_speech.text = text
	_speech.modulate.a = 1.0
	Sfx.say(_tamada.global_position + Vector3.UP * 1.6, "f", text)


# ------------------------------------------------------------ наливают

func pour(_p: Node) -> void:
	NetUtil.call_server(self, "srv_pour", [])


@rpc("any_peer", "reliable")
func srv_pour() -> void:
	if not multiplayer.is_server():
		return
	var peer := NetUtil.sender(self)
	if kind == K.NONE:
		return
	var n := int(_pours.get(peer, 0))
	if n >= FREE_POURS:
		NetUtil.call_peer(self, peer, "no_more", [])
		return
	_pours[peer] = n + 1
	if stage == St.CONTEST:
		_contest[peer] = int(_contest.get(peer, 0)) + 1
	var p := get_tree().get_root().get_node_or_null("World/Players/%d" % peer)
	var drink := &"champagne" if kind == K.WEDDING and n % 3 == 0 else &"vodka"
	if p:
		NetUtil.call_peer(p, peer, "receive_drink", [drink, "Тамада"])
	NetUtil.call_peer(self, peer, "poured", [FREE_POURS - n - 1])


@rpc("authority", "reliable")
func poured(left: int) -> void:
	Inventory.stat_add("party_drinks")
	Sfx.play("bottle_clink", null, -6.0)
	if left == 0:
		Events.notify("Тамада: «Тебе хватит, родной»", Color(1, 0.85, 0.6))


@rpc("authority", "reliable")
func no_more() -> void:
	Events.notify("Тамада: «Всё-всё, тебе больше не наливаем!»", Color(1, 0.7, 0.5))


# ------------------------------------------------------------ вид (у всех)

func _visuals(delta: float) -> void:
	var on := kind != K.NONE
	for g in _guests:
		g.visible = on
	_bride.visible = kind == K.WEDDING
	_groom.visible = kind == K.WEDDING
	_portrait.visible = kind == K.FUNERAL
	_tamada.visible = on
	_speech.modulate.a = maxf(_speech.modulate.a - delta * 0.15, 0.0)
	if on:
		for i in _guests.size():
			var g := _guests[i]
			if kind == K.WEDDING and i % 2 == 0:
				g.pose = "idle"
				g.position.y = absf(sin(_t * 4.0 + i)) * 0.12   # пляшут
				g.rotation.y += delta * (1.5 if i % 4 == 0 else -1.2)
			else:
				g.position.y = 0.0
				g.pose = "drink" if fmod(_t + i * 1.7, 9.0) < 1.2 else "talk"
		_tamada.pose = "talk" if _speech.modulate.a > 0.3 else "idle"
	if _music_kind != kind:
		_music_kind = kind
		if kind == K.NONE:
			_music.stop()
		else:
			_music.stream = Sfx.stream_of("wedding_music" if kind == K.WEDDING else "funeral_music")
			_music.play()
	if Engine.get_process_frames() % 60 == 0:
		var dc := get_tree().get_first_node_in_group("day_cycle") as DayCycle
		if dc:
			_board.text = "ОБЪЯВЛЕНИЕ\n" + next_party_text(dc.day) + "\nВход свободный"


class _Table:
	extends Node
	var club: Node

	func _init(c: Node) -> void:
		club = c

	func get_prompt(_p: Node) -> String:
		if club.kind == Club.K.NONE:
			return "Пустой стол. Гулянка — по объявлению на доске"
		return "Налить (бесплатно) — %s" % ("конкурс идёт!" if club.stage == Club.St.CONTEST else "за молодых!" if club.kind == Club.K.WEDDING else "помянуть")

	func interact(p: Node) -> void:
		if club.kind != Club.K.NONE:
			club.pour(p)
