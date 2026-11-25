extends Node3D
## Баба Зоя на лавочке. Продаёт червей и семечки (через окно прилавка), ругается на пьяных
## и всё докладывает участковому. Ударишь бабку — участковый узнает сразу.

const GOODS := [["bait", &"worm"], ["bait", &"maggot"], ["food", &"seeds"], ["misc", &"brine"], ["tool", &"net"]]
const SCOLD := ["Опять нажрался, ирод!", "Глаза б мои тебя не видели, алкаш!", "Вот я Петровичу-то расскажу!",
	"В мои годы так не пили!", "Иди проспись, срамота!", "Ой, позорище-то какое…"]
const HELLO := ["Червячков, милок? Свежие, сама копала.", "Семечки жареные, не то что в магазине.",
	"Опарыш — первый сорт!", "Бери, пока Петрович не видит."]

var model: CharacterModel
var _speech: Label3D
var _scan := 0.0
var _told: Dictionary = {}     ## peer -> когда последний раз жаловалась


func _enter_tree() -> void:
	transform = Layout.xform("babka")


func _ready() -> void:
	Chatter.attach.call_deferred(self, "old", SpeechBank.zoya(), 2.45, 5.0, "zoya")
	add_to_group("babka")
	add_to_group("poi")
	set_meta("poi_name", "Баба Зоя")
	var wood := Art.tex_world("planks", 0.6)
	var iron := Art.color(Color(0.15, 0.15, 0.15), 0.5, 0.6)
	Build.block(self, Vector3(0, 0.45, 0), Vector3(1.8, 0.06, 0.45), wood, true)
	Build.block(self, Vector3(0, 0.8, -0.22), Vector3(1.8, 0.35, 0.05), wood, false, Vector3(-0.15, 0, 0))
	for x in [-0.75, 0.75]:
		Build.block(self, Vector3(x, 0.22, 0), Vector3(0.06, 0.44, 0.45), iron, false)
	# Ведро с червями и мешок семечек
	Build.cylinder(self, Vector3(1.25, 0.18, 0.15), 0.16, 0.36, Art.color(Color(0.55, 0.55, 0.6), 0.4, 0.6), true, 12)
	Art.add_mesh(self, Art.cyl(0.15, 0.15, 0.02, 12), Art.color(Color(0.35, 0.22, 0.15)), Vector3(1.25, 0.36, 0.15))
	Art.add_mesh(self, Art.sphere(0.2, 10), Art.color(Color(0.85, 0.78, 0.6), 0.9), Vector3(-1.2, 0.2, 0.1), Vector3.ZERO, Vector3(1, 1.2, 1))
	model = Build.person(self, Vector3(-0.3, 0.0, 0.05), 0.0,
		{"shirt": 4, "pants": 1, "skin": 0, "hat": 2, "hat_color": 1, "face": 0}, "seller", true)
	model.rotation.y = PI
	model.pose = "sit"
	model.height_scale = 0.9
	Build.text(self, Vector3(-0.3, 1.75, 0.05), "Баба Зоя", 36, Color(1, 0.85, 0.85), 0.006, 0.0, true)
	_speech = Build.text(self, Vector3(-0.3, 2.1, 0.05), "", 36, Color(1, 1, 0.8), 0.006, 0.0, true)
	Build.talk_area(self, Vector3(-0.3, 0.8, 0.4), Vector3(1.6, 1.6, 1.2), self)


func display_name() -> String:
	return "Баба Зоя"


func store_title() -> String:
	return "БАБА ЗОЯ"


func seller_name() -> String:
	return "Баба Зоя"


func greeting() -> String:
	var me := get_tree().get_first_node_in_group("local_player")
	if me and float(me.drunk) > 50.0:
		return SCOLD.pick_random()
	return HELLO.pick_random()


func price_of(kind: String, id: StringName) -> int:
	if kind == "food":
		return 20
	if kind == "misc":
		return 50
	if kind == "tool":
		return 900
	return roundi(GameData.item_price(kind, id) * 0.8)


func get_prompt(_p: Node) -> String:
	return "Баба Зоя: черви, семечки, рассол… и кое-что из-под полы"


func interact(_p: Node) -> void:
	var ui := get_tree().get_first_node_in_group("store_ui")
	if ui:
		ui.open(self)


## Ударили бабку.
func on_melee_hit(by: int, _damage: float) -> void:
	if not multiplayer.is_server():
		return
	NetUtil.call_all(self, "say", ["Караул! Убивают! ПЕТРОВИЧ!"])
	var police := get_tree().get_first_node_in_group("police")
	if police:
		police.report(by, "избил бабушку")


## Участковый/драка: бабка что-то увидела.
func tattle(line: String) -> void:
	NetUtil.call_all(self, "say", [line])


@rpc("authority", "call_remote", "reliable")
func say(text: String) -> void:
	_speech.text = text
	_speech.modulate.a = 1.0
	Sfx.say(global_position + Vector3(0, 1.4, 0), "old", text, "zoya")


func _process(delta: float) -> void:
	_speech.modulate.a = maxf(_speech.modulate.a - delta * 0.2, 0.0)
	model.pose = "sit"
	if not multiplayer.is_server():
		return
	_scan -= delta
	if _scan > 0.0:
		return
	_scan = 1.0
	var now := Time.get_ticks_msec() / 1000.0
	for p in get_tree().get_nodes_in_group("players"):
		var pp := p as Node3D
		var peer: int = p.name.to_int()
		if p.hidden or pp.global_position.distance_to(global_position) > 9.0:
			continue
		if float(p.drunk) > 60.0 and now - float(_told.get(peer, -999.0)) > 60.0:
			_told[peer] = now
			NetUtil.call_all(self, "say", [SCOLD.pick_random()])
			var police := get_tree().get_first_node_in_group("police")
			if police and float(p.drunk) > 75.0:
				police.report(peer, "пьяный дебош (нажаловалась баба Зоя)", false)
