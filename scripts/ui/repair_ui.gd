extends ModalUi
## Ремонт «Нивы»: 4 поломки по очереди, на каждую — выбрать инструмент. 3 из 4 — починил.

const FAULTS := [
	["Свеча не даёт искру", "Свечной ключ", ["Кувалда", "Синяя изолента"]],
	["Ремень генератора свистит", "Ключ на 13", ["Насос", "Отвёртка"]],
	["Колесо снято, болты в траве", "Баллонный ключ", ["Изолента", "Молоток"]],
	["Провод от аккумулятора болтается", "Синяя изолента", ["Кувалда", "Насос"]],
	["Вмятина на крыле — дверь не закрывается", "Киянка", ["Свечной ключ", "Изолента"]],
	["Колесо спущено", "Насос", ["Ключ на 13", "Отвёртка"]],
	["Карбюратор захлебнулся", "Отвёртка", ["Кувалда", "Насос"]],
	["Глушитель отвалился", "Проволока", ["Свечной ключ", "Киянка"]],
]

var _job: Node
var _order: Array = []
var _step := 0
var _score := 0
var _title: Label
var _fault: Label
var _row: HBoxContainer
var _log: Label


func _ready() -> void:
	_setup("repair_ui", "РЕМОНТ «НИВЫ»", 600, Color(1.0, 0.75, 0.4))
	_title = UiKit.label("", 17, Color(1, 1, 1, 0.7))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_title)
	_fault = UiKit.label("", 22, Color(1, 0.9, 0.6))
	_fault.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fault.autowrap_mode = TextServer.AUTOWRAP_WORD
	body.add_child(_fault)
	_row = ModalUi.row(10)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(_row)
	_log = UiKit.label("", 16, Color(0.8, 1, 0.8))
	_log.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD
	body.add_child(_log)
	body.add_child(UiKit.button("Бросить (Esc)", close))


func open(job: Node) -> void:
	_job = job
	_order = FAULTS.duplicate()
	_order.shuffle()
	_order = _order.slice(0, 4)
	_step = 0
	_score = 0
	_log.text = "Гена: «Глянь, а? Я в моторах не шарю…»"
	_next()
	_show()


func _next() -> void:
	ModalUi.clear(_row)
	if _step >= _order.size():
		var ok := _score >= 3
		_job.finished(ok)
		close()
		return
	var f: Array = _order[_step]
	_title.text = "Поломка %d из %d · починено: %d" % [_step + 1, _order.size(), _score]
	_fault.text = f[0]
	var tools: Array = [f[1]] + f[2]
	tools.shuffle()
	for t in tools:
		var name: String = t
		_row.add_child(UiKit.button(name, func() -> void: _pick(name)))


func _pick(tool: String) -> void:
	var f: Array = _order[_step]
	Sfx.play("hammer", null, -6.0, 0.2)
	var slip := randf() < Inventory.drunk / 100.0 * 0.35
	if slip:
		_log.text = "%s выскользнул из рук и улетел под машину…" % tool
	elif tool == f[1]:
		_score += 1
		_log.text = ["Готово!", "Подтянул — держится!", "Вот так-то лучше"].pick_random()
	else:
		_log.text = "%s тут не поможет… Гена хватается за голову" % tool
	_step += 1
	_next()
