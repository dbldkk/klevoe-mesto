class_name BaitData
extends Resource
## Наживка. Покупается пачками; некоторую можно съесть.

@export var id: StringName
@export var display_name: String = "Наживка"
@export_multiline var description: String = ""
@export var price: int = 40
## Сколько штук в одной покупке.
@export var pack_size: int = 10
## Больше 1 — клюёт быстрее.
@export var bite_speed: float = 1.0
## Множители шанса для рыб: id рыбы -> множитель. Кого нет в списке — x1.
@export var fish_multipliers: Dictionary[StringName, float] = {}
## Не ниже этой редкости (на какашку мелочь не клюёт).
@export var min_rarity: int = 0
## Множитель для рыб от редкой и выше.
@export var rare_bonus: float = 1.0
## Если больше 0 — наживку можно съесть.
@export var satiety: float = 0.0
## Продаётся ли в магазине.
@export var in_shop: bool = true
