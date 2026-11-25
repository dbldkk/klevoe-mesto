class_name CasinoDealer
extends Node3D
## Человек у автомата / крупье. Принимает ставку деньгами или вещью:
## вещь оценивает сам (может отказать, если вещь дрянь) и назначает за неё сумму.
## Случай решает хост: srv_play → результат приходит игроку.

@export_enum("slots", "roulette", "thimbles") var game: String = "slots"
@export var dealer_name: String = "Крупье"
@export var face: String = "neutral"
@export var skin_data: Dictionary = {}
## 0 — берёт всё подряд, 1 — очень придирчив к вещам.
@export var picky: float = 0.3

## Барабаны слотов: символ, вес.
const REELS := [["poop", 30], ["bread", 25], ["beer", 20], ["vodka", 12], ["pike", 8], ["golden", 5]]
## Три одинаковых: множитель. Две одинаковые (не какашки): x2, два золотых: x4.
const TRIPLE := {"poop": 0, "bread": 5, "beer": 8, "vodka": 15, "pike": 30, "golden": 100}
const RED := [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]
## Наперстки: шанс угадать и выигрыш.
const THIMBLE_CHANCE := 0.15
const THIMBLE_MULT := 6

var model: CharacterModel
var _rng := RandomNumberGenerator.new()
var _talk := 0.0


func _ready() -> void:
	Chatter.attach.call_deferred(self, "f" if face.ends_with("_f") else "m", SpeechBank.dealer(), 2.3, 4.5)
	_rng.randomize()
	model = Build.person(self, Vector3.ZERO, 0.0, skin_data, face, game == "roulette")
	Build.text(self, Vector3(0, 2.2, 0), dealer_name, 40, Color(1, 0.9, 0.6), 0.006, 0.0, true)
	Build.talk_area(self, Vector3(0, 1.0, -0.5), Vector3(1.4, 1.9, 1.6), self)


func display_name() -> String:
	return dealer_name


func game_title() -> String:
	match game:
		"roulette": return "Рулетка"
		"thimbles": return "Напёрстки"
	return "Автомат «Золотой карась»"


func get_prompt(_player: Node) -> String:
	var host := get_parent()
	if host.has_method("can_play") and not host.can_play():
		return host.refuse_line()
	return "%s: сделать ставку (%s)" % [dealer_name, game_title()]


func interact(player: Node) -> void:
	var host := get_parent()
	if host.has_method("can_play") and not host.can_play():
		Events.notify(host.refuse_line(), Color.TOMATO)
		return
	if player.stinky > 0.0:
		Events.notify("%s: «От тебя воняет! Помойся — потом приходи играть»" % dealer_name, Color.ORANGE)
		return
	var ui := get_tree().get_first_node_in_group("casino_ui")
	if ui:
		_talk = 2.0
		ui.open(self)


func _process(delta: float) -> void:
	if model and not get_parent().has_method("can_play"):
		_talk = maxf(_talk - delta, 0.0)
		model.pose = "talk" if _talk > 0.0 else "idle"


# ------------------------------------------------------------ оценка вещи (у игрока)

## {ok, value, line}: возьмёт ли вещь в ставку и за сколько.
func appraise(kind: String, id: StringName, count: int, cond: float) -> Dictionary:
	var fair := GameData.item_value(kind, id, count, cond)
	var nm := GameData.item_name(kind, id) if kind != "fish" else GameData.get_fish(id).display_name
	if game == "thimbles":
		# Гоша берёт что угодно — хоть какашку.
		var v := maxi(1, roundi(fair * _rng.randf_range(0.5, 0.85)))
		return {"ok": true, "value": v, "line": ["Пойдёт! Ставлю за это %d ₽." % v, "Ну давай, %d ₽ — и крутим." % v].pick_random()}
	if kind == "bait" and id == &"poop":
		return {"ok": false, "value": 0, "line": "Ты мне что, говно предлагаешь?! Охрана!"}
	if kind == "bottle":
		return {"ok": false, "value": 0, "line": "Пустую бутылку — в фандомат, а не ко мне."}
	if fair < 30 + picky * 120:
		return {"ok": false, "value": 0, "line": "%s? За это я даже рубль не поставлю." % nm}
	if kind == "rod" and cond < 30:
		return {"ok": false, "value": 0, "line": "Удочка ж сломанная. Почини — потом приходи."}
	var v := roundi(fair * _rng.randf_range(0.55, 0.9) * (1.0 - picky * 0.25))
	return {"ok": true, "value": v, "line": ["Ладно, принимаю за %d ₽." % v, "Оценю в %d ₽. Играем?" % v,
		"%d ₽ — и ни копейкой больше." % v].pick_random()}


