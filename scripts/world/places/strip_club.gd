class_name NeonClub
extends Node3D
## Заведение на окраине: неон, пилон, бар, вышибала. Без откровенной наготы —
## бельё / купальники, танец процедурный, приват — затемнение за деньги.

const COVER := 200
const MAX_DRUNK := 75.0
const TIP := 50
const TIP_AMOUNTS := [50, 100, 500]
const PRIVATE := 400
## Верх бархатной сцены (центр блока 0.35, высота 0.7). Ноги персонажа — в начале координат модели.
const STAGE_TOP := 0.7

var _inside := false
var _bouncer: CharacterModel
var _dancers: Array[CharacterModel] = []
var _t := 0.0
var _fade: ColorRect
var _private_t := 0.0
var _flourish: Array[float] = []
var _notes: Array[CPUParticles3D] = []
var _dancer_ids: Array[String] = []
var _dancer_names: Array[String] = []
var _dancer_pole: Array[bool] = []
var _home: Array[Vector3] = []
var _tip_ui: CanvasLayer
var _tip_title: Label
var _tip_status: Label
var _tip_idx := -1


## Пусто — можно войти; "money" / "drunk" — причина отказа (для тестов и вышибалы).
static func entry_reason(money: int, drunk: float) -> String:
	if drunk >= MAX_DRUNK:
		return "drunk"
	if money < COVER:
		return "money"
	return ""


func _ready() -> void:
	transform = Layout.xform("strip_club")
	var s: Array = Layout.SPOTS["strip_club"]
	Layout.snap_to_ground(self, float(s[2]), float(s[3]))
	add_to_group("poi")
	set_meta("poi_name", "Клуб «Неон»")
	set_meta("poi_spot", "strip_club")
	var st := Node3D.new()
	st.name = "Static"
	add_child(st)
	_build(st)
	_spawn_people()
	_make_fade()
	_make_tip_ui()


func _build(st: Node3D) -> void:
	var wall := Art.color(Color(0.12, 0.06, 0.14), 0.9)
	var floor := Art.color(Color(0.08, 0.07, 0.09), 0.7)
	var velvet := Art.color(Color(0.35, 0.05, 0.12), 0.85)
	var gold := Art.color(Color(0.75, 0.6, 0.2), 0.4, 0.5)
	# коробка стоит на земле: стены от пола до крыши (центр = половина высоты).
	# Фундамент уходит в грунт, чтобы край площадки не просвечивал.
	var found := Art.color(Color(0.18, 0.12, 0.14), 0.95)
	Build.block(st, Vector3(0, -0.55, 0), Vector3(12.6, 1.1, 10.6), found, true)
	Build.block(st, Vector3(0, 0.04, 0), Vector3(12.0, 0.08, 10.0), floor, true)
	# стены 0..4.8 м
	Build.block(st, Vector3(0, 2.4, -5.0), Vector3(12.2, 4.8, 0.2), wall, true)
	Build.block(st, Vector3(-6.05, 2.4, 0), Vector3(0.2, 4.8, 10.0), wall, true)
	Build.block(st, Vector3(6.05, 2.4, 0), Vector3(0.2, 4.8, 10.0), wall, true)
	# фасад с проёмом для входа (2 м шириной, 2.5 м высотой) — без коллизии в проходе
	Build.block(st, Vector3(-3.55, 2.4, 5.0), Vector3(5.1, 4.8, 0.2), wall, true)
	Build.block(st, Vector3(3.55, 2.4, 5.0), Vector3(5.1, 4.8, 0.2), wall, true)
	Build.block(st, Vector3(0, 3.65, 5.0), Vector3(2.1, 2.3, 0.2), wall, true)  # перемычка
	Build.block(st, Vector3(0, 4.85, 0), Vector3(12.4, 0.15, 10.4), Art.color(Color(0.08, 0.05, 0.1)), false)
	# открытая дверь сбоку, не перекрывает проход
	Build.block(st, Vector3(1.15, 1.25, 5.55), Vector3(0.08, 2.5, 1.0), Art.color(Color(0.15, 0.08, 0.18)), true, Vector3(0, 0.6, 0))
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
	Build.board_sign(self, Vector3(0, 0.0, 5.6), "КЛУБ «НЕОН» · 200 ₽", 0.0, Vector2(1.4, 0.36), 2.5)


