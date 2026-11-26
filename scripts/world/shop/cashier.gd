extends Node3D
## Кассирша Зина. E — оплатить корзину.

const LINES := [
	"Пакет нужен?",
	"Карта «Шестёрочки» есть?",
	"Мелочи не будет?",
	"Опять на рыбалку? Ну-ну.",
	"Следующий!",
]


func get_prompt(_player: Node) -> String:
	if get_parent().is_closed():
		return "Зина в панике звонит в полицию"
	if not Inventory.cart.is_empty() and not Inventory.cart_matches(get_parent().spot_key):
		return "Это корзина другого магазина"
	if Inventory.cart.is_empty():
		return "Поболтать с кассиршей Зиной"
	return "Оплатить корзину: %d ₽" % Inventory.cart_total()


func _ready() -> void:
	Chatter.attach.call_deferred(self, "f", SpeechBank.zina(), 2.2, 4.0, "zina")
	add_to_group("npc")


func interact(player: Node) -> void:
	if get_parent().is_closed():
		Events.notify("Зина: «Закрыто! Не подходи!»", Color.TOMATO)
		return
	if player.stinky > 0.0:
		Events.notify("Зина: «Фу! Не обслуживаю! Иди помойся!»", Color.ORANGE)
		return
	if Inventory.cart.is_empty():
		Events.notify("Зина: «%s»" % LINES.pick_random(), Color(1, 0.9, 0.8))
		return
	if Inventory.theft != Inventory.Theft.NONE:
		Events.notify("Зина: «Вон отсюда, ворюга!»", Color.TOMATO)
		return
	if not Inventory.cart_matches(get_parent().spot_key):
		Events.notify("Эту корзину нужно оплатить в другом магазине", Color.TOMATO)
		return
	var total := Inventory.cart_total()
	if Inventory.pay_cart():
		Sfx.play("cash", global_position + Vector3.UP)
		Events.notify("Оплачено %d ₽. Зина: «%s»" % [total, LINES.pick_random()], Color.PALE_GREEN)
	elif Inventory.money < total:
		Events.notify("Не хватает %d ₽. Выложи лишнее (C) или… рискни" % (total - Inventory.money), Color.TOMATO)
