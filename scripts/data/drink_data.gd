class_name DrinkData
extends Resource
## Алкоголь. После выпивания остаётся пустая бутылка.

@export var id: StringName
@export var display_name: String = "Напиток"
@export var price: int = 90
## Насколько поднимает опьянение (шкала 0..100).
@export var strength: float = 12.0
## Сколько здоровья отнимает.
@export var health_cost: float = 0.0
## Насколько сильнее захочется в туалет.
@export var bladder: float = 10.0
@export var bottle_color: Color = Color(0.4, 0.25, 0.1)
## Форма: 0 — пивная, 1 — винная, 2 — водочная, 3 — пузатая (коньяк)
@export var shape: int = 0
