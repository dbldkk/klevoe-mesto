class_name Tournament
extends Node
## Рыбное соревнование Дяди Толи: каждый день с 17:00 до 18:30. Побеждает самая крупная рыба.
## Ловят все; клиенты сообщают улов хосту (report_catch), хост ведёт лидера и в конце платит приз.

const START_MIN := 17.0 * 60.0
const END_MIN := 18.5 * 60.0
const PRIZE_BASE := 400
const PRIZE_PER_PLAYER := 200

## Синхронизируется:
@export var active: bool = false
@export var leader_name: String = ""
@export var leader_fish: String = ""
@export var leader_kg: float = 0.0
@export var prize: int = 0

var _leader_peer := 0
var _done_day := -1


func _ready() -> void:
	add_to_group("tournament")


func time_left_text() -> String:
	var dc := get_tree().get_first_node_in_group("day_cycle") as DayCycle
	if dc == null:
		return ""
	var left := int(END_MIN - fmod(dc.minutes, 1440.0))
	return "до 18:30 (ещё %d мин)" % maxi(left, 0)


func _process(_delta: float) -> void:
	if not multiplayer.is_server():
		return
	var dc := get_tree().get_first_node_in_group("day_cycle") as DayCycle
	if dc == null:
		return
	var m := fmod(dc.minutes, 1440.0)
	if not active and m >= START_MIN and m < END_MIN and _done_day != dc.day:
		active = true
		_done_day = dc.day
		_leader_peer = 0
		leader_name = ""
		leader_fish = ""
		leader_kg = 0.0
		prize = PRIZE_BASE + PRIZE_PER_PLAYER * get_tree().get_nodes_in_group("players").size()
		NetUtil.call_all(self, "announce", ["Дядя Толя: «СОРЕВНОВАНИЕ! Кто до 18:30 поймает самую крупную рыбу — получит %d ₽!»" % prize, true])
	elif active and (m >= END_MIN or m < START_MIN):
		active = false
		if _leader_peer != 0:
			NetUtil.call_peer(self, _leader_peer, "win", [prize])
			NetUtil.call_all(self, "announce", ["Соревнование окончено! Победил %s: %s, %.2f кг. Приз %d ₽!" % [leader_name, leader_fish, leader_kg, prize], true])
		else:
			NetUtil.call_all(self, "announce", ["Соревнование окончено — никто ничего не поймал. Толя расстроен", false])


## Клиент поймал рыбу.
func report_catch(fish_id: StringName, kg: float) -> void:
	if active:
		NetUtil.call_server(self, "srv_catch", [String(fish_id), kg])


@rpc("any_peer", "reliable")
func srv_catch(fish_id: String, kg: float) -> void:
	if not multiplayer.is_server() or not active:
		return
	var peer := NetUtil.sender(self)
	if kg <= leader_kg:
		return
	var f := GameData.get_fish(StringName(fish_id))
	if f == null or kg > f.max_kg * 1.01:
		return
	_leader_peer = peer
	leader_name = Net.peer_names.get(peer, "Кто-то")
	leader_fish = f.display_name
	leader_kg = kg
	NetUtil.call_all(self, "announce", ["Соревнование: лидирует %s — %s, %.2f кг!" % [leader_name, leader_fish, kg], false])


@rpc("authority", "reliable")
func announce(text: String, big: bool) -> void:
	Events.notify(text, Color(1.0, 0.85, 0.3) if big else Color(0.9, 0.9, 0.7))
	if big:
		Sfx.play("whistle")


@rpc("authority", "reliable")
func win(amount: int) -> void:
	Inventory.money += amount
	Inventory.stat_add("earned", amount)
	Inventory.stat_add("tourn_wins")
	Inventory.changed.emit()
	Sfx.play("slot_win")
	Events.notify("Ты выиграл соревнование! +%d ₽" % amount, Color.GOLD)
