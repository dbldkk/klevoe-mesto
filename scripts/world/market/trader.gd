class_name Trader
extends Node3D
## Дядя Толя — скупает рыбу на рынке.
##
## С ним можно торговаться. Он соглашается охотнее, если:
##  * он пьян (подарки-выпивку он выпивает сразу),
##  * у него хорошее настроение (подарки, удачные сделки),
##  * он лоялен лично к тебе (подарки ему; бутылка в голову — сильно портит).
## Состояние живёт на хосте и сохраняется вместе с миром.

const SOBER_PER_SEC := 0.12
const SLEEP_TIME := 60.0
const ANGRY_TIME := 40.0

@export var drunk: float = 0.0
@export var mood: float = 0.0          ## -50..50, общее настроение
@export var asleep_time: float = 0.0
@export var angry_time: float = 0.0
@export var strikes: int = 0           ## отказов подряд
## Пьёт подаренное прямо сейчас (для анимации у всех).
@export var drink_anim: float = 0.0
@export var drink_id: StringName = &""
@export var hurt_time: float = 0.0

## Только на сервере: id профиля -> лояльность (-100..100)
var loyalty: Dictionary = {}

@onready var visual: CharacterModel = $Visual
@onready var label: Label3D = $Status

var _t := 0.0
var _talking := 0.0
var _shown_drink: StringName = &"-"


func display_name() -> String:
	return "Дядя Толя"


## Поговорил — немного жестикулирует.
func talk_anim() -> void:
	_talking = 2.5


# ------------------------------------------------------------ ремонт удочек

## Сколько стоит починить удочку (цена падает с лояльностью и опьянением).
func repair_cost(rod: RodData, cond: float) -> int:
	var k := rod.price * (0.7 if cond <= 0.0 else 0.5 * (100.0 - cond) / 100.0)
	k *= 1.0 - clampf(Inventory.trader_loyalty, -50.0, 80.0) * 0.004 - drunk * 0.002
	return maxi(30, roundi(k))


## Чинит удочку в ячейке. Пьяный Толя чинит дешевле, но может починить не до конца.
func repair(slot_index: int) -> String:
	var s = Inventory.slot(slot_index)
	if s == null or s.kind != "rod":
		return ""
	var rod := GameData.get_rod(s.id)
	var cost := repair_cost(rod, s.cond)
	if Inventory.money < cost:
		return "Не хватает денег"
	Inventory.money -= cost
	var result := 100.0
	if drunk > 55.0 and randf() < 0.5:
		result = randf_range(55.0, 85.0)
	s.cond = result
	Inventory.changed.emit()
	NetUtil.call_server(self, "srv_deal")
	talk_anim()
	if result < 100.0:
		return "Ик… готово. Ну, почти."
	return "Как новая! С тебя %d ₽." % cost


func _ready() -> void:
	Chatter.attach.call_deferred(self, "m_low", ["Рыбу беру! Свежую — дороже, мятую — дешевле.", "Неси, что поймал, не обижу.",
		"Говорят, на Дальнем плёсе судак пошёл крупный.", "Лещ сегодня в цене, смекаешь?"], 2.4, 5.0)
	add_to_group("trader")
	add_to_group("npc")
	Net.hosted.connect(_load)
	Net.player_registered.connect(func(peer: int, _d: Dictionary) -> void: _push_loyalty(peer))
	Saves.before_save.connect(_save)


func is_available() -> bool:
	return asleep_time <= 0.0 and angry_time <= 0.0


# ------------------------------------------------------------ торг (считается у игрока)

## Сколько он сам предложит от честной цены.
func offer_factor(my_loyalty: float) -> float:
	return clampf(0.6 + drunk * 0.003 + mood * 0.004 + my_loyalty * 0.002, 0.35, 1.1)


## До скольки от честной цены он ещё может согласиться.
func accept_factor(my_loyalty: float) -> float:
	return clampf(0.85 + drunk * 0.009 + mood * 0.006 + my_loyalty * 0.004, 0.5, 2.2)


func status_word() -> String:
	if asleep_time > 0.0:
		return "храпит под прилавком"
	if angry_time > 0.0:
		return "обиделся и не разговаривает"
	return GameData.drunk_word(drunk)


func say() -> String:
	var lines: Array
	if drunk < 15:
		lines = ["Чего надо? Рыбу показывай.", "Цены у меня честные. Почти.", "Не нравится — неси на другой рынок."]
	elif drunk < 45:
		lines = ["О, рыбачок! Ну давай, давай, показывай.", "Хороший сегодня денёк, а?", "Ты заходи, если что."]
	elif drunk < 75:
		lines = ["Ты мне как брат, понимаешь?", "Ик… Почём рыба? Да бери сколько хочешь!", "Давай за рыбалку!"]
	else:
		lines = ["Я тебя… уважаю…", "Ббб… бери всё…", "Где мой прилавок? А, вот он."]
	return lines.pick_random()


