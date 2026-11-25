extends ModalUi
## «Спорим?» — смотришь на другого игрока и жмёшь Z. Выбираешь, о чём спор и на сколько.
## Тот принимает (Y) — деньги обоих «на кону», победитель забирает всё.

const KINDS := [["swim", "Спорим, я переплыву озеро!"], ["chug", "Спорим, выпью бутылку залпом!"]]
const STAKES := [100, 300, 500, 1000]

var _target: Node
var _who: Label
var _kind := "swim"
var _stake := 300
var _kind_btns := {}
var _stake_btns := {}
var _info: Label


func _ready() -> void:
	_setup("dispute_ui", "СПОРИМ?", 560, Color(1.0, 0.8, 0.4))
	_who = UiKit.label("", 19, Color(0.85, 0.9, 1.0))
	_who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_who)
	for k in KINDS:
		var id: String = k[0]
		var b := UiKit.button(k[1], func() -> void: _pick_kind(id))
		b.toggle_mode = true
		_kind_btns[id] = b
		body.add_child(b)
	var r := ModalUi.row(8)
	r.alignment = BoxContainer.ALIGNMENT_CENTER
	r.add_child(UiKit.label("На кону:", 18))
	for s in STAKES:
		var v: int = s
		var b := UiKit.button("%d ₽" % v, func() -> void: _pick_stake(v), 16)
		b.toggle_mode = true
		_stake_btns[v] = b
		r.add_child(b)
	body.add_child(r)
	_info = UiKit.label("", 15, Color(1, 1, 1, 0.6))
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD
	body.add_child(_info)
	var rr := ModalUi.row(10)
	rr.alignment = BoxContainer.ALIGNMENT_CENTER
	rr.add_child(UiKit.button("Предложить спор", _propose))
	rr.add_child(UiKit.button("Отмена", close))
	body.add_child(rr)


func open(target: Node) -> void:
	_target = target
	_who.text = "С кем: %s   ·   у тебя %d ₽" % [target.player_name, Inventory.money]
	_pick_kind(_kind)
	_pick_stake(_stake)
	_show()


func _pick_kind(k: String) -> void:
	_kind = k
	for id in _kind_btns:
		(_kind_btns[id] as Button).button_pressed = id == k
	_update_info()


func _pick_stake(v: int) -> void:
	_stake = v
	for s in _stake_btns:
		(_stake_btns[s] as Button).button_pressed = s == v
	_update_info()


func _update_info() -> void:
	if _kind == "swim":
		_info.text = "Плывёшь отсюда на тот берег (финиш покажут). Без лодки и за отведённое время."
	else:
		_info.text = "Нужна крепкая бутылка в карманах. Держи ЛКМ — пьёшь; подкатывает — отпусти. Поперхнёшься — проиграл."


func _propose() -> void:
	var me := get_tree().get_first_node_in_group("local_player")
	if me == null or _target == null:
		return
	var err: String = me.can_dispute(_kind, _stake)
	if err != "":
		Events.notify(err, Color.TOMATO)
		return
	me.propose_dispute(_target, _kind, _stake)
	close()
