extends Node
## Вещи и состояние ЛОКАЛЬНОГО игрока (автозагрузка Inventory).
##
## Вещи лежат в ячейках: первые 9 — панель быстрого доступа (1-9), остальные — рюкзак.
## Ячейка: null или {"kind": String, "id": StringName, "count": int, "cond": float (у удочек)}.
## Выбранная ячейка панели — то, что в руках: удочка — ловить, бутылка — пить, еда — есть.
## Пойманная рыба лежит отдельно, в садке.

signal changed
signal selection_changed

const START_MONEY := 500
const HOTBAR := 9
const SLOTS := 27
const MAX_CART := 10
const MAX_HEALTH := 100.0

enum Theft { NONE, CHECKING, CHASED }

var money: int = START_MONEY
var slots: Array = []
var selected: int = 0
var equipped_bait: StringName = &""
var basket: Array[Dictionary] = []   ## садок: [{id, kg}]
var blindness: float = 0.0
var goose_loot: Array = []
var drunk: float = 0.0
var health: float = MAX_HEALTH
var satiety: float = 100.0           ## сытость: 100 — сыт, 0 — голоден
var bladder: float = 0.0             ## по-маленькому: 100 — срочно
var bowel: float = 0.0               ## по-большому: 100 — срочно
var stats: Dictionary = {}
## Счётчики за текущий день (для итогов дня и титулов).
var today: Dictionary = {}

# Не сохраняется:
var cart: Array[Dictionary] = []     ## неоплаченные товары [{kind, id}]
var theft: Theft = Theft.NONE
var trader_loyalty: float = 0.0      ## присылает хост
var theft_value: int = 0             ## на какую сумму пытаешься украсть (чем больше — тем труднее убежать)
var calm_time: float = 0.0           ## после сигареты руки не трясутся


func _ready() -> void:
	reset()


func reset() -> void:
	money = START_MONEY
	slots = []
	slots.resize(SLOTS)
	selected = 0
	add_item("rod", &"bamboo", 1, false)
	add_item("bait", &"bread", 10, false)
	add_item("bait", &"worm", 5, false)
	add_item("drink", &"beer", 2, false)
	add_item("food", &"crackers", 1, false)
	equipped_bait = &"bread"
	basket = []
	blindness = 0.0
	goose_loot = []
	drunk = 0.0
	health = MAX_HEALTH
	satiety = 100.0
	bladder = 0.0
	bowel = 0.0
	stats = _default_stats()
	today = _default_today()
	calm_time = 0.0
	theft_value = 0
	cart = []
	theft = Theft.NONE
	trader_loyalty = 0.0
	changed.emit()
	selection_changed.emit()


func _default_stats() -> Dictionary:
	return {"caught": 0, "biggest_kg": 0.0, "biggest_name": "", "earned": 0,
		"drinks": 0, "blackouts": 0, "thefts_ok": 0, "thefts_busted": 0,
		"bottles_thrown": 0, "hits": 0, "rods_broken": 0, "poops": 0,
		"fish_count": {}, "fish_record": {}}


## Ключи статистики, которые считаются и за день.
const TODAY_MAP := {"drinks": "drinks", "caught": "fish", "earned": "earned", "hits": "hits",
	"thefts_ok": "thefts", "poops": "poops", "bets": "bets", "bottles_returned": "bottles",
	"boxes": "boxes", "knockouts": "knockouts", "smokes": "smokes", "toasts": "toasts", "belochka": "belochka",
	"tourn_wins": "tourn_wins", "moonshine": "moonshine", "jailed": "jailed",
	"net_fish": "net_fish", "fined": "fined", "bribes": "bribes", "disputes_won": "disputes_won",
	"party_drinks": "party_drinks", "farm_jobs": "farm_jobs", "repairs": "repairs"}


func _default_today() -> Dictionary:
	return {"drinks": 0, "fish": 0, "fish_kg": 0.0, "earned": 0, "hits": 0, "thefts": 0, "poops": 0,
		"bets": 0, "bet_won": 0, "bet_lost": 0, "bottles": 0, "boxes": 0, "knockouts": 0, "smokes": 0, "toasts": 0, "belochka": 0, "tourn_wins": 0, "moonshine": 0, "jailed": 0,
		"net_fish": 0, "fined": 0, "bribes": 0, "disputes_won": 0, "party_drinks": 0, "farm_jobs": 0, "repairs": 0,
		"money_start": money}


