class_name Chatter
extends Node
## Живые реплики NPC: когда подходишь близко, человек что-то говорит — текстом над головой и голосом
## (Sfx.say: понятная речь или бормотание). Только у себя на экране, по очереди, не чаще раза в полминуты.

var lines: Array = []
var voice := "m"
var radius := 5.0
var height := 2.35
var _label: Label3D
var _cool := 0.0
var _last := -1
var _check := 0.0
var _was_near := false
var condition: Callable = Callable()   ## если задано — говорит, только когда вернёт true

static var _global_until := 0.0        ## чтобы двое не говорили разом


static func attach(npc: Node3D, voice_id: String, phrases: Array, h := 2.35, r := 5.0) -> Chatter:
	var c := Chatter.new()
	c.voice = voice_id
	c.lines = phrases
	c.height = h
	c.radius = r
	npc.add_child(c)
	return c


func _ready() -> void:
	_label = Build.text(get_parent() as Node3D, Vector3(0, height, 0), "", 34, Color(1, 1, 0.85), 0.006, 0.0, true)
	_label.no_depth_test = false
	_label.outline_size = 8
	_cool = randf_range(2.0, 6.0)


func _process(delta: float) -> void:
	_cool -= delta
	_label.modulate.a = maxf(_label.modulate.a - delta * 0.22, 0.0)
	_label.visible = _label.modulate.a > 0.02
	_check -= delta
	if _check > 0.0:
		return
	_check = 0.4
	if not Net.is_online() or lines.is_empty() or Events.ui_open:
		return
	var me := get_tree().get_first_node_in_group("local_player") as Node3D
	var npc := get_parent() as Node3D
	if me == null or not npc.is_visible_in_tree():
		return
	var near := me.global_position.distance_to(npc.global_position) < radius
	# говорит, когда подошёл (а не всё время, пока стоишь рядом)
	if near and (not _was_near or _cool < -20.0) and _cool <= 0.0 and Time.get_ticks_msec() / 1000.0 > _global_until:
		if condition.is_valid() and not condition.call():
			_was_near = near
			return
		speak()
	_was_near = near


func speak(text := "") -> void:
	if text == "":
		var i := randi() % lines.size()
		if i == _last and lines.size() > 1:
			i = (i + 1) % lines.size()
		_last = i
		var l = lines[i]
		text = l.call() if l is Callable else String(l)
	_label.text = text
	_label.modulate.a = 1.0
	_cool = randf_range(25.0, 40.0)
	_global_until = Time.get_ticks_msec() / 1000.0 + 4.0
	Sfx.say((get_parent() as Node3D).global_position + Vector3.UP * (height - 0.6), voice, text)
