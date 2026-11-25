class_name MiscData
extends Resource
## Прочие предметы: бита ("weapon"), сигареты ("smoke").

@export var id: StringName
@export var kind: String = "weapon"
@export var display_name: String = "Предмет"
@export_multiline var description: String = ""
@export var price: int = 100
## Сколько штук в одной покупке.
@export var pack_size: int = 1
## Для оружия — урон; для сигарет — сила «успокоения».
@export var power: float = 10.0
@export var color: Color = Color(0.6, 0.4, 0.2)


static func make(p_id: StringName, p_kind: String, p_name: String, p_price: int, p_pack: int,
		p_power: float, p_color: Color, p_desc: String) -> MiscData:
	var m := MiscData.new()
	m.id = p_id
	m.kind = p_kind
	m.display_name = p_name
	m.price = p_price
	m.pack_size = p_pack
	m.power = p_power
	m.color = p_color
	m.description = p_desc
	return m