func stat_add(key: String, amount = 1) -> void:
	stats[key] = stats.get(key, 0) + amount
	if TODAY_MAP.has(key):
		var k: String = TODAY_MAP[key]
		today[k] = today.get(k, 0) + amount


func today_add(key: String, amount = 1) -> void:
	today[key] = today.get(key, 0) + amount


func reset_today() -> void:
	today = _default_today()


# ------------------------------------------------------------ ячейки

func slot(i: int):
	return slots[i] if i >= 0 and i < SLOTS else null


func selected_slot():
	return slots[selected]


func select(i: int) -> void:
	selected = clampi(i, 0, HOTBAR - 1)
	selection_changed.emit()


## Положить вещь. Возвращает false, если не влезло (тогда ничего не добавлено).
func add_item(kind: String, id: StringName, count: int = 1, notify := true, cond := 100.0) -> bool:
	if count <= 0 or not _valid_item(kind, id):
		return false
	if free_space_for(kind, id) < count:
		if notify:
			Events.notify("Инвентарь полон!", Color.TOMATO)
		return false
	var left := count
	var stack := GameData.stack_size(kind)
	if stack > 1:
		for i in SLOTS:
			var s = slots[i]
			if s and s.kind == kind and s.id == id and s.count < stack:
				var put := mini(stack - s.count, left)
				s.count += put
				left -= put
				if left == 0:
					break
	for i in SLOTS:
		if left == 0:
			break
		if slots[i] == null:
			var put := mini(stack, left)
			slots[i] = {"kind": kind, "id": id, "count": put}
			if kind == "rod":
				slots[i]["cond"] = cond
			left -= put
	if kind == "bait" and get_bait_count() <= 0:
		equipped_bait = id
	changed.emit()
	return true


func free_space_for(kind: String, id: StringName) -> int:
	var stack := GameData.stack_size(kind)
	var n := 0
	for s in slots:
		if s == null:
			n += stack
		elif stack > 1 and s.kind == kind and s.id == id:
			n += stack - s.count
	return n


func count_of(kind: String, id: StringName) -> int:
	var n := 0
	for s in slots:
		if s and s.kind == kind and s.id == id:
			n += s.count
	return n


func first_of_kind(kind: String) -> int:
	for i in SLOTS:
		if slots[i] and slots[i].kind == kind:
			return i
	return -1


func remove_item(kind: String, id: StringName, count: int = 1) -> bool:
	if count <= 0:
		return false
	if count_of(kind, id) < count:
		return false
	var left := count
	# Сначала из выбранной ячейки, потом с конца.
	var order := [selected]
	for i in range(SLOTS - 1, -1, -1):
		if i != selected:
			order.append(i)
	for i in order:
		var s = slots[i]
		if s and s.kind == kind and s.id == id:
			var take := mini(s.count, left)
			s.count -= take
			left -= take
			if s.count <= 0:
				slots[i] = null
			if left == 0:
				break
	changed.emit()
	return true


func remove_slot(i: int, count: int = 1) -> void:
	if i < 0 or i >= SLOTS or count <= 0:
		return
	var s = slots[i]
	if s == null:
		return
	s.count -= count
	if s.count <= 0:
		slots[i] = null
	changed.emit()


## Перетаскивание: поменять местами или сложить одинаковые.
func move_slot(from: int, to: int) -> void:
	if from == to or from < 0 or from >= SLOTS or to < 0 or to >= SLOTS:
		return
	var a = slots[from]
	var b = slots[to]
	if a and b and a.kind == b.kind and a.id == b.id and GameData.stack_size(a.kind) > 1:
		var stack := GameData.stack_size(a.kind)
		var put := mini(stack - b.count, a.count)
		b.count += put
		a.count -= put
		if a.count <= 0:
			slots[from] = null
	else:
		slots[from] = b
		slots[to] = a
	changed.emit()
	selection_changed.emit()


# ------------------------------------------------------------ удочки

## Удочка в руках (или null, если в руках не удочка или она сломана).
func get_rod() -> RodData:
	var s = selected_slot()
	if s and s.kind == "rod" and s.get("cond", 100.0) > 0.0:
		return GameData.get_rod(s.id)
	return null


