extends Node
## Глобальная шина событий (автозагрузка Events).

## Всплывающее сообщение в углу экрана.
signal toast(text: String, color: Color)
## Затемнение экрана (вырубился / нокаут).
signal blackout(text: String)
## Начался новый день (после сна).
signal new_day(day: int)

## true, пока открыто какое-то окно — игрок не ходит и не ловит.
var ui_open: bool = false


const FEMALE := ["Зина", "Люда", "Невеста", "Тётя Валя"]
const OLD := ["Баба Зоя", "Бабка"]


func notify(text: String, color: Color = Color.WHITE, speak := true) -> void:
	toast.emit(text, color)
	if not speak:
		return
	# Реплика NPC («Имя: «…»») — бормочем «по-симски».
	var i := text.find(": «")
	if i > 0 and i < 30:
		var who := text.substr(0, i)
		var voice := "m"
		if who in OLD:
			voice = "old"
		elif who in FEMALE:
			voice = "f"
		elif who.begins_with("Дядя") or who.begins_with("Михалыч") or who.begins_with("Участковый"):
			voice = "m_low"
		var me := get_tree().get_first_node_in_group("local_player") as Node3D
		Sfx.say(Vector3.ZERO, voice, text)