# ------------------------------------------------------------ E

func get_prompt(_player: Node) -> String:
	if asleep_time > 0.0:
		return "Дядя Толя храпит…"
	if angry_time > 0.0:
		return "Дядя Толя обиделся"
	return "Поговорить с Дядей Толей"


func interact(_player: Node) -> void:
	if asleep_time > 0.0:
		Events.notify("Хррр… Пшшш…", Color.LIGHT_GRAY)
		return
	if angry_time > 0.0:
		Events.notify("Дядя Толя: «Отстань, сказал!»", Color.TOMATO)
		return
	var me := get_tree().get_first_node_in_group("local_player")
	if me and me.stinky > 0.0:
		Events.notify("Дядя Толя: «Фу-у! От тебя несёт! Иди искупайся в озере!»", Color.ORANGE)
		return
	var ui := get_tree().get_first_node_in_group("trader_ui")
	if ui:
		ui.open(self)


func get_gift_prompt(_player: Node) -> String:
	var d := Inventory.get_drink()
	return "Налить Дяде Толе: %s" % d.display_name if d and asleep_time <= 0.0 else ""


func gift(_player: Node) -> void:
	give_drink()


# ------------------------------------------------------------ подарки и итоги торга (вызывает игрок)

func give_drink() -> bool:
	var d := Inventory.take_drink()
	if d == null:
		return false
	NetUtil.call_server(self, "srv_gift", ["drink", d.strength, d.id])
	Events.notify("Дядя Толя залпом выпил %s" % d.display_name, Color(1, 0.85, 0.5))
	return true


func give_snack(slot_index: int) -> bool:
	var it = Inventory.slot(slot_index)
	if it == null or not GameData.is_edible(it.kind, it.id):
		return false
	Inventory.remove_slot(slot_index)
	NetUtil.call_server(self, "srv_gift", ["snack", 0.0])
	Events.notify("Дядя Толя закусил. Доволен.", Color(1, 0.85, 0.5))
	return true


func give_fish(index: int) -> bool:
	var e := Inventory.remove_fish(index)
	if e.is_empty():
		return false
	var f := GameData.get_fish(e.id)
	NetUtil.call_server(self, "srv_gift", ["fish", 3.0 + f.rarity * 4.0])
	Events.notify("Подарил Дяде Толе: %s" % f.display_name, Color(1, 0.85, 0.5))
	return true


func report_deal() -> void:
	NetUtil.call_server(self, "srv_deal")


func report_refusal() -> void:
	NetUtil.call_server(self, "srv_refusal")


# ------------------------------------------------------------ сервер

@rpc("any_peer", "reliable")
func srv_gift(kind: String, value: float, item: StringName = &"") -> void:
	if not multiplayer.is_server():
		return
	var peer := NetUtil.sender(self)
	match kind:
		"drink":
			drink_id = item
			drink_anim = 2.2
			drunk = minf(drunk + value, 100.0)
			mood = minf(mood + 5.0 + value * 0.2, 50.0)
			_change_loyalty(peer, 4.0 + value * 0.1)
			if drunk >= 100.0:
				asleep_time = SLEEP_TIME
				_announce("Дядя Толя перебрал и уснул под прилавком")
		"snack":
			mood = minf(mood + 4.0, 50.0)
			drunk = maxf(drunk - 8.0, 0.0)
			_change_loyalty(peer, 2.0)
		"fish":
			mood = minf(mood + value, 50.0)
			_change_loyalty(peer, value)
	strikes = maxi(strikes - 1, 0)


@rpc("any_peer", "reliable")
func srv_deal() -> void:
	if not multiplayer.is_server():
		return
	strikes = 0
	mood = minf(mood + 1.0, 50.0)
	_change_loyalty(NetUtil.sender(self), 1.0)


@rpc("any_peer", "reliable")
func srv_refusal() -> void:
	if not multiplayer.is_server():
		return
	strikes += 1
	mood = maxf(mood - 3.0, -50.0)
	_change_loyalty(NetUtil.sender(self), -1.0)
	if strikes >= 3:
		strikes = 0
		angry_time = ANGRY_TIME
		_announce("Дядя Толя обиделся на торгаша")


