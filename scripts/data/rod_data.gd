class_name RodData
extends Resource
## Удочка. У каждой удочки в инвентаре есть состояние 0..100 (износ);
## на 0 она ломается, починить можно у Дяди Толи.

@export var id: StringName
@export var display_name: String = "Удочка"
@export var price: int = 300
## Рассчитана на рыбу до этого веса. Тяжелее — сильно изнашивается, но вытащить можно.
@export var max_kg: float = 2.0
## Скорость подмотки, м/с.
@export var reel_speed: float = 1.2
## Максимальная дальность заброса, м.
@export var max_cast: float = 14.0
## Прочность: чем больше, тем медленнее изнашивается.
@export var toughness: float = 1.0
@export var color: Color = Color(0.8, 0.7, 0.4)
