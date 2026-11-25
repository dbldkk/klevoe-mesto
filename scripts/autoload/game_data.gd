extends Node
## Справочник всех вещей и рыб + случайные броски (автозагрузка GameData).
## Типы предметов: "rod", "bait", "drink", "food", "weapon", "smoke", "bottle" (пустая, id = &"empty").

var fish: Array[FishData] = [
	preload("res://data/fish/bleak.tres"),
	preload("res://data/fish/roach.tres"),
	preload("res://data/fish/ruffe.tres"),
	preload("res://data/fish/crucian.tres"),
	preload("res://data/fish/perch.tres"),
	preload("res://data/fish/tench.tres"),
	preload("res://data/fish/bream.tres"),
	preload("res://data/fish/zander.tres"),
	preload("res://data/fish/carp.tres"),
	preload("res://data/fish/pike.tres"),
	preload("res://data/fish/catfish.tres"),
	preload("res://data/fish/golden.tres"),
	preload("res://data/fish/tsar.tres"),
]

var rods: Array[RodData] = [
	preload("res://data/rods/bamboo.tres"),
	preload("res://data/rods/telescopic.tres"),
	preload("res://data/rods/spinning.tres"),
	preload("res://data/rods/carbon.tres"),
	preload("res://data/rods/feeder.tres"),
	preload("res://data/rods/sea.tres"),
]

var baits: Array[BaitData] = [
	preload("res://data/bait/bread.tres"),
	preload("res://data/bait/corn.tres"),
	preload("res://data/bait/worm.tres"),
	preload("res://data/bait/maggot.tres"),
	preload("res://data/bait/dough.tres"),
	preload("res://data/bait/sausage.tres"),
	preload("res://data/bait/poop.tres"),
]

var drinks: Array[DrinkData] = [
	preload("res://data/drinks/beer.tres"),
	preload("res://data/drinks/strong_beer.tres"),
	preload("res://data/drinks/cider.tres"),
	preload("res://data/drinks/port.tres"),
	preload("res://data/drinks/wine.tres"),
	preload("res://data/drinks/vodka.tres"),
	preload("res://data/drinks/cognac.tres"),
	preload("res://data/drinks/samogon.tres"),
	preload("res://data/drinks/champagne.tres"),
]

var foods: Array[FoodData] = [
	preload("res://data/food/noodles.tres"),
	preload("res://data/food/crackers.tres"),
	preload("res://data/food/cheburek.tres"),
	preload("res://data/food/shawarma.tres"),
	preload("res://data/food/seeds.tres"),
	preload("res://data/food/mushroom.tres"),
	preload("res://data/food/berry.tres"),
]

## Бита и сигареты.
var misc: Array[MiscData] = [
	MiscData.make(&"bucket", "tool", "Ведро «Депутат»", 35, 1, 1.0, Color(0.5,0.55,0.56),
		"Можно уронить из инвентаря. Иногда получается головной убор. Q — снять."),
	MiscData.make(&"bat", "weapon", "Бита «Аргумент»", 600, 1, 25.0, Color(0.72, 0.52, 0.3),
		"ЛКМ — ударить. Можно подраться с охранником… если не боишься."),
	MiscData.make(&"cigs", "smoke", "Сигареты «Окурок»", 140, 20, 1.0, Color(0.85, 0.2, 0.15),
		"ЛКМ — закурить. Руки меньше трясутся, голод перебивает."),
	MiscData.make(&"belomor", "smoke", "Папиросы «Беломор»", 90, 20, 1.5, Color(0.25, 0.45, 0.75),
		"Крепкие. Успокаивают надолго, но здоровье не прибавляют."),
	MiscData.make(&"sugar", "misc", "Сахар, 1 кг", 80, 1, 1.0, Color(0.95, 0.95, 0.95),
		"Для самогонного аппарата: 2 кг сахара + 1 пачка дрожжей."),
	MiscData.make(&"yeast", "misc", "Дрожжи «Бодрые»", 45, 1, 1.0, Color(0.9, 0.75, 0.2),
		"Для самогонного аппарата."),
	MiscData.make(&"flashlight", "tool", "Фонарик", 250, 1, 1.0, Color(0.2, 0.2, 0.25),
		"F — включить/выключить. Ночью без него рыбачить тяжко."),
	MiscData.make(&"net", "tool", "Сеть-путанка", 900, 1, 1.0, Color(0.85, 0.45, 0.15),
		"ЛКМ у воды — поставить. Через пару часов вытащить (E). Рыбнадзор за такое штрафует."),
	MiscData.make(&"brine", "misc", "Огуречный рассол", 60, 1, 1.0, Color(0.6, 0.75, 0.35),
		"ЛКМ — выпить. Лучшее средство утром после вчерашнего."),
]

