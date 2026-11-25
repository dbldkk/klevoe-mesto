class_name NeonClub
extends Node3D
## Заведение на окраине: неон, пилон, бар, вышибала. Без откровенной наготы —
## бельё / купальники, танец процедурный, приват — затемнение за деньги.

const COVER := 200
const MAX_DRUNK := 75.0
const TIP := 50
const PRIVATE := 400

var _inside := false
var _dancers: Array[CharacterModel] = []
var _t := 0.0
var _fade: ColorRect
var _private_t := 0.0


## Пусто — можно войти; "money" / "drunk" — причина отказа (для тестов и вышибалы).
static func entry_reason(money: int, drunk: float) -> String:
	if drunk >= MAX_DRUNK:
		return "drunk"
	if money < COVER:
		return "money"
	return ""


func _ready() -> void:
	transform = Layout.xform("strip_club")
	add_to_group("poi")
	set_meta("poi_name", "Клуб «Неон»")
	var st := Node3D.new()
	st.name = "Static"
	add_child(st)
	_build(st)
	_spawn_people()
	_make_fade()


func _build(st: Node3D) -> void:
	var wall := Art.color(Color(0.12, 0.06, 0.14), 0.9)
	var floor := Art.color(Color(0.08, 0.07, 0.09), 0.7)
	var velvet := Art.color(Color(0.35, 0.05, 0.12), 0.85)
	var gold := Art.color(Color(0.75, 0.6, 0.2), 0.4, 0.5)
	# коробка: вход с +Z (к дороге)
	Build.block(st, Vector3(0, 0.02, 0), Vector3(12.0, 0.05, 10.0), floor, false)
	Build.block(st, Vector3(0, 3.2, -5.0), Vector3(12.2, 3.2, 0.2), wall, true)
	Build.block(st, Vector3(-6.05, 3.2, 0), Vector3(0.2, 3.2, 10.0), wall, true)
	Build.block(st, Vector3(6.05, 3.2, 0), Vector3(0.2, 3.2, 10.0), wall, true)
	Build.block(st, Vector3(0, 3.2, 5.0), Vector3(12.2, 3.2, 0.2), wall, true)
	Build.block(st, Vector3(0, 4.85, 0), Vector3(12.4, 0.15, 10.4), Art.color(Color(0.08, 0.05, 0.1)), false)
	# дверь
	Build.block(st, Vector3(0, 1.3, 5.05), Vector3(1.6, 2.5, 0.12), Art.color(Color(0.15, 0.08, 0.18)), true)
	# сцена и пилон
	Build.block(st, Vector3(0, 0.35, -2.8), Vector3(5.2, 0.7, 3.2), velvet, true)
	Art.add_mesh(st, Art.cyl(0.04, 0.04, 3.4, 10), gold, Vector3(0, 2.4, -2.8))
	# бар слева
	Build.block(st, Vector3(-4.4, 0.55, 1.2), Vector3(2.4, 1.1, 3.6), Art.color(Color(0.18, 0.1, 0.08), 0.7), true)
	# диванчики
	for x in [3.6, 4.6]:
		Build.block(st, Vector3(x, 0.35, 0.6), Vector3(1.2, 0.7, 2.2), velvet, true)
	# неон
	_neon(st, Vector3(0, 3.6, 5.12), "НЕОН", Color(1.0, 0.25, 0.7))
	_neon(st, Vector3(0, 3.8, -4.85), "SHOW", Color(0.3, 0.8, 1.0))
	var pink := OmniLight3D.new()
	pink.light_color = Color(1.0, 0.3, 0.7)
	pink.light_energy = 2.4
	pink.omni_range = 10.0
	pink.position = Vector3(0, 3.2, 0)
	st.add_child(pink)
	var cyan := OmniLight3D.new()
	cyan.light_color = Color(0.3, 0.7, 1.0)
	cyan.light_energy = 1.6
	cyan.omni_range = 8.0
	cyan.position = Vector3(0, 2.6, -2.6)
	st.add_child(cyan)
	var music := AudioStreamPlayer3D.new()
	music.stream = Sfx.stream_of("club_music")
	music.bus = "Music"
	music.unit_size = 9.0
	music.max_distance = 40.0
	music.volume_db = -8.0
	music.position = Vector3(0, 1.5, -1.0)
	st.add_child(music)
	if music.stream:
		music.play()
	Build.board_sign(self, Vector3(0, 0.0, 5.6), "КЛУБ «НЕОН» · 200 ₽", 0.0, Vector2(1.4, 0.36), 2.5)


func _neon(st: Node3D, pos: Vector3, txt: String, col: Color) -> void:
	var lbl := Build.text(st, pos, txt, 48, col, 0.012)
	# лёгкое свечение надписью
	if lbl:
		lbl.modulate = col


func _lingerie(m: CharacterModel) -> void:
	# Бельё = короткий топ + короткие шорты, без анатомической наготы.
	m.outfit = 0
	m.stripes = false
	m.hat = CharacterModel.Hat.NONE
	m.shirt = Color(0.75, 0.35, 0.55)
	m.pants = Color(0.15, 0.08, 0.12)
	m.skin = CharacterModel.SKINS[0]
	m.fat = false
	# чуть короче штаны: используем тот же меш, тёмный, как «шортики» за счёт цвета + компакт
	m.height_scale = 1.0
	m.restyle()
	# визуально «топ»: уже есть рубашка; для танцовщиц перекрашиваем торс плотнее через restyle default
	# Дополнительно — не расстёгиваем и не оголяем (outfit 0).


