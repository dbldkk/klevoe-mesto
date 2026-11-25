class_name FishData
extends Resource
## Описание одного вида рыбы. Новая рыба — новый .tres в res://data/fish/ + строка в GameData.fish.

enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }
enum Habitat { ANYWHERE, REEDS, DEEP, PIT }
enum Pattern { PLAIN, STRIPES, SPOTS, GOLD, DARK }

@export var id: StringName
@export var display_name: String = "Рыба"
@export_multiline var description: String = ""
@export var rarity: Rarity = Rarity.COMMON
## Относительный шанс клёва (шансы всех рыб нормируются).
@export var base_chance: float = 10.0
@export var min_kg: float = 0.1
@export var max_kg: float = 1.0
@export var price_per_kg: int = 100
## Насколько бодро сопротивляется (1 = обычно).
@export var strength: float = 1.0
## Где водится: везде / в зарослях / на глубине.
@export var habitat: Habitat = Habitat.ANYWHERE

@export_group("Внешний вид")
@export var body_color: Color = Color(0.6, 0.65, 0.7)
@export var belly_color: Color = Color(0.92, 0.92, 0.88)
@export var fin_color: Color = Color(0.7, 0.4, 0.35)
@export var pattern: Pattern = Pattern.PLAIN
## Вытянутость тела (щука — длинная, лещ — высокий).
@export var body_length: float = 1.0
@export var body_height: float = 1.0


static func rarity_name(r: Rarity) -> String:
	match r:
		Rarity.COMMON: return "обычная"
		Rarity.UNCOMMON: return "необычная"
		Rarity.RARE: return "редкая"
		Rarity.EPIC: return "эпическая"
		Rarity.LEGENDARY: return "легендарная"
	return "?"


static func rarity_color(r: Rarity) -> Color:
	match r:
		Rarity.COMMON: return Color(0.85, 0.85, 0.85)
		Rarity.UNCOMMON: return Color(0.45, 0.9, 0.45)
		Rarity.RARE: return Color(0.4, 0.65, 1.0)
		Rarity.EPIC: return Color(0.8, 0.45, 1.0)
		Rarity.LEGENDARY: return Color(1.0, 0.75, 0.2)
	return Color.WHITE


static func habitat_name(h: Habitat) -> String:
	match h:
		Habitat.REEDS: return "в зарослях камыша"
		Habitat.DEEP: return "на глубине"
		Habitat.PIT: return "в яме на Дальнем плёсе"
	return "везде"