## Цена пустой бутылки в фандомате.
const BOTTLE_RETURN_PRICE := 6

## Скрытая механика: насколько опьянение поднимает шанс рыбы каждой редкости.
const DRUNK_RARITY_BONUS := [0.0, 0.6, 1.5, 3.0, 4.0]
## Сколько штук влезает в одну ячейку.
const STACK := {"rod": 1, "bait": 99, "drink": 10, "food": 10, "bottle": 10, "weapon": 1, "smoke": 40, "misc": 10, "tool": 3}


func _find(list: Array, id: StringName) -> Resource:
	for it in list:
		if it.id == id:
			return it
	return null


func get_fish(id: StringName) -> FishData: return _find(fish, id)
func get_rod(id: StringName) -> RodData: return _find(rods, id)
func get_bait(id: StringName) -> BaitData: return _find(baits, id)
func get_drink(id: StringName) -> DrinkData: return _find(drinks, id)
func get_food(id: StringName) -> FoodData: return _find(foods, id)
func get_misc(id: StringName) -> MiscData: return _find(misc, id)


func get_item(kind: String, id: StringName) -> Resource:
	match kind:
		"rod": return get_rod(id)
		"bait": return get_bait(id)
		"drink": return get_drink(id)
		"food": return get_food(id)
		"weapon", "smoke", "misc", "tool": return get_misc(id)
	return null


func item_name(kind: String, id: StringName) -> String:
	if kind == "bottle":
		return "Пустая бутылка"
	var it := get_item(kind, id)
	return it.display_name if it else "?"


func item_price(kind: String, id: StringName) -> int:
	var it := get_item(kind, id)
	return it.price if it else 0


func item_description(kind: String, id: StringName) -> String:
	match kind:
		"rod":
			var r := get_rod(id)
			return "Рассчитана на рыбу до %.0f кг. Заброс до %.0f м." % [r.max_kg, r.max_cast]
		"bait":
			var b := get_bait(id)
			var s := b.description
			if b.satiety > 0:
				s += " Можно съесть."
			return s
		"drink":
			var d := get_drink(id)
			return "Крепость: %s. Выпей — станет веселее." % ("лёгкий" if d.strength < 15 else "средний" if d.strength < 25 else "крепкий")
		"food":
			var f := get_food(id)
			return "Утоляет голод%s." % (", лечит" if f.health > 0 else "")
		"bottle":
			return "Можно бросить в кого-нибудь (ЛКМ) или сдать в фандомат у «Шестёрочки»."
		"weapon", "smoke", "misc", "tool":
			return get_misc(id).description
	return ""


## Сколько вещь стоит «по-честному» (для ставок в казино и наперстках).
func item_value(kind: String, id: StringName, count: int = 1, cond: float = 100.0) -> int:
	var unit := 0.0
	match kind:
		"rod":
			unit = item_price(kind, id) * (0.25 if cond <= 0.0 else 0.45 + 0.45 * cond / 100.0)
		"bait":
			var b := get_bait(id)
			unit = 2.0 if id == &"poop" else float(b.price) / b.pack_size
		"smoke":
			var m := get_misc(id)
			unit = float(m.price) / m.pack_size
		"bottle":
			unit = BOTTLE_RETURN_PRICE
		"fish":
			var f := get_fish(id)
			unit = f.price_per_kg * cond if f else 0.0   # для рыбы cond = вес
		_:
			unit = item_price(kind, id) * 0.8
	return maxi(0, roundi(unit * count))


func stack_size(kind: String) -> int:
	return STACK.get(kind, 1)


func is_edible(kind: String, id: StringName) -> bool:
	if kind == "food":
		return true
	if kind == "bait":
		var b := get_bait(id)
		return b != null and b.satiety > 0
	return false


# ------------------------------------------------------------ рыбалка

## Шанс каждой рыбы в процентах (сумма 100). zone: "open" / "reeds" / "deep" / "pit",
## с приставкой "far_" — на Дальнем плёсе (крупнее и реже мелочь).
## Ночью клюют сом, судак и щука, мелочь спит. Погода — общий множитель на крупную рыбу.
const NIGHT_FISH := {&"catfish": 3.0, &"zander": 2.0, &"pike": 1.4, &"bleak": 0.4, &"roach": 0.5, &"ruffe": 0.6}