func _spawn_people() -> void:
	# вышибала у двери
	var b := CharacterModel.new()
	b.name = "Bouncer"
	b.position = Vector3(1.4, 0, 4.4)
	b.rotation.y = PI
	b.shirt = Color(0.08, 0.08, 0.1)
	b.pants = Color(0.1, 0.1, 0.12)
	b.hat = CharacterModel.Hat.BALD
	b.height_scale = 1.12
	add_child(b)
	Build.talk_area(self, Vector3(0, 1.2, 5.3), Vector3(2.4, 2.4, 1.8), self)

	for i in 3:
		var d := CharacterModel.new()
		d.name = "Dancer%d" % i
		d.position = Vector3(-1.4 + i * 1.4, 0.7, -2.8)
		d.rotation.y = PI
		_lingerie(d)
		# более короткий силуэт: после restyle ничего анатомического не добавляем
		add_child(d)
		_dancers.append(d)
		var tip := _Tip.new()
		tip.club = self
		tip.kind = "tip"
		tip.position = d.position + Vector3(0, 0, 0.8)
		add_child(tip)
	var priv := _Tip.new()
	priv.club = self
	priv.kind = "private"
	priv.position = Vector3(0, 1.0, -1.4)
	add_child(priv)

	# бармен
	var bar := CharacterModel.new()
	bar.position = Vector3(-4.2, 0, 1.2)
	bar.rotation.y = PI / 2
	bar.shirt = Color(0.15, 0.1, 0.18)
	bar.pants = Color(0.1, 0.1, 0.1)
	bar.hat = CharacterModel.Hat.NONE
	add_child(bar)


func _process(delta: float) -> void:
	_t += delta
	for i in _dancers.size():
		var d := _dancers[i]
		if d == null or not is_instance_valid(d):
			continue
		var phase := _t * (1.6 + i * 0.25) + i
		d.rotation.y = PI + sin(phase) * 0.5
		d.position.y = 0.7 + absf(sin(phase * 2.0)) * 0.08
		if d.spine:
			d.spine.rotation.z = sin(phase * 1.3) * 0.2
			d.spine.rotation.x = sin(phase * 0.8) * 0.08
	if _private_t > 0.0:
		_private_t -= delta
		if _fade:
			var a := 1.0 if _private_t > 0.6 else clampf(_private_t / 0.6, 0.0, 1.0)
			_fade.color.a = a
			_fade.visible = a > 0.02
		if _private_t <= 0.0:
			_fade.visible = false
			Events.notify("Шоу окончено. Чаевые уже в кассе.", Color(0.95, 0.7, 0.85))


func _make_fade() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.visible = false
	layer.add_child(_fade)


func get_prompt(_player: Node) -> String:
	if _inside:
		return "Выйти из «Неона»"
	var why := entry_reason(Inventory.money, Inventory.drunk)
	if why == "drunk":
		return "Вышибала: «Ой, братан, ты слишком весёлый»"
	if why == "money":
		return "Вход %d ₽ — не хватает" % COVER
	return "Войти в «Неон» (%d ₽)" % COVER


func interact(player: Node) -> void:
	if _inside:
		_inside = false
		if player is Node3D:
			(player as Node3D).global_position = to_global(Vector3(0, 0.2, 6.4))
		Events.notify("Ну, заходи ещё.", Color(0.9, 0.75, 0.85))
		return
	var why := entry_reason(Inventory.money, Inventory.drunk)
	if why == "drunk":
		Events.notify("Вышибала качает головой: «Проспись и приходи.»", Color(0.9, 0.6, 0.5))
		return
	if why == "money":
		Events.notify("Вход %d ₽. У тебя не хватает." % COVER, Color.TOMATO)
		return
	Inventory.money -= COVER
	Inventory.changed.emit()
	_inside = true
	if player is Node3D:
		(player as Node3D).global_position = to_global(Vector3(0, 0.2, 3.2))
	Events.notify("Добро пожаловать в «Неон». Чаевые — у сцены, приват — ближе к пилону.", Color(1.0, 0.55, 0.8))
	Sfx.play("cash", global_position, -8.0)


func tip() -> bool:
	if Inventory.money < TIP:
		Events.notify("На чай не хватает (%d ₽)" % TIP, Color.TOMATO)
		return false
	Inventory.money -= TIP
	Inventory.changed.emit()
	Events.notify("Танцовщица улыбается и кланяется.", Color(1.0, 0.7, 0.85))
	Sfx.play("coin", global_position, -8.0)
	return true


func _private_dance(player: Node) -> void:
	if Inventory.money < PRIVATE:
		Events.notify("Приват — %d ₽. Не хватает." % PRIVATE, Color.TOMATO)
		return
	Inventory.money -= PRIVATE
	Inventory.changed.emit()
	_private_t = 4.0
	if _fade:
		_fade.visible = true
		_fade.color = Color(0, 0, 0, 1)
	Events.notify("Свет гаснет. Дальше — только музыка.", Color(0.8, 0.8, 0.85))


class _Tip extends Area3D:
	var club: Node
	var kind := "tip"

	func _ready() -> void:
		collision_layer = 16
		collision_mask = 0
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(1.2, 2.0, 1.0) if kind == "tip" else Vector3(2.4, 2.2, 1.6)
		cs.shape = sh
		add_child(cs)

	func get_prompt(_player: Node) -> String:
		if kind == "private":
			return "Заказать приватный танец (%d ₽)" % PRIVATE
		return "Дать на чай (%d ₽)" % TIP

	func interact(player: Node) -> void:
		if club == null:
			return
		if kind == "private" and club.has_method("_private_dance"):
			club._private_dance(player)
		elif club.has_method("tip"):
			club.tip()
