extends Node
## Следит за репликой NPC в окне (Label) и, когда текст меняется, бормочет «по-симски» голосом voice().

var label: Label
var voice: Callable
var _last := ""


func _process(_delta: float) -> void:
	if label == null or not label.is_visible_in_tree():
		_last = label.text if label else ""
		return
	if label.text != _last:
		_last = label.text
		if _last.length() > 3 and not _last.begins_with("*"):
			var me := get_tree().get_first_node_in_group("local_player") as Node3D
			var at := me.global_position + Vector3.UP * 1.6 if me else Vector3.ZERO
			Sfx.say(at, String(voice.call()), _last)


static func attach(ui: Node, l: Label, v: Callable) -> void:
	var w: Node = load("res://scripts/ui/speech_watch.gd").new()
	w.label = l
	w.voice = v
	ui.add_child(w)