func held_rod_slot():
	var s = selected_slot()
	return s if s and s.kind == "rod" else null


func has_any_rod() -> bool:
	return first_of_kind("rod") >= 0


## Износ удочки в руках. Возвращает true, если сломалась.
func wear_rod(amount: float) -> bool:
	var s = held_rod_slot()
	if s == null:
		return false
	var before: float = s.get("cond", 100.0)
	s.cond = maxf(before - amount, 0.0)
	if s.cond <= 0.0 and before > 0.0:
		stat_add("rods_broken")
		changed.emit()
		return true
	return false


func rod_slots() -> Array[int]:
	var out: Array[int] = []
	for i in SLOTS:
		if slots[i] and slots[i].kind == "rod":
			out.append(i)
	return out


# ------------------------------------------------------------ наживка

func get_bait_count(id: StringName = equipped_bait) -> int:
	return count_of("bait", id)


func equip_bait(id: StringName) -> void:
	if get_bait_count(id) > 0:
		equipped_bait = id
		changed.emit()


func consume_bait(id: StringName = equipped_bait) -> bool:
	if not remove_item("bait", id, 1):
		return false
	if get_bait_count() <= 0:
		_auto_bait()
	return true


func cycle_bait() -> void:
	var available: Array[StringName] = []
	for b in GameData.baits:
		if get_bait_count(b.id) > 0:
			available.append(b.id)
	if available.is_empty():
		return
	var i := available.find(equipped_bait)
	equipped_bait = available[(i + 1) % available.size()]
	changed.emit()


func _auto_bait() -> void:
	equipped_bait = &""
	for b in GameData.baits:
		if get_bait_count(b.id) > 0:
			equipped_bait = b.id
			break
	changed.emit()


# ------------------------------------------------------------ еда и выпивка

## Съесть из ячейки (еда или съедобная наживка).
func eat_slot(i: int) -> bool:
	var s = slots[i]
	if s == null or not GameData.is_edible(s.kind, s.id):
		return false
	var sat := 0.0
	var bow := 0.0
	var hp := 0.0
	if s.kind == "food":
		var f := GameData.get_food(s.id)
		sat = f.satiety
		bow = f.bowel
		hp = f.health
	else:
		var b := GameData.get_bait(s.id)
		sat = b.satiety
		bow = b.satiety * 0.4
	satiety = minf(satiety + sat, 100.0)
	bowel = minf(bowel + bow, 100.0)
	health = minf(health + hp + 4.0, MAX_HEALTH)
	drunk = maxf(drunk - 4.0, 0.0)
	remove_slot(i)
	if s.kind == "bait" and get_bait_count() <= 0:
		_auto_bait()
	return true


func first_food_slot() -> int:
	for i in SLOTS:
		var s = slots[i]
		if s and s.kind == "food":
			return i
	for i in SLOTS:
		var s = slots[i]
		if s and GameData.is_edible(s.kind, s.id):
			return i
	return -1


## Напиток в руках, иначе первый найденный.
func get_drink() -> DrinkData:
	var s = selected_slot()
	if s and s.kind == "drink":
		return GameData.get_drink(s.id)
	var i := first_of_kind("drink")
	return GameData.get_drink(slots[i].id) if i >= 0 else null


func take_drink() -> DrinkData:
	var d := get_drink()
	if d and remove_item("drink", d.id, 1):
		return d
	return null


func add_drunk(amount: float) -> void:
	drunk = clampf(drunk + amount, 0.0, 100.0)


func damage(amount: float) -> void:
	health = clampf(health - amount, 0.0, MAX_HEALTH)
	changed.emit()


# ------------------------------------------------------------ рыба

func add_fish(id: StringName, kg: float) -> void:
	basket.append({"id": id, "kg": kg, "talking":false})
	stat_add("caught")
	var counts: Dictionary = stats.get("fish_count", {})
	counts[String(id)] = int(counts.get(String(id), 0)) + 1
	stats.fish_count = counts
	var records: Dictionary = stats.get("fish_record", {})
	records[String(id)] = maxf(float(records.get(String(id), 0.0)), kg)
	stats.fish_record = records
	today_add("fish_kg", kg)
	if kg > float(stats.biggest_kg):
		stats.biggest_kg = kg
		var f := GameData.get_fish(id)
		stats.biggest_name = f.display_name if f else ""
	changed.emit()


