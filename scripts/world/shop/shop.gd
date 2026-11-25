class_name ShopController
extends Node3D
## «Шестёрочка»: следит, не вышел ли игрок с неоплаченной корзиной.
## Решение «заметил / не заметил» принимает хост.

enum Result { CLEAN, SPOTTED, BUSTED, ESCAPED, HIT_SPOTTED, HIT_BUSTED, HIT_ESCAPED }

const THEFT_FINE := 300
const HIT_FINE := 150
## Внутренняя часть магазина (локальные координаты).
const HALF := Vector2(7.8, 5.3)

@onready var guard: Guard = $Guard

var _was_inside := false
var _rng := RandomNumberGenerator.new()


func _enter_tree() -> void:
	transform = Layout.xform("shop")


func _ready() -> void:
	add_to_group("poi")
	set_meta("poi_name", "«Шестёрочка»")
	add_to_group("shop")
	_rng.randomize()


## Михалыч в нокауте — магазин не работает.
func is_closed() -> bool:
	return guard.is_out()


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
			and Inventory.theft == Inventory.Theft.NONE:
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
	if not guard.is_chasing() and not guard.is_out() and _rng.randf() < guard.spot_chance(count, bulky, drunk, value):
		guard.start_chase(peer, 0, value)
		send_result(peer, Result.SPOTTED)
		var extra := " С таким грузом далеко не убежишь!" if value > 1000 else ""
		announce_all("Охранник погнался за %s!%s" % [pname, extra])
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
	announce_all("%s нагадил прямо в «Шестёрочке»! Михалыч в бешенстве" % pname)
	if not guard.is_chasing():
		guard.start_chase(peer, 1)
		send_result(peer, Result.HIT_SPOTTED)


func send_result(peer: int, result: int) -> void:
	NetUtil.call_peer(self, peer, "theft_result", [result])


@rpc("authority", "reliable")
func theft_result(result: int) -> void:
	match result:
		Result.CLEAN:
			Inventory.claim_cart()
			Events.notify("Вынес незаметно. Охранник ничего не понял", Color.GOLD)
		Result.SPOTTED:
			Inventory.theft = Inventory.Theft.CHASED
			Events.notify("Михалыч: «А НУ СТОЯТЬ!» — БЕГИ!", Color.RED)
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