## Самый большой возможный выигрыш со ставки.
func max_payout(stake: int) -> int:
	match game:
		"roulette": return stake * 36
		"thimbles": return stake * THIMBLE_MULT
	return stake * TRIPLE.golden


# ------------------------------------------------------------ игра (решает хост)

## choice: для рулетки {"type": "red"/"black"/"even"/"odd"/"low"/"high"/"number", "n": int},
## для наперстков {"cup": 0..2}.
func play(stake: int, choice: Dictionary) -> void:
	NetUtil.call_server(self, "srv_play", [stake, choice])


@rpc("any_peer", "reliable")
func srv_play(stake: int, choice: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var result := {}
	match game:
		"slots":
			var r: Array = [_reel(), _reel(), _reel()]
			result = {"reels": r, "mult": _slot_mult(r)}
		"roulette":
			var n := _rng.randi_range(0, 36)
			result = {"n": n, "mult": _roulette_mult(n, choice)}
		"thimbles":
			var cup := int(choice.get("cup", 0))
			var win := _rng.randf() < THIMBLE_CHANCE
			var ball := cup if win else (cup + 1 + _rng.randi() % 2) % 3
			result = {"ball": ball, "mult": THIMBLE_MULT if win else 0}
	result["stake"] = stake
	on_server_result(NetUtil.sender(self), stake, result)
	NetUtil.call_peer(self, NetUtil.sender(self), "play_result", [result])


## Для наперсточника — копит выигранное.
func on_server_result(peer: int, stake: int, result: Dictionary) -> void:
	var host := get_parent()
	if host.has_method("on_bet_result"):
		host.on_bet_result(peer, stake, result)


@rpc("authority", "reliable")
func play_result(result: Dictionary) -> void:
	var ui := get_tree().get_first_node_in_group("casino_ui")
	if ui:
		ui.on_result(self, result)


func _reel() -> String:
	var total := 0
	for r in REELS:
		total += r[1]
	var x := _rng.randi() % total
	for r in REELS:
		x -= r[1]
		if x < 0:
			return r[0]
	return "poop"


static func _slot_mult(r: Array) -> float:
	if r[0] == r[1] and r[1] == r[2]:
		return TRIPLE[r[0]]
	var counts := {}
	for s in r:
		counts[s] = counts.get(s, 0) + 1
	for s in counts:
		if counts[s] == 2 and s != "poop":
			return 4.0 if s == "golden" else 2.0
	return 0.0


static func _roulette_mult(n: int, c: Dictionary) -> float:
	var t: String = c.get("type", "red")
	if n == 0:
		return 36.0 if t == "number" and int(c.get("n", -1)) == 0 else 0.0
	match t:
		"red": return 2.0 if n in RED else 0.0
		"black": return 2.0 if n not in RED else 0.0
		"even": return 2.0 if n % 2 == 0 else 0.0
		"odd": return 2.0 if n % 2 == 1 else 0.0
		"low": return 2.0 if n <= 18 else 0.0
		"high": return 2.0 if n >= 19 else 0.0
		"number": return 36.0 if n == int(c.get("n", -1)) else 0.0
	return 0.0


static func is_red(n: int) -> bool:
	return n in RED