func fish_price(entry: Dictionary) -> int:
	var f := GameData.get_fish(entry.id)
	return maxi(1, roundi(f.price_per_kg * entry.kg)) if f else 0


func basket_value(indices: Array = []) -> int:
	var total := 0
	for i in basket.size():
		if indices.is_empty() or i in indices:
			total += fish_price(basket[i])
	return total


func sell_fish(indices: Array, total: int) -> void:
	var sorted := indices.duplicate()
	sorted.sort()
	sorted.reverse()
	for i in sorted:
		basket.remove_at(i)
	money += total
	stat_add("earned", total)
	changed.emit()


func remove_fish(index: int) -> Dictionary:
	if index < 0 or index >= basket.size():
		return {}
	var e: Dictionary = basket[index]
	basket.remove_at(index)
	changed.emit()
	return e


# ------------------------------------------------------------ корзина магазина

func add_to_cart(kind: String, id: StringName, price: int = -1, shop_id: String = "") -> bool:
	if not _valid_item(kind, id):
		return false
	if theft != Theft.NONE:
		Events.notify("Сначала разберись с охранником!", Color.TOMATO)
		return false
	if not cart_matches(shop_id):
		Events.notify("Сначала оплати или выложи корзину другого магазина", Color.TOMATO)
		return false
	if cart.size() >= MAX_CART:
		Events.notify("Корзина полная", Color.TOMATO)
		return false
	cart.append({"kind": kind, "id": id, "price": GameData.item_price(kind, id) if price < 0 else price, "shop": shop_id})
	Events.notify("В корзину: %s" % GameData.item_name(kind, id), Color(0.85, 0.95, 0.85))
	changed.emit()
	return true


func cart_matches(shop_id: String) -> bool:
	for c in cart:
		if str(c.get("shop", "")) != shop_id:
			return false
	return true


func cart_total() -> int:
	var t := 0
	for c in cart:
		t += int(c.get("price", GameData.item_price(c.kind, c.id)))
	return t


func cart_bulky() -> bool:
	for c in cart:
		if c.kind == "rod":
			return true
	return false


func pay_cart() -> bool:
	var total := cart_total()
	if money < total:
		return false
	if not _cart_fits():
		Events.notify("В инвентаре нет места", Color.TOMATO)
		return false
	money -= total
	_receive_cart()
	return true


## Купить сразу (прилавок «Бухло и Табак»).
func buy(kind: String, id: StringName, price: int = -1) -> bool:
	if not _valid_item(kind, id):
		return false
	if price < 0:
		price = GameData.item_price(kind, id)
	if money < price:
		Events.notify("Не хватает денег", Color.TOMATO)
		return false
	var amount := 1
	if kind == "bait":
		amount = GameData.get_bait(id).pack_size
	elif kind == "smoke":
		amount = GameData.get_misc(id).pack_size
	if not add_item(kind, id, amount):
		return false
	money -= price
	changed.emit()
	return true


func pack_of(kind: String, id: StringName) -> int:
	if kind == "bait":
		return GameData.get_bait(id).pack_size
	if kind == "smoke":
		return GameData.get_misc(id).pack_size
	return 1


func claim_cart() -> void:
	stat_add("thefts_ok")
	_receive_cart()


func confiscate_cart(fine: int) -> int:
	var paid := mini(money, fine)
	money -= paid
	cart.clear()
	stat_add("thefts_busted")
	theft = Theft.NONE
	changed.emit()
	return paid


func drop_cart() -> void:
	if theft != Theft.NONE:
		return
	cart.clear()
	changed.emit()


func _cart_fits() -> bool:
	# Simulate each pack in order, including partially filled stacks.
	var trial := slots.duplicate(true)
	for c in cart:
		if not _valid_item(c.kind, c.id):
			return false
		var left := pack_of(c.kind, c.id)
		var stack := GameData.stack_size(c.kind)
		for s in trial:
			if s and s.kind == c.kind and s.id == c.id:
				var put := mini(maxi(stack - int(s.count), 0), left)
				s.count += put
				left -= put
		for i in SLOTS:
			if left == 0:
				break
			if trial[i] == null:
				var put := mini(stack, left)
				trial[i] = {"kind": c.kind, "id": c.id, "count": put}
				left -= put
		if left > 0:
			return false
	return true