func _neon(st: Node3D, pos: Vector3, txt: String, col: Color) -> void:
	var lbl := Build.text(st, pos, txt, 48, col, 0.012)
	# лёгкое свечение надписью
	if lbl:
		lbl.modulate = col


func _dress_dancer(m: CharacterModel, def: Dictionary) -> void:
	m.female = true
	m.lingerie = int(def["lingerie"])
	m.stockings = bool(def["stockings"])
	m.outfit = 0
	m.stripes = false
	m.hat = CharacterModel.Hat.NONE
	m.face_name = String(def["face"])
	m.hair_color = def["hair"]
	m.skin = CharacterModel.SKINS[int(def["skin"])]
	m.fat = false
	m.height_scale = float(def.get("height", 1.0))
	# иначе CharacterModel каждый кадр тянет y к 0 и девушки проваливаются в помост
	m.settle_floor = false


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
	_bouncer = b
	Chatter.attach.call_deferred(b, "m_low", SpeechBank.bouncer(), 2.5, 5.0, "bouncer")
	Build.talk_area(self, Vector3(0, 1.2, 5.3), Vector3(2.4, 2.4, 1.8), self)

	# три танцовщицы: женская фигура, длинные волосы, бельё разных цветов
	var defs: Array = [
		{"id": "alina", "name": "Алина", "face": "dancer_a", "hair": Color(0.08, 0.05, 0.04),
			"skin": 0, "lingerie": 1, "stockings": true, "pole": true, "height": 1.02,
			"pos": Vector3(0.0, STAGE_TOP, -2.8)},
		{"id": "katya", "name": "Катя", "face": "dancer_b", "hair": Color(0.38, 0.16, 0.08),
			"skin": 1, "lingerie": 2, "stockings": true, "pole": false, "height": 0.98,
			"pos": Vector3(-1.6, STAGE_TOP, -2.5)},
		{"id": "nika", "name": "Ника", "face": "dancer_c", "hair": Color(0.55, 0.42, 0.22),
			"skin": 0, "lingerie": 3, "stockings": false, "pole": false, "height": 1.0,
			"pos": Vector3(1.6, STAGE_TOP, -2.2)},
	]
	for def in defs:
		var d := CharacterModel.new()
		d.name = "Dancer_%s" % def["id"]
		_dress_dancer(d, def)
		d.position = def["pos"]
		d.rotation.y = PI
		add_child(d)
		_dancers.append(d)
		_dancer_ids.append(String(def["id"]))
		_dancer_names.append(String(def["name"]))
		_dancer_pole.append(bool(def["pole"]))
		_home.append(def["pos"])
		_flourish.append(0.0)
		_notes.append(_make_notes(d))
		var lbl := Label3D.new()
		lbl.text = String(def["name"])
		lbl.font_size = 32
		lbl.pixel_size = 0.006
		lbl.position = Vector3(0, 2.15, 0)
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.modulate = Color(1.0, 0.75, 0.88)
		d.add_child(lbl)
		var tip := _Tip.new()
		tip.club = self
		tip.kind = "tip"
		tip.dancer_idx = _dancers.size() - 1
		tip.position = d.position + Vector3(0, 0.8, 0.85)
		add_child(tip)
	var priv := _Tip.new()
	priv.club = self
	priv.kind = "private"
	priv.position = Vector3(2.9, 1.0, -1.5)
	add_child(priv)

	var bar_service := _Bar.new()
	bar_service.name = "BarService"
	add_child(bar_service)
	Build.talk_area(self,Vector3(-2.9,1.1,1.2),Vector3(1.4,1.7,2.8),bar_service)
	# бармен
	var bar := CharacterModel.new()
	bar.position = Vector3(-4.2, 0, 1.2)
	bar.rotation.y = PI / 2
	bar.shirt = Color(0.15, 0.1, 0.18)
	bar.pants = Color(0.1, 0.1, 0.1)
	bar.hat = CharacterModel.Hat.NONE
	add_child(bar)


