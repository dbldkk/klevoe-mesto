class_name ShopController
extends Node3D
## «Шестёрочка»: следит, не вышел ли игрок с неоплаченной корзиной.
## Решение «заметил / не заметил» принимает хост.

enum Result { CLEAN, SPOTTED, BUSTED, ESCAPED, HIT_SPOTTED, HIT_BUSTED, HIT_ESCAPED }

const THEFT_FINE := 300
const HIT_FINE := 150
## Внутренняя часть магазина (локальные координаты).
const HALF := Vector2(7.8, 5.3)

@export var spot_key := "shop"
@export var shop_title := "Шестёрочка"
@export var price_multiplier := 1.0

@onready var guard: Guard = $Guard
@onready var sentry: Guard = $Guard2

var _was_inside := false
var _rng := RandomNumberGenerator.new()


func _enter_tree() -> void:
	transform = Layout.xform(spot_key)


func _ready() -> void:
	add_to_group("poi")
	set_meta("poi_name", "«%s»" % shop_title)
	add_to_group("shop")
	_rng.randomize()
	# Видимые рамки и камера объясняют более строгую проверку на выходе.
	var metal := Art.color(Color(0.18, 0.22, 0.25))
	for x in [-1.3, 1.3]:
		Build.block(self, Vector3(x, 0.95, 4.75), Vector3(0.1, 1.9, 0.18), metal, false)
	Build.block(self, Vector3(2.0, 2.7, 4.8), Vector3(0.25, 0.2, 0.4), metal, false)
	Build.text(self, Vector3(0, 2.63, 5.76), "ВИДЕОНАБЛЮДЕНИЕ · 2 ОХРАННИКА", 22, Color.GOLD, 0.003)


## Магазин закрывается, только если оба охранника выведены из строя.
func is_closed() -> bool:
	return guard.is_out() and sentry.is_out()


func price_of(kind: String, id: StringName) -> int:
	return ceili(GameData.item_price(kind, id) * price_multiplier)


func guards() -> Array[Guard]:
	return [guard, sentry]


func responder() -> Guard:
	for officer in guards():
		if not officer.stays_inside and not officer.is_out() and not officer.is_chasing() and is_inside(officer.global_position):
			return officer
	return null


func detection_chance(count: int, bulky: bool, drunk: float, value: int = 0) -> float:
	var missed := 1.0
	for officer in guards():
		if not officer.is_out() and not officer.is_chasing() and is_inside(officer.global_position):
			missed *= 1.0 - officer.spot_chance(count, bulky, drunk, value)
	return 1.0 - missed


func is_inside(p: Vector3) -> bool:
	var l := to_local(p)
	return absf(l.x) < HALF.x and absf(l.z) < HALF.y and l.y > -1.0 and l.y < 3.8


func _physics_process(_delta: float) -> void:
	var p := get_tree().get_first_node_in_group("local_player") as Node3D
	if p == null:
		_was_inside = false
		return
	var inside := is_inside(p.global_position)
	if _was_inside and not inside and not Inventory.cart.is_empty() \
			and Inventory.theft == Inventory.Theft.NONE and Inventory.cart_matches(spot_key):
		Inventory.theft = Inventory.Theft.CHECKING
		Inventory.theft_value = Inventory.cart_total()
		NetUtil.call_server(self, "srv_theft", [Inventory.cart.size(), Inventory.cart_bulky(),
			Inventory.drunk, Net.player_name, Inventory.theft_value])
	_was_inside = inside


@rpc("any_peer", "reliable")
func srv_theft(count: int, bulky: bool, drunk: float, pname: String, value: int = 0) -> void:
	if not multiplayer.is_server():
		return
	var peer := NetUtil.sender(self)
	for officer in guards():
		if officer.is_chasing() and officer._target_peer == peer and officer._chase_reason == 0:
			send_result(peer, Result.SPOTTED)
			return
	if _rng.randf() < detection_chance(clampi(count, 1, Inventory.MAX_CART), bulky, clampf(drunk, 0, 100), maxi(value, 0)):
		var runner := responder()
		if runner:
			runner.start_chase(peer, 0, value)
			send_result(peer, Result.SPOTTED)
			announce_all("%s: %s погнался за %s, второй охранник остаётся на посту!" % [shop_title, runner.guard_name, pname])
		else:
			# Дежурный перехватывает товар на выходе, не бросая магазин.
			send_result(peer, Result.BUSTED)
			announce_all("%s: дежурный охранник остановил %s на выходе" % [shop_title, pname])
	else:
		send_result(peer, Result.CLEAN)


## Кто-то нагадил в магазине — охранник в ярости.
func report_mess() -> void:
	NetUtil.call_server(self, "srv_mess", [Net.player_name])


@rpc("any_peer", "reliable")
func srv_mess(pname: String) -> void:
	if not multiplayer.is_server():
		return
	var peer := NetUtil.sender(self)
	announce_all("%s нагадил прямо в «%s»! Охрана в бешенстве" % [pname, shop_title])
	var runner := responder()
	if runner:
		runner.start_chase(peer, 1)
		send_result(peer, Result.HIT_SPOTTED)


func send_result(peer: int, result: int) -> void:
	NetUtil.call_peer(self, peer, "theft_result", [result])


@rpc("authority", "reliable")
func theft_result(result: int) -> void:
	if result in [Result.CLEAN, Result.SPOTTED, Result.BUSTED, Result.ESCAPED]:
		if Inventory.cart.is_empty() or not Inventory.cart_matches(spot_key):
			return
	match result:
		Result.CLEAN:
			Inventory.claim_cart()
			Events.notify("Вынес незаметно. Охранник ничего не понял", Color.GOLD)
		Result.SPOTTED:
			Inventory.theft = Inventory.Theft.CHASED
			Events.notify("Охрана: «А НУ СТОЯТЬ!» — БЕГИ!", Color.RED)
		Result.BUSTED:
			var paid := Inventory.confiscate_cart(THEFT_FINE)
			Events.notify("Поймали! Товар отобрали, штраф %d ₽" % paid, Color.RED)
		Result.ESCAPED:
			Inventory.claim_cart()
			Events.notify("Ушёл! Добыча твоя", Color.GOLD)
		Result.HIT_SPOTTED:
			Events.notify("Михалыч взбесился и бежит за тобой!", Color.RED)
		Result.HIT_BUSTED:
			var paid := mini(Inventory.money, HIT_FINE)
			Inventory.money -= paid
			Inventory.damage(15.0)
			Events.notify("Михалыч догнал и навалял. Штраф %d ₽" % paid, Color.RED)
		Result.HIT_ESCAPED:
			Events.notify("Удрал от Михалыча", Color.GOLD)


func announce_all(text: String) -> void:
	NetUtil.call_all(self, "announce", [text])


@rpc("authority", "reliable")
func announce(text: String) -> void:
	Events.notify(text, Color(0.75, 0.85, 1.0))