## Ударили — обида на всю жизнь (почти).
func on_melee_hit(by: int, damage: float) -> void:
	if not multiplayer.is_server():
		return
	mood = maxf(mood - 15.0, -50.0)
	angry_time = 60.0
	hurt_time = 2.0
	_change_loyalty(by, -12.0 - damage * 0.4)
	_announce("Дядя Толя: «Ай! %s, ты чего дерёшься?!»" % Net.peer_names.get(by, "Ты"))


## Бутылкой в торговца — минус настроение и много лояльности.
func on_bottle_hit(by: int) -> void:
	if not multiplayer.is_server():
		return
	mood = maxf(mood - 15.0, -50.0)
	angry_time = ANGRY_TIME
	_change_loyalty(by, -25.0)
	_announce("%s попал бутылкой в Дядю Толю! Тот в ярости" % Net.peer_names.get(by, "Кто-то"))


func _change_loyalty(peer: int, delta: float) -> void:
	var pid := Net.profile_of(peer)
	if pid == "":
		return
	loyalty[pid] = clampf(float(loyalty.get(pid, 0.0)) + delta, -100.0, 100.0)
	_push_loyalty(peer)


func _push_loyalty(peer: int) -> void:
	if not multiplayer.is_server():
		return
	NetUtil.call_peer(self, peer, "set_my_loyalty", [float(loyalty.get(Net.profile_of(peer), 0.0))])


@rpc("authority", "reliable")
func set_my_loyalty(v: float) -> void:
	Inventory.trader_loyalty = v
	Inventory.changed.emit()


func _announce(text: String) -> void:
	NetUtil.call_all(self, "announce", [text])


@rpc("authority", "reliable")
func announce(text: String) -> void:
	Events.notify(text, Color(0.75, 0.85, 1.0))


func _process(delta: float) -> void:
	_t += delta
	var d := drunk / 100.0
	visual.drunk = d
	# Пьёт подарок: бутылка в руке, запрокинул голову.
	var want: StringName = drink_id if drink_anim > 0.0 else &""
	if want != _shown_drink:
		_shown_drink = want
		visual.set_held("drink" if want != &"" else "", want)
	if drink_anim > 0.0:
		visual.pose = "drink"
		visual.set_face("trader_drunk" if drunk > 30.0 else "trader")
		label.text = "Дядя Толя · *глык-глык*"
	elif hurt_time > 0.0:
		visual.pose = "ko" if hurt_time > 1.2 else "sit"
		visual.set_face("hurt")
		label.text = "Дядя Толя · ой-ой-ой…"
	elif asleep_time > 0.0:
		visual.pose = "sit"
		visual.set_face("trader_sleep")
		visual.set_head_tilt(0.6, 0.3)
		label.text = "Хррр… Zzz"
	else:
		visual.pose = "talk" if _talking > 0.0 else "idle"
		visual.set_face("trader_drunk" if drunk > 45.0 else "trader")
		visual.set_head_tilt(0.0, 0.0)
		label.text = "Дядя Толя · %s" % status_word()
	_talking = maxf(_talking - delta, 0.0)

	if not multiplayer.is_server():
		return
	if hurt_time > 0.0:
		hurt_time = maxf(hurt_time - delta, 0.0)
	if drink_anim > 0.0:
		drink_anim -= delta
		if drink_anim <= 0.0:
			# Пустую бутылку — через плечо.
			var bottles := get_tree().get_first_node_in_group("bottles")
			if bottles and drink_id != &"":
				var side := global_basis.x * randf_range(-1, 1) + global_basis.z * 0.8
				bottles._spawn(drink_id, global_position + Vector3.UP * 1.6 + global_basis.z * 0.3,
					side * 2.0 + Vector3.UP * 2.0, 0)
	drunk = maxf(drunk - SOBER_PER_SEC * delta, 0.0)
	mood = move_toward(mood, 0.0, 0.02 * delta)
	if angry_time > 0.0:
		angry_time = maxf(angry_time - delta, 0.0)
	if asleep_time > 0.0:
		asleep_time = maxf(asleep_time - delta, 0.0)
		if asleep_time <= 0.0:
			drunk = 60.0
			_announce("Дядя Толя проснулся. Опохмелиться бы…")


# ------------------------------------------------------------ сохранение

func _save() -> void:
	Saves.set_section("trader", {"drunk": drunk, "mood": mood, "loyalty": loyalty})


func _load() -> void:
	var s := Saves.get_section("trader")
	drunk = float(s.get("drunk", 0.0))
	mood = float(s.get("mood", 0.0))
	loyalty = s.get("loyalty", {})
	asleep_time = 0.0
	angry_time = 0.0
	strikes = 0