func _make_notes(at: Node3D) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.92
	p.amount = 18
	p.lifetime = 1.5
	p.position = Vector3(0, 1.2, 0)
	p.direction = Vector3(0, 1, 0)
	p.spread = 55.0
	p.initial_velocity_min = 1.4
	p.initial_velocity_max = 3.2
	p.gravity = Vector3(0, -4.5, 0)
	p.angular_velocity_min = -8.0
	p.angular_velocity_max = 8.0
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.12, 0.002, 0.06)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.62, 0.28)
	mat.roughness = 0.7
	mesh.material = mat
	p.mesh = mesh
	at.add_child(p)
	return p


func _process(delta: float) -> void:
	if not Net.is_online():
		return
	var local := get_tree().get_first_node_in_group("local_player") as Node3D
	if local and local.global_position.distance_to(global_position)>50 and _private_t<=0:
		return
	_t += delta
	for i in _dancers.size():
		var d := _dancers[i]
		if d == null or not is_instance_valid(d):
			continue
		var phase := _t * (1.6 + i * 0.25) + i
		var bounce := absf(sin(phase * 2.0)) * 0.08
		if i < _flourish.size() and _flourish[i] > 0.0:
			bounce += absf(sin(_t * 10.0)) * 0.06
		if _dancer_pole[i]:
			# танец у пилона: кружение вокруг шеста, ноги на верхней кромке сцены
			var spin := _t * 1.35
			var r := 0.22
			d.position = Vector3(sin(spin) * r, STAGE_TOP + bounce, _home[i].z + cos(spin) * r)
			d.rotation.y = spin + PI * 0.5
		else:
			d.rotation.y = PI + sin(phase) * 0.55
			d.position.x = _home[i].x
			d.position.z = _home[i].z
			d.position.y = STAGE_TOP + bounce
		if d.spine:
			d.spine.rotation.z = sin(phase * 1.3) * 0.22
			d.spine.rotation.x = sin(phase * 0.8) * 0.1
		if i < _flourish.size() and _flourish[i] > 0.0:
			_flourish[i] -= delta
			d.rotation.y += delta * 7.0
			if d.spine:
				d.spine.rotation.x += sin(_t * 10.0) * 0.18
			if d.arm_r:
				d.arm_r.rotation.x = -1.2 + sin(_t * 8.0) * 0.3
	if _private_t > 0.0:
		_private_t -= delta
		if _fade:
			var a := 1.0 if _private_t > 0.6 else clampf(_private_t / 0.6, 0.0, 1.0)
			_fade.color.a = a
			_fade.visible = a > 0.02
		if _private_t <= 0.0:
			_fade.visible = false
			Events.ui_open = Sfx.menus_block_voice()
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


func _make_tip_ui() -> void:
	_tip_ui = CanvasLayer.new()
	_tip_ui.layer = 8
	_tip_ui.visible = false
	add_child(_tip_ui)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tip_ui.add_child(dim)
	var panel := UiKit.panel(Vector2(420, 0), Color(0.1, 0.07, 0.1, 0.95))
	_tip_ui.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	v.add_child(UiKit.title("ЧАЕВЫЕ", Color(1.0, 0.55, 0.8)))
	_tip_title = UiKit.label("", 20, Color(1, 0.9, 0.95))
	_tip_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_tip_title)
	_tip_status = UiKit.label("", 16, Color(1, 1, 1, 0.7))
	_tip_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_tip_status)
	for amt in TIP_AMOUNTS:
		v.add_child(UiKit.button("Дать %d ₽" % amt, _confirm_tip.bind(amt)))
	v.add_child(UiKit.button("Отмена", _close_tip_ui))