func _valid_item(kind: String, id: StringName) -> bool:
	if kind == "bottle":
		return id == &"empty"
	var item := GameData.get_item(kind, id)
	if item == null:
		return false
	return kind not in ["weapon", "smoke", "misc", "tool"] or item.kind == kind


func _receive_cart() -> void:
	for c in cart:
		var amount := 1
		if c.kind == "bait":
			amount = GameData.get_bait(c.id).pack_size
		elif c.kind == "smoke":
			amount = GameData.get_misc(c.id).pack_size
		if not add_item(c.kind, c.id, amount, false):
			Events.notify("Не влезло: %s" % GameData.item_name(c.kind, c.id), Color.TOMATO)
	cart.clear()
	theft = Theft.NONE
	changed.emit()


# ------------------------------------------------------------ сохранение

func to_dict() -> Dictionary:
	var out_slots := []
	for s in slots:
		if s == null:
			out_slots.append(null)
		else:
			var e := {"kind": s.kind, "id": String(s.id), "count": s.count}
			if s.has("cond"):
				e["cond"] = s.cond
			out_slots.append(e)
	var fish_list := []
	for e in basket:
		fish_list.append({"id": String(e.id), "kg": e.kg, "talking":bool(e.get("talking",false))})
	return {
		"version": 4, "blindness":blindness, "goose_loot":goose_loot,
		"money": money, "slots": out_slots, "selected": selected,
		"equipped_bait": String(equipped_bait), "basket": fish_list,
		"drunk": drunk, "health": health, "satiety": satiety,
		"bladder": bladder, "bowel": bowel, "stats": stats, "today": today,
	}


func from_dict(d: Dictionary) -> void:
	reset()
	money = int(d.get("money", START_MONEY))
	slots = []
	slots.resize(SLOTS)
	if d.has("slots"):
		var src: Array = d.slots
		for i in mini(src.size(), SLOTS):
			var e = src[i]
			if e is Dictionary and GameData.get_item(e.kind, StringName(e.id)) != null or (e is Dictionary and e.kind == "bottle"):
				var s := {"kind": String(e.kind), "id": StringName(e.id), "count": int(e.count)}
				if e.has("cond"):
					s["cond"] = float(e.cond)
				slots[i] = s
	else:
		_migrate_v2(d)
	selected = clampi(int(d.get("selected", 0)), 0, HOTBAR - 1)
	equipped_bait = StringName(d.get("equipped_bait", "bread"))
	if get_bait_count() <= 0:
		_auto_bait()
	basket.clear()
	for e in d.get("basket", []):
		if GameData.get_fish(StringName(e.id)):
			basket.append({"id": StringName(e.id), "kg": float(e.kg), "talking":bool(e.get("talking",false))})
	blindness = clampf(float(d.get("blindness",0.0)),0.0,1.0)
	var loot = d.get("goose_loot",[])
	if loot is Array:
		for item in loot:
			if item is Dictionary and _valid_item(str(item.get("kind","")),StringName(item.get("id",""))):
				goose_loot.append(item.duplicate())
	drunk = float(d.get("drunk", 0.0))
	health = float(d.get("health", MAX_HEALTH))
	satiety = float(d.get("satiety", 100.0))
	bladder = float(d.get("bladder", 0.0))
	bowel = float(d.get("bowel", 0.0))
	var s: Dictionary = _default_stats()
	s.merge(d.get("stats", {}), true)
	stats = s
	var td: Dictionary = _default_today()
	td.merge(d.get("today", {}), true)
	today = td
	changed.emit()
	selection_changed.emit()


## Сохранения версии 0.2 (без ячеек).
func _migrate_v2(d: Dictionary) -> void:
	for r in d.get("owned_rods", []):
		if GameData.get_rod(StringName(r)):
			add_item("rod", StringName(r), 1, false)
	for k in d.get("bait", {}):
		if GameData.get_bait(StringName(k)) and int(d.bait[k]) > 0:
			add_item("bait", StringName(k), int(d.bait[k]), false)
	for k in d.get("drinks", {}):
		if GameData.get_drink(StringName(k)) and int(d.drinks[k]) > 0:
			add_item("drink", StringName(k), int(d.drinks[k]), false)
	if int(d.get("empty_bottles", 0)) > 0:
		add_item("bottle", &"empty", int(d.empty_bottles), false)