## Время/погода для броска (ставит сервер перед roll_*): night 0..1, big — множитель крупной рыбы, speed — клёв.
var conditions := {"night": 0.0, "big": 1.0, "speed": 1.0}


func fish_chances(bait_id: StringName, drunk: float = 0.0, zone: String = "open") -> Dictionary:
	var bait := get_bait(bait_id)
	var d := clampf(drunk / 100.0, 0.0, 1.0)
	var far := zone.begins_with("far_")
	zone = zone.trim_prefix("far_")
	var weights := {}
	var total := 0.0
	for f in fish:
		var w: float = f.base_chance
		if bait:
			w *= float(bait.fish_multipliers.get(f.id, 1.0))
			if f.rarity < bait.min_rarity:
				w = 0.0
			elif f.rarity >= FishData.Rarity.RARE:
				w *= bait.rare_bonus
		match f.habitat:
			FishData.Habitat.REEDS:
				w *= 3.0 if zone == "reeds" else 0.5
			FishData.Habitat.DEEP:
				w *= 3.0 if zone == "deep" else (4.5 if zone == "pit" else 0.25)
			FishData.Habitat.PIT:
				# Царь-сом: только в яме и только тем, кто «видит» (скрытая механика).
				w = 0.0
				if zone == "pit" and far and d >= 0.45:
					w = 0.35 * (d - 0.4) * 10.0 * (bait.rare_bonus if bait else 1.0)
		if far and f.rarity == FishData.Rarity.COMMON:
			w *= 0.55
		elif far:
			w *= 1.5
		if zone == "reeds" and f.rarity >= FishData.Rarity.UNCOMMON:
			w *= 1.6
		w *= 1.0 + d * DRUNK_RARITY_BONUS[f.rarity]
		var night: float = conditions.night
		if night > 0.0:
			w *= lerpf(1.0, float(NIGHT_FISH.get(f.id, 1.0)), night)
		if f.rarity >= FishData.Rarity.UNCOMMON:
			w *= conditions.big
		weights[f.id] = w
		total += w
	for id in weights:
		weights[id] = weights[id] / maxf(total, 0.0001) * 100.0
	return weights


func roll_fish(bait_id: StringName, rng: RandomNumberGenerator, drunk: float = 0.0, zone: String = "open") -> FishData:
	var chances := fish_chances(bait_id, drunk, zone)
	var r := rng.randf() * 100.0
	for f in fish:
		r -= chances[f.id]
		if r <= 0.0:
			return f
	return fish.back()


## Мелкие экземпляры чаще крупных (а пьяному и в зарослях везёт на крупных).
func roll_weight(f: FishData, rng: RandomNumberGenerator, drunk: float = 0.0, zone: String = "open") -> float:
	var far := zone.begins_with("far_")
	zone = zone.trim_prefix("far_")
	var exponent := maxf(2.0 - drunk / 100.0 * 1.2 - (0.4 if zone == "reeds" else 0.0) - (0.45 if far else 0.0), 0.6)
	var t := pow(rng.randf(), exponent)
	return snappedf(lerpf(f.min_kg, f.max_kg, t), 0.01)


func roll_bite_delay(bait_id: StringName, rng: RandomNumberGenerator, drunk: float = 0.0) -> float:
	var bait := get_bait(bait_id)
	var speed := bait.bite_speed if bait else 1.0
	speed *= 1.0 + drunk / 100.0 * 1.2
	speed *= conditions.speed
	return rng.randf_range(5.0, 25.0) / speed


# ------------------------------------------------------------ слова вместо цифр

func drunk_word(drunk: float) -> String:
	if drunk < 5: return "трезвый"
	if drunk < 25: return "слегка навеселе"
	if drunk < 50: return "поддатый"
	if drunk < 75: return "хорошо набрался"
	if drunk < 92: return "в стельку"
	return "сейчас вырубится"


func loyalty_word(v: float) -> String:
	if v <= -50: return "враг"
	if v <= -15: return "недолюбливает"
	if v < 15: return "нейтрально"
	if v < 50: return "уважает"
	return "кореш"


func condition_word(c: float) -> String:
	if c <= 0: return "сломана"
	if c < 25: return "еле живая"
	if c < 60: return "потрёпанная"
	if c < 90: return "хорошая"
	return "как новая"