func _open_tip(idx: int) -> void:
	if idx < 0 or idx >= _dancer_names.size():
		return
	_tip_idx = idx
	_tip_title.text = "Дать денег %s" % _dancer_names[idx]
	_tip_status.text = "У тебя %d ₽" % Inventory.money
	_tip_ui.visible = true
	Events.ui_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _close_tip_ui() -> void:
	if _tip_ui == null or not _tip_ui.visible:
		return
	_tip_ui.visible = false
	_tip_idx = -1
	Events.ui_open = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var p := get_tree().get_first_node_in_group("local_player")
	if p:
		p.input_cooldown = 0.3


func _unhandled_input(event: InputEvent) -> void:
	if _tip_ui and _tip_ui.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close_tip_ui()


func _confirm_tip(amount: int) -> void:
	if _tip_idx < 0:
		return
	if Inventory.money < amount:
		Events.notify("На чай не хватает (%d ₽)" % amount, Color.TOMATO)
		_tip_status.text = "Не хватает. У тебя %d ₽" % Inventory.money
		return
	Inventory.money -= amount
	Inventory.changed.emit()
	var idx := _tip_idx
	_close_tip_ui()
	Sfx.play("coin", global_position, -8.0)
	NetUtil.call_all(self, "tip_fx", [idx, amount])


func get_prompt(player: Node) -> String:
	if _is_inside(player):
		return "Выйти из «Неона»"
	var why := entry_reason(Inventory.money, Inventory.drunk)
	if why == "drunk":
		return "Вышибала: «Ой, братан, ты слишком весёлый»"
	if why == "money":
		return "Вход %d ₽ — не хватает" % COVER
	return "Войти в «Неон» (%d ₽)" % COVER


func interact(player: Node) -> void:
	if _is_inside(player):
		_inside = false
		if player is Node3D:
			(player as Node3D).global_position = to_global(Vector3(0, 0.2, 6.4))
		_bounce_say("Ну, заходи ещё.")
		Events.notify("Ну, заходи ещё.", Color(0.9, 0.75, 0.85))
		return
	var why := entry_reason(Inventory.money, Inventory.drunk)
	if why == "drunk":
		_bounce_say("Ой, братан, ты слишком весёлый. Проспись и приходи.")
		Events.notify("Вышибала качает головой: «Проспись и приходи.»", Color(0.9, 0.6, 0.5))
		return
	if why == "money":
		_bounce_say("Вход двести рублей. Без денег и без скандала, тогда милости прошу.")
		Events.notify("Вход %d ₽. У тебя не хватает." % COVER, Color.TOMATO)
		return
	Inventory.money -= COVER
	Inventory.changed.emit()
	_inside = true
	if player is Node3D:
		(player as Node3D).global_position = to_global(Vector3(0, 0.2, 3.2))
	_bounce_say("Добро пожаловать в «Неон». Чаевые — у сцены, приват — ближе к пилону.")
	Events.notify("Добро пожаловать в «Неон». Чаевые — у сцены, приват — ближе к пилону.", Color(1.0, 0.55, 0.8))
	Sfx.play("cash", global_position, -8.0)


func _bounce_say(text: String) -> void:
	var pos := global_position + Vector3(1.4, 1.7, 4.4)
	if _bouncer and is_instance_valid(_bouncer):
		pos = _bouncer.global_position + Vector3(0, 1.7, 0)
	Sfx.say(pos, "m_low", text, "bouncer")


func tip() -> bool:
	# совместимость со старым вызовом «50 ₽»
	if _dancers.is_empty():
		return false
	_open_tip(0)
	return true


func tip_dancer(idx: int) -> void:
	_open_tip(idx)


@rpc("any_peer", "reliable")
func tip_fx(idx: int, amount: int) -> void:
	if idx < 0 or idx >= _dancers.size():
		return
	if idx < _flourish.size():
		_flourish[idx] = 2.2
	if idx < _notes.size() and _notes[idx]:
		_notes[idx].restart()
		_notes[idx].emitting = true
	var nm := _dancer_names[idx] if idx < _dancer_names.size() else "Танцовщица"
	var line := _tip_line(idx, amount)
	Events.notify("%s: «%s»" % [nm, line], Color(1.0, 0.7, 0.85), false)
	var d := _dancers[idx]
	var pos := d.global_position + Vector3(0, 1.7, 0)
	var speaker := _dancer_ids[idx] if idx < _dancer_ids.size() else "alina"
	Sfx.say(pos, "f_high", line, speaker)


func _tip_line(idx: int, amount: int) -> String:
	var id := _dancer_ids[idx] if idx < _dancer_ids.size() else "alina"
	var bank: Array = SpeechBank.alina()
	if id == "katya":
		bank = SpeechBank.katya()
	elif id == "nika":
		bank = SpeechBank.nika()
	if bank.is_empty():
		return "Спасибо, дорогой."
	# щедрые чаевые — вторая реплика
	return String(bank[1] if amount >= 100 and bank.size() > 1 else bank[0])


func _private_dance(player: Node) -> void:
	if _private_t > 0 or not _is_inside(player):
		return
	if Inventory.money < PRIVATE:
		Events.notify("Приват — %d ₽. Не хватает." % PRIVATE, Color.TOMATO)
		return
	Inventory.money -= PRIVATE
	Inventory.changed.emit()
	if _private_t > 0:
		return
	Events.ui_open = true
	player.fishing.cancel()
	_private_t = 4.0
	if _fade:
		_fade.visible = true
		_fade.color = Color(0, 0, 0, 1)
	Events.notify("Свет гаснет. Дальше — только музыка.", Color(0.8, 0.8, 0.85))


class _Tip extends Interactable:
	var club: Node
	var kind := "tip"
	var dancer_idx := -1

	func _ready() -> void:
		collision_layer = 16
		collision_mask = 0
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(1.2, 2.0, 1.0) if kind == "tip" else Vector3(0.8, 2.0, 0.7)
		cs.shape = sh
		add_child(cs)

	func get_prompt(_player: Node) -> String:
		if kind == "private":
			return "Заказать приватный танец (%d ₽)" % PRIVATE
		var nm := "танцовщице"
		if club and dancer_idx >= 0 and club.get("_dancer_names") and dancer_idx < club._dancer_names.size():
			nm = club._dancer_names[dancer_idx]
		return "Дать денег %s (50 / 100 / 500 ₽)" % nm

	func interact(player: Node) -> void:
		if club == null or not club._is_inside(player):
			return
		if kind == "private" and club.has_method("_private_dance"):
			club._private_dance(player)
		elif club.has_method("tip_dancer"):
			club.tip_dancer(dancer_idx)


func _is_inside(player: Node3D) -> bool:
	var p := to_local(player.global_position)
	return absf(p.x)<5.9 and p.z>-4.9 and p.z<4.8 and p.y>-0.5 and p.y<4.8


class _Bar extends Node:
	const GOODS := [["drink",&"beer"],["drink",&"wine"],["drink",&"champagne"],["food",&"crackers"]]
	func store_title() -> String:
		return "БАР «НЕОН»"
	func seller_name() -> String:
		return "Бармен Слава"
	func greeting() -> String:
		return "Меню короткое. Истории после третьего бокала — длинные."
	func price_of(kind: String,id: StringName) -> int:
		return roundi(GameData.item_price(kind,id)*1.15)
	func get_prompt(_p: Node) -> String:
		return "Бар «Неон»: напитки и закуска"
	func interact(p: Node) -> void:
		if get_parent()._is_inside(p):
			var ui := get_tree().get_first_node_in_group("store_ui")
			if ui:
				ui.open(self)
